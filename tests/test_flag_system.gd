## FlagSystem (P4-01, ARCHITECTURE §7): flags, event log, consequence rules (immediate, delayed, next shift,
## ending), once-only firing, chaining, meters, JSON snapshot round trip, and the dialogue / call / EventBus
## integrations.
extends GutTest

var _rule_ids: Array[StringName] = []
var _trust_before: int = 0
var _cult_before: int = 0


func before_each() -> void:
	FlagSystem.reset()
	_trust_before = MissionDirector.public_trust
	_cult_before = GameState.cult_awareness
	CallDirector.shift_clock_minutes = 0


func after_each() -> void:
	for rule_id: StringName in _rule_ids:
		FlagSystem.unregister_rule(rule_id)
	_rule_ids.clear()
	FlagSystem.reset()
	MissionDirector.public_trust = _trust_before
	GameState.public_trust = _trust_before
	GameState.cult_awareness = _cult_before
	CallDirector.shift_clock_minutes = 0


func _flag_is(key: StringName, expected: Variant, default: Variant = null) -> bool:
	return FlagSystem.get_flag(key, default) == expected


func _effect(kind: FlagEffect.Kind, key: StringName, value: Variant = null, target: StringName = &"") -> FlagEffect:
	var effect: FlagEffect = FlagEffect.new()
	effect.kind = kind
	effect.key = key
	effect.value = value
	effect.target = target
	return effect


func _condition(key: StringName, op: FlagCondition.Op, value: Variant) -> FlagCondition:
	var condition: FlagCondition = FlagCondition.new()
	condition.key = key
	condition.op = op
	condition.value = value
	return condition


func _rule(id: StringName, trigger: StringName, effects: Array[FlagEffect],
		timing: ConsequenceRule.Timing = ConsequenceRule.Timing.IMMEDIATE, delay: int = 0,
		conditions: Array[FlagCondition] = [], once: bool = true) -> ConsequenceRule:
	var rule: ConsequenceRule = ConsequenceRule.new()
	rule.id = id
	rule.trigger_event = trigger
	rule.effects = effects
	rule.timing = timing
	rule.delay = delay
	rule.conditions = conditions
	rule.once = once
	FlagSystem.register_rule(rule)
	_rule_ids.append(id)
	return rule


func test_flags_set_emit_once_and_clear() -> void:
	watch_signals(EventBus)
	FlagSystem.set_flag(&"lake_house_cleared", true)
	FlagSystem.set_flag(&"lake_house_cleared", true)
	assert_true(_flag_is(&"lake_house_cleared", true))
	assert_signal_emit_count(EventBus, "flag_changed", 1, "unchanged values do not re-emit")
	assert_true(_flag_is(&"missing", 7, 7))
	FlagSystem.clear_flag(&"lake_house_cleared")
	assert_false(FlagSystem.has_flag(&"lake_house_cleared"))


func test_events_record_and_match_payloads() -> void:
	FlagSystem.record_event(&"call_ignored", {"call": &"closet_monster"})
	FlagSystem.record_event(&"call_classified", {"call": &"meat_truck", "verdict": &"ambush"})
	assert_true(FlagSystem.has_event(&"call_ignored"))
	assert_true(FlagSystem.has_event(&"call_ignored", &"closet_monster"))
	assert_false(FlagSystem.has_event(&"call_ignored", &"meat_truck"))
	assert_true(FlagSystem.has_event(&"call_classified", {"verdict": &"ambush"}))
	assert_false(FlagSystem.has_event(&"call_classified", {"verdict": &"genuine"}))
	assert_eq(FlagSystem.count_events(&"call_ignored"), 1)
	var event: Dictionary = FlagSystem.events[0]
	var shift: int = event["shift"]
	var minute: int = event["t"]
	assert_eq(shift, MissionDirector.shift_number)
	assert_eq(minute, 0)


