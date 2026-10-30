## Builds the vertical-slice consequence rules (GAMEPLAY_MECHANICS §4, §5.7, §10, §11; ARCHITECTURE §7.5) into
## data/consequences/rules/<group>/<id>.tres, validating each with ConsequenceValidator first.
##   godot --headless --path . -s res://tools/consequences/build_slice_rules.gd
## Rule format: [id, description, trigger, trigger_payload, effects, options]
##   effects: [[kind, key, value, target], ...] with kind one of "set", "meter", "trait", "call", "unlock", "spawn"
##   options: {"timing": "delayed" | "next_shift" | "ending", "delay": int, "once": bool,
##             "conditions": [[key, "eq" | "neq" | "gt" | "gte" | "lt" | "lte" | "has_event", value], ...]}
## Meter deltas stack on top of what MissionDirector already applies (a missed call is −5 trust, a wrong verdict
## −3, a correct one +2), so e.g. the closet call's §10.1 "trust −20" is −15 here.
## Authority: TOOLS
extends SceneTree

@warning_ignore_start("unsafe_call_argument", "unsafe_cast", "untyped_declaration", "unsafe_method_access")

const OUT_DIR: String = "res://data/consequences/rules"
const KINDS: Dictionary = {
	"set": FlagEffect.Kind.SET_FLAG, "meter": FlagEffect.Kind.ADD_METER, "trait": FlagEffect.Kind.APPLY_TRAIT,
	"call": FlagEffect.Kind.QUEUE_CALL, "unlock": FlagEffect.Kind.UNLOCK_MISSION, "spawn": FlagEffect.Kind.SPAWN_EVENT,
}
const OPS: Dictionary = {
	"eq": FlagCondition.Op.EQ, "neq": FlagCondition.Op.NEQ, "gt": FlagCondition.Op.GT, "gte": FlagCondition.Op.GTE,
	"lt": FlagCondition.Op.LT, "lte": FlagCondition.Op.LTE, "has_event": FlagCondition.Op.HAS_EVENT,
}
const TIMINGS: Dictionary = {
	"immediate": ConsequenceRule.Timing.IMMEDIATE, "delayed": ConsequenceRule.Timing.DELAYED_MINUTES,
	"next_shift": ConsequenceRule.Timing.NEXT_SHIFT, "ending": ConsequenceRule.Timing.ENDING,
}


func _initialize() -> void:
	var groups: Dictionary = {"slice": _slice_rules(), "followup": _followup_rules(), "matrix": _matrix_rules(),
		"siege": _siege_rules()}
	var rules: Array[ConsequenceRule] = []
	var group_of: Dictionary = {}
	for group: String in groups:
		for spec: Array in groups[group]:
			var rule: ConsequenceRule = _rule(spec)
			rules.append(rule)
			group_of[rule.id] = group
	var context: Dictionary = ConsequenceValidator.build_context(rules)
	var failures: int = 0
	for rule: ConsequenceRule in rules:
		var result: Dictionary = ConsequenceValidator.validate(rule, context)
		var errors: PackedStringArray = result["errors"]
		var warnings: PackedStringArray = result["warnings"]
		var dir: String = OUT_DIR.path_join(group_of[rule.id])
		DirAccess.make_dir_recursive_absolute(dir)
		var err: Error = ERR_INVALID_DATA
		if errors.is_empty():
			err = ResourceSaver.save(rule, dir.path_join("%s.tres" % rule.id))
		print("%s %s errors=%s warnings=%s" % ["SAVE" if err == OK else "FAIL", rule.id, errors, warnings])
		if err != OK:
			failures += 1
	print("RULES: %d built, %d failed" % [rules.size(), failures])
	quit(failures)


# --- Slice calls (GAMEPLAY §10) ----------------------------------------------------------------

