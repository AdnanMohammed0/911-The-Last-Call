## Station Siege horde mode (P4-09, GAMEPLAY_MECHANICS §11 "Station Under Siege"): the cult cuts power and
## phones and storms Station 4 in waves while the team holds the operations room.
## Starts on the host once per campaign, as soon as the team is idle in the station, when cult awareness
## reached 90 (MissionDirector.is_station_siege_triggered()) or the flag `station_siege_pending` is true
## (ending resolver P4-08, consequence rules); `start()` also starts it directly. It kicks every station
## door open, bakes the station navmesh, then runs the SiegePlan waves from the entry markers and keeps
## steering the hostiles toward the nearest standing officer. Holding through the last wave records
## `station_siege_survived`; the whole team down for `wipe_grace_sec` records `station_siege_fallen`
## (consequence rules apply the meters).
## Authority: HOST (waves, spawning, outcome) / every peer (blackout lights, HUD)
class_name StationSiege
extends Node3D

enum State { IDLE, BREACH, INTERMISSION, WAVE, SURVIVED, FALLEN }

const GROUP: StringName = &"station_siege"
const NAV_SOURCE_GROUP: StringName = &"station_siege_nav_source"
const FLAG_PENDING: StringName = &"station_siege_pending"
const FLAG_ACTIVE: StringName = &"station_siege_active"
const FLAG_OUTCOME: StringName = &"station_siege_outcome"
const SURVIVED: StringName = &"survived"
const FALLEN: StringName = &"fallen"
## The team must be idle in the station this long before the siege begins (lets every peer load).
const START_DELAY_SEC: float = 6.0
const HUNT_PULSE_SEC: float = 2.5
const STATUS_INTERVAL_SEC: float = 1.0
const SPAWN_JITTER: float = 1.5

signal state_changed(state: State)
signal wave_started(wave: int)
signal wave_cleared(wave: int)
signal finished(outcome: StringName)

@export var plan: SiegePlan
@export var spawner: EnemySpawner
@export var navigation: MissionNavigation
## Spawned hostiles land here (the spawner's spawn_path); reinforcements are tracked too.
@export var enemies_root: Node3D
## Marker3D children: where each wave comes in, used in turn.
@export var entry_points: Node3D
## Centre of the operations room; hostiles head here when no officer is standing.
@export var defend_point: Node3D
@export var squad: AISquad
## Shown during the blackout.
@export var emergency_lights: Node3D
## Station nodes (relative to this node) whose collision the navmesh is baked from. Doors stay out: the
## breach kicks them open.
@export var nav_sources: Array[NodePath] = []
## Nodes whose lights go dark when the power is cut.
@export var power_roots: Array[NodePath] = []
## Parent of the station doors kicked open by the breach.
@export var doors_path: NodePath
## Start by itself when the conditions hold (off in tests and set-piece levels).
@export var auto_start: bool = true

var state: State = State.IDLE
## 0-based index of the current (or upcoming) wave; -1 before the first.
var wave_index: int = -1
var countdown: float = 0.0
## Hostiles of this wave still to come or still fighting (replicated for the HUD).
var hostiles_left: int = 0
var neutralized: int = 0

var _hostiles: Array[HostileAgent] = []
var _roster: Array[ArchetypeData] = []
var _spawn_timer: float = 0.0
var _entry_cursor: int = 0
var _arm_timer: float = 0.0
var _hunt_timer: float = 0.0
var _status_timer: float = 0.0
var _wipe_timer: float = 0.0
var _shift_was_running: bool = false
var _powered: bool = true
var _dimmed: Array[Light3D] = []
var _flicker: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hud: CanvasLayer
var _hud_label: Label


func _ready() -> void:
	add_to_group(GROUP)
	_rng.randomize()
	_build_hud()
	if emergency_lights != null:
		emergency_lights.visible = false
	if enemies_root != null:
		enemies_root.child_entered_tree.connect(_on_enemy_added)
	EventBus.hostile_killed.connect(func(hostile: Node, by_peer: int) -> void: _on_neutralized(hostile, by_peer))
	EventBus.suspect_arrested.connect(func(hostile: Node, by_peer: int) -> void: _on_neutralized(hostile, by_peer))


static func find(tree: SceneTree) -> StationSiege:
	return tree.get_first_node_in_group(GROUP) as StationSiege


## True while the station is under attack (dispatch keeps the phones quiet).
static func is_siege_running(tree: SceneTree) -> bool:
	var siege: StationSiege = find(tree)
	return siege != null and siege.is_running()


func is_running() -> bool:
	return state == State.BREACH or state == State.INTERMISSION or state == State.WAVE


