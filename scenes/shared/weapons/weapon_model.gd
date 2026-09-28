## Gun model built from WeaponData: the imported model in assets/3D/weapons/<model_id>.glb (origin at the
## firing grip, muzzle towards -Z), or a procedural gun when the model is missing. Measures the model once
## per id to place the muzzle, the sight line (ADS) and the support-hand point used by the first-person arms
## and the third-person rigs.
## Used as the first-person viewmodel, the gun in a character's hands, and on racks / the floor.
## Authority: LOCAL
class_name WeaponModel
extends Node3D

const MODEL_DIR: String = "res://assets/3D/weapons/"
const GLOVE_COLOR: Color = Color(0.05, 0.05, 0.055)
const SLEEVE_COLOR: Color = Color(0.1, 0.12, 0.16)

## model id -> {"aabb": AABB, "muzzle": Vector3, "sight": float, "support": Vector3}
static var _metrics: Dictionary[StringName, Dictionary] = {}

var data: WeaponData
var model_id: StringName = &""
var muzzle: Marker3D
## Where the off hand holds the gun (model space). Equal to the grip for one-handed pistols.
var support_point: Vector3 = Vector3.ZERO
var is_one_handed: bool = false


static func build(weapon: WeaponData, render_layers: int = 1, with_arms: bool = false) -> WeaponModel:
	var model: WeaponModel = build_model(weapon.get_model_id(), weapon.slot == WeaponData.Slot.SIDEARM, render_layers, weapon)
	model.data = weapon
	if with_arms:
		model._add_arms(render_layers)
	return model


## Model by id (enemies use it for weapons outside the player catalog, e.g. the machete).
static func build_model(id: StringName, one_handed: bool, render_layers: int = 1, fallback: WeaponData = null) -> WeaponModel:
	var model: WeaponModel = WeaponModel.new()
	model.name = "Model_%s" % id
	model.model_id = id
	model.is_one_handed = one_handed
	var path: String = MODEL_DIR + String(id) + ".glb"
	var scene: Node3D = ModelKit.instance(path)
	if scene != null:
		scene.name = "Mesh"
		model.add_child(scene)
	elif fallback != null:
		model._build_procedural(fallback)
	var metrics: Dictionary = _measure(model)
	model.support_point = metrics["support"]
	if one_handed:
		model.support_point = Vector3(-0.01, -0.035, 0.03)
	model.muzzle = Marker3D.new()
	model.muzzle.name = "Muzzle"
	model.muzzle.position = metrics["muzzle"]
	model.add_child(model.muzzle)
	ModelKit.set_layers(model, render_layers)
	return model


## Height of the sight line above the grip (ADS lowers the gun by this so the sights sit on screen centre).
static func sight_height(weapon: WeaponData) -> float:
	var id: StringName = weapon.get_model_id()
	if not _metrics.has(id):
		var probe: WeaponModel = build(weapon)
		probe.free()
	if _metrics.has(id):
		var metrics: Dictionary = _metrics[id]
		var sight: float = metrics["sight"]
		return sight
	var height: float = 0.07 if weapon.slot == WeaponData.Slot.SIDEARM else 0.085
	return height * 0.5 + 0.018


## Bounds of the gun in its own space.
func get_bounds() -> AABB:
	var metrics: Dictionary = _metrics.get(model_id, {})
	var box: AABB = metrics.get("aabb", AABB(Vector3(-0.02, -0.1, -0.5), Vector3(0.04, 0.2, 0.6)))
	return box


## Moves the gun (keeping its rotation) so its visual centre sits on the parent's origin.
func centre_on_parent() -> void:
	position = -(basis * get_bounds().get_center())


# --- Measuring ---------------------------------------------------------------------------------

static func _measure(model: WeaponModel) -> Dictionary:
	if _metrics.has(model.model_id):
		return _metrics[model.model_id]
	var box: AABB = ModelKit.bounds_in(model, model)
	if box.size == Vector3.ZERO:
		box = AABB(Vector3(-0.02, -0.1, -0.5), Vector3(0.04, 0.2, 0.6))
	var points: PackedVector3Array = _points(model)
	var front: float = box.position.z
	var length: float = box.size.z
	# Muzzle: the average height of the vertices at the very front of the gun.
	var muzzle_y: float = 0.0
	var count: int = 0
	var sight: float = -1.0
	for point: Vector3 in points:
		if point.z < front + length * 0.03:
			muzzle_y += point.y
			count += 1
		# Sight line: highest point over the receiver (just in front of the grip to a bit behind it).
		if point.z > -length * 0.3 and point.z < length * 0.08:
			sight = maxf(sight, point.y)
	muzzle_y = muzzle_y / count if count > 0 else box.end.y - box.size.y * 0.3
	if sight < 0.0:
		sight = box.end.y
	var support: Vector3 = Vector3(0.0, muzzle_y - 0.035, front * 0.52)
	var metrics: Dictionary = {"aabb": box, "muzzle": Vector3(0.0, muzzle_y, front), "sight": sight + 0.004, "support": support}
	_metrics[model.model_id] = metrics
	return metrics