func _slice_rules() -> Array:
	return [
		# 10.1 "Scratching Behind the Wall": ignoring the teen leaves her with the escaped convict.
		["closet_monster_missed", "Nobody answered the closet monster call.", &"call_ignored",
			{"call": &"call_closet_monster"}, [["spawn", &"closet_monster_abandoned"]]],
		["closet_monster_dismissed", "The closet monster call was closed with no response.", &"call_classified",
			{"call": &"call_closet_monster", "verdict": &"ignore"}, [["spawn", &"closet_monster_abandoned"]]],
		["closet_monster_neighbour_report", "45 minutes later a neighbour reports blood under the door: the teen is dead.",
			&"closet_monster_abandoned", {}, [
				["set", &"closet_teen_dead", true], ["set", &"closet_monster_resolved", &"teen_killed"],
				["meter", &"public_trust", -15], ["meter", &"guilt", 20], ["spawn", &"guilt_raised"],
			], {"timing": "delayed", "delay": 45}],
		["closet_monster_rescued", "Silent approach worked: the teen is safe and the convict's notebook details the next ambush on the station.",
			&"mission_success", {"call": &"call_closet_monster"}, [
				["set", &"closet_monster_resolved", &"hostage_rescued"], ["set", &"station_ambush_intel", true],
				["meter", &"public_trust", 10], ["meter", &"victims_saved", 1], ["meter", &"evidence_collected", 1],
			]],
		["closet_monster_failed", "The farmhouse response failed and the teen did not survive.", &"mission_failed",
			{"call": &"call_closet_monster"}, [
				["set", &"closet_teen_dead", true], ["set", &"closet_monster_resolved", &"teen_killed"],
				["meter", &"guilt", 15], ["spawn", &"guilt_raised"],
			]],
		# 10.2 "Call From a Cut Line": closing it as a fault lets the haunting spread.
		["cut_line_missed", "Nobody answered the cut line call.", &"call_ignored", {"call": &"call_cut_line"},
			[["spawn", &"cut_line_dismissed"]]],
		["cut_line_closed_as_fault", "The cut line call was written off as a prank / line fault.", &"call_classified",
			{"call": &"call_cut_line", "verdict": &"prank"}, [["spawn", &"cut_line_dismissed"]]],
		["cut_line_closed_unanswered", "The cut line call was closed with no response.", &"call_classified",
			{"call": &"call_cut_line", "verdict": &"ignore"}, [["spawn", &"cut_line_dismissed"]]],
		["cut_line_blackout", "30 minutes later the district blacks out and her voice bleeds into the team radios.",
			&"cut_line_dismissed", {}, [
				["set", &"district_blackout", true], ["set", &"haunting_radio_bleed", true],
				["meter", &"public_trust", -10],
			], {"timing": "delayed", "delay": 30}],
		["lake_house_curse_broken", "The remains were buried: the Drowned Woman is at rest.", &"remains_buried", {}, [
				["set", &"lake_house_cleared", true], ["set", &"haunting_radio_bleed", false],
				["meter", &"public_trust", 5], ["meter", &"victims_saved", 1],
			]],
		# 10.3 "The Meat Truck": arresting the Ambush Leader opens the interrogation next shift.
		["ambush_leader_in_custody", "The Ambush Leader was arrested alive.", &"suspect_arrested",
			{"archetype": &"ambush_leader"}, [["set", &"ambush_leader_in_custody", true], ["meter", &"cult_awareness", 10]]],
		["ambush_leader_interrogation", "Next shift the arrested Ambush Leader is ready to talk (unlocks call_interrogation).",
			&"suspect_arrested", {"archetype": &"ambush_leader"}, [["set", &"ambush_leader_arrested", true]],
			{"timing": "next_shift", "delay": 1}],
		["meat_truck_ambush_disrupted", "The highway ambush was broken up.", &"mission_success",
			{"call": &"call_meat_truck"}, [["meter", &"cult_awareness", 15], ["meter", &"ambushes_disrupted", 1]]],
		["decoy_cruiser_lost", "The cult's RPG destroyed the empty decoy cruiser (budget already −$3,000).",
			&"decoy_cruiser_destroyed", {}, [["set", &"decoy_cruiser_lost", true]]],
		["decoy_cruiser_saved", "Tech drove the decoy cruiser out of the RPG's line of fire.", &"decoy_cruiser_saved", {},
			[["set", &"decoy_cruiser_saved", true]]],
		["meat_truck_missed", "Nobody answered the meat truck call.", &"call_ignored", {"call": &"call_meat_truck"},
			[["spawn", &"meat_truck_abandoned"]]],
		["meat_truck_dismissed", "The meat truck call was closed with no response.", &"call_classified",
			{"call": &"call_meat_truck", "verdict": &"ignore"}, [["spawn", &"meat_truck_abandoned"]]],
		["meat_truck_lead_missed", "The cult stayed quiet and the lead on the ambush crew was lost.", &"meat_truck_abandoned", {},
			[["set", &"meat_truck_lead_missed", true], ["meter", &"cult_awareness", -5]]],
		["meat_truck_trap_sprung", "Treated as a genuine breakdown, the team drives straight into the trap.", &"call_classified",
			{"call": &"call_meat_truck", "verdict": &"genuine"}, [["set", &"meat_truck_trap_sprung", true]]],
	]


