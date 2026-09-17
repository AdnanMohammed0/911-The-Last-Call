## Response loop between dispatch and the field (GAMEPLAY_MECHANICS §1 core loop).
##
## A response opens when the team classifies a call GENUINE / AMBUSH, or when a dialogue line dispatches
## units ("Units are on the way" → &"dispatch_units", "Send a deputy to arrest her" → &"dispatch_arrest").
## What the team finds depends on the call's hidden truth, not on what they believed:
##   GENUINE / DIVERSION → raid · AMBUSH → ambush (more, tougher enemies) · PRANK → arrest the caller ·
##   PARANORMAL → nothing there (wasted units).
## The team gears up in the armory, deploys through the garage, and may extract at the van at any time;
## the mission report scores what they achieved (kills, arrests, unlawful kills, abandoning the scene).
## Also carries loadouts into the mission, runs the shift (calls handled, shift complete) and awards XP.
## Authority: HOST (state changes are broadcast to every peer)
extends Node

enum State { IDLE, RESPONSE, DEPLOYED, SECURED, FAILED }

const RESPONSE_VERDICTS: Array[StringName] = [&"genuine", &"ambush"]
const STATION_SCENE: String = "res://scenes/dispatch/operations_room.tscn"
const WAREHOUSE: String = "res://scenes/field/missions/warehouse_raid.tscn"
const SUBURB: String = "res://scenes/field/missions/aspen_drive.tscn"
const DEFAULT_MISSION: String = WAREHOUSE
const MISSION_NAMES: Dictionary[String, String] = {WAREHOUSE: "Harbor Warehouse", SUBURB: "Aspen Drive"}
## Which map each call sends the team to (unlisted calls use DEFAULT_MISSION).
const CALL_MISSIONS: Dictionary[StringName, String] = {
	&"call_cut_line": SUBURB, &"call_lost_child": SUBURB, &"call_domestic": SUBURB, &"call_overdose": SUBURB,
	&"call_home_invasion": SUBURB, &"call_school_threat": SUBURB, &"call_closet_monster": SUBURB,
}
const KIND_DIFFICULTY: Dictionary[StringName, float] = {&"raid": 1.25, &"ambush": 1.5, &"arrest": 1.0, &"empty": 1.0}

const TRUST_FAILURE: int = -12
const WIPE_GRACE_SEC: float = 6.0
const RETURN_DELAY_SEC: float = 5.0
const XP_CORRECT_VERDICT: int = 60
const XP_WRONG_VERDICT: int = -30
const XP_MISSED_CALL: int = -40
const XP_SHIFT_COMPLETE: int = 250

signal state_changed(state: State)
signal objective_changed(text: String)
## Short banner for every peer (response alert, report, promotions…).
signal announcement(title: String, subtitle: String)
signal shift_changed()

var state: State = State.IDLE
var mission_scene: String = ""
var mission_call_id: StringName = &""
var mission_kind: StringName = &""
var objective_text: String = ""
var difficulty: float = 1.0
var hostiles_total: int = 0
var hostiles_left: int = 0
## Shift progress (replicated).
var shift_number: int = 1
var calls_handled: int = 0
var calls_total: int = 0
var public_trust: int = 75
## Tests turn this off to exercise the loop without leaving the test scene.
var scene_changes_enabled: bool = true

## Host: peer id -> {primary, sidearm, primary_mag, primary_reserve, sidearm_mag, sidearm_reserve, armor}
var _loadouts: Dictionary[int, Dictionary] = {}
## Host: mission tallies.
var _kills: int = 0
var _arrests: int = 0
var _unlawful: int = 0
var _downed: int = 0
var _wipe_timer: float = 0.0
var _return_timer: float = -1.0


func _ready() -> void:
	EventBus.call_classified.connect(_on_call_classified)
	EventBus.call_event.connect(_on_call_event)
	EventBus.call_missed.connect(_on_call_missed)
	EventBus.hostile_killed.connect(_on_hostile_killed)
	EventBus.suspect_arrested.connect(_on_suspect_arrested)
	EventBus.player_downed.connect(func(_peer: int) -> void:
		if multiplayer.is_server() and is_in_mission():
			_downed += 1)
	if NetManager.has_signal("session_ended"):
		NetManager.session_ended.connect(func(_reason: String) -> void: reset())


func mission_name() -> String:
	return MISSION_NAMES.get(mission_scene, "Field response")


func is_in_mission() -> bool:
	return state == State.DEPLOYED or state == State.SECURED


