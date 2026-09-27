## Procedural humanoid used by players and hostiles: jointed body (pelvis, torso, head, two-bone arms and
## legs) posed every frame with analytic IK — hands on the weapon's grip and support point, feet on a walk
## cycle driven by how fast the character actually moves, crouch, lean, aim pitch and full-body poses
## (surrender, arrested, dead, reload, melee swing). Looks (clothes, head gear, vest) come from a look table
## so the same rig dresses a police officer, a hooded thug or a balaclava gunman.
## Faces -Z like every character in the game; feet on y = 0.
## Authority: LOCAL (purely visual; owners feed it replicated state)
class_name HumanoidRig
extends Node3D

enum Stance { UNARMED, RIFLE, PISTOL, MELEE }

const HIP_HEIGHT: float = 0.95
const THIGH: float = 0.43
const SHIN: float = 0.42
const UPPER_ARM: float = 0.29
const FOREARM: float = 0.28
const HIP_WIDTH: float = 0.1
const SHOULDER_WIDTH: float = 0.2
const SHOULDER_HEIGHT: float = 0.5
const NECK_HEIGHT: float = 0.62
const ANKLE_HEIGHT: float = 0.08
const CROUCH_DROP: float = 0.4

## Named outfits. Keys: skin, top, pants, boots, gloves (Color); head (cap / helmet / balaclava / beanie /
## hood / hair); head_color; vest (bool); vest_color; ied (bool); armband (Color, alpha 0 = none);
## back_text (String on the back of the vest).
const LOOKS: Dictionary[StringName, Dictionary] = {
	&"police": {"skin": Color(0.78, 0.6, 0.48), "top": Color(0.09, 0.12, 0.2), "pants": Color(0.07, 0.08, 0.12),
		"boots": Color(0.03, 0.03, 0.03), "gloves": Color(0.04, 0.04, 0.045), "head": &"cap", "head_color": Color(0.06, 0.08, 0.14),
		"vest": true, "vest_color": Color(0.12, 0.13, 0.14), "back_text": "POLICE"},
	&"thug": {"skin": Color(0.62, 0.45, 0.34), "top": Color(0.2, 0.2, 0.22), "pants": Color(0.12, 0.16, 0.26),
		"boots": Color(0.25, 0.22, 0.2), "gloves": Color(0.62, 0.45, 0.34), "head": &"beanie", "head_color": Color(0.08, 0.08, 0.09)},
	&"hostage_taker": {"skin": Color(0.72, 0.55, 0.43), "top": Color(0.06, 0.06, 0.07), "pants": Color(0.1, 0.1, 0.11),
		"boots": Color(0.04, 0.04, 0.04), "gloves": Color(0.03, 0.03, 0.03), "head": &"balaclava", "head_color": Color(0.05, 0.05, 0.05)},
	&"cultist_gunman": {"skin": Color(0.7, 0.54, 0.44), "top": Color(0.28, 0.04, 0.06), "pants": Color(0.08, 0.06, 0.06),
		"boots": Color(0.05, 0.04, 0.04), "gloves": Color(0.05, 0.04, 0.04), "head": &"hood", "head_color": Color(0.22, 0.03, 0.05)},
	&"ambush_leader": {"skin": Color(0.66, 0.5, 0.4), "top": Color(0.08, 0.08, 0.08), "pants": Color(0.1, 0.1, 0.09),
		"boots": Color(0.03, 0.03, 0.03), "gloves": Color(0.03, 0.03, 0.03), "head": &"balaclava", "head_color": Color(0.04, 0.04, 0.04),
		"vest": true, "vest_color": Color(0.2, 0.21, 0.17)},
	&"zealot": {"skin": Color(0.74, 0.57, 0.45), "top": Color(0.55, 0.5, 0.4), "pants": Color(0.25, 0.22, 0.17),
		"boots": Color(0.15, 0.12, 0.1), "gloves": Color(0.74, 0.57, 0.45), "head": &"hair", "head_color": Color(0.1, 0.07, 0.05), "ied": true},
	&"prankster": {"skin": Color(0.8, 0.63, 0.5), "top": Color(0.85, 0.35, 0.1), "pants": Color(0.2, 0.3, 0.5),
		"boots": Color(0.9, 0.9, 0.9), "gloves": Color(0.8, 0.63, 0.5), "head": &"cap", "head_color": Color(0.1, 0.3, 0.7)},
}

