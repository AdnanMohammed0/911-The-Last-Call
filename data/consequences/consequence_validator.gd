## Checks ConsequenceRule resources: missing ids or triggers, effects pointing at calls or traits that do not
## exist, unknown targets, empty keys, odd delays, self-looping rules, and duplicate ids. Errors mean the rule
## would misbehave at runtime; warnings are worth a second look (e.g. a trigger no system records yet).
## Used by tools/consequences/build_slice_rules.gd and tests/test_consequence_rules.gd.
## Authority: TOOLS (pure data checks)
class_name ConsequenceValidator
extends RefCounted

const RULES_DIR: String = "res://data/consequences/rules"
const TRAITS_DIR: String = "res://data/traits"
const TARGETS: Array[StringName] = [&"", &"caller_peer", &"all_officers", &"random_officer"]
## Events the game records by itself (FlagSystem's EventBus hooks, MissionDirector and field maps).
const SYSTEM_EVENTS: Array[StringName] = [
	&"call_classified", &"call_ignored", &"suspect_arrested", &"hostile_killed", &"officer_downed",
	&"civilian_killed", &"mission_success", &"mission_failed", &"shift_completed", &"decoy_cruiser_destroyed",
	&"decoy_cruiser_saved", &"remains_buried",
]


## Everything a rule may refer to: {"calls": {id: true}, "traits": {id: true}, "events": {id: true}}.
## `rules` contributes the events their SPAWN_EVENT effects create.
static func build_context(rules: Array[ConsequenceRule] = []) -> Dictionary:
	var calls: Dictionary = {}
	var events: Dictionary = {}
	for event_id: StringName in SYSTEM_EVENTS:
		events[event_id] = true
	for path: String in CallValidator._find_resources(CallValidator.CALLS_DIR):
		var call: CallData = load(path) as CallData
		if call == null or call.id == &"":
			continue
		calls[call.id] = true
		if call.dialogue == null:
			continue
		for node: DialogueNode in call.dialogue.nodes:
			if node == null:
				continue
			for event_id: StringName in node.on_enter_events:
				events[event_id] = true
	for rule: ConsequenceRule in rules:
		for effect: FlagEffect in rule.effects:
			if effect != null and effect.kind == FlagEffect.Kind.SPAWN_EVENT:
				events[effect.key] = true
	var traits: Dictionary = {}
	for file: String in DirAccess.get_files_at(TRAITS_DIR):
		var path: String = TRAITS_DIR.path_join(file.trim_suffix(".remap"))
		if path.ends_with(".tres"):
			var trait_data: TraitData = load(path) as TraitData
			if trait_data != null:
				traits[trait_data.id] = true
	return {"calls": calls, "traits": traits, "events": events}


static func validate(rule: ConsequenceRule, context: Dictionary) -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	var warnings: PackedStringArray = PackedStringArray()
	if rule == null:
		errors.append("not a ConsequenceRule")
		return {"errors": errors, "warnings": warnings}
	var calls: Dictionary = context.get("calls", {})
	var traits: Dictionary = context.get("traits", {})
	var events: Dictionary = context.get("events", {})
	if rule.id == &"":
		errors.append("missing id")
	if rule.trigger_event == &"":
		errors.append("missing trigger_event")
	elif not events.has(rule.trigger_event):
		warnings.append("trigger '%s' is never recorded by the game or another rule" % rule.trigger_event)
	if rule.effects.is_empty():
		errors.append("no effects")
	match rule.timing:
		ConsequenceRule.Timing.DELAYED_MINUTES:
			if rule.delay <= 0:
				warnings.append("DELAYED_MINUTES with delay %d runs at once" % rule.delay)
		ConsequenceRule.Timing.NEXT_SHIFT:
			if rule.delay < 1:
				warnings.append("NEXT_SHIFT delay %d is treated as 1" % rule.delay)
	var payload_call: Variant = rule.trigger_payload.get("call", null)
	if payload_call != null and not calls.has(StringName(str(payload_call))):
		errors.append("trigger_payload names unknown call '%s'" % payload_call)
	for condition: FlagCondition in rule.conditions:
		if condition == null or condition.key == &"":
			errors.append("condition without a key")
	for effect: FlagEffect in rule.effects:
		if effect == null:
			errors.append("empty effect slot")
			continue
		var label: String = FlagEffect.Kind.keys()[effect.kind]
		if effect.key == &"":
			errors.append("%s effect without a key" % label)
			continue
		if not effect.target in TARGETS:
			errors.append("%s effect has unknown target '%s'" % [label, effect.target])
		match effect.kind:
			FlagEffect.Kind.ADD_METER:
				if not (effect.value is int or effect.value is float):
					errors.append("ADD_METER '%s' needs a numeric delta" % effect.key)
			FlagEffect.Kind.APPLY_TRAIT:
				if not traits.has(effect.key):
					errors.append("APPLY_TRAIT names unknown trait '%s'" % effect.key)
			FlagEffect.Kind.QUEUE_CALL:
				if not calls.has(effect.key):
					errors.append("QUEUE_CALL names unknown call '%s'" % effect.key)
			FlagEffect.Kind.SPAWN_EVENT:
				if effect.key == rule.trigger_event and not rule.once:
					warnings.append("repeatable rule spawns its own trigger '%s' (loop)" % effect.key)
	return {"errors": errors, "warnings": warnings}


## Loads and validates every rule under `dir`: {path: {"errors", "warnings", "id"}}; duplicate ids are errors.
static func validate_directory(dir: String = RULES_DIR) -> Dictionary:
	var paths: PackedStringArray = _find_rules(dir)
	var rules: Array[ConsequenceRule] = []
	for path: String in paths:
		var rule: ConsequenceRule = load(path) as ConsequenceRule
		if rule != null:
			rules.append(rule)
	var context: Dictionary = build_context(rules)
	var seen: Dictionary = {}
	var results: Dictionary = {}
	for path: String in paths:
		var rule: ConsequenceRule = load(path) as ConsequenceRule
		var result: Dictionary = validate(rule, context)
		if rule != null:
			result["id"] = rule.id
			if seen.has(rule.id):
				var errors: PackedStringArray = result["errors"]
				errors.append("duplicate id '%s' (also %s)" % [rule.id, seen[rule.id]])
				result["errors"] = errors
			seen[rule.id] = path
		results[path] = result
	return results


static func _find_rules(dir: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return found
	for file: String in DirAccess.get_files_at(dir):
		var name: String = file.trim_suffix(".remap")
		if name.ends_with(".tres"):
			found.append(dir.path_join(name))
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_find_rules(dir.path_join(sub)))
	return found