static func kind_for_truth(truth: CallData.Truth) -> StringName:
	match truth:
		CallData.Truth.AMBUSH:
			return &"ambush"
		CallData.Truth.PRANK:
			return &"arrest"
		CallData.Truth.PARANORMAL:
			return &"empty"
	return &"raid"


static func objective_for_kind(kind: StringName) -> String:
	match kind:
		&"arrest":
			return "Find the caller. Shout [H] so they give up, then hold [F] to arrest"
		&"empty":
			return "Search the area, then return to the police van"
		&"ambush":
			return "Neutralize or arrest the suspects — leaving early at the van costs XP"
	return "Neutralize or arrest the suspects — leaving early at the van costs XP"


# --- Host API ----------------------------------------------------------------------------

## Host: open a response for `call_id`. The mission kind follows the call's truth when the call is known.
func start_response(call_id: StringName, verdict: StringName, scene_path: String = "") -> void:
	if not multiplayer.is_server() or is_in_mission() or (state == State.RESPONSE and call_id == mission_call_id):
		return
	var kind: StringName = &"ambush" if verdict == &"ambush" else (&"arrest" if verdict == &"prank" else &"raid")
	var call: CallData = CallDirector.registered_calls.get(call_id, null)
	if call != null:
		kind = kind_for_truth(call.truth)
	var path: String = scene_path if scene_path != "" else CALL_MISSIONS.get(call_id, DEFAULT_MISSION)
	var tough: float = KIND_DIFFICULTY.get(kind, 1.25) * (1.0 + 0.1 * (shift_number - 1))
	var title: String = call.title if call != null else "Emergency"
	_sync_state.rpc(State.RESPONSE, path, call_id, kind, tough,
		"Gear up in the armory, then hold [F] at the garage door to deploy")
	var mission: String = MISSION_NAMES.get(path, "the scene")
	var headline: String = "arrest the caller" if kind == &"arrest" else "units requested"
	_announce.rpc("RESPONSE AUTHORIZED", "%s — %s at %s. Gear up and deploy." % [title, headline, mission])


## Host: move the whole team into the mission map with their current gear.
func deploy() -> bool:
	if not multiplayer.is_server() or state != State.RESPONSE:
		return false
	save_loadouts()
	_kills = 0
	_arrests = 0
	_unlawful = 0
	_downed = 0
	_sync_state.rpc(State.DEPLOYED, mission_scene, mission_call_id, mission_kind, difficulty, objective_for_kind(mission_kind))
	_wipe_timer = 0.0
	_go_to(GameState.Phase.FIELD, mission_scene)
	return true


## Host: the mission map reports how many hostiles are still active.
func report_hostiles(left: int, total: int) -> void:
	if not multiplayer.is_server() or state != State.DEPLOYED:
		return
	if left != hostiles_left or total != hostiles_total:
		_sync_hostiles.rpc(left, total)
	if left <= 0 and (total > 0 or mission_kind == &"empty"):
		var text: String = "Area clear — regroup at the police van" if mission_kind != &"empty" else "Nothing here. Return to the police van"
		_sync_state.rpc(State.SECURED, mission_scene, mission_call_id, mission_kind, difficulty, text)
		if mission_kind != &"empty":
			_announce.rpc("AREA SECURED", "All suspects neutralized. Get to the police van.")


## Host: the team reached the van. Ends the mission at any point and scores it.
func extract() -> bool:
	if not multiplayer.is_server() or not is_in_mission():
		return false
	var report: Dictionary = score_mission(mission_kind, hostiles_total, _kills, _arrests, _unlawful, _downed)
	var xp: int = report["xp"]
	var trust: int = report["trust"]
	_change_trust(trust)
	GameState.station_budget += maxi(xp, 0) * 4
	Career.award_team(xp, "Mission report", "missions")
	var lines: PackedStringArray = report["lines"]
	lines.append("%+d XP  ·  Public trust %+d" % [xp, trust])
	_finish("MISSION REPORT", "\n".join(lines))
	return true


func fail(reason: String) -> void:
	if not multiplayer.is_server() or not is_in_mission():
		return
	_change_trust(TRUST_FAILURE)
	Career.award_team(-80, "Mission failed")
	_sync_state.rpc(State.FAILED, mission_scene, mission_call_id, mission_kind, difficulty, "Mission failed — returning to Station 4")
	_announce.rpc("MISSION FAILED", "%s  ·  Public trust %d  ·  -80 XP" % [reason, TRUST_FAILURE])
	_return_timer = RETURN_DELAY_SEC