# --- Inputs (set by the owner every frame) ---
## Radians, positive = looking up.
var aim_pitch: float = 0.0
## 0 = standing, 1 = full crouch.
var crouch: float = 0.0
## -1..1 (left / right).
var lean: float = 0.0
var aiming: bool = false
var sprinting: bool = false
var reloading: bool = false
## idle (normal), surrender, arrested, dead, melee, flee.
var pose: StringName = &"idle"

var stance: Stance = Stance.UNARMED
var weapon: WeaponModel
var render_layers: int = 1

var _look: Dictionary = {}
var _materials: Dictionary[StringName, StandardMaterial3D] = {}
var _parts: Dictionary[StringName, MeshInstance3D] = {}
var _chest: Node3D
var _head: Node3D
var _weapon_socket: Node3D
var _last_position: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _phase: float = 0.0
var _gait: float = 0.0
var _crouch_smooth: float = 0.0
var _pose_blend: Dictionary[StringName, float] = {}
var _melee_time: float = -10.0
var _time: float = 0.0
var _started: bool = false


func _ready() -> void:
	if _look.is_empty():
		dress(&"police")
	_last_position = global_position


## (Re)build the body in outfit `look_id` (LOOKS) with optional overrides (e.g. {"armband": class colour}).
func dress(look_id: StringName, overrides: Dictionary = {}) -> void:
	var base: Dictionary = LOOKS.get(look_id, LOOKS[&"police"])
	_look = base.duplicate()
	_look.merge(overrides, true)
	if weapon != null and weapon.get_parent() != null:
		weapon.get_parent().remove_child(weapon)
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_parts.clear()
	_materials.clear()
	_build_body()
	if weapon != null:
		_attach_weapon(weapon)
	ModelKit.set_layers(self, render_layers)


## Put `model` in the character's hands (null = empty hands). The rig owns the model afterwards.
func set_weapon(model: WeaponModel, new_stance: Stance = Stance.RIFLE) -> void:
	if weapon != null and is_instance_valid(weapon):
		weapon.queue_free()
	weapon = model
	stance = new_stance if model != null else Stance.UNARMED
	if model != null:
		_attach_weapon(model)
		ModelKit.set_layers(model, render_layers)


func set_render_layers(layers: int) -> void:
	render_layers = layers
	ModelKit.set_layers(self, layers)


## Trigger a melee swing (hostile machete / rifle butt).
func play_melee() -> void:
	_melee_time = _time


## World position of the weapon muzzle (falls back to the chest).
func muzzle_position() -> Vector3:
	if weapon != null and weapon.muzzle != null and weapon.is_inside_tree():
		return weapon.muzzle.global_position
	return global_transform * Vector3(0.1, HIP_HEIGHT + 0.45, -0.4)


func get_head_node() -> Node3D:
	return _head


func _process(delta: float) -> void:
	if delta <= 0.0 or not is_inside_tree():
		return
	_time += delta
	var moved: Vector3 = global_position - _last_position
	_last_position = global_position
	if not _started:
		_started = true
		moved = Vector3.ZERO
	var local_move: Vector3 = global_basis.inverse() * (moved / delta)
	local_move.y = 0.0
	if local_move.length() > 12.0:
		local_move = Vector3.ZERO   # teleport / snap
	_velocity = _velocity.lerp(local_move, clampf(10.0 * delta, 0.0, 1.0))
	_crouch_smooth = lerpf(_crouch_smooth, crouch, clampf(10.0 * delta, 0.0, 1.0))
	for key: StringName in [&"surrender", &"arrested", &"dead"]:
		var current: float = _pose_blend.get(key, 0.0)
		_pose_blend[key] = move_toward(current, 1.0 if pose == key else 0.0, delta * 3.5)
	_solve(delta)


# --- Pose solver -------------------------------------------------------------------------------

