## Procedural gun mesh built from WeaponData (receiver, barrel, grip, magazine, sights, stock) with a
## muzzle marker. Used both as the first-person viewmodel and as the third-person model on other players.
## Authority: LOCAL
class_name WeaponModel
extends Node3D

var data: WeaponData
var muzzle: Marker3D


static func build(weapon: WeaponData, render_layers: int = 1) -> WeaponModel:
	var model: WeaponModel = WeaponModel.new()
	model.data = weapon
	model.name = "Model_%s" % weapon.id
	var metal: StandardMaterial3D = StandardMaterial3D.new()
	metal.albedo_color = weapon.body_color
	metal.albedo_color = weapon.body_color.lightened(0.12)
	metal.metallic = 0.35
	metal.roughness = 0.45
	var polymer: StandardMaterial3D = StandardMaterial3D.new()
	polymer.albedo_color = weapon.body_color.lightened(0.05)
	polymer.roughness = 0.8
	var length: float = weapon.body_length
	var is_sidearm: bool = weapon.slot == WeaponData.Slot.SIDEARM
	var height: float = 0.07 if is_sidearm else 0.085
	# -Z is forward.
	model._box(Vector3(0.045, height, length), Vector3(0, 0, -length * 0.5), metal, render_layers)
	model._cylinder(0.012 if is_sidearm else 0.015, weapon.barrel_length, Vector3(0, height * 0.18, -length - weapon.barrel_length * 0.5), metal, render_layers)
	model._box(Vector3(0.036, 0.11, 0.05), Vector3(0, -height * 0.5 - 0.045, -0.02 if is_sidearm else -0.06), polymer, render_layers, -0.3)
	if not is_sidearm:
		var mag_depth: float = 0.05 if weapon.pellets > 1 else 0.14
		model._box(Vector3(0.03, mag_depth, 0.06), Vector3(0, -height * 0.5 - mag_depth * 0.5, -length * 0.45), polymer, render_layers, 0.15)
		model._box(Vector3(0.04, 0.07, 0.2), Vector3(0, -0.01, 0.1), polymer, render_layers)
		model._box(Vector3(0.05, 0.04, length * 0.35), Vector3(0, -height * 0.5 - 0.02, -length * 0.85), polymer, render_layers)
	model._box(Vector3(0.012, 0.018, 0.012), Vector3(0, height * 0.5 + 0.009, -length + 0.02), metal, render_layers)
	model._box(Vector3(0.03, 0.016, 0.012), Vector3(0, height * 0.5 + 0.008, -0.01), metal, render_layers)
	model.muzzle = Marker3D.new()
	model.muzzle.name = "Muzzle"
	model.muzzle.position = Vector3(0, height * 0.18, -length - weapon.barrel_length)
	model.add_child(model.muzzle)
	return model


## Height of the sight line above the model origin (ADS aligns it with the screen centre).
static func sight_height(weapon: WeaponData) -> float:
	var height: float = 0.07 if weapon.slot == WeaponData.Slot.SIDEARM else 0.085
	return height * 0.5 + 0.018


func _box(size: Vector3, at: Vector3, material: Material, layers: int, tilt: float = 0.0) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	_add(mesh, at, material, layers, tilt)


func _cylinder(radius: float, length: float, at: Vector3, material: Material, layers: int) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	_add(mesh, at, material, layers, PI * 0.5)


func _add(mesh: Mesh, at: Vector3, material: Material, layers: int, tilt: float) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation.x = tilt
	instance.layers = layers
	add_child(instance)
