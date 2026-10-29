## Authored consequence rules (P4-02): every rule under data/consequences/rules validates, FlagSystem loads
## them, trigger_payload filtering works, and the slice story chains play out end to end (closet monster
## ignored -> teen dead 45 minutes later, Ambush Leader arrested -> interrogation next shift -> hideout raid
## the shift after, ignored genuine calls -> guilt -> phantom ringing).
extends GutTest

const SLICE_RULES: Array[StringName] = [
	&"closet_monster_missed", &"closet_monster_neighbour_report", &"cut_line_blackout",
	&"ambush_leader_interrogation", &"cult_hideout_unlocked", &"genuine_call_ignored", &"guilt_phantom_ringing",
]

var _trust_before: int = 0
var _cult_before: int = 0
var _shift_before: int = 0
var _added_calls: Array[StringName] = []


func before_each() -> void:
	FlagSystem.reset()
	_trust_before = MissionDirector.public_trust
	_cult_before = GameState.cult_awareness
	_shift_before = MissionDirector.shift_number
	CallDirector.shift_clock_minutes = 0


func after_each() -> void:
	FlagSystem.reset()
	MissionDirector.public_trust = _trust_before
	GameState.public_trust = _trust_before
	GameState.cult_awareness = _cult_before
	MissionDirector.shift_number = _shift_before
	CallDirector.shift_clock_minutes = 0
	for call_id: StringName in _added_calls:
		CallDirector.registered_calls.erase(call_id)
	_added_calls.clear()
	TraitSystem.reset_player(1)


func _flag_is(key: StringName, expected: Variant, default: Variant = null) -> bool:
	return FlagCondition.values_equal(FlagSystem.get_flag(key, default), expected)


func _int_flag(key: StringName) -> int:
	var value: Variant = FlagSystem.get_flag(key, 0)
	return value if value is int else 0


func _register(path: String) -> CallData:
	var call: CallData = load(path) as CallData
	if not CallDirector.registered_calls.has(call.id):
		CallDirector.register_call(call)
		_added_calls.append(call.id)
	return call


func test_every_authored_rule_validates() -> void:
	var results: Dictionary = ConsequenceValidator.validate_directory()
	assert_gte(results.size(), 30, "the slice, follow-up and matrix rules are authored")
	for path: String in results:
		var result: Dictionary = results[path]
		var errors: PackedStringArray = result["errors"]
		var warnings: PackedStringArray = result["warnings"]
		assert_eq(errors.size(), 0, "%s: %s" % [path, ", ".join(errors)])
		assert_eq(warnings.size(), 0, "%s: %s" % [path, ", ".join(warnings)])


func test_flag_system_loads_the_authored_rules() -> void:
	for rule_id: StringName in SLICE_RULES:
		assert_not_null(FlagSystem.get_rule(rule_id), "%s is loaded at start" % rule_id)


func test_validator_flags_broken_rules() -> void:
	var rule: ConsequenceRule = ConsequenceRule.new()
	rule.trigger_payload = {"call": &"call_does_not_exist"}
	var effect: FlagEffect = FlagEffect.new()
	effect.kind = FlagEffect.Kind.APPLY_TRAIT
	effect.key = &"no_such_trait"
	rule.effects = [effect]
	var result: Dictionary = ConsequenceValidator.validate(rule, ConsequenceValidator.build_context())
	var errors: PackedStringArray = result["errors"]
	var joined: String = " | ".join(errors)
	assert_string_contains(joined, "missing id")
	assert_string_contains(joined, "missing trigger_event")
	assert_string_contains(joined, "call_does_not_exist")
	assert_string_contains(joined, "no_such_trait")


func test_trigger_payload_filters_events() -> void:
	var rule: ConsequenceRule = FlagSystem.get_rule(&"closet_monster_dismissed")
	assert_true(rule.payload_matches({"call": &"call_closet_monster", "verdict": &"ignore", "truth": &"prank"}))
	assert_true(rule.payload_matches({"call": "call_closet_monster", "verdict": "ignore"}), "String matches StringName")
	assert_false(rule.payload_matches({"call": &"call_closet_monster", "verdict": &"dispatch"}))
	assert_false(rule.payload_matches({"verdict": &"ignore"}), "a missing key never matches")
	FlagSystem.record_event(&"call_classified", {"call": &"call_meat_truck", "verdict": &"ignore"})
	assert_false(FlagSystem.has_event(&"closet_monster_abandoned"), "other calls do not trigger the closet rule")