# --- Follow-up calls (shift 2 interrogation, shift 3 hideout) -------------------------------------

func _followup_rules() -> Array:
	return [
		["cult_hideout_location_known", "The Ambush Leader took the deal and gave up the hideout.",
			&"mission_unlocked_cult_hideout", {}, [["set", &"cult_hideout_location_known", true], ["meter", &"evidence_collected", 1]]],
		["cult_hideout_unlocked", "Next shift the raid on the cult hideout can go ahead (unlocks call_cult_hideout).",
			&"mission_unlocked_cult_hideout", {}, [["unlock", &"cult_hideout"]], {"timing": "next_shift", "delay": 1}],
		["interrogation_refused", "No deal: the Ambush Leader warns the cult that the station is onto them.",
			&"cult_aware_station", {}, [["set", &"cult_aware_station", true], ["meter", &"cult_awareness", 15]]],
		["cult_hideout_raid_launched", "The team was sent to raid the cult hideout.", &"mission_cult_hideout_active", {},
			[["set", &"cult_hideout_raid_started", true]]],
		["cult_hideout_raided", "The cult hideout was raided successfully.", &"mission_success", {"call": &"call_cult_hideout"},
			[["set", &"cult_network_dismantled", true], ["meter", &"public_trust", 15], ["meter", &"evidence_collected", 1]]],
		["cult_movement_tracked", "The Investigator tracked the cult van's movements.", &"cult_movement_tracked", {},
			[["set", &"cult_movement_tracked", true], ["meter", &"evidence_collected", 1]]],
		["cult_activity_detected", "A full response at the warehouse confirmed cult activity.", &"cult_activity_detected", {},
			[["set", &"cult_activity_detected", true], ["meter", &"evidence_collected", 1]]],
	]


# --- Assessment matrix (§5.7), guilt (§3.3), ending counters (§11) ----------------------------------

