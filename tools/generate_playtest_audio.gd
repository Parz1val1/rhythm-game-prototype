## Generates restrained, sample-free backing loops for the Combat V1 playtest.
##
## The three stereo WAV files share an exact eight-bar, 130 BPM timeline so the
## harness can switch between them without moving the BeatClock.
extends SceneTree

const SAMPLE_RATE: int = 44100
const BPM: float = 130.0
const BEATS_PER_BAR: int = 4
const BARS: int = 8
const TOTAL_BEATS: int = BEATS_PER_BAR * BARS
const SECONDS_PER_BEAT: float = 60.0 / BPM
const FRAME_COUNT: int = 651323
const OUTPUT_DIRECTORY: String = "res://audio/playtest_v1"

class Mix:
	extends RefCounted

	var left := PackedFloat32Array()
	var right := PackedFloat32Array()

	func _init() -> void:
		left.resize(FRAME_COUNT)
		right.resize(FRAME_COUNT)
		left.fill(0.0)
		right.fill(0.0)

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	_write_wave("campfire_strings.wav", _compose_campfire_strings())
	_write_wave("stonebeat.wav", _compose_stonebeat())
	_write_wave("starcurrent.wav", _compose_starcurrent())
	print("=== done ===")
	quit()

func _midi(note: int) -> float:
	return 440.0 * pow(2.0, float(note - 69) / 12.0)

func _pan_gains(pan: float) -> Vector2:
	var angle := (pan + 1.0) * PI / 4.0
	return Vector2(cos(angle), sin(angle))

func _add_pluck(
	mix: Mix,
	beat: float,
	note: int,
	amplitude: float,
	pan: float,
	decay_seconds: float = 1.15,
	brightness: float = 1.0
) -> void:
	var start := int(round(beat * SECONDS_PER_BEAT * SAMPLE_RATE)) % FRAME_COUNT
	var frame_total := int(round(decay_seconds * SAMPLE_RATE))
	var frequency := _midi(note)
	var gains := _pan_gains(pan)
	var phase_step := TAU * frequency / SAMPLE_RATE
	for local_frame in range(frame_total):
		var time := float(local_frame) / SAMPLE_RATE
		var attack := minf(1.0, time / 0.006)
		var envelope := attack * exp(-4.8 * time / decay_seconds)
		var phase := phase_step * local_frame
		var body := (
			sin(phase)
			+ 0.42 * brightness * sin(2.003 * phase + 0.12)
			+ 0.18 * brightness * sin(3.997 * phase + 0.31)
			+ 0.08 * brightness * sin(7.01 * phase)
		) / (1.0 + 0.68 * brightness)
		var sample := amplitude * envelope * body
		var target := (start + local_frame) % FRAME_COUNT
		mix.left[target] += sample * gains.x
		mix.right[target] += sample * gains.y

func _add_low_thump(mix: Mix, beat: float, amplitude: float, pan: float = 0.0) -> void:
	var start := int(round(beat * SECONDS_PER_BEAT * SAMPLE_RATE)) % FRAME_COUNT
	var frame_total := int(round(0.24 * SAMPLE_RATE))
	var gains := _pan_gains(pan)
	var phase := 0.0
	for local_frame in range(frame_total):
		var time := float(local_frame) / SAMPLE_RATE
		var frequency := 78.0 - 34.0 * minf(1.0, time / 0.18)
		phase += TAU * frequency / SAMPLE_RATE
		var envelope := minf(1.0, time / 0.002) * exp(-22.0 * time)
		var sample := amplitude * envelope * sin(phase)
		var target := (start + local_frame) % FRAME_COUNT
		mix.left[target] += sample * gains.x
		mix.right[target] += sample * gains.y

