## First-person player controller: walk, sprint, crouch, lean, stamina, flashlight.
## The owner simulates and publishes `sync_*` + stance/lean/sprint/flashlight through ClientSync;
## everyone else smooths toward them. The host validates movement in MovementValidator.
## Authority: OWNING PEER (client-authoritative movement, host-validated)
class_name Player
extends CharacterBody3D

enum Stance { STAND, CROUCH }

## Movement while downed (GAMEPLAY §3.1 "crawl allowed").
const CRAWL_SPEED: float = 0.6
## Footstep noise radii (GAMEPLAY §7), scaled by ClassData.noise_multiplier (Breacher 1.6 -> ~7 m walk).
const FOOTSTEP_NOISE_WALK: float = 4.0
const FOOTSTEP_NOISE_SPRINT: float = 10.0
const FOOTSTEP_NOISE_CROUCH: float = 1.5
const FOOTSTEP_NOISE_INTERVAL: float = 0.45

const GROUP: StringName = &"players"

signal stance_changed(new_stance: Stance)
signal stamina_changed(value: float, max_value: float)
signal exhausted()
signal interaction_prompt_changed(prompt: String)

@export_group("Speed")
@export var walk_speed: float = 3.5            # Drowned Woman hunt speed (3.8) = 1.1x walk
@export var sprint_speed: float = 4.75         # ...and 0.8x sprint (GAMEPLAY_MECHANICS §9)
@export var crouch_speed: float = 1.75
## Class multiplier (GAMEPLAY_MECHANICS §2) x trait modifiers such as Limping (0.7).
@export var move_speed_multiplier: float = 1.0
@export var ground_acceleration: float = 12.0
@export var air_acceleration: float = 2.0

@export_group("Stamina")
## Seconds of continuous sprint (per class: 5-7 s).
@export var sprint_duration: float = 7.0
@export var stamina_regen_delay: float = 1.0
## Stamina seconds recovered per real second.
@export var stamina_regen_rate: float = 1.5
## After running dry, sprint unlocks again only once stamina reaches this value.
@export var stamina_recover_threshold: float = 2.0

@export_group("Crouch")
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.1
@export var eye_offset: float = 0.15
@export var crouch_transition_speed: float = 5.0
@export var crouch_toggle: bool = false

@export_group("Lean")
@export var lean_distance: float = 0.45
@export var lean_angle_degrees: float = 12.0
@export var lean_speed: float = 7.0
@export var lean_wall_margin: float = 0.25

@export_group("Look")
@export var mouse_sensitivity: float = 0.0022
@export var max_pitch_degrees: float = 85.0

@export_group("Network")
## How fast remote copies catch up with the replicated transform (1/s).
@export var remote_smoothing: float = 18.0
## Remote copies snap instead of gliding when further than this.
@export var remote_snap_distance: float = 4.0

@export_group("Interaction")
@export var interaction_reach: float = 2.6

@export_group("Audio / Footsteps")
## Walking / footstep audio stream (drag & drop here in Inspector).
@export var footstep_sound: AudioStream
## Optional array of footstep variations; if non-empty, one is chosen at random.
@export var footstep_sounds: Array[AudioStream] = []
## Base playback volume in dB.
@export var footstep_volume_db: float = 0.0
## How fast footstep sound fades in and out when starting and stopping (higher = faster).
@export var footstep_fade_speed: float = 8.0

@export var peer_id: int = 1:
	set(value):
		peer_id = value
		set_multiplayer_authority(value)
		# Host-owned state (spawn visibility now, health/sanity later) stays with the host.
		var host_sync: Node = get_node_or_null(^"HostSync")
		if host_sync != null:
			host_sync.set_multiplayer_authority(1)
		# Host-validated gameplay nodes carried by the player also stay with the host.
		for host_owned: NodePath in [^"Health", ^"ReviveArea"]:
			var node: Node = get_node_or_null(host_owned)
			if node != null:
				node.set_multiplayer_authority(1)
		if is_node_ready():
			_apply_authority()

## Host-replicated (HostSync): the owner dropped; the body waits for a reconnect.
var connection_lost: bool = false:
	set(value):
		connection_lost = value
		if _name_label != null:
			_update_name_label()

## 0..100. Host-owned, replicated by HostSync. Full sanity bands / drain rules arrive with P3-03.
var sanity: float = 100.0
## True while an anomaly holds this player (input disabled on the owner).
var grabbed_by_anomaly: bool = false

