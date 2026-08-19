param(
    [Parameter(Mandatory = $true)]
    [string] $Path
)

$resolvedPaths = @(Resolve-Path -Path $Path)
if ($resolvedPaths.Count -ne 1) {
    throw "Expected exactly one evidence CSV, resolved $($resolvedPaths.Count)."
}
$resolvedPath = $resolvedPaths[0].Path
$rows = @(Import-Csv -LiteralPath $resolvedPath)
$boundaryRows = @($rows | Where-Object { $_.record_type -eq 'boundary' })

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
}

$result | ConvertTo-Json
if ($missed -ne 0 -or $duplicates -ne 0 -or $nonMonotonic -ne 0) {
    Write-Error 'Timing evidence contains missing, duplicate, or non-monotonic subdivisions.'
    exit 1
}

Write-Output '=== done ==='
