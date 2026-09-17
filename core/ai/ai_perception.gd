## AI senses (GAMEPLAY_MECHANICS §8.2): vision cone (lit / dark range), flashlight-beam detection,
## hearing (EventBus noise + voice) and an awareness meter:
##   UNAWARE < 0.3 <= SUSPICIOUS < 0.6 <= SEARCHING < 1.0 = COMBAT
## After COMBAT_CALLOUT_SEC in combat it emits `callout` so the squad (P3-11) shares the target.
## Put it under the agent; `eye` is where the AI looks from (defaults to the agent + 1.6 m).
## Authority: HOST
class_name AIPerception
extends Node

enum Level { UNAWARE, SUSPICIOUS, SEARCHING, COMBAT }

const SUSPICIOUS_AT: float = 0.3
const SEARCHING_AT: float = 0.6
const COMBAT_AT: float = 1.0
const COMBAT_CALLOUT_SEC: float = 1.5
const LIGHT_ZONE_GROUP: StringName = &"light_zones"

signal level_changed(new_level: Level)
signal target_spotted(player: Player)
## Squad callout: share what we know with allies.
signal callout(target_peer: int, position: Vector3)

@export var eye: Node3D
@export var fov_degrees: float = 100.0
@export var sight_range_lit: float = 30.0
@export var sight_range_dark: float = 8.0
@export var flashlight_detect_range: float = 25.0
## Treat every target as lit (daylight exteriors).
@export var ambient_lit: bool = false
## Awareness per second when a target is fully visible up close.
@export var sight_gain: float = 1.6
@export var decay_per_sec: float = 0.06
## Seconds without seeing the target before COMBAT decays.
@export var combat_memory_sec: float = 6.0
@export var tick_rate: float = 10.0

var awareness: float = 0.0
var level: Level = Level.UNAWARE
var target: Player = null
var last_known_position: Vector3 = Vector3.INF
var last_noise_position: Vector3 = Vector3.INF
var is_target_visible: bool = false
var time_since_seen: float = INF
var visible_player_count: int = 0

var _accumulator: float = 0.0
var _combat_time: float = 0.0
var _called_out: bool = false

@onready var _agent: Node3D = get_parent() as Node3D


func _ready() -> void:
	EventBus.noise_event.connect(_on_noise)
	EventBus.voice_noise.connect(_on_voice_noise)
	_accumulator = randf() / tick_rate


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_accumulator += delta
	var interval: float = 1.0 / tick_rate
	if _accumulator < interval:
		return
	var step: float = _accumulator
	_accumulator = 0.0
	sense(step)


## One perception update over `delta` seconds (tests call it directly).
func sense(delta: float) -> void:
	var seen_any: bool = false
	var best_target: Player = null
	var best_gain: float = 0.0
	visible_player_count = 0
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var player: Player = node as Player
		if player == null or not player.get_health().is_alive():
			continue
		if flashlight_hits_me(player):
			_raise(COMBAT_AT)
			_see(player)
			return
		var gain: float = visibility_gain(player)
		if gain > 0.0:
			visible_player_count += 1
			seen_any = true
			if gain > best_gain:
				best_gain = gain
				best_target = player

	if best_target != null:
		_raise(minf(awareness + best_gain * sight_gain * delta, COMBAT_AT))
		if awareness >= SEARCHING_AT:
			_see(best_target)
		else:
			last_known_position = best_target.global_position
	else:
		is_target_visible = false
		time_since_seen += delta
		var decay: float = decay_per_sec * delta
		if level == Level.COMBAT and time_since_seen < combat_memory_sec:
			decay = 0.0
		awareness = maxf(awareness - decay, 0.0)
		_update_level()

	if level == Level.COMBAT:
		_combat_time += delta
		if not _called_out and _combat_time >= COMBAT_CALLOUT_SEC and last_known_position != Vector3.INF:
			_called_out = true
			callout.emit(target.peer_id if target != null else 0, last_known_position)
	else:
		_combat_time = 0.0
		_called_out = false
	if not seen_any and best_target == null:
		visible_player_count = 0


## 0 when not visible; otherwise 0..1 (closer and nearer the centre of the cone = stronger).
func visibility_gain(player: Player) -> float:
	var from: Vector3 = get_eye_position()
	var to: Vector3 = player.get_eye_position() - Vector3(0, 0.3, 0)
	var offset: Vector3 = to - from
	var distance: float = offset.length()
	var sight_range: float = sight_range_lit if is_lit(player) else sight_range_dark
	if distance > sight_range or distance < 0.01:
		return 0.0
	var angle: float = rad_to_deg(get_forward().angle_to(offset.normalized()))
	if angle > fov_degrees * 0.5:
		return 0.0
	if not has_line_of_sight(from, to, player):
		return 0.0
	var distance_factor: float = 1.0 - distance / sight_range
	var centre_factor: float = 1.0 - angle / (fov_degrees * 0.5) * 0.5
	var stance_factor: float = 0.6 if player.stance == Player.Stance.CROUCH else 1.0
	return clampf((0.25 + 0.75 * distance_factor) * centre_factor * stance_factor, 0.0, 1.0)


