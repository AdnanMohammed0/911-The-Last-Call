## First-person player controller: walk, sprint, crouch, lean, stamina.
## Authority: OWNING PEER (client-authoritative movement; host sanity checks come in P1-08).
class_name Player
extends CharacterBody3D

enum Stance { STAND, CROUCH }

signal stance_changed(new_stance: Stance)
signal stamina_changed(value: float, max_value: float)
signal exhausted()

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

@export var peer_id: int = 1:
	set(value):
		peer_id = value
		set_multiplayer_authority(value)
		if is_node_ready():
			_apply_authority()

# Replicated state (MultiplayerSynchronizer in P1-07).
var stance: Stance = Stance.STAND
var lean_amount: float = 0.0          # -1..1
var is_sprinting: bool = false
var stamina: float = 0.0

var _is_exhausted: bool = false
var _regen_cooldown: float = 0.0
var _crouch_toggled: bool = false
var _current_height: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _input: PlayerInput = $PlayerInput
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _capsule: CapsuleShape3D = _collision.shape as CapsuleShape3D
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D


func _ready() -> void:
	stamina = sprint_duration
	_current_height = stand_height
	_apply_height()
	_apply_authority()


func _apply_authority() -> void:
	var is_local: bool = is_multiplayer_authority()
	_camera.current = is_local
	set_physics_process(is_local)
	set_process(is_local)
	if is_local and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
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


func get_max_stamina() -> float:
	return sprint_duration


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


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
	var free_distance: float = origin.distance_to(hit["position"] as Vector3) - lean_wall_margin
	return clampf(free_distance / lean_distance, 0.0, 1.0)