func current_wave() -> SiegeWave:
	if plan == null or wave_index < 0 or wave_index >= plan.waves.size():
		return null
	return plan.waves[wave_index]


func wave_count() -> int:
	return plan.waves.size() if plan != null else 0


## Host: the campaign calls for a siege and the team is idle in the station.
func should_start() -> bool:
	if state != State.IDLE or FlagSystem.has_flag(FLAG_OUTCOME) or wave_count() == 0:
		return false
	var pending: bool = FlagCondition.values_equal(FlagSystem.get_flag(FLAG_PENDING, false), true)
	if not (pending or MissionDirector.is_station_siege_triggered()):
		return false
	return GameState.is_phase(&"dispatch") and MissionDirector.state == MissionDirector.State.IDLE \
		and CallDirector.current_state == CallDirector.CallState.IDLE


## Host: cut the power and phones, breach the doors and start the first countdown.
func start(reason: StringName = &"cult_awareness") -> bool:
	if not multiplayer.is_server() or state != State.IDLE or wave_count() == 0:
		return false
	_shift_was_running = CallDirector.shift_running
	CallDirector.pause_shift()
	neutralized = 0
	wave_index = -1
	FlagSystem.set_flag(FLAG_ACTIVE, true)
	FlagSystem.clear_flag(FLAG_PENDING)
	FlagSystem.record_event(&"station_siege_started", {"reason": reason, "shift": MissionDirector.shift_number})
	MissionDirector.announce("STATION UNDER SIEGE",
		"Power and phones are down. Arm up at the armory and hold the operations room.")
	_set_state(State.BREACH)
	_breach_doors()
	_prepare_navigation()
	return true


func _process(delta: float) -> void:
	if not _powered and emergency_lights != null:
		_flicker += delta
		emergency_lights.visible = fmod(_flicker, 1.6) < 1.25
	if multiplayer.is_server():
		step(delta)


## Host: advances the siege by `delta` seconds (driven by _process; tests call it directly).
func step(delta: float) -> void:
	if not multiplayer.is_server():
		return
	match state:
		State.IDLE:
			if auto_start and should_start():
				_arm_timer += delta
				if _arm_timer >= START_DELAY_SEC:
					_arm_timer = 0.0
					start(&"cult_awareness" if MissionDirector.is_station_siege_triggered() else &"campaign")
			else:
				_arm_timer = 0.0
			return
		State.INTERMISSION:
			countdown -= delta
			if countdown <= 0.0:
				_begin_wave()
		State.WAVE:
			_spawn_step(delta)
			_prune()
			if _roster.is_empty() and _hostiles.is_empty():
				_clear_wave()
	if not is_running():
		return
	_hunt_timer -= delta
	if _hunt_timer <= 0.0:
		_hunt_timer = HUNT_PULSE_SEC
		_hunt()
	_check_wipe(delta)
	if not is_running():
		return
	_status_timer -= delta
	if _status_timer <= 0.0:
		_push_status()


# --- Waves ------------------------------------------------------------------------------------

func _next_intermission() -> void:
	wave_index += 1
	var wave: SiegeWave = current_wave()
	countdown = wave.intermission_sec
	_set_state(State.INTERMISSION)
	if wave_index > 0:
		MissionDirector.announce("WAVE %d CLEARED" % wave_index,
			"Next wave in %d seconds. Restock at the armory." % ceili(countdown))


func _begin_wave() -> void:
	var wave: SiegeWave = current_wave()
	_roster = wave.roster()
	_spawn_timer = 0.0
	if spawner != null:
		spawner.use_mission_difficulty = false
		spawner.difficulty = wave.difficulty * (1.0 + 0.1 * (MissionDirector.shift_number - 1))
	_set_state(State.WAVE)
	MissionDirector.announce("WAVE %d / %d" % [wave_index + 1, wave_count()], wave.announcement)
	wave_started.emit(wave_index + 1)


func _spawn_step(delta: float) -> void:
	if _roster.is_empty():
		return
	_spawn_timer -= delta
	var wave: SiegeWave = current_wave()
	if _spawn_timer > 0.0 or _hostiles.size() >= wave.max_alive:
		return
	_spawn_timer = wave.spawn_interval_sec
	var archetype: ArchetypeData = _roster.pop_front()
	if spawner == null or archetype == null:
		return
	var squad_path: NodePath = NodePath()
	if squad != null:
		squad_path = spawner._level_root().get_path_to(squad)
	var hostile: HostileAgent = spawner.spawn_hostile(archetype.resource_path, _entry_transform(), squad_path)
	_track(hostile)
	_refresh_visibility()