## Scores a finished mission (`killed` counts lawful kills only; `unlawful` never counts as progress).
## Returns {"xp": int, "trust": int, "lines": PackedStringArray}.
static func score_mission(kind: StringName, total: int, killed: int, arrested: int, unlawful: int, downed: int) -> Dictionary:
	var lines: PackedStringArray = PackedStringArray()
	var xp: int = 0
	var trust: int = 0
	if kind == &"empty" or total <= 0:
		xp = 20
		trust = -4
		lines.append("Nothing found — units were pulled from other calls")
	else:
		var neutralized: int = mini(killed + arrested, total)
		var ratio: float = float(neutralized) / float(total)
		lines.append("Suspects neutralized %d / %d  (%d arrested)" % [neutralized, total, arrested])
		xp += killed * 35 + arrested * 90
		if neutralized == 0:
			xp -= 120
			trust -= 8
			lines.append("Left the scene without engaging")
		else:
			xp += roundi(250.0 * ratio)
			trust += roundi(-4.0 + 10.0 * ratio)
			if neutralized >= total:
				xp += 150
				lines.append("Scene fully resolved")
		if kind == &"arrest" and arrested > 0:
			xp += 150
			trust += 3
			lines.append("Prank caller taken into custody")
	if unlawful > 0:
		xp -= unlawful * 200
		trust -= unlawful * 10
		lines.append("Unlawful kills: %d (unarmed or surrendered)" % unlawful)
	if downed > 0:
		xp -= downed * 40
		lines.append("Officers downed: %d" % downed)
	return {"xp": xp, "trust": trust, "lines": lines}


func _finish(title: String, subtitle: String) -> void:
	# Weapons are handed back at the station: everyone returns unarmed.
	_loadouts.clear()
	_announce.rpc(title, subtitle)
	_sync_state.rpc(State.IDLE, "", &"", &"", 1.0, "")
	_go_to(GameState.Phase.DISPATCH, STATION_SCENE)


# --- Calls, verdicts and the shift ------------------------------------------------------

func _on_call_classified(call_id: StringName, verdict: StringName) -> void:
	if not multiplayer.is_server():
		return
	var record: Dictionary = CallDirector.call_history.get(call_id, {})
	if record.has("truth"):
		var truth: CallData.Truth = record["truth"]
		if verdict == verdict_for_truth(truth):
			Career.award_team(XP_CORRECT_VERDICT, "Correct assessment", "calls_correct")
			_change_trust(2)
		else:
			Career.award_team(XP_WRONG_VERDICT, "Wrong assessment", "calls_wrong")
			_change_trust(-3)
	_count_call()
	if verdict in RESPONSE_VERDICTS:
		start_response(call_id, verdict)


func _on_call_missed(_call_id: StringName) -> void:
	if not multiplayer.is_server():
		return
	Career.award_team(XP_MISSED_CALL, "Missed 911 call")
	_change_trust(-5)
	_count_call()


func _on_call_event(call_id: StringName, event_name: StringName) -> void:
	if not multiplayer.is_server():
		return
	match event_name:
		&"dispatch_units":
			start_response(call_id, &"genuine")
		&"dispatch_arrest":
			start_response(call_id, &"prank")


static func verdict_for_truth(truth: CallData.Truth) -> StringName:
	match truth:
		CallData.Truth.PRANK:
			return &"prank"
		CallData.Truth.AMBUSH:
			return &"ambush"
		CallData.Truth.PARANORMAL:
			return &"paranormal"
	return &"genuine"


func _count_call() -> void:
	calls_handled += 1
	_push_shift()


## Host: set the number of calls this shift (DispatchSetup after queuing).
func set_calls_total(total: int) -> void:
	if multiplayer.is_server():
		calls_total = total
		_push_shift()


## Host: everything answered → reward, then start the next, harder shift.
func complete_shift() -> void:
	if not multiplayer.is_server():
		return
	var bonus: int = XP_SHIFT_COMPLETE + public_trust * 2
	Career.award_team(bonus, "Shift %d complete" % shift_number, "shifts")
	_announce.rpc("SHIFT %d COMPLETE" % shift_number, "Public trust %d  ·  +%d XP  ·  The next shift will be harder" % [public_trust, bonus])
	shift_number += 1
	calls_handled = 0
	_push_shift()


func _change_trust(amount: int) -> void:
	public_trust = clampi(public_trust + amount, 0, 100)
	GameState.public_trust = public_trust
	_push_shift()