## Trauma kits carried (any class can revive with one). Host-owned, replicated by HostSync.
## TODO(P2-15): filled from the loadout armory.
var trauma_kits: int = 0

## Class this player was spawned as (see data/classes/).
var class_id: StringName = &""
var class_color: Color = Color(0.3, 0.8, 0.4)
var noise_multiplier: float = 1.0
var _noise_timer: float = 0.0
var _noise_last_position: Vector3 = Vector3.INF

# --- Replicated by ClientSync (owner -> everyone) ---
var sync_position: Vector3 = Vector3.ZERO
var sync_yaw: float = 0.0
var sync_pitch: float = 0.0
var stance: Stance = Stance.STAND
var lean_amount: float = 0.0          # -1..1
var is_sprinting: bool = false
var flashlight_on: bool = false:
	set(value):
		flashlight_on = value
		if _flashlight != null:
			_flashlight.visible = value

# Local only.
var stamina: float = 0.0

var _is_exhausted: bool = false
var _regen_cooldown: float = 0.0
var _crouch_toggled: bool = false
var _current_height: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var current_interaction_prompt: String = ""
var _current_door_target: Door = null

@onready var _input: PlayerInput = $PlayerInput
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _capsule: CapsuleShape3D = _collision.shape as CapsuleShape3D
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _interactor: PlayerInteractor = $PlayerInteractor
@onready var _hud: CanvasLayer = $HUD
@onready var _flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var _body: PlayerBody = $Body
@onready var _health: HealthComponent = $Health
@onready var _head_visual: Node3D = $Head/Camera3D/HeadVisual
@onready var _name_label: Label3D = $Head/NameLabel
@onready var _audio_listener: AudioListener3D = $Head/Camera3D/AudioListener3D
@onready var _footstep_player: AudioStreamPlayer3D = $FootstepPlayer


func _ready() -> void:
	add_to_group(GROUP)
	stamina = sprint_duration
	_current_height = stand_height
	_apply_height()
	_flashlight.visible = flashlight_on
	_body.set_class_color(class_color)
	_update_name_label()
	_publish_sync_state()
	_apply_authority()
	if _footstep_player != null:
		_footstep_player.finished.connect(_on_footstep_finished)


func _apply_authority() -> void:
	var is_local: bool = is_multiplayer_authority()
	_camera.current = is_local
	set_physics_process(is_local)
	set_process(true)  # owner: mouse look, remote: smoothing
	_interactor.set_physics_process(is_local)
	_hud.visible = is_local
	# Own body only casts shadows / shows to others; our camera does not render it.
	_body.set_first_person([_body, _head_visual, _name_label], is_local)
	if is_local:
		_camera.cull_mask = 0xFFFFF & ~PlayerBody.RENDER_LAYER_FIRST_PERSON
		if _audio_listener != null:
			_audio_listener.make_current()
	if is_local and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		_update_remote(delta)
		_update_body_pose(delta)
		_emit_footstep_noise(delta)
		return
	var look: Vector2 = _input.consume_look()
	if look == Vector2.ZERO:
		return
	rotate_y(-look.x * mouse_sensitivity)
	var max_pitch: float = deg_to_rad(max_pitch_degrees)
	_camera.rotation.x = clampf(_camera.rotation.x - look.y * mouse_sensitivity, -max_pitch, max_pitch)


func _physics_process(delta: float) -> void:
	_update_body_pose(delta)
	_emit_footstep_noise(delta)
	_input.sample()
	_update_stance(delta)
	_update_sprint_and_stamina(delta)
	_update_movement(delta)
	_update_lean(delta)
	_update_flashlight()
	_update_interaction()
	_update_footsteps(delta)
	_publish_sync_state()


## Returns the player owned by `peer_id` in the current tree, or null.
static func find_by_peer(tree: SceneTree, peer_id: int) -> Player:
	for node: Node in tree.get_nodes_in_group(GROUP):
		var player: Player = node as Player
		if player != null and player.peer_id == peer_id:
			return player
	return null


## Applies class stats. Call before the node enters the tree (PlayerSpawner does).
func apply_class(data: ClassData) -> void:
	if data == null:
		return
	class_id = data.id
	class_color = data.color
	noise_multiplier = data.noise_multiplier
	move_speed_multiplier = data.move_speed_multiplier
	sprint_duration = data.sprint_duration
	stamina = sprint_duration
	(get_node(^"Health") as HealthComponent).setup(data.max_health, data.damage_resistance)
	# TODO(P3-03): max_sanity, sanity drain.