func _clear_wave() -> void:
	FlagSystem.record_event(&"siege_wave_cleared", {"wave": wave_index + 1, "waves": wave_count()})
	wave_cleared.emit(wave_index + 1)
	if wave_index + 1 >= wave_count():
		_end(SURVIVED)
	else:
		_next_intermission()


## Host: the siege is over. `outcome` is SURVIVED or FALLEN.
func _end(outcome: StringName) -> void:
	if not multiplayer.is_server() or not is_running():
		return
	_set_state(State.SURVIVED if outcome == SURVIVED else State.FALLEN)
	_roster.clear()
	for hostile: HostileAgent in _hostiles:
		if is_instance_valid(hostile):
			hostile.queue_free()
	_hostiles.clear()
	if enemies_root != null:
		for child: Node in enemies_root.get_children():
			child.queue_free()
	var payload: Dictionary = {"wave": wave_index + 1, "waves": wave_count(), "neutralized": neutralized}
	FlagSystem.set_flag(FLAG_ACTIVE, false)
	FlagSystem.set_flag(FLAG_OUTCOME, outcome)
	if outcome == SURVIVED:
		Career.award_team(plan.xp_survived, "Station held", "missions")
		FlagSystem.record_event(&"station_siege_survived", payload)
		MissionDirector.announce("STATION HELD",
			"All %d waves repelled · %d attackers neutralized · +%d XP" % [wave_count(), neutralized, plan.xp_survived])
	else:
		Career.award_team(plan.xp_fallen, "Station overrun")
		FlagSystem.record_event(&"station_siege_fallen", payload)
		MissionDirector.announce("STATION OVERRUN",
			"The cult took Station 4 on wave %d of %d." % [wave_index + 1, wave_count()])
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var player: Player = node as Player
		if player != null:
			player.get_health().restore()
	if _shift_was_running:
		CallDirector.resume_shift()
	_push_status()
	finished.emit(outcome)


# --- Hostiles -----------------------------------------------------------------------------------

func _on_enemy_added(node: Node) -> void:
	if multiplayer.is_server() and is_running():
		_track(node as HostileAgent)


func _track(hostile: HostileAgent) -> void:
	if hostile != null and not hostile in _hostiles:
		_hostiles.append(hostile)


func _prune() -> void:
	for hostile: HostileAgent in _hostiles.duplicate():
		if not is_instance_valid(hostile) or not hostile.is_active():
			_hostiles.erase(hostile)
	hostiles_left = _hostiles.size() + _roster.size()


func _on_neutralized(hostile: Node, by_peer: int) -> void:
	if not multiplayer.is_server() or not is_running() or not hostile in _hostiles:
		return
	neutralized += 1
	if by_peer != 0 and plan != null:
		Career.award(by_peer, plan.xp_per_hostile, "Station defended", "kills")


## Hostiles that lost sight of the team are told where the nearest standing officer is, so the horde keeps
## pressing into the station instead of wandering the parking lot.
func _hunt() -> void:
	var officers: Array[Player] = _standing_players()
	for hostile: HostileAgent in _hostiles:
		if not is_instance_valid(hostile) or not hostile.is_active() or not hostile.is_inside_tree():
			continue
		var perception: AIPerception = hostile.perception
		if perception == null or (perception.level == AIPerception.Level.COMBAT and perception.is_target_visible):
			continue
		var target: Player = _nearest(officers, hostile.global_position)
		if target != null:
			perception.receive_callout(target.peer_id, target.global_position)
		elif defend_point != null:
			perception.alert(defend_point.global_position)


func _check_wipe(delta: float) -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group(Player.GROUP)
	if players.is_empty() or not _standing_players().is_empty():
		_wipe_timer = 0.0
		return
	_wipe_timer += delta
	if _wipe_timer >= plan.wipe_grace_sec:
		_end(FALLEN)


func _standing_players() -> Array[Player]:
	var standing: Array[Player] = []
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var player: Player = node as Player
		if player != null and not player.connection_lost and player.get_health().is_alive():
			standing.append(player)
	return standing


static func _nearest(players: Array[Player], from: Vector3) -> Player:
	var best: Player = null
	var best_distance: float = INF
	for player: Player in players:
		var distance: float = player.global_position.distance_squared_to(from)
		if distance < best_distance:
			best_distance = distance
			best = player
	return best


