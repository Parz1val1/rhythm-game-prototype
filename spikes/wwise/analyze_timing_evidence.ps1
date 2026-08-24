param(
    [Parameter(Mandatory = $true)]
    [string] $Path
)

$resolvedPaths = @(Resolve-Path -Path $Path)
if ($resolvedPaths.Count -ne 1) {
    throw "Expected exactly one evidence CSV, resolved $($resolvedPaths.Count)."
}
$resolvedPath = $resolvedPaths[0].Path
$summaryPath = [System.IO.Path]::ChangeExtension($resolvedPath, '.json')
if (-not (Test-Path -LiteralPath $summaryPath)) {
    throw "Expected evidence summary beside CSV: $summaryPath"
}
$summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
$requiredPositionMetrics = @(
    'position_samples',
    'position_discontinuities',
    'rejected_position_samples',
    'backward_position_samples',
    'max_position_delta_error_ms',
    'position_discontinuity_threshold_ms'
)
foreach ($metric in $requiredPositionMetrics) {
    if ($null -eq $summary.PSObject.Properties[$metric]) {
        throw "Evidence summary predates position-discontinuity instrumentation: missing '$metric'."
    }
}
$rows = @(Import-Csv -LiteralPath $resolvedPath)
$boundaryRows = @($rows | Where-Object { $_.record_type -eq 'boundary' })
$positionDiscontinuityRows = @($rows | Where-Object { $_.record_type -eq 'position_discontinuity' })
$positionRegressionRows = @($rows | Where-Object { $_.record_type -eq 'position_regression' })
$positionAnomalyRows = @($positionDiscontinuityRows + $positionRegressionRows)

$steps = foreach ($row in $boundaryRows) {
    $beat = [int] $row.index
    switch ($row.kind) {
        'beat' { $beat * 4; break }
        'half' { $beat * 4 + 2; break }
        'quarter' {
            if ($row.value -eq '0.25') { $beat * 4 + 1 }
            elseif ($row.value -eq '0.75') { $beat * 4 + 3 }
            else { throw "Unknown quarter subdivision '$($row.value)'" }
            break
        }
        default { throw "Unknown boundary kind '$($row.kind)'" }
    }
}

$missed = 0
$duplicates = 0
$nonMonotonic = 0
$lastStep = $null
foreach ($step in $steps) {
    if ($null -eq $lastStep) {
        if ($step -gt 1) { $missed += $step - 1 }
    }
    elseif ($step -eq $lastStep) {
        $duplicates += 1
    }
    elseif ($step -lt $lastStep) {
        $nonMonotonic += 1
    }
    elseif ($step -gt $lastStep + 1) {
        $missed += $step - $lastStep - 1
    }
    $lastStep = [math]::Max($step, $lastStep)
}

$result = [ordered]@{
    path = $resolvedPath
    recorded_boundaries = $steps.Count
    first_quarter_step = if ($steps.Count -gt 0) { $steps[0] } else { $null }
    last_quarter_step = if ($steps.Count -gt 0) { $steps[-1] } else { $null }
    whole_beats = @($boundaryRows | Where-Object { $_.kind -eq 'beat' }).Count
    half_beats = @($boundaryRows | Where-Object { $_.kind -eq 'half' }).Count
    quarter_beats = @($boundaryRows | Where-Object { $_.kind -eq 'quarter' }).Count
    missed_boundaries = $missed
    duplicate_boundaries = $duplicates
    non_monotonic_boundaries = $nonMonotonic
    position_samples = [int] $summary.position_samples
    position_discontinuities = [int] $summary.position_discontinuities
    rejected_position_samples = [int] $summary.rejected_position_samples
    backward_position_samples = [int] $summary.backward_position_samples
    max_position_delta_error_ms = [double] $summary.max_position_delta_error_ms
    position_discontinuity_threshold_ms = [double] $summary.position_discontinuity_threshold_ms
    raw_position_discontinuity_records = $positionDiscontinuityRows.Count
    raw_position_regression_records = $positionRegressionRows.Count
}

$result | ConvertTo-Json
if ($positionDiscontinuityRows.Count -ne [int] $summary.position_discontinuities) {
    Write-Error 'Raw discontinuity records do not match the evidence summary.'
    exit 1
}
$rawRejectedPositionSamples = @($positionAnomalyRows | Where-Object { $_.value -eq 'accepted=false' }).Count
if ($rawRejectedPositionSamples -ne [int] $summary.rejected_position_samples) {
    Write-Error 'Raw rejected-position records do not match the evidence summary.'
    exit 1
}
if ($missed -ne 0 -or $duplicates -ne 0 -or $nonMonotonic -ne 0) {
    Write-Error 'Timing evidence contains missing, duplicate, or non-monotonic musical boundaries.'
    exit 1
}

Write-Output '=== done ==='