func test_immediate_rule_runs_effects_once() -> void:
	_rule(&"test_ignored_closet", &"call_ignored", [
		_effect(FlagEffect.Kind.SET_FLAG, &"closet_teen_dead", true),
		_effect(FlagEffect.Kind.ADD_METER, &"ignored_calls", 1),
		_effect(FlagEffect.Kind.UNLOCK_MISSION, &"cult_hideout"),
	], ConsequenceRule.Timing.IMMEDIATE, 0,
		[_condition(&"call_ignored", FlagCondition.Op.HAS_EVENT, &"closet_monster")])
	FlagSystem.record_event(&"call_ignored", {"call": &"another_call"})
	assert_false(FlagSystem.has_flag(&"closet_teen_dead"), "the condition needs the closet call")
	FlagSystem.record_event(&"call_ignored", {"call": &"closet_monster"})
	assert_true(_flag_is(&"closet_teen_dead", true))
	assert_true(_flag_is(&"mission_unlocked_cult_hideout", true))
	assert_true(_flag_is(&"ignored_calls", 1))
	FlagSystem.record_event(&"call_ignored", {"call": &"closet_monster"})
	assert_true(_flag_is(&"ignored_calls", 1), "once rules fire a single time")
func test_repeatable_rule_and_flag_conditions() -> void:
	_rule(&"test_count_kills", &"hostile_killed", [_effect(FlagEffect.Kind.ADD_METER, &"kills", 1)],
		ConsequenceRule.Timing.IMMEDIATE, 0, [_condition(&"curfew", FlagCondition.Op.NEQ, true)], false)
	FlagSystem.record_event(&"hostile_killed")
	FlagSystem.record_event(&"hostile_killed")
	assert_true(_flag_is(&"kills", 2))
	FlagSystem.set_flag(&"curfew", true)
	FlagSystem.record_event(&"hostile_killed")
	assert_true(_flag_is(&"kills", 2))
func test_delayed_rule_waits_for_the_shift_clock() -> void:
	CallDirector.shift_clock_minutes = 30
	_rule(&"test_neighbour_report", &"call_ignored", [_effect(FlagEffect.Kind.SET_FLAG, &"blood_reported", true)],
		ConsequenceRule.Timing.DELAYED_MINUTES, 45)
	FlagSystem.record_event(&"call_ignored", {"call": &"closet_monster"})
	assert_eq(FlagSystem.pending.size(), 1)
	var due: int = FlagSystem.pending[0]["due_minute"]
	assert_eq(due, 75)
	FlagSystem.record_event(&"call_ignored", {"call": &"closet_monster"})
	assert_eq(FlagSystem.pending.size(), 1, "a pending once-rule is not scheduled twice")
	FlagSystem.tick(MissionDirector.shift_number, 74)
	assert_false(FlagSystem.has_flag(&"blood_reported"))
	FlagSystem.tick(MissionDirector.shift_number, 75)
	assert_true(_flag_is(&"blood_reported", true))
	assert_eq(FlagSystem.pending.size(), 0)


func test_next_shift_and_ending_rules() -> void:
	var shift: int = MissionDirector.shift_number
	_rule(&"test_next_shift", &"mission_success", [_effect(FlagEffect.Kind.SET_FLAG, &"press_interest", true)],
		ConsequenceRule.Timing.NEXT_SHIFT, 1)
	_rule(&"test_ending", &"mission_success", [_effect(FlagEffect.Kind.SET_FLAG, &"never_now", true)],
		ConsequenceRule.Timing.ENDING)
	FlagSystem.record_event(&"mission_success", {"call": &"meat_truck"})
	FlagSystem.tick(shift, 359)
	assert_false(FlagSystem.has_flag(&"press_interest"))
	FlagSystem.tick(shift + 1, 0)
	assert_true(_flag_is(&"press_interest", true))
	assert_true(&"test_ending" in FlagSystem.ending_candidates)
	assert_false(FlagSystem.has_flag(&"never_now"), "ending rules are resolved at the ending, not now")


