## First-person player controller: walk, sprint, crouch, lean, stamina, flashlight.
## The owner simulates and publishes `sync_*` + stance/lean/sprint/flashlight through ClientSync;
## everyone else smooths toward them. The host validates movement in MovementValidator.
## Authority: OWNING PEER (client-authoritative movement, host-validated)
class_name Player
extends CharacterBody3D

enum Stance { STAND, CROUCH }

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

@export var peer_id: int = 1:
	set(value):
		peer_id = value
		set_multiplayer_authority(value)
		# Host-owned state (spawn visibility now, health/sanity later) stays with the host.
		var host_sync: Node = get_node_or_null(^"HostSync")
		if host_sync != null:
			host_sync.set_multiplayer_authority(1)
		if is_node_ready():
			_apply_authority()

## Host-replicated (HostSync): the owner dropped; the body waits for a reconnect.
var connection_lost: bool = false:
	set(value):
		connection_lost = value
		if _name_label != null:
			_update_name_label()

## Class this player was spawned as (see data/classes/).
var class_id: StringName = &""
var class_color: Color = Color(0.3, 0.8, 0.4)

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
@onready var _head_visual: Node3D = $Head/Camera3D/HeadVisual
@onready var _name_label: Label3D = $Head/NameLabel


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
	if is_local and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		_update_remote(delta)
		return
	var look: Vector2 = _input.consume_look()
	if look == Vector2.ZERO:
		return
	rotate_y(-look.x * mouse_sensitivity)
	var max_pitch: float = deg_to_rad(max_pitch_degrees)
	_camera.rotation.x = clampf(_camera.rotation.x - look.y * mouse_sensitivity, -max_pitch, max_pitch)


func _physics_process(delta: float) -> void:
	_input.sample()
	_update_stance(delta)
	_update_sprint_and_stamina(delta)
	_update_movement(delta)
	_update_lean(delta)
	_update_flashlight()
	_update_interaction()
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
	move_speed_multiplier = data.move_speed_multiplier
	sprint_duration = data.sprint_duration
	stamina = sprint_duration
	# TODO(P3-02/P3-03): max_health, damage_resistance, max_sanity, sanity drain.


## Owner: block gameplay input (pause menu, chat, cutscenes).
func set_input_enabled(enabled: bool) -> void:
	_input.enabled = enabled


func _update_name_label() -> void:
	var display_name: String = NetManager.get_player_name(peer_id)
	_name_label.text = "%s (disconnected)" % display_name if connection_lost else display_name
	_name_label.modulate = Color(0.6, 0.6, 0.6) if connection_lost else class_color.lightened(0.3)


## Fastest legitimate horizontal speed (used by the host's MovementValidator).
func get_max_move_speed() -> float:
	return maxf(maxf(walk_speed, sprint_speed), crouch_speed) * move_speed_multiplier


## Owner: the host rejected our movement (MovementValidator); snap back.
func apply_server_correction(target_position: Vector3) -> void:
	global_position = target_position
	velocity = Vector3.ZERO
	_publish_sync_state()


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


func _update_remote(delta: float) -> void:
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


# --- Flashlight -------------------------------------------------------------

func _update_flashlight() -> void:
	if _input.flashlight_just_pressed:
		flashlight_on = not flashlight_on


# --- Stance -----------------------------------------------------------------

func _update_stance(delta: float) -> void:
	if _input.crouch_just_pressed:
		_crouch_toggled = not _crouch_toggled
	var wants_crouch: bool = _crouch_toggled if crouch_toggle else _input.crouch_held

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
	is_sprinting = _input.sprint and moving_forward and stance == Stance.STAND \
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