func _add_wood_hit(
	mix: Mix, beat: float, amplitude: float, pan: float, random_seed: int
) -> void:
	var start := int(round(beat * SECONDS_PER_BEAT * SAMPLE_RATE)) % FRAME_COUNT
	var frame_total := int(round(0.18 * SAMPLE_RATE))
	var gains := _pan_gains(pan)
	var random := RandomNumberGenerator.new()
	random.seed = random_seed
	var previous_noise := 0.0
	for local_frame in range(frame_total):
		var time := float(local_frame) / SAMPLE_RATE
		var envelope := minf(1.0, time / 0.0015) * exp(-31.0 * time)
		var noise := random.randf_range(-1.0, 1.0)
		var click := noise - previous_noise
		previous_noise = noise
		var tone := sin(TAU * 286.0 * time) + 0.38 * sin(TAU * 571.0 * time)
		var sample := amplitude * envelope * (0.72 * tone + 0.18 * click)
		var target := (start + local_frame) % FRAME_COUNT
		mix.left[target] += sample * gains.x
		mix.right[target] += sample * gains.y

func _add_shaker(
	mix: Mix, beat: float, amplitude: float, pan: float, random_seed: int
) -> void:
	var start := int(round(beat * SECONDS_PER_BEAT * SAMPLE_RATE)) % FRAME_COUNT
	var frame_total := int(round(0.075 * SAMPLE_RATE))
	var gains := _pan_gains(pan)
	var random := RandomNumberGenerator.new()
	random.seed = random_seed
	var previous_noise := 0.0
	for local_frame in range(frame_total):
		var time := float(local_frame) / SAMPLE_RATE
		var envelope := minf(1.0, time / 0.001) * exp(-58.0 * time)
		var noise := random.randf_range(-1.0, 1.0)
		var high_passed := noise - 0.82 * previous_noise
		previous_noise = noise
		var sample := amplitude * envelope * high_passed
		var target := (start + local_frame) % FRAME_COUNT
		mix.left[target] += sample * gains.x
		mix.right[target] += sample * gains.y

func _add_looping_pad(
	mix: Mix, note: int, amplitude: float, pan: float, phase_offset: float
) -> void:
	var loop_seconds := float(FRAME_COUNT) / SAMPLE_RATE
	var frequency: float = round(_midi(note) * loop_seconds) / loop_seconds
	var gains := _pan_gains(pan)
	for frame in range(FRAME_COUNT):
		var normalized := float(frame) / FRAME_COUNT
		var phase: float = TAU * frequency * (float(frame) / SAMPLE_RATE) + phase_offset
		var movement := 0.72 + 0.28 * sin(TAU * 4.0 * normalized + phase_offset)
		var shimmer := sin(phase) + 0.2 * sin(2.0 * phase + 0.7)
		var sample := amplitude * movement * shimmer / 1.2
		mix.left[frame] += sample * gains.x
		mix.right[frame] += sample * gains.y

func _compose_campfire_strings() -> Mix:
	var mix := Mix.new()
	var progression: Array[Array] = [
		[50, 57, 62, 65], # Dm
		[46, 53, 58, 62], # Bb
		[48, 55, 60, 64], # C
		[45, 52, 57, 60], # Am
	]
	for bar in range(BARS):
		var start := float(bar * BEATS_PER_BAR)
		var chord: Array = progression[bar % progression.size()]
		for string_index in range(chord.size()):
			_add_pluck(
				mix,
				start + 0.055 * string_index,
				chord[string_index],
				0.105,
				-0.48 + 0.32 * string_index,
				1.65,
				0.75
			)
		_add_pluck(mix, start + 2.0, chord[0] + 12, 0.065, -0.28, 0.95, 0.55)
		_add_pluck(mix, start + 3.0, chord[2], 0.055, 0.28, 0.8, 0.45)
		for local_beat in range(BEATS_PER_BAR):
			var beat := start + local_beat
			_add_low_thump(mix, beat, 0.027 if local_beat in [0, 2] else 0.015)
			_add_shaker(
				mix,
				beat + 0.5,
				0.009,
				0.2 if local_beat % 2 else -0.2,
				100 + bar * 4 + local_beat
			)
	return mix