func test_spawned_events_chain_and_loops_stop() -> void:
	_rule(&"test_chain_a", &"arrest_made", [_effect(FlagEffect.Kind.SPAWN_EVENT, &"press_conference")])
	_rule(&"test_chain_b", &"press_conference", [_effect(FlagEffect.Kind.SET_FLAG, &"on_tv", true)])
	FlagSystem.record_event(&"arrest_made")
	assert_true(_flag_is(&"on_tv", true))
	_rule(&"test_loop", &"echo", [_effect(FlagEffect.Kind.SPAWN_EVENT, &"echo")], ConsequenceRule.Timing.IMMEDIATE,
		0, [], false)
	FlagSystem.record_event(&"echo")
	assert_eq(FlagSystem.count_events(&"echo"), FlagSystem.MAX_CHAIN_DEPTH + 1, "a self-triggering rule stops")


func test_global_meters_go_through_their_owners() -> void:
	_rule(&"test_meters", &"press_leak", [
		_effect(FlagEffect.Kind.ADD_METER, &"public_trust", -20),
		_effect(FlagEffect.Kind.ADD_METER, &"cult_awareness", "15"),
	])
	FlagSystem.record_event(&"press_leak")
	assert_eq(MissionDirector.public_trust, clampi(_trust_before - 20, 0, 100))
	assert_eq(GameState.public_trust, MissionDirector.public_trust)
	assert_eq(GameState.cult_awareness, clampi(_cult_before + 15, 0, 100))


func test_traits_target_the_caller_peer() -> void:
	_rule(&"test_guilt", &"civilian_shot", [_effect(FlagEffect.Kind.APPLY_TRAIT, &"ptsd", 2, &"caller_peer")])
	FlagSystem.record_event(&"civilian_shot", {"peer_id": 1})
	assert_true(TraitSystem.has_trait(1, &"ptsd"))
	TraitSystem.remove(1, &"ptsd")


func test_queue_call_effect_enqueues_registered_calls() -> void:
	var call: CallData = CallData.new()
	call.id = &"test_followup_call"
	CallDirector.register_call(call)
	_rule(&"test_followup", &"call_ignored", [_effect(FlagEffect.Kind.QUEUE_CALL, &"test_followup_call", 10)])
	FlagSystem.record_event(&"call_ignored")
	assert_true(&"test_followup_call" in CallDirector.call_queue)
	CallDirector.call_queue.erase(&"test_followup_call")
	CallDirector.registered_calls.erase(&"test_followup_call")


func test_snapshot_survives_json_and_restores() -> void:
	CallDirector.shift_clock_minutes = 12
	_rule(&"test_snapshot_rule", &"call_ignored", [_effect(FlagEffect.Kind.SET_FLAG, &"later", true)],
		ConsequenceRule.Timing.DELAYED_MINUTES, 30)
	_rule(&"test_snapshot_once", &"call_classified", [_effect(FlagEffect.Kind.SET_FLAG, &"classified_once", true)])
	FlagSystem.set_flag(&"closet_monster_resolved", &"hostage_rescued")
	FlagSystem.set_flag(&"evidence_count", 3)
	FlagSystem.record_event(&"call_ignored", {"call": &"closet_monster"})
	FlagSystem.record_event(&"call_classified", {"call": &"meat_truck"})
	var text: String = JSON.stringify(FlagSystem.snapshot())
	FlagSystem.reset()
	var parsed: Dictionary = JSON.parse_string(text)
	FlagSystem.restore(parsed)
	assert_true(_flag_is(&"closet_monster_resolved", &"hostage_rescued"))
	assert_true(_flag_is(&"evidence_count", 3))
	assert_true(FlagSystem.has_event(&"call_ignored", &"closet_monster"))
	assert_eq(FlagSystem.pending.size(), 1)
	var entry: Dictionary = FlagSystem.pending[0]
	assert_true(entry["rule_id"] is StringName)
	var due: int = entry["due_minute"]
	assert_eq(due, 42)
	assert_true(FlagSystem.fired_once.has(&"test_snapshot_once"))
	FlagSystem.tick(MissionDirector.shift_number, 42)
	assert_true(_flag_is(&"later", true), "restored pending rules still fire")
