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


func test_shift_one_has_fifteen_branching_calls() -> void:
	var truths: Dictionary[int, int] = {}
	var minutes: Array[int] = []
	var ids: Array[StringName] = [&"call_highway_crash", &"call_willow_court", &"call_harbor_truck", &"call_lost_child",
		&"call_drowned_voice", &"call_domestic", &"call_gas_station", &"call_church_bells", &"call_overdose",
		&"call_deputy_down", &"call_home_invasion", &"call_school_threat", &"call_barn_fire", &"call_diner_hostage",
		&"call_last_call"]
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
	var call: CallData = load("res://data/calls/shift1/call_willow_court.tres") as CallData
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


func test_most_calls_are_genuine_or_ambush() -> void:
	var genuine: int = 0
	var ambush: int = 0
	var count: int = 0
	var dispatching: int = 0
	var arrest_options: int = 0
	for path: String in CallValidator._find_resources("res://data/calls/shift1"):
		var call: CallData = load(path) as CallData
		if call == null:
			continue
		count += 1
		if call.truth == CallData.Truth.GENUINE:
			genuine += 1
		elif call.truth == CallData.Truth.AMBUSH:
			ambush += 1
		var has_dispatch: bool = false
		for node: DialogueNode in call.dialogue.nodes:
			if &"dispatch_units" in node.on_enter_events:
				has_dispatch = true
			if &"dispatch_arrest" in node.on_enter_events:
				arrest_options += 1
		if has_dispatch:
			dispatching += 1
	assert_eq(count, 15, "fifteen calls this shift")
	assert_gte(genuine + ambush, 9, "most calls are worth rolling units for (%d genuine, %d ambush)" % [genuine, ambush])
	assert_gte(ambush, 4, "several ambushes")
	assert_gte(dispatching, 12, "most calls can dispatch the team from the conversation")
	assert_gte(arrest_options, 2, "prank callers can be arrested")


func test_calls_ring_early_in_the_shift() -> void:
	var minutes: Array[int] = []
	for path: String in CallValidator._find_resources("res://data/calls/shift1"):
		var call: CallData = load(path) as CallData
		if call != null:
			minutes.append(call.earliest_minute)
	minutes.sort()
	assert_lte(minutes[0], 3, "the first call comes almost immediately")
	var gaps: int = 0
	for i: int in range(1, minutes.size() - 1):
		gaps += minutes[i] - minutes[i - 1]
	var average_gap: float = float(gaps) / float(maxi(minutes.size() - 2, 1))
	assert_lte(average_gap, 8.0, "about five in-game minutes between calls (%.1f)" % average_gap)
