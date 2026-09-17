## The Drowned Woman, Class-B hunter (GAMEPLAY_MECHANICS §9.2):
##   DORMANT ─(EMF ≥ 3 / basement entered / shift trigger)→ MANIFEST ─6 s→ STALK ─(target sanity < 40 or 45 s)→ HUNT
##   HUNT ─(≤ 2 m)→ ATTACK ─(released)→ RETREAT ─(30–60 s)→ STALK (players in zone) / DORMANT
##   STALK ─(all flashlights in the zone off for 20 s)→ MANIFEST
##   reverse tone → RETREAT · salt line / everyone leaves the zone → DORMANT · bones buried → BANISHED
## Authority: HOST
class_name DrownedWoman
extends Anomaly

const DORMANT: StringName = &"dormant"
const MANIFEST: StringName = &"manifest"
const STALK: StringName = &"stalk"
const HUNT: StringName = &"hunt"
const ATTACK: StringName = &"attack"
const RETREAT: StringName = &"retreat"
const BANISHED: StringName = &"banished"

const MANIFEST_SECONDS: float = 6.0
const MANIFEST_SANITY_DRAIN: float = 4.0       # per second, players with line of sight
const STALK_SANITY_TRIGGER: float = 40.0
const STALK_TELEPORT_INTERVAL: Vector2 = Vector2(6.0, 10.0)
const LIGHTS_OFF_REMANIFEST: float = 20.0
const HUNT_KILL_LIGHT_RADIUS: float = 6.0
const ATTACK_RANGE: float = 2.0
const GRAB_SECONDS: float = 3.0
const GRAB_BREAK_LIGHT_DISTANCE: float = 8.0
const ATTACK_DAMAGE: float = 60.0
const ATTACK_SANITY: float = 40.0

signal whispered(peer_id: int)
signal water_level_changed(level: float)

@export var hunt_speed: float = 3.8
@export var stalk_duration: float = 45.0
@export var retreat_cooldown: Vector2 = Vector2(30.0, 60.0)

var target: Player = null
## 0..1, rises while hunting (level designers drive a water plane from `water_level_changed`).
var water_level: float = 0.0
var emf_level: int = 1

var _retreat_for: float = 0.0
var _next_teleport_at: float = 0.0
var _lights_off_time: float = 0.0
var _grabbed_by_released: bool = false
var _stalk_time: float = 0.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D


func _build_states() -> void:
	fsm.add_state(DORMANT, _enter_dormant, _update_dormant)
	fsm.add_state(MANIFEST, _enter_manifest, _update_manifest)
	fsm.add_state(STALK, _enter_stalk, _update_stalk)
	fsm.add_state(HUNT, _enter_hunt, _update_hunt)
	fsm.add_state(ATTACK, _enter_attack, _update_attack, _exit_attack)
	fsm.add_state(RETREAT, _enter_retreat, _update_retreat)
	fsm.add_state(BANISHED, _enter_banished)
	fsm.start(DORMANT)


# --- Triggers & weaknesses (host API; called by tools, zones, rituals) ----------------

## EMF reader interaction (P? EMF tools): level ≥ 3 wakes her.
func notify_emf(level: int) -> void:
	if fsm.current == DORMANT and level >= 3 and _manifest_allowed():
		fsm.transition_to(MANIFEST)


## A player walked into the basement trigger.
func notify_basement_entered() -> void:
	if fsm.current == DORMANT and _manifest_allowed():
		fsm.transition_to(MANIFEST)


## Scripted shift-minute trigger.
func trigger() -> void:
	if fsm.current == DORMANT:
		fsm.transition_to(MANIFEST)


func on_reverse_tone_complete() -> void:
	if fsm.current in [STALK, HUNT, ATTACK, MANIFEST]:
		fsm.transition_to(RETREAT)


func on_salt_line() -> void:
	if fsm.current != BANISHED and fsm.current != DORMANT:
		fsm.transition_to(DORMANT)


## Salt thrown at her while she holds someone breaks the grab.
func on_salt_thrown() -> void:
	if fsm.current == ATTACK:
		_grabbed_by_released = true