func _solve(delta: float) -> void:
	var speed: float = _velocity.length()
	var dead: float = _pose_blend.get(&"dead", 0.0)
	var arrested: float = _pose_blend.get(&"arrested", 0.0)
	var surrender: float = _pose_blend.get(&"surrender", 0.0)
	var kneel: float = maxf(arrested, surrender * 0.85)
	var amount: float = clampf(speed / 3.5, 0.0, 1.5) * (1.0 - kneel)
	_gait = lerpf(_gait, amount, clampf(8.0 * delta, 0.0, 1.0))
	if _gait > 0.03:
		_phase += delta * TAU * (1.25 + speed * 0.32)
	var crouch_amount: float = maxf(_crouch_smooth, 0.0)
	var stride: float = clampf(speed * 0.19, 0.0, 0.6) * (1.0 - crouch_amount * 0.4)
	var move_dir: Vector3 = _velocity.normalized() if speed > 0.05 else Vector3.FORWARD
	var bob: float = absf(sin(_phase)) * 0.035 * _gait

	# Hips.
	var hip_y: float = HIP_HEIGHT - crouch_amount * CROUCH_DROP - kneel * 0.5 + bob - 0.02 * _gait
	var hips: Vector3 = Vector3(0.0, hip_y, 0.0)
	var hip_yaw: float = sin(_phase) * 0.08 * _gait
	# Torso: leans into the run, forward in a crouch, twists with the stride, rolls with lean.
	var torso_pitch: float = -0.12 * _gait - 0.3 * crouch_amount + (aim_pitch * 0.25 if stance != Stance.UNARMED else 0.0)
	if sprinting:
		torso_pitch -= 0.12
	var chest_basis: Basis = Basis.from_euler(Vector3(torso_pitch, -hip_yaw * 0.7, -lean * 0.22))
	if stance == Stance.RIFLE and pose != &"surrender":
		chest_basis = chest_basis * Basis(Vector3.UP, -0.22)
	_chest.transform = Transform3D(chest_basis, hips)
	var head_pitch: float = aim_pitch * 0.65 - torso_pitch * 0.5
	var head_tilt: float = 0.12 if stance == Stance.RIFLE and aiming and pose == &"idle" else 0.0
	_head.transform = Transform3D(Basis.from_euler(Vector3(head_pitch, 0.22 if head_tilt > 0.0 else 0.0, -head_tilt)), Vector3(0.0, NECK_HEIGHT, 0.0))
	_place(&"pelvis", hips + Vector3(0.0, 0.02, 0.0), Basis(Vector3.UP, hip_yaw))

	# Legs.
	for side: int in [-1, 1]:
		var hip_joint: Vector3 = hips + Basis(Vector3.UP, hip_yaw) * Vector3(side * HIP_WIDTH, -0.04, 0.0)
		var phase: float = _phase + (PI if side > 0 else 0.0)
		var swing: Vector3 = move_dir * sin(phase) * stride * 0.5
		var lift: float = maxf(0.0, cos(phase)) * 0.13 * minf(_gait, 1.0)
		var foot: Vector3 = Vector3(side * (HIP_WIDTH + 0.02 + crouch_amount * 0.05), ANKLE_HEIGHT + lift, 0.0) + swing
		if crouch_amount > 0.05 and _gait < 0.2:
			foot.z += (0.12 if side < 0 else -0.08) * crouch_amount
		if kneel > 0.01:
			# Kneeling: shins flat on the floor behind the hips.
			var knee_down: Vector3 = Vector3(side * 0.13, 0.08, -0.12)
			foot = foot.lerp(knee_down + Vector3(0, 0.02, SHIN), kneel)
		var pole: Vector3 = Vector3(side * 0.15, 0.0, -1.0)
		var joints: Array[Vector3] = _ik(hip_joint, foot, THIGH, SHIN, pole)
		_segment(_key("thigh", side), hip_joint, joints[0])
		_segment(_key("shin", side), joints[0], joints[1])
		var toe_pitch: float = -lift * 1.5
		_place(_key("foot", side), joints[1] + Vector3(0, -0.04, -0.06), Basis.from_euler(Vector3(toe_pitch, 0.0, 0.0)))

	# Arms.
	var shoulders: Array[Vector3] = [
		_chest.transform * Vector3(-SHOULDER_WIDTH, SHOULDER_HEIGHT, 0.0),
		_chest.transform * Vector3(SHOULDER_WIDTH, SHOULDER_HEIGHT, 0.0),
	]
	var hands: Array[Vector3] = _hand_targets(shoulders, hips, surrender, arrested)
	for index: int in 2:
		var side: int = -1 if index == 0 else 1
		var pole: Vector3 = Vector3(side * 0.9, -1.0, 0.6)
		if pose == &"surrender":
			pole = Vector3(side, 0.2, 0.5)
		var joints: Array[Vector3] = _ik(shoulders[index], hands[index], UPPER_ARM, FOREARM, pole)
		_segment(_key("upper_arm", side), shoulders[index], joints[0])
		_segment(_key("forearm", side), joints[0], joints[1])
		var dir: Vector3 = (joints[1] - joints[0]).normalized()
		_place(_key("hand", side), joints[1] + dir * 0.045, _basis_along(dir))

	# Weapon visible only while held.
	if weapon != null:
		weapon.visible = pose != &"surrender" and pose != &"arrested" and dead < 0.5

	# Death: fall onto the back around the feet.
	rotation.x = lerpf(0.0, -1.45, ease(dead, 0.6))
	position.y = dead * 0.12