func _push_shift() -> void:
	if multiplayer.is_server():
		_sync_shift.rpc(shift_number, calls_handled, calls_total, public_trust)


# --- Loadouts ----------------------------------------------------------------------------

## Host: remember every player's weapons, ammo and armor before a level change.
func save_loadouts() -> void:
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var player: Player = node as Player
		if player == null:
			continue
		var weapons: WeaponHolder = player.get_weapons()
		_loadouts[player.peer_id] = {
			"primary": weapons.primary_id, "sidearm": weapons.sidearm_id,
			"primary_mag": weapons.primary_mag, "primary_reserve": weapons.primary_reserve,
			"sidearm_mag": weapons.sidearm_mag, "sidearm_reserve": weapons.sidearm_reserve,
			"armor": player.get_health().armor,
		}


## Host: the saved loadout for `peer_id` (empty when none).
func get_loadout(peer_id: int) -> Dictionary:
	return _loadouts.get(peer_id, {})


func reset() -> void:
	state = State.IDLE
	mission_scene = ""
	mission_call_id = &""
	mission_kind = &""
	objective_text = ""
	difficulty = 1.0
	hostiles_left = 0
	hostiles_total = 0
	shift_number = 1
	calls_handled = 0
	calls_total = 0
	public_trust = 75
	_loadouts.clear()
	_return_timer = -1.0


# --- Internals ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _return_timer >= 0.0:
		_return_timer -= delta
		if _return_timer < 0.0:
			for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
				(node as Player).get_health().restore()
			_loadouts.clear()
			_sync_state.rpc(State.IDLE, "", &"", &"", 1.0, "")
			_go_to(GameState.Phase.DISPATCH, STATION_SCENE)
		return
	if not is_in_mission():
		return
	var players: Array[Node] = get_tree().get_nodes_in_group(Player.GROUP)
	var standing: int = 0
	for node: Node in players:
		var player: Player = node as Player
		if player != null and not player.connection_lost and player.get_health().is_alive():
			standing += 1
	if players.is_empty() or standing > 0:
		_wipe_timer = 0.0
		return
	_wipe_timer += delta
	if _wipe_timer >= WIPE_GRACE_SEC:
		fail("The whole team went down")


func _on_hostile_killed(hostile: Node, by_peer: int) -> void:
	if not multiplayer.is_server() or not is_in_mission():
		return
	var agent: HostileAgent = hostile as HostileAgent
	if agent != null and agent.killed_unlawfully:
		_unlawful += 1
		if by_peer != 0:
			Career.award(by_peer, -60, "Unlawful kill")
		return
	_kills += 1
	if by_peer != 0:
		Career.award(by_peer, 15, "Suspect neutralized", "kills")


func _on_suspect_arrested(_hostile: Node, by_peer: int) -> void:
	if not multiplayer.is_server() or not is_in_mission():
		return
	_arrests += 1
	if by_peer != 0:
		Career.award(by_peer, 30, "Suspect arrested", "arrests")


func _go_to(phase: GameState.Phase, scene_path: String) -> void:
	GameState.phase = phase
	if not scene_changes_enabled:
		return
	if NetManager.is_online():
		NetManager.change_level(scene_path)
	else:
		GameState.current_scene_path = scene_path
		get_tree().change_scene_to_file.call_deferred(scene_path)
		EventBus.phase_changed.emit(GameState.phase_name(phase))


@rpc("authority", "call_local", "reliable")
func _sync_state(new_state: State, scene_path: String, call_id: StringName, kind: StringName, new_difficulty: float, objective: String) -> void:
	state = new_state
	mission_scene = scene_path
	mission_call_id = call_id
	mission_kind = kind
	difficulty = new_difficulty
	if new_state == State.IDLE or new_state == State.RESPONSE:
		hostiles_left = 0
		hostiles_total = 0
	state_changed.emit(state)
	objective_text = objective
	objective_changed.emit(objective_text)


@rpc("authority", "call_local", "reliable")
func _sync_hostiles(left: int, total: int) -> void:
	hostiles_left = left
	hostiles_total = total
	objective_changed.emit(objective_text)


@rpc("authority", "call_local", "reliable")
func _sync_shift(shift: int, handled: int, total: int, trust: int) -> void:
	shift_number = shift
	calls_handled = handled
	calls_total = total
	public_trust = trust
	shift_changed.emit()
	objective_changed.emit(objective_text)


@rpc("authority", "call_local", "reliable")
func _announce(title: String, subtitle: String) -> void:
	announcement.emit(title, subtitle)