static func _points(model: Node3D) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var to_model: Transform3D = ModelKit.relative_transform(model, mesh_instance)
		for surface: int in mesh_instance.mesh.get_surface_count():
			var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				result.append(to_model * vertex)
	return result


# --- First-person arms -------------------------------------------------------------------------

## Gloved hands on the grip and the support point, with sleeves running back out of the bottom of the screen.
func _add_arms(layers: int) -> void:
	var glove: StandardMaterial3D = StandardMaterial3D.new()
	glove.albedo_color = GLOVE_COLOR
	glove.roughness = 0.75
	var sleeve: StandardMaterial3D = StandardMaterial3D.new()
	sleeve.albedo_color = SLEEVE_COLOR
	sleeve.roughness = 0.9
	var arms: Node3D = Node3D.new()
	arms.name = "Arms"
	add_child(arms)
	# Firing hand wraps the grip; forearm heads back and down to the right.
	var right_hand: Vector3 = Vector3(0.0, -0.045, 0.02)
	_hand(arms, right_hand, glove, Vector3(0, 0, -0.12))
	_segment(arms, right_hand + Vector3(0.01, -0.03, 0.05), right_hand + Vector3(0.06, -0.3, 0.4), 0.03, sleeve)
	_segment(arms, right_hand + Vector3(0.0, -0.01, 0.035), right_hand + Vector3(0.02, -0.04, 0.09), 0.03, glove)
	# Support hand.
	var left_hand: Vector3 = support_point
	if is_one_handed:
		left_hand = Vector3(-0.025, -0.055, 0.035)
	_hand(arms, left_hand, glove, Vector3(0, 0, 0.35))
	var elbow: Vector3 = left_hand + (Vector3(-0.22, -0.3, 0.3) if not is_one_handed else Vector3(-0.1, -0.3, 0.3))
	_segment(arms, left_hand + Vector3(-0.01, -0.03, 0.03), elbow, 0.028, sleeve)
	ModelKit.set_layers(arms, layers, false)


func _hand(parent: Node3D, at: Vector3, material: Material, tilt: Vector3) -> void:
	var palm: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.05, 0.075, 0.09)
	palm.mesh = mesh
	palm.material_override = material
	palm.position = at
	palm.rotation = tilt
	parent.add_child(palm)
	var fingers: MeshInstance3D = MeshInstance3D.new()
	var finger_mesh: CapsuleMesh = CapsuleMesh.new()
	finger_mesh.radius = 0.02
	finger_mesh.height = 0.075
	fingers.mesh = finger_mesh
	fingers.material_override = material
	fingers.position = at + Vector3(0.0, 0.0, -0.045)
	fingers.rotation = Vector3(0.0, 0.0, PI * 0.5)
	parent.add_child(fingers)


func _segment(parent: Node3D, from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var limb: MeshInstance3D = MeshInstance3D.new()
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = from.distance_to(to) + radius * 2.0
	limb.mesh = mesh
	limb.material_override = material
	limb.position = (from + to) * 0.5
	var up: Vector3 = (to - from).normalized()
	var side: Vector3 = up.cross(Vector3.FORWARD)
	if side.length() < 0.01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	limb.basis = Basis(side, up, side.cross(up).normalized())
	parent.add_child(limb)


# --- Procedural fallback -----------------------------------------------------------------------

func _build_procedural(weapon: WeaponData) -> void:
	var metal: StandardMaterial3D = StandardMaterial3D.new()
	metal.albedo_color = weapon.body_color.lightened(0.12)
	metal.metallic = 0.35
	metal.roughness = 0.45
	var polymer: StandardMaterial3D = StandardMaterial3D.new()
	polymer.albedo_color = weapon.body_color.lightened(0.05)
	polymer.roughness = 0.8
	var length: float = weapon.body_length
	var is_sidearm: bool = weapon.slot == WeaponData.Slot.SIDEARM
	var height: float = 0.07 if is_sidearm else 0.085
	var rear: float = length * (0.15 if is_sidearm else 0.3)
	_box(Vector3(0.045, height, length), Vector3(0, height * 0.5, rear - length * 0.5), metal)
	_cylinder(0.012 if is_sidearm else 0.015, weapon.barrel_length, Vector3(0, height * 0.65, rear - length - weapon.barrel_length * 0.5), metal)
	_box(Vector3(0.036, 0.11, 0.05), Vector3(0, -0.04, 0.0), polymer, -0.3)
	if not is_sidearm:
		_box(Vector3(0.03, 0.14, 0.06), Vector3(0, -0.05, rear - length * 0.45), polymer, 0.15)
		_box(Vector3(0.04, 0.07, 0.2), Vector3(0, 0.03, rear + 0.1), polymer)


func _box(size: Vector3, at: Vector3, material: Material, tilt: float = 0.0) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	_add(mesh, at, material, tilt)


func _cylinder(radius: float, length: float, at: Vector3, material: Material) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	_add(mesh, at, material, PI * 0.5)


func _add(mesh: Mesh, at: Vector3, material: Material, tilt: float) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation.x = tilt
	add_child(instance)