func test_eventbus_signals_become_events() -> void:
	EventBus.call_missed.emit(&"closet_monster")
	EventBus.call_event.emit(&"lake_house", &"cult_activity_detected")
	EventBus.call_classified.emit(&"meat_truck", &"ambush")
	assert_true(FlagSystem.has_event(&"call_ignored", &"closet_monster"))
	assert_true(FlagSystem.has_event(&"cult_activity_detected", &"lake_house"))
	assert_true(FlagSystem.has_event(&"call_classified", {"call": &"meat_truck", "verdict": &"ambush"}))


func test_dialogue_choice_conditions_lock_and_reject() -> void:
	var gated: DialogueChoice = DialogueChoice.new()
	gated.text = "Ask about the notebook"
	gated.next = &"end"
	gated.conditions = [_condition(&"station_ambush_intel", FlagCondition.Op.EQ, true)]
	var open: DialogueChoice = DialogueChoice.new()
	open.text = "Stay on the line"
	open.next = &"end"
	var start: DialogueNode = DialogueNode.new()
	start.id = &"start"
	start.line = "Hello?"
	start.choices = [gated, open]
	var finish: DialogueNode = DialogueNode.new()
	finish.id = &"end"
	finish.line = "Bye."
	var graph: DialogueGraph = DialogueGraph.new()
	graph.initial_node_id = &"start"
	graph.nodes = [start, finish]
	var runner: DialogueRunner = DialogueRunner.new()
	runner.start(graph)
	var choices: Array[Dictionary] = runner.get_available_choices_data()
	var gated_open: bool = choices[0]["unlocked"]
	var reason: String = choices[0]["lock_reason"]
	var plain_open: bool = choices[1]["unlocked"]
	assert_false(gated_open)
	assert_eq(reason, "Not available")
	assert_true(plain_open)
	var rejected: Dictionary = runner.select_choice(0)
	var rejected_ok: bool = rejected["success"]
	assert_false(rejected_ok)
	FlagSystem.set_flag(&"station_ambush_intel", true)
	var now_open: bool = runner.get_available_choices_data()[0]["unlocked"]
	assert_true(now_open)
	var picked: Dictionary = runner.select_choice(0)
	var picked_ok: bool = picked["success"]
	assert_true(picked_ok)


func test_calls_wait_for_required_flags() -> void:
	var call: CallData = CallData.new()
	call.id = &"test_gated_call"
	call.requires_flags = {"mission_unlocked_cult_hideout": true}
	CallDirector.register_call(call)
	CallDirector.call_queue.append(&"test_gated_call")
	assert_false(CallDirector.is_call_available(&"test_gated_call"))
	assert_eq(CallDirector.gated_call_count(), 1)
	assert_eq(CallDirector.take_next_available_call(), &"")
	FlagSystem.set_flag(&"mission_unlocked_cult_hideout", true)
	assert_true(CallDirector.is_call_available(&"test_gated_call"))
	assert_eq(CallDirector.take_next_available_call(), &"test_gated_call")
	CallDirector.registered_calls.erase(&"test_gated_call")


func test_mismatched_value_types_never_error() -> void:
	FlagSystem.set_flag(&"suspects", 1)
	FlagSystem.set_flag(&"suspects", true)
	assert_true(_flag_is(&"suspects", true), "a bool can replace an int without a comparison error")
	assert_false(_condition(&"suspects", FlagCondition.Op.EQ, 1).evaluate(FlagSystem))
	assert_false(_condition(&"suspects", FlagCondition.Op.GT, 0).evaluate(FlagSystem))
	assert_true(_condition(&"suspects", FlagCondition.Op.NEQ, &"yes").evaluate(FlagSystem))
	FlagSystem.set_flag(&"verdict", &"ambush")
	assert_true(_condition(&"verdict", FlagCondition.Op.EQ, "ambush").evaluate(FlagSystem), "String matches StringName")
	assert_true(FlagSystem.flags_match({"verdict": "ambush"}))
	assert_false(FlagSystem.flags_match({"verdict": 3}))
