## Butterfly-effect state (ARCHITECTURE §7): story flags, the campaign event log, and consequence rules.
## Every narrative-relevant action becomes an event through record_event(); rules triggered by it run their
## effects immediately, after a shift-clock delay, at a later shift, or are kept for the ending resolver.
## Flags and events replicate to every peer (late joiners get a full snapshot); pending rules, once-only
## bookkeeping and rule evaluation stay on the host. snapshot() / restore() give the save system a JSON-safe
## copy of the whole state.
## Authority: HOST (mutation, rules) → replicated (flags, events)
extends Node

signal event_recorded(event: Dictionary)

const RULES_DIR: String = "res://data/consequences/rules/"
const SNAPSHOT_VERSION: int = 1
## Chained SPAWN_EVENT effects stop here so a rule loop cannot hang the host.
const MAX_CHAIN_DEPTH: int = 8
const METER_TRUST: StringName = &"public_trust"
const METER_BUDGET: StringName = &"station_budget"
const METER_CULT: StringName = &"cult_awareness"

var flags: Dictionary[StringName, Variant] = {}
## {id: StringName, t: int (shift-clock minute), shift: int, payload: Dictionary}
var events: Array[Dictionary] = []
## {rule_id: StringName, due_shift: int, due_minute: int, payload: Dictionary}
var pending: Array[Dictionary] = []
var fired_once: Dictionary[StringName, bool] = {}
## Rule ids whose ENDING-timed conditions were met, for the ending resolver.
var ending_candidates: Array[StringName] = []

var _rules_by_trigger: Dictionary[StringName, Array] = {}
var _rules_by_id: Dictionary[StringName, ConsequenceRule] = {}
var _chain_depth: int = 0


func _ready() -> void:
	load_rules()
	EventBus.call_event.connect(_on_call_event)
	EventBus.call_classified.connect(func(call_id: StringName, verdict: StringName) -> void:
		_record_if_host(&"call_classified", {"call": call_id, "verdict": verdict, "truth": call_truth(call_id)}))
	EventBus.call_missed.connect(func(call_id: StringName) -> void:
		_record_if_host(&"call_ignored", {"call": call_id, "truth": call_truth(call_id)}))
	EventBus.suspect_arrested.connect(func(hostile: Node, by_peer: int) -> void:
		_record_if_host(&"suspect_arrested", {"peer_id": by_peer, "mission": MissionDirector.mission_call_id,
			"archetype": archetype_of(hostile)}))
	EventBus.hostile_killed.connect(func(hostile: Node, by_peer: int) -> void:
		_record_if_host(&"hostile_killed", {"peer_id": by_peer, "mission": MissionDirector.mission_call_id,
			"archetype": archetype_of(hostile)}))
	EventBus.hostage_executed.connect(func(hostile: Node) -> void:
		_record_if_host(&"civilian_killed", {"mission": MissionDirector.mission_call_id,
			"archetype": archetype_of(hostile)}))
	EventBus.player_downed.connect(func(peer_id: int) -> void:
		_record_if_host(&"officer_downed", {"peer_id": peer_id, "mission": MissionDirector.mission_call_id}))
	EventBus.shift_clock_updated.connect(func(minutes: int) -> void:
		if _is_server():
			tick(current_shift(), minutes))
	NetManager.peer_joined.connect(_on_peer_joined)
	if NetManager.has_signal("session_ended"):
		NetManager.session_ended.connect(func(_reason: String) -> void: reset())


# --- Queries (any peer) ----------------------------------------------------------------------

func get_flag(key: StringName, default: Variant = null) -> Variant:
	return flags.get(key, default)


func has_flag(key: StringName) -> bool:
	return flags.has(key)


## True if `event_id` was recorded. `match_payload` narrows it: null = any, a Dictionary = every key must
## match, anything else = the payload's "call" (or "value") must equal it.
func has_event(event_id: StringName, match_payload: Variant = null) -> bool:
	return count_events(event_id, match_payload) > 0


func count_events(event_id: StringName, match_payload: Variant = null) -> int:
	var count: int = 0
	for event: Dictionary in events:
		var payload: Dictionary = event.get("payload", {})
		if event["id"] == event_id and _payload_matches(payload, match_payload):
			count += 1
	return count