## Where each hand goes this frame: on the weapon, swinging, raised or cuffed behind the back.
func _hand_targets(shoulders: Array[Vector3], hips: Vector3, surrender: float, arrested: float) -> Array[Vector3]:
	var swing: float = sin(_phase) * 0.22 * minf(_gait, 1.2)
	var relaxed: Array[Vector3] = [
		shoulders[0] + Vector3(-0.05, -0.53, -swing * 0.9),
		shoulders[1] + Vector3(0.05, -0.53, swing * 0.9),
	]
	var result: Array[Vector3] = relaxed.duplicate()
	if weapon != null and stance != Stance.UNARMED:
		_update_socket(shoulders[1])
		var grip: Vector3 = _weapon_socket.transform * Vector3(0.0, -0.035, 0.015)
		var support: Vector3 = _weapon_socket.transform * weapon.support_point
		if stance == Stance.MELEE:
			support = relaxed[0]
		if reloading and stance != Stance.MELEE:
			support = _weapon_socket.transform * Vector3(0.0, -0.12, weapon.support_point.z * 0.4)
		result = [support, grip]
	var raised: Array[Vector3] = [shoulders[0] + Vector3(-0.12, 0.42, -0.08), shoulders[1] + Vector3(0.12, 0.42, -0.08)]
	var cuffed: Array[Vector3] = [hips + Vector3(-0.07, 0.12, 0.2), hips + Vector3(0.07, 0.12, 0.2)]
	for i: int in 2:
		result[i] = result[i].lerp(raised[i], surrender).lerp(cuffed[i], arrested)
	return result


## Places the weapon socket: shouldered and following the aim, low ready while sprinting, one-handed swing
## for melee.
func _update_socket(right_shoulder: Vector3) -> void:
	var bounds: AABB = weapon.get_bounds()
	var rear: float = clampf(bounds.end.z, 0.0, 0.35)
	var pitch: float = aim_pitch
	var ready: float = 0.0 if aiming else 0.35
	if sprinting:
		ready = 0.9
	var socket: Transform3D
	match stance:
		Stance.PISTOL:
			var reach: Vector3 = Vector3(-0.17, -0.04, -0.46 if aiming else -0.38)
			socket = Transform3D(Basis.IDENTITY, right_shoulder + reach)
			ready *= 0.8
		Stance.MELEE:
			var swing_t: float = clampf((_time - _melee_time) / 0.45, 0.0, 1.0)
			var swing: float = sin(swing_t * PI) if swing_t < 1.0 else 0.0
			var hold: Basis = Basis.from_euler(Vector3(0.9 - swing * 2.4, 0.0, -0.2))
			socket = Transform3D(hold, right_shoulder + Vector3(0.05, -0.42 + swing * 0.35, -0.25 - swing * 0.2))
			pitch = 0.0
			ready = 0.0
		_:
			socket = Transform3D(Basis.IDENTITY, right_shoulder + Vector3(-0.09, 0.0, -rear + 0.05))
	# Rotate around the shoulder: aim pitch up / down, plus the low-ready dip.
	var pivot: Transform3D = Transform3D(Basis(Vector3.RIGHT, pitch - ready), right_shoulder)
	var local: Transform3D = Transform3D(socket.basis, socket.origin - right_shoulder)
	_weapon_socket.transform = pivot * local
	if ready > 0.0 and stance == Stance.RIFLE:
		_weapon_socket.transform = _weapon_socket.transform * Transform3D(Basis(Vector3.UP, 0.35 * ready), Vector3.ZERO)