func on_bones_buried() -> void:
	fsm.transition_to(BANISHED)


# --- States -----------------------------------------------------------------------

func _enter_dormant() -> void:
	manifested = false
	target = null
	emf_level = 1 + _rng.randi() % 2
	_set_collision(false)
	_stop()


func _update_dormant(_delta: float) -> StringName:
	return &""


func _enter_manifest() -> void:
	manifested = true
	emf_level = 5
	var spot: Node3D = _pick_dark_node(false)
	if spot != null:
		global_position = spot.global_position
	_fx.rpc(&"flicker_lights")
	_fx.rpc(&"slam_doors")


func _update_manifest(delta: float) -> StringName:
	for player: Player in players_in_zone():
		if _has_line_of_sight(player):
			player.apply_sanity_damage(MANIFEST_SANITY_DRAIN * delta, &"drowned_woman")
	return STALK if fsm.time_in_state >= MANIFEST_SECONDS else &""


func _enter_stalk() -> void:
	manifested = false
	_set_collision(false)
	_stop()
	_stalk_time = 0.0
	_lights_off_time = 0.0
	_next_teleport_at = _rng.randf_range(STALK_TELEPORT_INTERVAL.x, STALK_TELEPORT_INTERVAL.y)
	_choose_target()
	if target != null:
		whispered.emit(target.peer_id)
		if NetManager.is_online() and target.peer_id != multiplayer.get_unique_id():
			_whisper_name.rpc_id(target.peer_id)
		else:
			_whisper_name()


func _update_stalk(delta: float) -> StringName:
	var inside: Array[Player] = players_in_zone()
	if inside.is_empty():
		return DORMANT
	_stalk_time += delta
	_choose_target()
	if fsm.time_in_state >= _next_teleport_at:
		_next_teleport_at = fsm.time_in_state + _rng.randf_range(STALK_TELEPORT_INTERVAL.x, STALK_TELEPORT_INTERVAL.y)
		var spot: Node3D = _pick_dark_node(true)
		if spot != null:
			global_position = spot.global_position
	var any_light: bool = false
	for player: Player in inside:
		any_light = any_light or player.flashlight_on
	_lights_off_time = 0.0 if any_light else _lights_off_time + delta
	if _lights_off_time >= LIGHTS_OFF_REMANIFEST:
		return MANIFEST
	if target != null and (target.sanity < STALK_SANITY_TRIGGER or _stalk_time >= stalk_duration):
		return HUNT
	return &""


func _enter_hunt() -> void:
	manifested = true
	_set_collision(true)
	_choose_target()
	_fx.rpc(&"hunt_scream")


func _update_hunt(delta: float) -> StringName:
	var inside: Array[Player] = players_in_zone()
	if inside.is_empty():
		return DORMANT
	if target == null or not target.get_health().is_alive() or not is_in_zone(target.global_position):
		_choose_target()
		if target == null:
			return RETREAT
	water_level = minf(water_level + delta * 0.02, 1.0)
	water_level_changed.emit(water_level)
	_kill_lights_near()
	var distance: float = global_position.distance_to(target.global_position)
	if distance <= ATTACK_RANGE:
		return ATTACK
	nav_agent.target_position = target.global_position
	var next: Vector3 = nav_agent.get_next_path_position()
	var direction: Vector3 = next - global_position
	direction.y = 0.0
	if direction.length() < 0.05:
		direction = target.global_position - global_position
		direction.y = 0.0
	direction = direction.normalized()
	velocity = direction * hunt_speed
	if direction.length() > 0.1:
		rotation.y = atan2(-direction.x, -direction.z)
	move_and_slide()
	return &""


func _enter_attack() -> void:
	_stop()
	_grabbed_by_released = false
	if target != null:
		target.set_grabbed_by_anomaly(true)
	_fx.rpc(&"grab")