## Owner: block gameplay input (pause menu, chat, cutscenes).
func set_input_enabled(enabled: bool) -> void:
	_input.enabled = enabled


func _update_name_label() -> void:
	var display_name: String = NetManager.get_player_name(peer_id)
	_name_label.text = "%s (disconnected)" % display_name if connection_lost else display_name
	_name_label.modulate = Color(0.6, 0.6, 0.6) if connection_lost else class_color.lightened(0.3)


## Host: lower sanity (anomalies, witnessing deaths…).
func apply_sanity_damage(amount: float, source: StringName) -> void:
	if not multiplayer.is_server() or amount <= 0.0:
		return
	sanity = clampf(sanity - amount, 0.0, 100.0)
	EventBus.sanity_damaged.emit(peer_id, amount, source)
	EventBus.sanity_changed.emit(peer_id, sanity)


## Host: make the owner switch their flashlight off (Drowned Woman kills lights).
func force_flashlight_off() -> void:
	if not multiplayer.is_server():
		return
	if is_multiplayer_authority():
		flashlight_on = false
	else:
		_rpc_flashlight_off.rpc_id(peer_id)


## Host: freeze / release the owner's controls while grabbed.
func set_grabbed_by_anomaly(grabbed: bool) -> void:
	if not multiplayer.is_server():
		return
	grabbed_by_anomaly = grabbed
	if is_multiplayer_authority():
		set_input_enabled(not grabbed)
	else:
		_rpc_set_grabbed.rpc_id(peer_id, grabbed)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_flashlight_off() -> void:
	if RpcGuard.is_from_host(self) and is_multiplayer_authority():
		flashlight_on = false


@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_grabbed(grabbed: bool) -> void:
	if RpcGuard.is_from_host(self) and is_multiplayer_authority():
		grabbed_by_anomaly = grabbed
		set_input_enabled(not grabbed)


func get_health() -> HealthComponent:
	return $Health


## Fastest legitimate horizontal speed (used by the host's MovementValidator).
func get_max_move_speed() -> float:
	var normal: float = maxf(maxf(walk_speed, sprint_speed), crouch_speed) * move_speed_multiplier
	# Keep the normal cap: a player going down mid-sprint still has momentum for a moment.
	return normal if get_health().is_alive() else maxf(CRAWL_SPEED, normal * 0.5)


## Owner: the host rejected our movement (MovementValidator); snap back.
func apply_server_correction(target_position: Vector3) -> void:
	global_position = target_position
	velocity = Vector3.ZERO
	_publish_sync_state()


func get_voice_emitter() -> AudioStreamPlayer3D:
	return $Head/VoiceEmitter


func get_camera() -> Camera3D:
	return _camera


func get_eye_position() -> Vector3:
	return _camera.global_position


func get_max_stamina() -> float:
	return sprint_duration


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


# --- Replication ------------------------------------------------------------

func _publish_sync_state() -> void:
	sync_position = global_position
	sync_yaw = rotation.y
	sync_pitch = _camera.rotation.x