## Next entry marker in turn, a little scattered and snapped to the navmesh, facing the operations room.
func _entry_transform() -> Transform3D:
	var origin: Vector3 = global_position
	if entry_points != null and entry_points.get_child_count() > 0:
		var marker: Node3D = entry_points.get_child(_entry_cursor % entry_points.get_child_count()) as Node3D
		_entry_cursor += 1
		origin = marker.global_position
	origin += Vector3(_rng.randf_range(-SPAWN_JITTER, SPAWN_JITTER), 0.0, _rng.randf_range(-SPAWN_JITTER, SPAWN_JITTER))
	if navigation != null and navigation.is_ready_for_ai:
		origin = NavigationServer3D.map_get_closest_point(navigation.get_navigation_map(), origin)
	var facing: Vector3 = Vector3.FORWARD
	if defend_point != null:
		facing = (defend_point.global_position - origin) * Vector3(1, 0, 1)
	if facing.length_squared() < 0.01:
		facing = Vector3.FORWARD
	return Transform3D(Basis.looking_at(facing.normalized()), origin)


# --- Station ------------------------------------------------------------------------------------

func _breach_doors() -> void:
	var doors: Node = get_node_or_null(doors_path) if not doors_path.is_empty() else null
	if doors == null:
		return
	for node: Node in doors.find_children("*", "Door", true, false):
		var door: Door = node as Door
		if door.current_state == Door.DoorState.CLOSED or door.current_state == Door.DoorState.PEEK:
			door.is_locked = false
			door.interact(Door.DoorAction.KICK, door.global_position + door.global_basis.z, 0)


func _prepare_navigation() -> void:
	if navigation == null or navigation.is_ready_for_ai:
		_next_intermission()
		return
	for path: NodePath in nav_sources:
		var source: Node = get_node_or_null(path)
		if source != null:
			source.add_to_group(NAV_SOURCE_GROUP)
	navigation.navigation_ready.connect(func(_covers: int) -> void:
		if state == State.BREACH:
			_next_intermission(), CONNECT_ONE_SHOT)
	navigation.bake_now()


## Siege hostiles only replicate to peers that loaded the station (see PlayerSpawner).
func _refresh_visibility() -> void:
	var level: Node = owner if owner != null else get_parent()
	if level == null:
		return
	for node: Node in level.find_children("*", "PlayerSpawner", true, false):
		(node as PlayerSpawner).refresh_visibility()
		return


func _set_state(new_state: State) -> void:
	state = new_state
	_prune()
	_push_status()
	state_changed.emit(state)


func _push_status() -> void:
	_status_timer = STATUS_INTERVAL_SEC
	var status: Array = [state, wave_index, wave_count(), hostiles_left, ceili(maxf(countdown, 0.0))]
	if _has_peers():
		_sync_status.rpc(status)
	else:
		_sync_status(status)


@rpc("authority", "call_local", "reliable")
func _sync_status(status: Array) -> void:
	if status.size() < 5:
		return
	var new_state: int = status[0]
	var wave: int = status[1]
	var waves: int = status[2]
	var left: int = status[3]
	var seconds: int = status[4]
	if not multiplayer.is_server():
		state = new_state as State
		wave_index = wave
		hostiles_left = left
		countdown = seconds
	_set_power(not is_running())
	_update_hud(wave, waves, left, seconds)


## Blackout: every station light goes dark and the red emergency lights blink (each peer, visual only).
func _set_power(on: bool) -> void:
	if on == _powered:
		return
	_powered = on
	if not on:
		for path: NodePath in power_roots:
			var root: Node = get_node_or_null(path)
			if root == null:
				continue
			for node: Node in root.find_children("*", "Light3D", true, false):
				var light: Light3D = node as Light3D
				if light is DirectionalLight3D or not light.visible or is_ancestor_of(light):
					continue
				light.visible = false
				_dimmed.append(light)
	else:
		for light: Light3D in _dimmed:
			if is_instance_valid(light):
				light.visible = true
		_dimmed.clear()
	if emergency_lights != null:
		emergency_lights.visible = not on
	_flicker = 0.0


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "SiegeHud"
	_hud.layer = 5
	_hud.visible = false
	add_child(_hud)
	_hud_label = Label.new()
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hud_label.offset_top = 64.0
	_hud_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hud_label.add_theme_font_size_override(&"font_size", 22)
	_hud_label.add_theme_color_override(&"font_color", Color(1.0, 0.35, 0.3))
	_hud_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_hud_label.add_theme_constant_override(&"outline_size", 6)
	_hud.add_child(_hud_label)


func _update_hud(wave: int, waves: int, left: int, seconds: int) -> void:
	if _hud_label == null:
		return
	_hud.visible = is_running()
	match state:
		State.BREACH:
			_hud_label.text = "STATION UNDER SIEGE — the cult is breaking in"
		State.INTERMISSION:
			_hud_label.text = "Wave %d / %d in %ds — arm up at the armory, hold the operations room" % [wave + 1, waves, seconds]
		State.WAVE:
			_hud_label.text = "WAVE %d / %d — attackers left: %d" % [wave + 1, waves, left]


func _has_peers() -> bool:
	return multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