## Two-bone IK: [joint, end] for a chain from `root` towards `target`, bending towards `pole`.
static func _ik(root: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Array[Vector3]:
	var to: Vector3 = target - root
	var length: float = to.length()
	var dir: Vector3 = to / length if length > 0.0001 else Vector3.DOWN
	var d: float = clampf(length, 0.02, l1 + l2 - 0.002)
	var cos_a: float = clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var bend: Vector3 = pole - dir * pole.dot(dir)
	if bend.length() < 0.0001:
		bend = dir.cross(Vector3.RIGHT)
	bend = bend.normalized()
	var joint: Vector3 = root + dir * cos_a * l1 + bend * sqrt(1.0 - cos_a * cos_a) * l1
	return [joint, root + dir * d]


func _col(key: String, fallback: Color) -> Color:
	var colour: Color = _look.get(key, fallback)
	return colour


static func _key(base: String, side: int) -> StringName:
	return StringName("%s_%d" % [base, side])


static func _basis_along(dir: Vector3) -> Basis:
	# +Y along `dir` (limbs are capsules standing on Y).
	var up: Vector3 = dir.normalized()
	var side: Vector3 = up.cross(Vector3.BACK)
	if side.length() < 0.01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	return Basis(side, up, side.cross(up).normalized())


func _segment(part: StringName, from: Vector3, to: Vector3) -> void:
	var mesh: MeshInstance3D = _parts.get(part)
	if mesh == null:
		return
	var dir: Vector3 = to - from
	var length: float = dir.length()
	var basis_along: Basis = _basis_along(dir if length > 0.0001 else Vector3.DOWN)
	var nominal: float = mesh.get_meta(&"length", length)
	mesh.transform = Transform3D(basis_along.scaled(Vector3(1.0, length / maxf(nominal, 0.001), 1.0)), (from + to) * 0.5)


func _place(part: StringName, at: Vector3, orientation: Basis) -> void:
	var mesh: MeshInstance3D = _parts.get(part)
	if mesh != null:
		mesh.transform = Transform3D(orientation, at)


# --- Building ----------------------------------------------------------------------------------

func _build_body() -> void:
	var skin: StandardMaterial3D = _material(&"skin", _col("skin", Color(0.78, 0.6, 0.48)), 0.65)
	var top: StandardMaterial3D = _material(&"top", _col("top", Color.GRAY), 0.9)
	var pants: StandardMaterial3D = _material(&"pants", _col("pants", Color.DIM_GRAY), 0.9)
	var boots: StandardMaterial3D = _material(&"boots", _col("boots", Color.BLACK), 0.6)
	var gloves: StandardMaterial3D = _material(&"gloves", _col("gloves", Color.BLACK), 0.7)

	_chest = Node3D.new()
	_chest.name = "Chest"
	add_child(_chest)
	# Torso: tapered, flattened front-to-back.
	var torso: CylinderMesh = CylinderMesh.new()
	torso.top_radius = 0.2
	torso.bottom_radius = 0.16
	torso.height = 0.5
	torso.radial_segments = 16
	var torso_mesh: MeshInstance3D = _mesh_node(_chest, "Torso", torso, top, Vector3(0, 0.27, 0))
	torso_mesh.scale = Vector3(1.0, 1.0, 0.62)
	var shoulders: CapsuleMesh = CapsuleMesh.new()
	shoulders.radius = 0.075
	shoulders.height = 0.5
	var shoulder_mesh: MeshInstance3D = _mesh_node(_chest, "Shoulders", shoulders, top, Vector3(0, SHOULDER_HEIGHT - 0.02, 0))
	shoulder_mesh.rotation.z = PI * 0.5
	shoulder_mesh.scale = Vector3(1.0, 1.0, 0.85)
	var neck: CylinderMesh = CylinderMesh.new()
	neck.top_radius = 0.055
	neck.bottom_radius = 0.065
	neck.height = 0.12
	_mesh_node(_chest, "Neck", neck, skin, Vector3(0, NECK_HEIGHT - 0.06, 0))
	# Belt.
	var belt: CylinderMesh = CylinderMesh.new()
	belt.top_radius = 0.165
	belt.bottom_radius = 0.165
	belt.height = 0.06
	var belt_mesh: MeshInstance3D = _mesh_node(_chest, "Belt", belt, _material(&"belt", Color(0.04, 0.04, 0.04), 0.5), Vector3(0, 0.03, 0))
	belt_mesh.scale = Vector3(1.0, 1.0, 0.7)
	if _look.get("vest", false):
		_build_vest()
	if _look.get("ied", false):
		_build_ied()

	_head = Node3D.new()
	_head.name = "Head"
	_chest.add_child(_head)
	_build_head(skin)

	# Pelvis.
	var pelvis: CapsuleMesh = CapsuleMesh.new()
	pelvis.radius = 0.11
	pelvis.height = 0.34
	var pelvis_mesh: MeshInstance3D = _mesh_node(self, "Pelvis", pelvis, pants, Vector3.ZERO)
	pelvis_mesh.mesh = pelvis
	_parts[&"pelvis"] = pelvis_mesh
	_bake_rotation(pelvis_mesh, Basis(Vector3.BACK, PI * 0.5).scaled(Vector3(1.0, 1.0, 0.8)))

	for side: int in [-1, 1]:
		_limb(_key("thigh", side), THIGH, 0.085, pants)
		_limb(_key("shin", side), SHIN, 0.065, pants)
		var boot: BoxMesh = BoxMesh.new()
		boot.size = Vector3(0.11, 0.1, 0.27)
		_parts[_key("foot", side)] = _mesh_node(self, "Foot%d" % side, boot, boots, Vector3.ZERO)
		_limb(_key("upper_arm", side), UPPER_ARM, 0.058, top)
		var sleeve: StandardMaterial3D = skin if _look.get("head", &"") == &"hair" else top
		_limb(_key("forearm", side), FOREARM, 0.048, sleeve)
		var hand: CapsuleMesh = CapsuleMesh.new()
		hand.radius = 0.042
		hand.height = 0.13
		_parts[_key("hand", side)] = _mesh_node(self, "Hand%d" % side, hand, gloves, Vector3.ZERO)
		var armband: Color = _look.get("armband", Color(0, 0, 0, 0))
		if armband.a > 0.0:
			var band: CylinderMesh = CylinderMesh.new()
			band.top_radius = 0.064
			band.bottom_radius = 0.064
			band.height = 0.05
			var band_mesh: MeshInstance3D = _mesh_node(_parts[_key("upper_arm", side)], "Armband", band, _material(&"armband", armband, 0.5, true), Vector3(0, 0.06, 0))
			band_mesh.name = "Armband"

	_weapon_socket = Node3D.new()
	_weapon_socket.name = "WeaponSocket"
	add_child(_weapon_socket)


func _build_head(skin: StandardMaterial3D) -> void:
	var gear: StringName = _look.get("head", &"hair")
	var gear_color: Color = _look.get("head_color", Color(0.1, 0.08, 0.06))
	var head_material: StandardMaterial3D = skin
	if gear == &"balaclava":
		head_material = _material(&"balaclava", gear_color, 0.95)
	var skull: SphereMesh = SphereMesh.new()
	skull.radius = 0.11
	skull.height = 0.24
	var skull_mesh: MeshInstance3D = _mesh_node(_head, "Skull", skull, head_material, Vector3(0, 0.12, 0))
	skull_mesh.scale = Vector3(0.92, 1.0, 1.02)
	var jaw: SphereMesh = SphereMesh.new()
	jaw.radius = 0.085
	jaw.height = 0.14
	_mesh_node(_head, "Jaw", jaw, head_material, Vector3(0, 0.055, -0.02))
	var eye_material: StandardMaterial3D = _material(&"eyes", Color(0.05, 0.05, 0.06), 0.3)
	if gear == &"balaclava":
		var strip: BoxMesh = BoxMesh.new()
		strip.size = Vector3(0.13, 0.035, 0.02)
		_mesh_node(_head, "EyeStrip", strip, skin, Vector3(0, 0.135, -0.1))
	for side: float in [-0.038, 0.038]:
		var eye: SphereMesh = SphereMesh.new()
		eye.radius = 0.013
		eye.height = 0.026
		_mesh_node(_head, "Eye", eye, eye_material, Vector3(side, 0.135, -0.104))
	if gear != &"balaclava":
		var nose: BoxMesh = BoxMesh.new()
		nose.size = Vector3(0.025, 0.045, 0.03)
		_mesh_node(_head, "Nose", nose, skin, Vector3(0, 0.1, -0.112))
	var cloth: StandardMaterial3D = _material(&"head_gear", gear_color, 0.85)
	match gear:
		&"cap":
			var crown: SphereMesh = SphereMesh.new()
			crown.radius = 0.118
			crown.height = 0.12
			crown.is_hemisphere = true
			_mesh_node(_head, "CapCrown", crown, cloth, Vector3(0, 0.165, 0.0))
			var brim: BoxMesh = BoxMesh.new()
			brim.size = Vector3(0.19, 0.012, 0.1)
			var brim_mesh: MeshInstance3D = _mesh_node(_head, "CapBrim", brim, cloth, Vector3(0, 0.17, -0.13))
			brim_mesh.rotation.x = 0.12
			var badge: BoxMesh = BoxMesh.new()
			badge.size = Vector3(0.035, 0.04, 0.01)
			_mesh_node(_head, "Badge", badge, _material(&"badge", Color(0.85, 0.7, 0.3), 0.3, false, 0.8), Vector3(0, 0.215, -0.108))
		&"helmet":
			var shell: SphereMesh = SphereMesh.new()
			shell.radius = 0.135
			shell.height = 0.14
			shell.is_hemisphere = true
			_mesh_node(_head, "Helmet", shell, cloth, Vector3(0, 0.15, 0.0))
		&"beanie":
			var knit: SphereMesh = SphereMesh.new()
			knit.radius = 0.12
			knit.height = 0.15
			knit.is_hemisphere = true
			var knit_mesh: MeshInstance3D = _mesh_node(_head, "Beanie", knit, cloth, Vector3(0, 0.15, 0.005))
			knit_mesh.scale = Vector3(1.0, 1.15, 1.0)
		&"hood":
			var hood: SphereMesh = SphereMesh.new()
			hood.radius = 0.15
			hood.height = 0.3
			var hood_mesh: MeshInstance3D = _mesh_node(_head, "Hood", hood, cloth, Vector3(0, 0.13, 0.035))
			hood_mesh.scale = Vector3(1.0, 1.05, 1.0)
			var face_hole: SphereMesh = SphereMesh.new()
			face_hole.radius = 0.1
			face_hole.height = 0.2
			_mesh_node(_head, "Shade", face_hole, _material(&"shade", Color(0.03, 0.02, 0.02), 1.0), Vector3(0, 0.115, -0.045))
		&"hair":
			var hair: SphereMesh = SphereMesh.new()
			hair.radius = 0.114
			hair.height = 0.1
			hair.is_hemisphere = true
			_mesh_node(_head, "Hair", hair, cloth, Vector3(0, 0.155, 0.01))


func _build_vest() -> void:
	var vest_color: Color = _look.get("vest_color", Color(0.12, 0.13, 0.14))
	var holder: Node3D = Node3D.new()
	holder.name = "Vest"
	_chest.add_child(holder)
	var vest: Node3D = ModelKit.prop(holder, &"plate_carrier", "Carrier", Vector3.ZERO, 180.0)
	if vest != null:
		# Stretch the carrier over this torso (0.44 wide, 0.5 tall, 0.32 deep).
		var box: AABB = ModelKit.bounds_in(vest, holder)
		vest.scale = Vector3(0.44 / maxf(box.size.x, 0.01), 0.5 / maxf(box.size.y, 0.01), 0.33 / maxf(box.size.z, 0.01))
		vest.position = Vector3(0, 0.1, 0.0)
	else:
		var plate: BoxMesh = BoxMesh.new()
		plate.size = Vector3(0.42, 0.42, 0.3)
		_mesh_node(holder, "Plate", plate, _material(&"vest", vest_color, 0.85), Vector3(0, 0.33, 0))
	var text: String = _look.get("back_text", "")
	if not text.is_empty():
		var label: Label3D = Label3D.new()
		label.text = text
		label.font_size = 48
		label.pixel_size = 0.0019
		label.outline_size = 0
		label.modulate = Color(0.92, 0.92, 0.9)
		label.position = Vector3(0, 0.4, 0.19)
		holder.add_child(label)
		var front: Label3D = label.duplicate() as Label3D
		front.position = Vector3(-0.08, 0.44, -0.19)
		front.rotation_degrees.y = 180.0
		front.pixel_size = 0.0011
		holder.add_child(front)


func _build_ied() -> void:
	var strap: StandardMaterial3D = _material(&"ied_strap", Color(0.12, 0.11, 0.09), 0.9)
	var block: StandardMaterial3D = _material(&"ied_block", Color(0.55, 0.48, 0.3), 0.8)
	var wire: StandardMaterial3D = _material(&"ied_wire", Color(0.8, 0.1, 0.08), 0.4, true)
	var band: CylinderMesh = CylinderMesh.new()
	band.top_radius = 0.185
	band.bottom_radius = 0.18
	band.height = 0.2
	var band_mesh: MeshInstance3D = _mesh_node(_chest, "IedBand", band, strap, Vector3(0, 0.26, 0))
	band_mesh.scale = Vector3(1.0, 1.0, 0.66)
	for i: int in 4:
		var stick: CylinderMesh = CylinderMesh.new()
		stick.top_radius = 0.028
		stick.bottom_radius = 0.028
		stick.height = 0.18
		_mesh_node(_chest, "Charge%d" % i, stick, block, Vector3(-0.1 + i * 0.066, 0.26, -0.13))
	var wire_mesh: BoxMesh = BoxMesh.new()
	wire_mesh.size = Vector3(0.24, 0.01, 0.01)
	_mesh_node(_chest, "Wire", wire_mesh, wire, Vector3(0, 0.34, -0.16))


func _attach_weapon(model: WeaponModel) -> void:
	if model.get_parent() != null:
		model.get_parent().remove_child(model)
	_weapon_socket.add_child(model)
	model.transform = Transform3D.IDENTITY


## Limb capsule standing on Y, length stored so `_segment` can stretch it.
func _limb(part: StringName, length: float, radius: float, material: Material) -> void:
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = length + radius * 1.2
	capsule.radial_segments = 12
	capsule.rings = 4
	var node: MeshInstance3D = _mesh_node(self, String(part), capsule, material, Vector3.ZERO)
	node.set_meta(&"length", length)
	_parts[part] = node


func _mesh_node(parent: Node, node_name: String, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node


## Bakes a fixed rotation into a mesh by wrapping it (so `_place` can still set the node's transform).
func _bake_rotation(node: MeshInstance3D, rotation_basis: Basis) -> void:
	var arrays_mesh: ArrayMesh = ArrayMesh.new()
	var source: Mesh = node.mesh
	for surface: int in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i: int in vertices.size():
			vertices[i] = rotation_basis * vertices[i]
		for i: int in normals.size():
			normals[i] = (rotation_basis * normals[i]).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = null
		arrays_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	node.mesh = arrays_mesh


func _material(key: StringName, colour: Color, roughness: float, emissive: bool = false, metallic: float = 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	material.metallic = metallic
	if emissive:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = 0.4
	_materials[key] = material
	return material