## Host: moving players make footstep noise the AI can hear. Works for remote copies too (speed comes
## from the replicated position), so clients never report their own noise.
func _emit_footstep_noise(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _noise_last_position == Vector3.INF:
		_noise_last_position = global_position
		_noise_timer = 0.0
		return
	_noise_timer += delta
	if _noise_timer < FOOTSTEP_NOISE_INTERVAL:
		return
	var here: Vector3 = global_position
	var travelled: float = Vector2(here.x - _noise_last_position.x, here.z - _noise_last_position.z).length()
	var speed: float = travelled / _noise_timer
	_noise_timer = 0.0
	_noise_last_position = here
	if speed < 0.8 or not get_health().is_alive():
		return
	var radius: float = FOOTSTEP_NOISE_WALK
	if stance == Stance.CROUCH:
		radius = FOOTSTEP_NOISE_CROUCH
	elif is_sprinting or speed > walk_speed * move_speed_multiplier * 1.15:
		radius = FOOTSTEP_NOISE_SPRINT
	EventBus.noise_event.emit(here, radius * noise_multiplier, peer_id)


## Downed / critical bodies lie on the floor (all peers).
func _update_body_pose(delta: float) -> void:
	var target: float = 0.0 if _health.is_alive() else -1.35
	_body.rotation.x = lerpf(_body.rotation.x, target, clampf(6.0 * delta, 0.0, 1.0))


func _update_remote(delta: float) -> void:
	var prev_pos := global_position
	var weight: float = clampf(remote_smoothing * delta, 0.0, 1.0)
	if global_position.distance_to(sync_position) > remote_snap_distance:
		global_position = sync_position
	else:
		global_position = global_position.lerp(sync_position, weight)
	rotation.y = lerp_angle(rotation.y, sync_yaw, weight)
	_camera.rotation.x = lerp_angle(_camera.rotation.x, sync_pitch, weight)

	var target_height: float = stand_height if stance == Stance.STAND else crouch_height
	if not is_equal_approx(_current_height, target_height):
		_current_height = move_toward(_current_height, target_height, crouch_transition_speed * delta)
		_apply_height()
	_head.position.x = lean_amount * lean_distance
	_head.rotation.z = -lean_amount * deg_to_rad(lean_angle_degrees)

	# Remote player footstep sounds
	var moved: float = Vector2(global_position.x - prev_pos.x, global_position.z - prev_pos.z).length()
	var remote_moving: bool = (moved > 0.015)
	_update_footsteps_internal(delta, remote_moving)


# --- Flashlight -------------------------------------------------------------

func _update_flashlight() -> void:
	if _input.flashlight_just_pressed:
		flashlight_on = not flashlight_on


# --- Stance -----------------------------------------------------------------

func _update_stance(delta: float) -> void:
	if _input.crouch_just_pressed:
		_crouch_toggled = not _crouch_toggled
	var wants_crouch: bool = (_crouch_toggled if crouch_toggle else _input.crouch_held) or not _health.is_alive()

	if wants_crouch and stance == Stance.STAND:
		_set_stance(Stance.CROUCH)
	elif not wants_crouch and stance == Stance.CROUCH and _can_stand():
		_set_stance(Stance.STAND)

	var target_height: float = stand_height if stance == Stance.STAND else crouch_height
	if not is_equal_approx(_current_height, target_height):
		_current_height = move_toward(_current_height, target_height, crouch_transition_speed * delta)
		_apply_height()


func _set_stance(new_stance: Stance) -> void:
	stance = new_stance
	stance_changed.emit(stance)


## True when there is headroom to grow the capsule back to standing height.
func _can_stand() -> bool:
	var rise: float = stand_height - _current_height
	return rise <= 0.0 or not test_move(global_transform, Vector3.UP * rise)


func _apply_height() -> void:
	_capsule.height = _current_height
	_collision.position.y = _current_height * 0.5
	_head.position.y = _current_height - eye_offset
	if _body != null:
		_body.set_height_ratio(_current_height / stand_height)


# --- Sprint & stamina -------------------------------------------------------

func _update_sprint_and_stamina(delta: float) -> void:
	var moving_forward: bool = _input.move.y < -0.1
	is_sprinting = _input.sprint and moving_forward and stance == Stance.STAND and _health.is_alive() \
		and is_on_floor() and not _is_exhausted

	var previous: float = stamina
	if is_sprinting:
		stamina = maxf(stamina - delta, 0.0)
		_regen_cooldown = stamina_regen_delay
		if stamina <= 0.0:
			_is_exhausted = true
			is_sprinting = false
			exhausted.emit()
	elif _regen_cooldown > 0.0:
		_regen_cooldown -= delta
	else:
		stamina = minf(stamina + stamina_regen_rate * delta, sprint_duration)

	if _is_exhausted and stamina >= minf(stamina_recover_threshold, sprint_duration):
		_is_exhausted = false
	if not is_equal_approx(previous, stamina):
		stamina_changed.emit(stamina, sprint_duration)


# --- Movement ---------------------------------------------------------------

func _update_movement(delta: float) -> void:
	var speed: float = walk_speed
	if stance == Stance.CROUCH:
		speed = crouch_speed
	elif is_sprinting:
		speed = sprint_speed
	speed *= move_speed_multiplier
	match _health.state:
		HealthComponent.State.DOWNED:
			speed = CRAWL_SPEED
		HealthComponent.State.CRITICAL:
			speed = 0.0

	var direction: Vector3 = transform.basis * Vector3(_input.move.x, 0.0, _input.move.y)
	direction.y = 0.0
	direction = direction.normalized() * minf(_input.move.length(), 1.0)

	var target: Vector3 = direction * speed
	var accel: float = ground_acceleration if is_on_floor() else air_acceleration
	var weight: float = clampf(accel * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, target.x, weight)
	velocity.z = lerpf(velocity.z, target.z, weight)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()


# --- Lean -------------------------------------------------------------------

func _update_lean(delta: float) -> void:
	var target: float = 0.0 if is_sprinting else _input.lean
	if target != 0.0:
		target *= _lean_clearance(signf(target))
	lean_amount = move_toward(lean_amount, target, lean_speed * delta)
	_head.position.x = lean_amount * lean_distance
	_head.rotation.z = -lean_amount * deg_to_rad(lean_angle_degrees)


## Fraction (0..1) of the full lean that fits before the camera would enter a wall.
func _lean_clearance(side: float) -> float:
	var origin: Vector3 = global_transform * Vector3(0.0, _head.position.y, 0.0)
	var to: Vector3 = origin + global_basis.x * side * (lean_distance + lean_wall_margin)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, to, collision_mask, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 1.0
	var hit_pos: Vector3 = hit["position"]
	var free_distance: float = origin.distance_to(hit_pos) - lean_wall_margin
	return clampf(free_distance / lean_distance, 0.0, 1.0)


# --- Interaction ------------------------------------------------------------

func _update_interaction() -> void:
	var origin: Vector3 = _camera.global_position
	var to: Vector3 = origin - _camera.global_basis.z * interaction_reach
	var query := PhysicsRayQueryParameters3D.create(origin, to, collision_mask | 1, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)

	var detected_door: Door = null
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if collider is Node:
			var node: Node = collider as Node
			while node != null and not (node is Door):
				node = node.get_parent()
			if node is Door:
				detected_door = node as Door

	_current_door_target = detected_door
	var prompt: String = _current_door_target.get_prompt_text() if _current_door_target != null else ""
	if prompt != current_interaction_prompt:
		current_interaction_prompt = prompt
		interaction_prompt_changed.emit(current_interaction_prompt)

	if _current_door_target != null:
		if _input.interact_just_pressed:
			_current_door_target.interact(Door.DoorAction.TOGGLE_OPEN, global_position, peer_id)
		elif _input.door_peek_just_pressed:
			_current_door_target.interact(Door.DoorAction.PEEK, global_position, peer_id)
		elif _input.door_kick_just_pressed:
			_current_door_target.interact(Door.DoorAction.KICK, global_position, peer_id)


# --- Footstep Audio ---------------------------------------------------------

func _update_footsteps(delta: float) -> void:
	var is_moving: bool = is_on_floor() and get_horizontal_speed() > 0.4
	_update_footsteps_internal(delta, is_moving)


func _update_footsteps_internal(delta: float, is_moving: bool) -> void:
	if _footstep_player == null:
		return

	var stream: AudioStream = footstep_sound
	if stream == null and not footstep_sounds.is_empty():
		stream = footstep_sounds[0]

	if stream == null:
		return

	if _footstep_player.stream != stream:
		_footstep_player.stream = stream

	if is_moving:
		if not _footstep_player.playing:
			_footstep_player.volume_db = -45.0
			_footstep_player.play()

		var target_pitch: float = 1.3 if is_sprinting else (0.85 if stance == Stance.CROUCH else 1.0)
		var target_vol: float = (footstep_volume_db - 6.0) if stance == Stance.CROUCH else footstep_volume_db

		_footstep_player.pitch_scale = move_toward(_footstep_player.pitch_scale, target_pitch, 5.0 * delta)
		_footstep_player.volume_db = move_toward(_footstep_player.volume_db, target_vol, footstep_fade_speed * 30.0 * delta)
	else:
		if _footstep_player.playing:
			_footstep_player.volume_db = move_toward(_footstep_player.volume_db, -60.0, footstep_fade_speed * 35.0 * delta)
			if _footstep_player.volume_db <= -40.0:
				_footstep_player.stop()


func _on_footstep_finished() -> void:
	var is_moving: bool = (is_on_floor() and get_horizontal_speed() > 0.4) if is_multiplayer_authority() else true
	if is_moving and _footstep_player != null and _footstep_player.stream != null:
		_footstep_player.play()