func _compose_stonebeat() -> Mix:
	var mix := Mix.new()
	var roots: Array[int] = [38, 38, 34, 34, 36, 36, 33, 33]
	for bar in range(BARS):
		var start := float(bar * BEATS_PER_BAR)
		var root := roots[bar]
		_add_pluck(mix, start, root, 0.13, -0.12, 1.05, 0.28)
		_add_pluck(mix, start + 2.5, root + 7, 0.06, 0.22, 0.62, 0.2)
		for local_beat in range(BEATS_PER_BAR):
			var beat := start + local_beat
			if local_beat in [0, 2]:
				_add_low_thump(mix, beat, 0.09 if local_beat == 0 else 0.066, -0.08)
			else:
				_add_wood_hit(mix, beat, 0.052, 0.28, 200 + bar * 4 + local_beat)
			_add_shaker(
				mix,
				beat + 0.5,
				0.012,
				-0.35 if local_beat % 2 else 0.35,
				300 + bar * 4 + local_beat
			)
		_add_wood_hit(mix, start + 3.75, 0.022, -0.28, 400 + bar)
	return mix

func _compose_starcurrent() -> Mix:
	var mix := Mix.new()
	var pad_voices: Array[Array] = [
		[50, 0.042, -0.5, 0.0],
		[57, 0.034, 0.5, 1.1],
		[60, 0.023, -0.1, 2.0],
		[65, 0.018, 0.2, 2.8],
	]
	for voice in pad_voices:
		_add_looping_pad(mix, voice[0], voice[1], voice[2], voice[3])
	var constellation: Array[int] = [74, 77, 81, 72, 76, 79, 69, 72]
	for bar in range(BARS):
		var start := float(bar * BEATS_PER_BAR)
		var note := constellation[bar]
		_add_pluck(
			mix,
			start + (0.0 if bar % 2 == 0 else 0.5),
			note,
			0.055,
			-0.55 + 0.16 * bar,
			2.1,
			1.25
		)
		if bar % 2 == 1:
			_add_pluck(mix, start + 2.75, note - 12, 0.032, 0.35, 1.4, 0.8)
		for local_beat in range(BEATS_PER_BAR):
			_add_low_thump(mix, start + local_beat, 0.012)
	return mix

func _master(mix: Mix) -> Vector2:
	var peak := 0.0
	var energy := 0.0
	for frame in range(FRAME_COUNT):
		peak = maxf(peak, maxf(absf(mix.left[frame]), absf(mix.right[frame])))
		energy += mix.left[frame] * mix.left[frame]
		energy += mix.right[frame] * mix.right[frame]
	var rms := sqrt(energy / (2.0 * FRAME_COUNT))
	var gain := minf(0.075 / maxf(rms, 0.000000001), 0.52 / maxf(peak, 0.000000001))
	for frame in range(FRAME_COUNT):
		mix.left[frame] *= gain
		mix.right[frame] *= gain
	return Vector2(rms * gain, peak * gain)

func _write_wave(filename: String, mix: Mix) -> void:
	var levels := _master(mix)
	var pcm := PackedByteArray()
	pcm.resize(FRAME_COUNT * 4)
	for frame in range(FRAME_COUNT):
		pcm.encode_s16(frame * 4, int(round(clampf(mix.left[frame], -1.0, 1.0) * 32767.0)))
		pcm.encode_s16(frame * 4 + 2, int(round(clampf(mix.right[frame], -1.0, 1.0) * 32767.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = true
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = FRAME_COUNT
	stream.data = pcm
	var path := "%s/%s" % [OUTPUT_DIRECTORY, filename]
	var error := stream.save_to_wav(path)
	if error != OK:
		printerr("FAIL: could not write %s (error %d)" % [path, error])
		quit(1)
		return
	print(
		"%s: %d frames, %.6fs, RMS=%.4f, peak=%.4f" % [
			filename,
			FRAME_COUNT,
			float(FRAME_COUNT) / SAMPLE_RATE,
			levels.x,
			levels.y,
		]
	)
