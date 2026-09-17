## Response loop between dispatch and the field (GAMEPLAY_MECHANICS §1 core loop):
## a call classified as GENUINE / AMBUSH opens a response → the team gears up in the Station 4 armory →
## the garage door deploys everyone to the mission map → hostiles cleared → extraction back to Station 4.
## Also carries each player's loadout (weapons, ammo, armor) across the level change.
## Authority: HOST (state changes are broadcast to every peer)
extends Node

enum State { IDLE, RESPONSE, DEPLOYED, SECURED, FAILED }

const RESPONSE_VERDICTS: Array[StringName] = [&"genuine", &"ambush"]
const STATION_SCENE: String = "res://scenes/dispatch/operations_room.tscn"
const DEFAULT_MISSION: String = "res://scenes/field/missions/warehouse_raid.tscn"
const MISSION_NAMES: Dictionary[String, String] = {
	"res://scenes/field/missions/warehouse_raid.tscn": "Harbor Warehouse",
}
const TRUST_SUCCESS: int = 6
const TRUST_FAILURE: int = -12
const BUDGET_SUCCESS: int = 1500
## Seconds with every player down before the mission fails.
const WIPE_GRACE_SEC: float = 6.0
const RETURN_DELAY_SEC: float = 5.0

signal state_changed(state: State)
signal objective_changed(text: String)
## Short banner for every peer (response alert, area secured, mission failed…).
signal announcement(title: String, subtitle: String)

var state: State = State.IDLE
var mission_scene: String = ""
var mission_call_id: StringName = &""
var objective_text: String = ""
## Ambush verdicts spawn a tougher force.
var difficulty: float = 1.0
var hostiles_total: int = 0
var hostiles_left: int = 0
## Tests turn this off to exercise the loop without leaving the test scene.
var scene_changes_enabled: bool = true

## Host: peer id -> {primary, sidearm, primary_mag, primary_reserve, sidearm_mag, sidearm_reserve, armor}
var _loadouts: Dictionary[int, Dictionary] = {}
var _wipe_timer: float = 0.0
var _return_timer: float = -1.0


func _ready() -> void:
	EventBus.call_classified.connect(_on_call_classified)
	if NetManager.has_signal("session_ended"):
		NetManager.session_ended.connect(func(_reason: String) -> void: reset())


func mission_name() -> String:
	return MISSION_NAMES.get(mission_scene, "Field response")


func is_in_mission() -> bool:
	return state == State.DEPLOYED or state == State.SECURED


# --- Host API ----------------------------------------------------------------------------

## Host: open a response for `call_id` (normally from a GENUINE / AMBUSH verdict).
func start_response(call_id: StringName, verdict: StringName, scene_path: String = DEFAULT_MISSION) -> void:
	if not multiplayer.is_server() or is_in_mission():
		return
	var tough: float = 1.35 if verdict == &"ambush" else 1.15
	_sync_state.rpc(State.RESPONSE, scene_path, call_id, tough,
		"Gear up in the armory, then hold [F] at the garage door to deploy")
	_announce.rpc("RESPONSE AUTHORIZED", "%s — armed suspects reported. Gear up and deploy." % mission_name())


## Host: move the whole team into the mission map with their current gear.
func deploy() -> bool:
	if not multiplayer.is_server() or state != State.RESPONSE:
		return false
	save_loadouts()
	_sync_state.rpc(State.DEPLOYED, mission_scene, mission_call_id, difficulty, "Clear the area of armed suspects")
	_wipe_timer = 0.0
	_go_to(GameState.Phase.FIELD, mission_scene)
	return true


## Host: the mission map reports how many hostiles are still active.
func report_hostiles(left: int, total: int) -> void:
	if not multiplayer.is_server() or state != State.DEPLOYED:
		return
	if left == hostiles_left and total == hostiles_total:
		return
	_sync_hostiles.rpc(left, total)
	if total > 0 and left <= 0:
		_sync_state.rpc(State.SECURED, mission_scene, mission_call_id, difficulty, "Area secured — regroup at the extraction van")
		_announce.rpc("AREA SECURED", "All suspects neutralized. Get to the extraction van.")


## Host: every standing player reached the extraction point.
func extract() -> bool:
	if not multiplayer.is_server() or state != State.SECURED:
		return false
	GameState.public_trust = clampi(GameState.public_trust + TRUST_SUCCESS, 0, 100)
	GameState.station_budget += BUDGET_SUCCESS
	_finish("MISSION COMPLETE", "Public trust +%d  ·  Budget +$%d" % [TRUST_SUCCESS, BUDGET_SUCCESS])
	return true


func fail(reason: String) -> void:
	if not multiplayer.is_server() or not is_in_mission():
		return
	GameState.public_trust = clampi(GameState.public_trust + TRUST_FAILURE, 0, 100)
	_sync_state.rpc(State.FAILED, mission_scene, mission_call_id, difficulty, "Mission failed — returning to Station 4")
	_announce.rpc("MISSION FAILED", "%s  ·  Public trust %d" % [reason, TRUST_FAILURE])
	_return_timer = RETURN_DELAY_SEC


func _finish(title: String, subtitle: String) -> void:
	save_loadouts()
	_announce.rpc(title, subtitle)
	_sync_state.rpc(State.IDLE, "", &"", 1.0, "")
	_go_to(GameState.Phase.DISPATCH, STATION_SCENE)


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
	objective_text = ""
	difficulty = 1.0
	hostiles_left = 0
	hostiles_total = 0
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
			_sync_state.rpc(State.IDLE, "", &"", 1.0, "")
			_go_to(GameState.Phase.DISPATCH, STATION_SCENE)
		return
	if state != State.DEPLOYED and state != State.SECURED:
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


func _on_call_classified(call_id: StringName, verdict: StringName) -> void:
	if multiplayer.is_server() and verdict in RESPONSE_VERDICTS:
		start_response(call_id, verdict)


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
func _sync_state(new_state: State, scene_path: String, call_id: StringName, new_difficulty: float, objective: String) -> void:
	state = new_state
	mission_scene = scene_path
	mission_call_id = call_id
	difficulty = new_difficulty
	if new_state == State.IDLE or new_state == State.RESPONSE:
		hostiles_left = 0
		hostiles_total = 0
	state_changed.emit(state)
	if objective != objective_text:
		objective_text = objective
		objective_changed.emit(objective)


@rpc("authority", "call_local", "reliable")
func _sync_hostiles(left: int, total: int) -> void:
	hostiles_left = left
	hostiles_total = total
	objective_changed.emit(objective_text)


@rpc("authority", "call_local", "reliable")
func _announce(title: String, subtitle: String) -> void:
	announcement.emit(title, subtitle)
