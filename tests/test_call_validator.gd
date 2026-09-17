## P2-01: CallValidator catches broken call data and accepts the authored slice call.
extends GutTest


func _valid_call() -> CallData:
	var start: DialogueNode = DialogueNode.new()
	start.id = &"start"
	start.line = "Hello?"
	start.auto_next = &"end"
	var end: DialogueNode = DialogueNode.new()
	end.id = &"end"
	end.line = "(click)"
	var graph: DialogueGraph = DialogueGraph.new()
	graph.nodes = [start, end]

	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	var profile: StressProfile = StressProfile.new()
	profile.tremor_curve = curve

	var call: CallData = CallData.new()
	call.id = &"call_test"
	call.title = "Test call"
	call.truth = CallData.Truth.GENUINE
	call.dialogue = graph
	call.stress_profile = profile
	return call


func _errors(call: CallData) -> PackedStringArray:
	var result: Dictionary = CallValidator.validate(call)
	return result["errors"]


func _warnings(call: CallData) -> PackedStringArray:
	var result: Dictionary = CallValidator.validate(call)
	return result["warnings"]


func test_valid_call_has_no_errors() -> void:
	assert_eq(_errors(_valid_call()).size(), 0)


func test_empty_id_is_an_error() -> void:
	var call: CallData = _valid_call()
	call.id = &""
	assert_true(" ".join(_errors(call)).contains("id is empty"))


func test_earliest_minute_outside_shift_is_an_error() -> void:
	var call: CallData = _valid_call()
	call.earliest_minute = 400
	assert_true(" ".join(_errors(call)).contains("outside the shift"))


func test_missing_dialogue_is_an_error() -> void:
	var call: CallData = _valid_call()
	call.dialogue = null
	assert_true(" ".join(_errors(call)).contains("dialogue graph is missing"))


func test_broken_dialogue_link_is_reported_through_call() -> void:
	var call: CallData = _valid_call()
	call.dialogue.nodes[0].auto_next = &"nowhere"
	assert_true(" ".join(_errors(call)).contains("auto_next 'nowhere' does not exist"))


func test_bad_loop_segment_is_an_error() -> void:
	var call: CallData = _valid_call()
	call.stress_profile.loop_segments = [Vector2(5.0, 2.0)]
	assert_true(" ".join(_errors(call)).contains("loop segment"))


func test_duplicate_record_ids_are_an_error() -> void:
	var call: CallData = _valid_call()
	var a: RecordEntry = RecordEntry.new()
	a.id = &"rec_a"
	a.content = "x"
	var b: RecordEntry = RecordEntry.new()
	b.id = &"rec_a"
	b.content = "y"
	call.records = [a, b]
	assert_true(" ".join(_errors(call)).contains("duplicate record id"))


func test_deceptive_call_without_clues_warns() -> void:
	var call: CallData = _valid_call()
	call.truth = CallData.Truth.AMBUSH
	assert_true(" ".join(_warnings(call)).contains("no clue"))


func test_paranormal_without_emf_warns() -> void:
	var call: CallData = _valid_call()
	call.truth = CallData.Truth.PARANORMAL
	assert_true(" ".join(_warnings(call)).contains("emf_frequency"))


func test_authored_calls_directory_is_valid() -> void:
	var results: Dictionary = CallValidator.validate_directory()
	assert_gt(results.size(), 0, "at least one authored call exists")
	var counts: Dictionary = {}
	var report: String = CallValidator.format_report(results, counts)
	var error_count: int = counts["errors"]
	assert_eq(error_count, 0, report)


func test_slice_call_closet_monster_loads() -> void:
	var call: CallData = load("res://data/calls/slice/call_closet_monster.tres") as CallData
	assert_not_null(call)
	assert_eq(call.id, &"call_closet_monster")
	assert_eq(call.truth, CallData.Truth.PRANK)
	assert_true(call.stress_profile.background_tags.has(&"adult_breathing"))


func test_shift_one_has_ten_branching_calls() -> void:
	var truths: Dictionary[int, int] = {}
	var minutes: Array[int] = []
	var ids: Array[StringName] = [&"call_highway_crash", &"call_cut_line", &"call_meat_truck", &"call_lost_child",
		&"call_drowned_voice", &"call_domestic", &"call_gas_station", &"call_church_bells", &"call_overdose", &"call_last_call"]
	for id: StringName in ids:
		var call: CallData = load("res://data/calls/shift1/%s.tres" % id) as CallData
		assert_not_null(call, String(id))
		var result: Dictionary = CallValidator.validate(call)
		var errors: PackedStringArray = result["errors"]
		assert_eq(errors.size(), 0, "%s: %s" % [id, errors])
		truths[call.truth] = truths.get(call.truth, 0) + 1
		minutes.append(call.earliest_minute)
		var branching: int = 0
		var class_choices: int = 0
		var endings: int = 0
		for node: DialogueNode in call.dialogue.nodes:
			if node.choices.size() >= 2:
				branching += 1
			if node.choices.is_empty() and node.auto_next == &"":
				endings += 1
			for choice: DialogueChoice in node.choices:
				if choice.required_class != &"":
					class_choices += 1
		assert_gte(call.dialogue.nodes.size(), 10, "%s is a real conversation" % id)
		assert_gte(branching, 4, "%s has several decision points" % id)
		assert_gt(class_choices, 0, "%s has class-only questions" % id)
		assert_gte(endings, 1, "%s can end" % id)
	assert_eq(truths.size(), 5, "every truth type appears in the shift")
	var sorted: Array[int] = minutes.duplicate()
	sorted.sort()
	assert_eq(minutes, sorted, "calls are spread through the shift in order")
	assert_lt(minutes[minutes.size() - 1], CallValidator.SHIFT_MINUTES)


func test_evidence_gated_question_unlocks_after_reveal() -> void:
	var call: CallData = load("res://data/calls/shift1/call_cut_line.tres") as CallData
	var runner: DialogueRunner = DialogueRunner.new()
	runner.start(call.dialogue, 150.0)
	assert_true(_pick(runner, &"tech"))
	assert_eq(runner.current_node_id, &"address")
	assert_false(_pick(runner, &"medic"), "tech-only question")
	assert_true(_pick(runner, &"tech"))
	assert_true(&"vacant_address" in runner.revealed_evidence)
	runner.tick(4.0)
	assert_eq(runner.current_node_id, &"tech_after")
	assert_true(_pick(runner, &"tech"), "confrontation unlocked by evidence")
	assert_eq(runner.current_node_id, &"confront_power")


func _pick(runner: DialogueRunner, class_id: StringName) -> bool:
	var result: Dictionary = runner.select_choice(0, class_id)
	var success: bool = result.get("success", false)
	return success
