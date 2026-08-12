# Verifies Response execution through the public CombatV1ResponseGrader interface.
extends SceneTree

var _has_failures: bool = false

func _init() -> void:
	_run()
	quit(1 if _has_failures else 0)

func _run() -> void:
	print("=== Combat V1 Response-grader tests ===")
	var GraderScript = load("res://combat_v1/response_grader.gd")
	if GraderScript == null:
		_check("Response grader module loads", false, true)
		print("=== done ===")
		return

	var config = GraderScript.Config.new()
	config.perfect_ms = 40.0
	config.great_ms = 70.0
	config.good_ms = 110.0
	config.near_miss_ms = 160.0
	config.miss_ms = 230.0
	config.major_mistakes_to_break_phrase = 2
	var grader = GraderScript.new()
	grader.setup(config)
	var result: Dictionary = grader.grade_note(&"up", &"up", 40.0)
	_check("matching input at the configured Perfect boundary is Perfect", result[&"grade"], GraderScript.Grade.PERFECT)
	result = grader.grade_note(&"up", &"up", -70.0)
	_check("matching input at the configured Great boundary is Great", result[&"grade"], GraderScript.Grade.GREAT)
	result = grader.grade_note(&"up", &"up", 110.0)
	_check("matching input at the configured Good boundary is Good", result[&"grade"], GraderScript.Grade.GOOD)
	result = grader.grade_note(&"up", &"up", -160.0)
	_check("matching input at the configured Near Miss boundary is Near Miss", result[&"grade"], GraderScript.Grade.NEAR_MISS)
	result = grader.grade_note(&"up", &"up", 230.0)
	_check("matching input at the configured Miss boundary is Miss", result[&"grade"], GraderScript.Grade.MISS)
	result = grader.grade_note(&"up", &"up", 230.1)
	_check("input beyond the configured Miss boundary is a Major Mistake", result[&"grade"], GraderScript.Grade.MAJOR_MISTAKE)
	result = grader.grade_note(&"up", &"left", 0.0)
	_check("wrong action at the correct time is a Miss", result[&"grade"], GraderScript.Grade.MISS)
	result = grader.grade_note(&"up", &"", 230.1)
	_check("an unplayed note beyond its window remains a Major Mistake", result[&"grade"], GraderScript.Grade.MAJOR_MISTAKE)
	_check("note results expose the grade name", result[&"grade_name"], &"major_mistake")

	var perfect_phrase: Array[Dictionary] = []
	perfect_phrase.append(grader.grade_note(&"up", &"up", 0.0))
	perfect_phrase.append(grader.grade_note(&"right", &"right", 20.0))
	perfect_phrase.append(grader.grade_note(&"down", &"down", -35.0))
	var summary: Dictionary = grader.summarize(perfect_phrase)
	_check("an all-Perfect phrase has a Perfect phrase grade", summary[&"grade"], GraderScript.Grade.PERFECT)
	_check(
		"an all-Great phrase has a Great phrase grade",
		_summarize_one(grader, grader.grade_note(&"up", &"up", 70.0))[&"grade"],
		GraderScript.Grade.GREAT
	)
	_check(
		"an all-Good phrase has a Good phrase grade",
		_summarize_one(grader, grader.grade_note(&"up", &"up", 110.0))[&"grade"],
		GraderScript.Grade.GOOD
	)
	_check(
		"an all-Near-Miss phrase has a Near Miss phrase grade",
		_summarize_one(grader, grader.grade_note(&"up", &"up", 160.0))[&"grade"],
		GraderScript.Grade.NEAR_MISS
	)
	_check(
		"an all-Miss phrase has a Miss phrase grade",
		_summarize_one(grader, grader.grade_note(&"up", &"up", 230.0))[&"grade"],
		GraderScript.Grade.MISS
	)
	_check(
		"an all-Major-Mistake phrase is broken",
		_summarize_one(grader, grader.grade_note(&"up", &"up", 230.1))[&"grade"],
		GraderScript.Grade.MAJOR_MISTAKE
	)

	var recovered_phrase: Array[Dictionary] = []
	recovered_phrase.append(grader.grade_note(&"up", &"up", 0.0))
	recovered_phrase.append(grader.grade_note(&"right", &"left", 0.0))
	recovered_phrase.append(grader.grade_note(&"down", &"down", 10.0))
	recovered_phrase.append(grader.grade_note(&"left", &"left", -10.0))
	recovered_phrase.append(grader.grade_note(&"up", &"up", 15.0))
	summary = grader.summarize(recovered_phrase)
	_check("strong later notes recover a phrase after one Miss", summary[&"grade"], GraderScript.Grade.GREAT)
	_check(
		"phrase summary reports every note-grade count",
		summary[&"grade_counts"],
		{
			&"perfect": 4,
			&"great": 0,
			&"good": 0,
			&"near_miss": 0,
			&"miss": 1,
			&"major_mistake": 0,
		}
	)
	var strict_config = GraderScript.Config.new()
	strict_config.phrase_great_min_score = 4.5
	var strict_grader = GraderScript.new()
	strict_grader.setup(strict_config)
	summary = strict_grader.summarize(recovered_phrase)
	_check("phrase-grade thresholds are configurable", summary[&"grade"], GraderScript.Grade.GOOD)

	var broken_phrase: Array[Dictionary] = []
	broken_phrase.append(grader.grade_note(&"up", &"", 230.1))
	broken_phrase.append(grader.grade_note(&"right", &"right", 0.0))
	broken_phrase.append(grader.grade_note(&"down", &"down", 0.0))
	broken_phrase.append(grader.grade_note(&"left", &"", 230.1))
	broken_phrase.append(grader.grade_note(&"up", &"up", 0.0))
	summary = grader.summarize(broken_phrase)
	_check("the configured major-mistake count marks a broken phrase", summary[&"grade"], GraderScript.Grade.MAJOR_MISTAKE)
	print("=== done ===")

func _summarize_one(grader, result: Dictionary) -> Dictionary:
	var results: Array[Dictionary] = []
	results.append(result)
	return grader.summarize(results)

func _check(label: String, got, expected) -> void:
	if got == expected:
		print("  PASS  %s" % label)
	else:
		_has_failures = true
		printerr("  FAIL  %s  ->  expected=%s  got=%s" % [label, expected, got])