func _matrix_rules() -> Array:
	var repeat: Dictionary = {"once": false}
	return [
		["genuine_call_ignored", "An unanswered genuine emergency: the victim was on their own.", &"call_ignored",
			{"truth": &"genuine"}, [["meter", &"public_trust", -10], ["meter", &"guilt", 20], ["spawn", &"guilt_raised"]], repeat],
		["genuine_call_dismissed", "A genuine emergency was closed with no response.", &"call_classified",
			{"truth": &"genuine", "verdict": &"ignore"},
			[["meter", &"public_trust", -10], ["meter", &"guilt", 20], ["spawn", &"guilt_raised"]], repeat],
		["genuine_call_laughed_off", "A real victim was treated as a prank caller.", &"call_classified",
			{"truth": &"genuine", "verdict": &"prank"},
			[["meter", &"public_trust", -7], ["meter", &"guilt", 15], ["spawn", &"guilt_raised"]], repeat],
		["prank_met_with_force", "A prank was answered as an armed ambush: heavy-handed response.", &"call_classified",
			{"truth": &"prank", "verdict": &"ambush"}, [["meter", &"public_trust", -7]], repeat],
		["civilian_casualty", "A hostage was executed during the response.", &"civilian_killed", {},
			[["meter", &"public_trust", -15], ["meter", &"guilt", 15], ["spawn", &"guilt_raised"]], repeat],
		["guilt_phantom_ringing", "Guilt reached 50: the team starts hearing phones that are not there.", &"guilt_raised", {},
			[["trait", &"phantom_ringing", null, &"all_officers"]], {"conditions": [[&"guilt", "gte", 50]]}],
		["trap_call_counted", "A cult trap call reached the line.", &"call_classified", {"truth": &"ambush"},
			[["meter", &"trap_calls_total", 1]], repeat],
		["trap_call_missed_counted", "A cult trap call went unanswered.", &"call_ignored", {"truth": &"ambush"},
			[["meter", &"trap_calls_total", 1]], repeat],
		["trap_call_detected", "A cult trap call was correctly identified as an ambush.", &"call_classified",
			{"truth": &"ambush", "verdict": &"ambush"}, [["meter", &"trap_calls_detected", 1]], repeat],
		["ambush_survived", "The team came back from an ambush.", &"mission_success", {"kind": &"ambush"},
			[["meter", &"ambushes_survived", 1], ["spawn", &"ambush_survived"]], repeat],
		["hardened_officers", "Three ambushes survived: the team is Hardened.", &"ambush_survived", {},
			[["trait", &"hardened", null, &"all_officers"]], {"conditions": [[&"ambushes_survived", "gte", 3]]}],
	]


# --- Station Siege (P4-09, §11): outcomes of the horde defence ---------------------------------------

func _siege_rules() -> Array:
	return [
		["station_siege_held", "The team held Station 4 through every wave: the town hears the station stood firm.",
			&"station_siege_survived", {}, [["set", &"station_defended", true], ["meter", &"public_trust", 10],
				["meter", &"cult_awareness", -20]]],
		["station_siege_overrun", "The cult overran Station 4: officers dragged out, the dispatch floor wrecked.",
			&"station_siege_fallen", {}, [["set", &"station_overrun", true], ["meter", &"public_trust", -15],
				["meter", &"guilt", 15], ["spawn", &"guilt_raised"], ["trait", &"ptsd", null, &"random_officer"]]],
		["siege_wave_repelled", "Another siege wave was pushed back out of the station.", &"siege_wave_cleared", {},
			[["meter", &"siege_waves_repelled", 1]], {"once": false}],
	]


# --- Builders ---------------------------------------------------------------------------------------

func _rule(spec: Array) -> ConsequenceRule:
	var rule: ConsequenceRule = ConsequenceRule.new()
	rule.id = spec[0]
	rule.description = spec[1]
	rule.trigger_event = spec[2]
	rule.trigger_payload = spec[3]
	var options: Dictionary = spec[5] if spec.size() > 5 else {}
	rule.timing = TIMINGS[options.get("timing", "immediate")]
	rule.delay = options.get("delay", 0)
	rule.once = options.get("once", true)
	var effects: Array[FlagEffect] = []
	for item: Array in spec[4]:
		var effect: FlagEffect = FlagEffect.new()
		effect.kind = KINDS[item[0]]
		effect.key = item[1]
		effect.value = item[2] if item.size() > 2 else null
		effect.target = item[3] if item.size() > 3 else &""
		effects.append(effect)
	rule.effects = effects
	var conditions: Array[FlagCondition] = []
	for item: Array in options.get("conditions", []):
		var condition: FlagCondition = FlagCondition.new()
		condition.key = item[0]
		condition.op = OPS[item[1]]
		condition.value = item[2]
		conditions.append(condition)
	rule.conditions = conditions
	return rule