## A player's flashlight pointing at us within range (and with line of sight) = instant detection.
func flashlight_hits_me(player: Player) -> bool:
	if not player.flashlight_on:
		return false
	var camera: Camera3D = player.get_camera()
	var beam_origin: Vector3 = camera.global_position
	var me: Vector3 = get_eye_position() - Vector3(0, 0.4, 0)
	var offset: Vector3 = me - beam_origin
	if offset.length() > flashlight_detect_range:
		return false
	var spot: SpotLight3D = camera.get_node_or_null(^"Flashlight") as SpotLight3D
	var half_angle: float = spot.spot_angle if spot != null else 28.0
	var beam_forward: Vector3 = -camera.global_basis.z
	if rad_to_deg(beam_forward.angle_to(offset.normalized())) > half_angle:
		return false
	return has_line_of_sight(beam_origin, me, player)


func is_lit(player: Player) -> bool:
	if ambient_lit or player.flashlight_on:
		return true
	var point: Vector3 = player.global_position + Vector3(0, 1.0, 0)
	for node: Node in get_tree().get_nodes_in_group(LIGHT_ZONE_GROUP):
		var zone: Area3D = node as Area3D
		if zone != null and _area_contains(zone, point):
			return true
	return false


func has_line_of_sight(from: Vector3, to: Vector3, player: Player) -> bool:
	var exclude: Array[RID] = [player.get_rid()]
	var body: CollisionObject3D = _agent as CollisionObject3D
	if body != null:
		exclude.append(body.get_rid())
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
	return _agent.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func get_eye_position() -> Vector3:
	return eye.global_position if eye != null else _agent.global_position + Vector3(0, 1.6, 0)


func get_forward() -> Vector3:
	var basis: Basis = eye.global_basis if eye != null else _agent.global_basis
	return -basis.z


## Squad member called out a target: jump to combat knowledge without having seen it ourselves.
func receive_callout(target_peer: int, position: Vector3) -> void:
	last_known_position = position
	if target == null and target_peer != 0:
		target = Player.find_by_peer(get_tree(), target_peer)
	_raise(maxf(awareness, COMBAT_AT))
	time_since_seen = 0.0


## Force a level (scripted ambushes, alarms).
func alert(position: Vector3) -> void:
	last_known_position = position
	_raise(COMBAT_AT)
	time_since_seen = 0.0


func _see(player: Player) -> void:
	var was_target: Player = target
	target = player
	is_target_visible = true
	time_since_seen = 0.0
	last_known_position = player.global_position
	if was_target != player:
		target_spotted.emit(player)


func _raise(value: float) -> void:
	awareness = clampf(value, 0.0, COMBAT_AT)
	_update_level()


func _update_level() -> void:
	var new_level: Level = Level.UNAWARE
	if awareness >= COMBAT_AT:
		new_level = Level.COMBAT
	elif awareness >= SEARCHING_AT:
		new_level = Level.SEARCHING
	elif awareness >= SUSPICIOUS_AT:
		new_level = Level.SUSPICIOUS
	if new_level != level:
		level = new_level
		level_changed.emit(level)


func _on_noise(position: Vector3, radius: float, _source_peer: int) -> void:
	if not multiplayer.is_server():
		return
	var distance: float = get_eye_position().distance_to(position)
	if distance > radius:
		return
	last_noise_position = position
	if level != Level.COMBAT:
		# Louder / closer noises push further: a gunshot next to you means searching, a distant step suspicion.
		var strength: float = 1.0 - distance / maxf(radius, 0.01)
		_raise(maxf(awareness, SUSPICIOUS_AT + (SEARCHING_AT - SUSPICIOUS_AT + 0.05) * strength))


func _on_voice_noise(peer_id: int, position: Vector3, loudness: float) -> void:
	_on_noise(position, lerpf(2.0, 20.0, clampf(loudness, 0.0, 1.0)), peer_id)


static func _area_contains(zone: Area3D, point: Vector3) -> bool:
	for child: Node in zone.get_children():
		var shape_node: CollisionShape3D = child as CollisionShape3D
		if shape_node == null or shape_node.shape == null:
			continue
		var local: Vector3 = shape_node.global_transform.affine_inverse() * point
		var box: BoxShape3D = shape_node.shape as BoxShape3D
		var sphere: SphereShape3D = shape_node.shape as SphereShape3D
		if box != null and absf(local.x) <= box.size.x * 0.5 and absf(local.y) <= box.size.y * 0.5 and absf(local.z) <= box.size.z * 0.5:
			return true
		if sphere != null and local.length() <= sphere.radius:
			return true
	return false