func events_of(event_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in events:
		if event["id"] == event_id:
			result.append(event)
	return result


## True when every key of `required` (flag → value) matches, e.g. CallData.requires_flags.
func flags_match(required: Dictionary) -> bool:
	for key: Variant in required:
		if not FlagCondition.values_equal(get_flag(StringName(str(key))), required[key]):
			return false
	return true


## True when every condition passes (an empty list passes).
func conditions_pass(conditions: Array[FlagCondition]) -> bool:
	for condition: FlagCondition in conditions:
		if condition != null and not condition.evaluate(self):
			return false
	return true


func current_shift() -> int:
	return MissionDirector.shift_number


## The call's hidden truth as a verdict-style name (&"prank", &"genuine", &"ambush", &"paranormal",
## &"diversion"), or &"" for unknown calls. Lets rules react to e.g. any ignored genuine call.
static func call_truth(call_id: StringName) -> StringName:
	var call: CallData = CallDirector.registered_calls.get(call_id, null)
	if call == null:
		return &""
	var names: PackedStringArray = CallData.Truth.keys()
	return StringName(names[call.truth].to_lower())


## Archetype id of a hostile (e.g. &"ambush_leader"), or &"".
static func archetype_of(hostile: Node) -> StringName:
	if hostile == null or not is_instance_valid(hostile):
		return &""
	var archetype: Variant = hostile.get("archetype")
	if archetype is ArchetypeData:
		var data: ArchetypeData = archetype
		return data.id
	return &""


func get_rule(rule_id: StringName) -> ConsequenceRule:
	return _rules_by_id.get(rule_id, null)


# --- Mutation (host) ----------------------------------------------------------------------------

## Host only. The single entry point for every narrative-relevant action.
func record_event(event_id: StringName, payload: Dictionary = {}) -> void:
	if not _is_server() or event_id == &"":
		return
	var event: Dictionary = {"id": event_id, "t": CallDirector.shift_clock_minutes, "shift": current_shift(),
		"payload": payload.duplicate(true)}
	events.append(event)
	if _has_peers():
		_sync_event.rpc(event)
	event_recorded.emit(event)
	if _chain_depth >= MAX_CHAIN_DEPTH:
		push_warning("FlagSystem: event chain too deep at '%s'; rules not evaluated" % event_id)
		return
	_chain_depth += 1
	for rule: ConsequenceRule in _rules_by_trigger.get(event_id, []):
		if rule.once and (fired_once.has(rule.id) or _is_pending(rule.id)):
			continue
		if rule.payload_matches(payload) and rule.conditions_pass(self):
			_schedule(rule, payload)
	_chain_depth -= 1


func set_flag(key: StringName, value: Variant) -> void:
	if not _is_server() or key == &"":
		return
	if flags.has(key) and FlagCondition.values_equal(flags[key], value):
		return
	if _has_peers():
		_sync_flag.rpc(key, value)
	else:
		_sync_flag(key, value)


func clear_flag(key: StringName) -> void:
	if not _is_server() or not flags.has(key):
		return
	if _has_peers():
		_sync_clear_flag.rpc(key)
	else:
		_sync_clear_flag(key)


## Adds `delta` to a global meter (or to a numeric flag of that name).
func add_meter(key: StringName, delta: int) -> void:
	if not _is_server() or delta == 0:
		return
	match key:
		METER_TRUST:
			MissionDirector.change_trust(delta)
		METER_BUDGET:
			GameState.modify_station_budget(delta)
		METER_CULT:
			GameState.modify_cult_awareness(delta)
		_:
			var current: Variant = get_flag(key, 0)
			var base: int = current if current is int else 0
			set_flag(key, base + delta)


## Host: runs every pending rule that has come due. Called from the shift clock each in-game minute.
func tick(shift: int, minute: int) -> void:
	if not _is_server():
		return
	for entry: Dictionary in pending.duplicate():
		var due_shift: int = entry["due_shift"]
		var due_minute: int = entry["due_minute"]
		if due_shift < shift or (due_shift == shift and due_minute <= minute):
			pending.erase(entry)
			var rule_id: StringName = entry["rule_id"]
			var rule: ConsequenceRule = get_rule(rule_id)
			if rule != null:
				var payload: Dictionary = entry["payload"]
				_apply(rule, payload)


## Registers a rule (tests and runtime-authored rules); replaces a rule with the same id.
func register_rule(rule: ConsequenceRule) -> void:
	if rule == null or rule.id == &"":
		return
	if _rules_by_id.has(rule.id):
		var previous: ConsequenceRule = _rules_by_id[rule.id]
		var list: Array = _rules_by_trigger.get(previous.trigger_event, [])
		list.erase(previous)
	_rules_by_id[rule.id] = rule
	if not _rules_by_trigger.has(rule.trigger_event):
		_rules_by_trigger[rule.trigger_event] = []
	_rules_by_trigger[rule.trigger_event].append(rule)


func unregister_rule(rule_id: StringName) -> void:
	var rule: ConsequenceRule = _rules_by_id.get(rule_id, null)
	if rule == null:
		return
	_rules_by_id.erase(rule_id)
	var list: Array = _rules_by_trigger.get(rule.trigger_event, [])
	list.erase(rule)


func load_rules(directory: String = RULES_DIR) -> void:
	if not DirAccess.dir_exists_absolute(directory):
		return
	for file: String in DirAccess.get_files_at(directory):
		var path: String = directory.path_join(file.trim_suffix(".remap"))
		if not (path.ends_with(".tres") or path.ends_with(".res")):
			continue
		var rule: ConsequenceRule = load(path) as ConsequenceRule
		if rule == null:
			push_warning("FlagSystem: %s is not a ConsequenceRule" % path)
		elif _rules_by_id.has(rule.id):
			push_warning("FlagSystem: duplicate rule id '%s' in %s" % [rule.id, path])
		else:
			register_rule(rule)
	for sub: String in DirAccess.get_directories_at(directory):
		load_rules(directory.path_join(sub))


## New campaign: forget every flag, event and pending rule (rules stay loaded).
func reset() -> void:
	flags.clear()
	events.clear()
	pending.clear()
	fired_once.clear()
	ending_candidates.clear()


# --- Persistence --------------------------------------------------------------------------------

## JSON-safe copy of the campaign state (StringNames become Strings).
func snapshot() -> Dictionary:
	var flag_copy: Dictionary = {}
	for key: StringName in flags:
		flag_copy[String(key)] = _json_safe(flags[key])
	var once: Array[String] = []
	for rule_id: StringName in fired_once:
		once.append(String(rule_id))
	var endings: Array[String] = []
	for rule_id: StringName in ending_candidates:
		endings.append(String(rule_id))
	return {
		"version": SNAPSHOT_VERSION,
		"flags": flag_copy,
		"events": _json_safe(events),
		"pending": _json_safe(pending),
		"fired_once": once,
		"ending_candidates": endings,
	}


## Host: restore a snapshot (from snapshot() or a parsed save file) and resend it to every peer.
func restore(data: Dictionary) -> void:
	if not _is_server():
		return
	reset()
	var saved_flags: Dictionary = data.get("flags", {})
	for key: Variant in saved_flags:
		flags[StringName(str(key))] = saved_flags[key]
	for item: Variant in data.get("events", []):
		if item is Dictionary:
			var event: Dictionary = item
			events.append(_restore_entry(event, "id"))
	for item: Variant in data.get("pending", []):
		if item is Dictionary:
			var entry: Dictionary = item
			pending.append(_restore_entry(entry, "rule_id"))
	for rule_id: Variant in data.get("fired_once", []):
		fired_once[StringName(str(rule_id))] = true
	for rule_id: Variant in data.get("ending_candidates", []):
		ending_candidates.append(StringName(str(rule_id)))
	if _has_peers():
		_sync_snapshot.rpc(flags, events)


# --- Internals ----------------------------------------------------------------------------------

func _schedule(rule: ConsequenceRule, payload: Dictionary) -> void:
	match rule.timing:
		ConsequenceRule.Timing.IMMEDIATE:
			_apply(rule, payload)
		ConsequenceRule.Timing.DELAYED_MINUTES:
			pending.append({"rule_id": rule.id, "due_shift": current_shift(),
				"due_minute": CallDirector.shift_clock_minutes + maxi(rule.delay, 0), "payload": payload.duplicate(true)})
		ConsequenceRule.Timing.NEXT_SHIFT:
			pending.append({"rule_id": rule.id, "due_shift": current_shift() + maxi(rule.delay, 1),
				"due_minute": 0, "payload": payload.duplicate(true)})
		ConsequenceRule.Timing.ENDING:
			if not rule.id in ending_candidates:
				ending_candidates.append(rule.id)
			fired_once[rule.id] = true


func _apply(rule: ConsequenceRule, payload: Dictionary) -> void:
	fired_once[rule.id] = true
	for effect: FlagEffect in rule.effects:
		if effect == null:
			continue
		match effect.kind:
			FlagEffect.Kind.SET_FLAG:
				set_flag(effect.key, effect.value)
			FlagEffect.Kind.ADD_METER:
				add_meter(effect.key, _as_int(effect.value))
			FlagEffect.Kind.APPLY_TRAIT:
				var shifts: int = _as_int(effect.value) if effect.value != null else -1
				for peer_id: int in _resolve_targets(effect.target, payload):
					TraitSystem.apply(peer_id, effect.key, rule.id, shifts)
			FlagEffect.Kind.QUEUE_CALL:
				if CallDirector.registered_calls.has(effect.key):
					CallDirector.enqueue_call(effect.key, maxi(_as_int(effect.value), 0))
				else:
					push_warning("FlagSystem: rule '%s' queues unknown call '%s'" % [rule.id, effect.key])
			FlagEffect.Kind.UNLOCK_MISSION:
				set_flag(StringName("mission_unlocked_%s" % effect.key), true)
			FlagEffect.Kind.SPAWN_EVENT:
				record_event(effect.key, payload)


func _resolve_targets(target: StringName, payload: Dictionary) -> Array[int]:
	var officers: Array[int] = []
	for peer_id: int in NetManager.roster:
		officers.append(peer_id)
	if officers.is_empty():
		officers.append(1)
	match target:
		&"caller_peer":
			var peer_id: int = payload.get("peer_id", 1)
			return [peer_id]
		&"random_officer":
			return [officers.pick_random()]
	return officers


func _on_call_event(call_id: StringName, event_name: StringName) -> void:
	_record_if_host(event_name, {"call": call_id})


func _record_if_host(event_id: StringName, payload: Dictionary) -> void:
	if _is_server():
		record_event(event_id, payload)


func _on_peer_joined(peer_id: int, _player_name: String) -> void:
	if multiplayer.is_server() and peer_id != 1:
		_sync_snapshot.rpc_id(peer_id, flags, events)


func _is_pending(rule_id: StringName) -> bool:
	for entry: Dictionary in pending:
		if entry["rule_id"] == rule_id:
			return true
	return false


static func _payload_matches(payload: Dictionary, wanted: Variant) -> bool:
	if wanted == null:
		return true
	if wanted is Dictionary:
		var fields: Dictionary = wanted
		for key: Variant in fields:
			if not payload.has(key) or not FlagCondition.values_equal(payload[key], fields[key]):
				return false
		return true
	return FlagCondition.values_equal(payload.get("call"), wanted) or FlagCondition.values_equal(payload.get("value"), wanted)


static func _as_int(value: Variant) -> int:
	if value is int:
		var whole: int = value
		return whole
	if value is float:
		var real: float = value
		return roundi(real)
	if value is bool:
		return 1 if value == true else 0
	if value is String or value is StringName:
		return str(value).to_int()
	return 0


static func _json_safe(value: Variant) -> Variant:
	if value is StringName:
		return str(value)
	if value is Dictionary:
		var source: Dictionary = value
		var copy: Dictionary = {}
		for key: Variant in source:
			copy[str(key)] = _json_safe(source[key])
		return copy
	if value is Array:
		var items: Array = value
		var list: Array = []
		for item: Variant in items:
			list.append(_json_safe(item))
		return list
	return value


## Turns a JSON-loaded entry back into the runtime shape (ids as StringName, numbers as int).
static func _restore_entry(source: Dictionary, id_key: String) -> Dictionary:
	var entry: Dictionary = source.duplicate(true)
	entry[id_key] = StringName(str(source.get(id_key, "")))
	for number_key: String in ["t", "shift", "due_shift", "due_minute"]:
		if entry.has(number_key):
			entry[number_key] = _as_int(entry[number_key])
	if not entry.get("payload", null) is Dictionary:
		entry["payload"] = {}
	return entry


func _is_server() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


func _has_peers() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


@rpc("authority", "call_local", "reliable")
func _sync_flag(key: StringName, value: Variant) -> void:
	var old: Variant = flags.get(key, null)
	flags[key] = value
	EventBus.flag_changed.emit(key, old, value)


@rpc("authority", "call_local", "reliable")
func _sync_clear_flag(key: StringName) -> void:
	var old: Variant = flags.get(key, null)
	flags.erase(key)
	EventBus.flag_changed.emit(key, old, null)


@rpc("authority", "call_remote", "reliable")
func _sync_event(event: Dictionary) -> void:
	events.append(event)
	event_recorded.emit(event)


@rpc("authority", "call_remote", "reliable")
func _sync_snapshot(snapshot_flags: Dictionary, snapshot_events: Array) -> void:
	for key: Variant in snapshot_flags:
		var flag_key: StringName = StringName(str(key))
		var old: Variant = flags.get(flag_key, null)
		flags[flag_key] = snapshot_flags[key]
		EventBus.flag_changed.emit(flag_key, old, flags[flag_key])
	events.clear()
	for item: Variant in snapshot_events:
		if item is Dictionary:
			var event: Dictionary = item
			events.append(event)