func test_ignored_closet_monster_kills_the_teen_45_minutes_later() -> void:
	var trust: int = MissionDirector.public_trust
	CallDirector.shift_clock_minutes = 10
	FlagSystem.record_event(&"call_ignored", {"call": &"call_closet_monster"})
	assert_true(FlagSystem.has_event(&"closet_monster_abandoned"))
	assert_false(FlagSystem.has_flag(&"closet_teen_dead"), "nothing happens straight away")
	FlagSystem.tick(MissionDirector.shift_number, 54)
	assert_false(FlagSystem.has_flag(&"closet_teen_dead"))
	FlagSystem.tick(MissionDirector.shift_number, 55)
	assert_true(_flag_is(&"closet_teen_dead", true))
	assert_true(_flag_is(&"closet_monster_resolved", &"teen_killed"))
	assert_eq(MissionDirector.public_trust, trust - 15)
	assert_eq(_int_flag(&"guilt"), 20)
	FlagSystem.record_event(&"call_classified", {"call": &"call_closet_monster", "verdict": &"ignore"})
	FlagSystem.tick(MissionDirector.shift_number, 200)
	assert_eq(_int_flag(&"guilt"), 20, "the teen only dies once")


func test_rescued_closet_monster_gives_station_ambush_intel() -> void:
	FlagSystem.record_event(&"mission_success", {"call": &"call_closet_monster"})
	assert_true(_flag_is(&"closet_monster_resolved", &"hostage_rescued"))
	assert_true(_flag_is(&"station_ambush_intel", true))
	assert_false(FlagSystem.has_flag(&"closet_teen_dead"))


func test_arrested_ambush_leader_opens_interrogation_then_hideout() -> void:
	_register("res://data/calls/shift2/call_interrogation.tres")
	_register("res://data/calls/shift3/call_cult_hideout.tres")
	var shift: int = MissionDirector.shift_number
	var cult: int = GameState.cult_awareness
	FlagSystem.record_event(&"suspect_arrested", {"peer_id": 1, "archetype": &"cultist"})
	assert_false(FlagSystem.has_flag(&"ambush_leader_in_custody"), "only the Ambush Leader counts")
	FlagSystem.record_event(&"suspect_arrested", {"peer_id": 1, "archetype": &"ambush_leader"})
	assert_true(_flag_is(&"ambush_leader_in_custody", true))
	assert_eq(GameState.cult_awareness, cult + 10)
	assert_false(CallDirector.is_call_available(&"call_interrogation"), "the interrogation waits a shift")
	FlagSystem.tick(shift + 1, 0)
	assert_true(_flag_is(&"ambush_leader_arrested", true))
	assert_true(CallDirector.is_call_available(&"call_interrogation"))
	MissionDirector.shift_number = shift + 1
	FlagSystem.record_event(&"mission_unlocked_cult_hideout", {"call": &"call_interrogation"})
	assert_true(_flag_is(&"cult_hideout_location_known", true))
	assert_false(CallDirector.is_call_available(&"call_cult_hideout"))
	FlagSystem.tick(shift + 2, 0)
	assert_true(CallDirector.is_call_available(&"call_cult_hideout"))
	FlagSystem.record_event(&"mission_success", {"call": &"call_cult_hideout"})
	assert_true(_flag_is(&"cult_network_dismantled", true))


func test_ignored_genuine_calls_build_guilt_until_phantom_ringing() -> void:
	var trust: int = MissionDirector.public_trust
	for i: int in 2:
		FlagSystem.record_event(&"call_ignored", {"call": &"call_filler_%d" % i, "truth": &"genuine"})
	assert_eq(_int_flag(&"guilt"), 40)
	assert_eq(MissionDirector.public_trust, trust - 20)
	assert_false(TraitSystem.has_trait(1, &"phantom_ringing"), "guilt is still below 50")
	FlagSystem.record_event(&"call_ignored", {"call": &"call_filler_2", "truth": &"prank"})
	assert_eq(_int_flag(&"guilt"), 40, "ignoring a prank costs nothing extra")
	FlagSystem.record_event(&"call_ignored", {"call": &"call_filler_3", "truth": &"genuine"})
	assert_eq(_int_flag(&"guilt"), 60)
	assert_true(TraitSystem.has_trait(1, &"phantom_ringing"))
	assert_eq(FlagSystem.count_events(&"guilt_raised"), 3)


func test_cut_line_dismissed_blacks_out_the_district() -> void:
	FlagSystem.record_event(&"call_ignored", {"call": &"call_cut_line"})
	assert_true(FlagSystem.has_event(&"cut_line_dismissed"))
	FlagSystem.tick(MissionDirector.shift_number, 30)
	assert_true(_flag_is(&"district_blackout", true))
