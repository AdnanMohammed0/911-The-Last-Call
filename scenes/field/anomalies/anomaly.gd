## Base for paranormal entities (GAMEPLAY_MECHANICS §9): a host-driven StateMachine, a haunted zone,
## helpers to find players, lights and dark nodes, and replication of position / state / visibility.
## Subclasses register their states in `_build_states()` and call `fsm.start(...)`.
## Authority: HOST
class_name Anomaly
extends CharacterBody3D

const GROUP: StringName = &"anomalies"
## Light3D nodes the anomaly can flicker or kill.
const LIGHTS_GROUP: StringName = &"anomaly_lights"
## Marker3D nodes the anomaly can teleport to while stalking.
const DARK_NODES_GROUP: StringName = &"anomaly_dark_nodes"

signal state_entered(state: StringName)

## Area3D that defines where this anomaly haunts (players inside count as "in the zone").
@export var zone: Area3D

## EMF emission level (0-5) for EMF Reader detection
@export var emf_level: int = 0

var fsm: StateMachine = StateMachine.new()

# --- Replicated (Sync) ---
var state_name: StringName = &"":
	set(value):
		state_name = value
		if is_node_ready() and not multiplayer.is_server():
			_apply_state_visuals()
var manifested: bool = false:
	set(value):
		manifested = value
		if is_node_ready():
			_apply_state_visuals()
var sync_position: Vector3 = Vector3.ZERO
var sync_yaw: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(GROUP)
	_rng.randomize()
	sync_position = global_position
	fsm.state_changed.connect(_on_state_changed)
	if multiplayer.is_server():
		_build_states()
	_apply_state_visuals()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		var weight: float = clampf(12.0 * delta, 0.0, 1.0)
		global_position = global_position.lerp(sync_position, weight) if global_position.distance_to(sync_position) < 5.0 else sync_position
		rotation.y = lerp_angle(rotation.y, sync_yaw, weight)
		return
	fsm.update(delta)
	sync_position = global_position
	sync_yaw = rotation.y


## Subclasses: add states and start the machine.
func _build_states() -> void:
	pass


# --- Queries --------------------------------------------------------------------

func players_in_zone() -> Array[Player]:
	var result: Array[Player] = []
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var player: Player = node as Player
		if player != null and player.get_health().state != HealthComponent.State.CRITICAL and is_in_zone(player.global_position):
			result.append(player)
	return result


func is_in_zone(point: Vector3) -> bool:
	if zone == null:
		return true
	return AIPerception._area_contains(zone, point + Vector3(0, 1.0, 0))


## Lowest sanity first; ties go to the player furthest from their teammates (isolated prey).
func lowest_sanity_player(candidates: Array[Player]) -> Player:
	var best: Player = null
	var best_key: float = INF
	for player: Player in candidates:
		var isolation: float = 0.0
		for other: Player in candidates:
			if other != player:
				isolation += player.global_position.distance_to(other.global_position)
		var key: float = player.sanity * 1000.0 - isolation
		if key < best_key:
			best_key = key
			best = player
	return best


func can_any_player_see(point: Vector3) -> bool:
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var player: Player = node as Player
		if player == null:
			continue
		var eye: Vector3 = player.get_eye_position()
		var to_point: Vector3 = point + Vector3(0, 1.4, 0) - eye
		var forward: Vector3 = -player.get_camera().global_basis.z
		if rad_to_deg(forward.angle_to(to_point.normalized())) > 55.0:
			continue
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, eye + to_point, 1, [player.get_rid(), get_rid()])
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return true
	return false


## True when `player` points a lit flashlight at us within `max_distance`.
func is_lit_by(player: Player, max_distance: float) -> bool:
	if not player.flashlight_on:
		return false
	var camera: Camera3D = player.get_camera()
	var offset: Vector3 = global_position + Vector3(0, 1.2, 0) - camera.global_position
	if offset.length() > max_distance:
		return false
	return rad_to_deg((-camera.global_basis.z).angle_to(offset.normalized())) <= 30.0


## Returns the current EMF emission level for EMF Reader detection
func get_emf_level() -> int:
	return emf_level


func lights_near(point: Vector3, radius: float) -> Array[Light3D]:
	var result: Array[Light3D] = []
	for node: Node in get_tree().get_nodes_in_group(LIGHTS_GROUP):
		var light: Light3D = node as Light3D
		if light != null and light.visible and light.global_position.distance_to(point) <= radius:
			result.append(light)
	return result


func dark_nodes() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group(DARK_NODES_GROUP):
		var marker: Node3D = node as Node3D
		if marker != null and is_in_zone(marker.global_position):
			result.append(marker)
	return result


# --- Replication ------------------------------------------------------------------

func _on_state_changed(_from: StringName, to: StringName) -> void:
	state_name = to
	_apply_state_visuals()
	state_entered.emit(to)


## Every peer: show / hide the body etc. Subclasses extend.
func _apply_state_visuals() -> void:
	var body: Node3D = get_node_or_null(^"Body") as Node3D
	if body != null:
		body.visible = manifested