func _update_attack(_delta: float) -> StringName:
	if target == null:
		return RETREAT
	# Teammates break the grab by shining a flashlight on her (or salt, see on_salt_thrown).
	for player: Player in players_in_zone():
		if player != target and is_lit_by(player, GRAB_BREAK_LIGHT_DISTANCE):
			_grabbed_by_released = true
	if _grabbed_by_released:
		return RETREAT
	if fsm.time_in_state >= GRAB_SECONDS:
		target.get_health().apply_damage(ATTACK_DAMAGE, HealthComponent.HitZone.TORSO)
		target.apply_sanity_damage(ATTACK_SANITY, &"drowned_woman_grab")
		return RETREAT
	return &""


func _exit_attack() -> void:
	if target != null:
		target.set_grabbed_by_anomaly(false)


func _enter_retreat() -> void:
	manifested = false
	_set_collision(false)
	_stop()
	_retreat_for = _rng.randf_range(retreat_cooldown.x, retreat_cooldown.y)
	_fx.rpc(&"vanish")


func _update_retreat(_delta: float) -> StringName:
	if fsm.time_in_state < _retreat_for:
		return &""
	return STALK if not players_in_zone().is_empty() else DORMANT


func _enter_banished() -> void:
	manifested = false
	target = null
	emf_level = 0
	_set_collision(false)
	_stop()
	_fx.rpc(&"banished")


# --- Helpers -------------------------------------------------------------------------

func _manifest_allowed() -> bool:
	var director: Node = get_node_or_null(^"/root/TensionDirector")
	if director == null:
		return true
	var allowed: bool = director.call(&"can_manifest")
	return allowed


func _choose_target() -> void:
	var inside: Array[Player] = players_in_zone()
	var alive: Array[Player] = inside.filter(func(p: Player) -> bool: return p.get_health().is_alive())
	target = lowest_sanity_player(alive)


func _pick_dark_node(out_of_sight: bool) -> Node3D:
	var candidates: Array[Node3D] = dark_nodes()
	if out_of_sight:
		candidates = candidates.filter(func(n: Node3D) -> bool: return not can_any_player_see(n.global_position))
	if candidates.is_empty():
		return null
	return candidates[_rng.randi() % candidates.size()]


func _kill_lights_near() -> void:
	for light: Light3D in lights_near(global_position, HUNT_KILL_LIGHT_RADIUS):
		_set_light_visible.rpc(get_path_to(light), false)
	for player: Player in players_in_zone():
		if player.flashlight_on and player.global_position.distance_to(global_position) <= HUNT_KILL_LIGHT_RADIUS:
			player.force_flashlight_off()


func _has_line_of_sight(player: Player) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(player.get_eye_position(), global_position + Vector3(0, 1.4, 0), 1, [player.get_rid(), get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _set_collision(enabled: bool) -> void:
	collision_layer = 1 if enabled else 0


func _stop() -> void:
	velocity = Vector3.ZERO


# --- Client FX ----------------------------------------------------------------------

func _apply_state_visuals() -> void:
	super()


@rpc("authority", "call_local", "reliable")
func _fx(effect: StringName) -> void:
	match effect:
		&"flicker_lights":
			for light: Light3D in lights_near(global_position, 25.0):
				_flicker(light)
		&"slam_doors":
			for node: Node in get_tree().get_nodes_in_group(&"doors"):
				if node.has_method(&"force_close"):
					node.call(&"force_close")
	var body: Node3D = get_node_or_null(^"Body") as Node3D
	if body != null:
		body.visible = manifested


func _flicker(light: Light3D) -> void:
	var base_energy: float = light.light_energy
	for i: int in 6:
		light.light_energy = base_energy * (0.1 if i % 2 == 0 else 1.0)
		await get_tree().create_timer(0.08).timeout
	light.light_energy = base_energy


@rpc("authority", "call_local", "reliable")
func _set_light_visible(path: NodePath, value: bool) -> void:
	var light: Light3D = get_node_or_null(path) as Light3D
	if light != null:
		light.visible = value


## Only the stalked player hears their name on the radio.
@rpc("authority", "call_remote", "reliable")
func _whisper_name() -> void:
	EventBus.hallucination.emit(&"radio_whisper", global_position)
