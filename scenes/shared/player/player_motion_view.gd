## Owner-only unarmed hands. Motion lives under the camera but never moves the camera or aim ray. The hands
## share the body's springy inertia: they trail sharp turns and swing back, sway with acceleration and stops,
## and dip on landing.
class_name PlayerMotionView
extends Node3D

@export_group("First Person Motion")
@export_range(0.0, 0.25, 0.01) var run_arm_pump: float = 0.17
@export_range(0.0, 0.1, 0.005) var walk_arm_swing: float = 0.045
@export_range(0.0, 0.08, 0.005) var side_sway: float = 0.035
@export_range(2.0, 20.0, 0.5) var settle_speed: float = 9.0
## Metres the hands trail per radian of sudden turn.
@export_range(0.0, 0.6, 0.01) var turn_drag: float = 0.3
## Metres the hands trail per m/s² of acceleration.
@export_range(0.0, 0.01, 0.0005) var accel_drag: float = 0.0045

var _player: Player
var _arms: Array[Node3D] = []
var _phase: float = 0.0
var _run_blend: float = 0.0
var _motion: float = 0.0
var _last_velocity: Vector2 = Vector2.ZERO
var _sway: float = 0.0
var _inertia: BodyDynamics.Spring = BodyDynamics.Spring.new(3.2, 0.38)
var _last_yaw: float = 0.0
var _air_time: float = 0.0
var _fall_speed: float = 0.0


func _ready() -> void:
	_player = get_parent().get_parent().get_parent() as Player
	_build_arms()
	visible = false


func _process(delta: float) -> void:
	if _player == null:
		return
	var yaw: float = _player.global_rotation.y
	var yaw_delta: float = angle_difference(_last_yaw, yaw)
	_last_yaw = yaw
	visible = _player.is_multiplayer_authority() and _player.get_weapons().get_active_weapon() == null \
		and _player.get_input().enabled and _player.get_health().is_alive()
	if not visible:
		return
	var planar: Vector2 = Vector2(_player.velocity.x, _player.velocity.z)
	var speed: float = planar.length() if _player.is_on_floor() else 0.0
	var weight: float = 1.0 - exp(-settle_speed * delta)
	_run_blend = lerpf(_run_blend, 1.0 if _player.is_sprinting and speed > 3.0 else 0.0, weight)
	_motion = lerpf(_motion, clampf(speed / maxf(_player.walk_speed, 0.1), 0.0, 1.0), weight)
	_phase += speed * delta * (2.5 + _run_blend * 0.45)
	var sideways: float = clampf((planar - _last_velocity).length() / maxf(delta, 0.001), 0.0, 25.0)
	var change: Vector2 = (planar - _last_velocity) / maxf(delta, 0.001)
	var local_accel: Vector3 = _player.global_basis.inverse() * Vector3(change.x, 0.0, change.y)
	if _player.is_on_floor():
		if _air_time > 0.2:
			_inertia.kick(Vector3(0.0, -0.9 * clampf(_fall_speed / 6.0, 0.2, 1.0), 0.0))
		_air_time = 0.0
		_fall_speed = 0.0
	else:
		_air_time += delta
		_fall_speed = maxf(_fall_speed, -_player.velocity.y)
	_inertia.value.x = clampf(_inertia.value.x + yaw_delta * turn_drag, -0.12, 0.12)
	var drag: Vector3 = Vector3(-local_accel.x, 0.0, -local_accel.z) * accel_drag
	var wobble: Vector3 = _inertia.step(drag.limit_length(0.07), delta)
	var local_velocity: Vector3 = _player.global_basis.inverse() * _player.velocity
	_sway = lerpf(_sway, clampf(-local_velocity.x / 6.0, -1.0, 1.0) * minf(sideways / 8.0, 1.0), weight)
	_last_velocity = planar
	for index: int in 2:
		var side: float = -1.0 if index == 0 else 1.0
		var arm: Node3D = _arms[index]
		var step: float = sin(_phase + (PI if index == 1 else 0.0))
		var pump: float = (walk_arm_swing + _run_blend * run_arm_pump) * _motion
		var target: Vector3 = Vector3(side * 0.32 + _sway * side_sway,
			-0.49 + maxf(step, 0.0) * pump + sin(_phase * 2.0) * 0.012 * _motion,
			-0.55 - step * pump * 0.5)
		arm.position = arm.position.lerp(target + wobble, weight)
		arm.rotation.x = lerpf(arm.rotation.x, -0.35 + step * pump * 1.7, weight)
		arm.rotation.z = lerpf(arm.rotation.z, -side * (0.1 + _run_blend * 0.17) - wobble.x * 1.4, weight)


func _build_arms() -> void:
	var cloth: StandardMaterial3D = StandardMaterial3D.new()
	cloth.albedo_color = Color(0.08, 0.11, 0.17)
	cloth.roughness = 0.95
	var glove: StandardMaterial3D = StandardMaterial3D.new()
	glove.albedo_color = Color(0.035, 0.04, 0.05)
	glove.roughness = 0.9
	for index: int in 2:
		var side: float = -1.0 if index == 0 else 1.0
		var arm: Node3D = Node3D.new()
		arm.name = "LeftArm" if index == 0 else "RightArm"
		arm.position = Vector3(side * 0.32, -0.49, -0.55)
		add_child(arm)
		_arms.append(arm)
		var sleeve: CapsuleMesh = CapsuleMesh.new()
		sleeve.radius = 0.073
		sleeve.height = 0.35
		_add_part(arm, "Sleeve", sleeve, cloth, Vector3(side * 0.02, -0.13, 0.10))
		var fist: SphereMesh = SphereMesh.new()
		fist.radius = 0.077
		fist.height = 0.135
		_add_part(arm, "Glove", fist, glove, Vector3(0.0, 0.045, -0.055))


func _add_part(parent: Node3D, part_name: String, mesh: Mesh, material: Material, at: Vector3) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
