## Level building toolkit used by the map builder scripts (tools/level_kit/build_*.gd): shared PBR materials
## with procedural noise detail (triplanar, so boxes never stretch), collision-backed geometry helpers,
## light fixtures (ceiling panels, pendants, street lamps, bulkheads — real fixtures, not glowing boxes),
## common props and a cinematic night environment.
## Authority: EDITOR / TOOLS (runs inside a build script, never in gameplay)
class_name LevelKit
extends RefCounted

const MATERIAL_DIR: String = "res://assets/materials/"

var root: Node3D
var _materials: Dictionary[String, StandardMaterial3D] = {}


func _init(level_root: Node3D) -> void:
	root = level_root


# --- Nodes ---------------------------------------------------------------------------------

func own(node: Node, parent: Node, node_name: String = "") -> Node:
	if node_name != "":
		node.name = node_name
	parent.add_child(node, true)
	node.owner = root
	return node


func group(parent: Node, node_name: String, at: Vector3 = Vector3.ZERO) -> Node3D:
	var node: Node3D = own(Node3D.new(), parent, node_name) as Node3D
	node.position = at
	return node


func instance(scene_path: String, parent: Node, node_name: String, at: Transform3D) -> Node:
	var scene: PackedScene = load(scene_path) as PackedScene
	var node: Node = scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.name = node_name
	parent.add_child(node, true)
	node.owner = root
	var spatial: Node3D = node as Node3D
	if spatial != null:
		spatial.transform = at
	return node


func marker(parent: Node, node_name: String, at: Vector3, yaw_deg: float = 0.0) -> Marker3D:
	var point: Marker3D = own(Marker3D.new(), parent, node_name) as Marker3D
	point.position = at
	point.rotation_degrees.y = yaw_deg
	return point


# --- Geometry ------------------------------------------------------------------------------

## Solid box with collision (for walls, floors, furniture).
func box(parent: Node, node_name: String, center: Vector3, size: Vector3, material: Material, yaw_deg: float = 0.0, collide: bool = true) -> Node3D:
	var holder: Node3D
	if collide:
		var body: StaticBody3D = own(StaticBody3D.new(), parent, node_name) as StaticBody3D
		var shape: CollisionShape3D = own(CollisionShape3D.new(), body, "Shape") as CollisionShape3D
		var box_shape: BoxShape3D = BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		holder = body
	else:
		holder = own(Node3D.new(), parent, node_name) as Node3D
	holder.position = center
	holder.rotation_degrees.y = yaw_deg
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var visual: MeshInstance3D = own(MeshInstance3D.new(), holder, "Mesh") as MeshInstance3D
	visual.mesh = mesh
	visual.material_override = material
	return holder


## Invisible collision volume (blocks movement, bullets and shapes the navmesh).
func collider(parent: Node, node_name: String, center: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = own(StaticBody3D.new(), parent, node_name) as StaticBody3D
	body.position = center
	var shape: CollisionShape3D = own(CollisionShape3D.new(), body, "Shape") as CollisionShape3D
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	return body


## Visual-only mesh (details that do not need collision).
func mesh(parent: Node, node_name: String, shape: Mesh, at: Vector3, material: Material, rotation_deg: Vector3 = Vector3.ZERO, shadows: bool = true) -> MeshInstance3D:
	var visual: MeshInstance3D = own(MeshInstance3D.new(), parent, node_name) as MeshInstance3D
	visual.mesh = shape
	visual.position = at
	visual.rotation_degrees = rotation_deg
	visual.material_override = material
	if not shadows:
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return visual


func cylinder(parent: Node, node_name: String, at: Vector3, radius: float, height: float, material: Material, collide: bool = true, top_radius: float = -1.0) -> Node3D:
	var holder: Node3D
	if collide:
		var body: StaticBody3D = own(StaticBody3D.new(), parent, node_name) as StaticBody3D
		var shape: CollisionShape3D = own(CollisionShape3D.new(), body, "Shape") as CollisionShape3D
		var cylinder_shape: CylinderShape3D = CylinderShape3D.new()
		cylinder_shape.radius = radius
		cylinder_shape.height = height
		shape.shape = cylinder_shape
		holder = body
	else:
		holder = own(Node3D.new(), parent, node_name) as Node3D
	holder.position = at
	var shape_mesh: CylinderMesh = CylinderMesh.new()
	shape_mesh.bottom_radius = radius
	shape_mesh.top_radius = radius if top_radius < 0.0 else top_radius
	shape_mesh.height = height
	shape_mesh.radial_segments = 20
	mesh(holder, "Mesh", shape_mesh, Vector3.ZERO, material)
	return holder


## Wall along X or Z between two corners, with optional door / window openings measured along the wall.
## openings: Array of [start_offset, width, bottom, top]
func wall(parent: Node, node_name: String, from: Vector3, to: Vector3, height: float, thickness: float, material: Material, openings: Array = []) -> Node3D:
	var node: Node3D = group(parent, node_name)
	var along_x: bool = absf(to.x - from.x) >= absf(to.z - from.z)
	var length: float = absf(to.x - from.x) if along_x else absf(to.z - from.z)
	var start: Vector3 = Vector3(minf(from.x, to.x), from.y, minf(from.z, to.z))
	var cuts: Array = openings.duplicate()
	cuts.sort_custom(func(a: Array, b: Array) -> bool:
		var a0: float = a[0]
		var b0: float = b[0]
		return a0 < b0)
	var cursor: float = 0.0
	var index: int = 0
	for cut: Array in cuts:
		var offset: float = cut[0]
		var width: float = cut[1]
		var bottom: float = cut[2]
		var top: float = cut[3]
		if offset > cursor:
			_wall_piece(node, "Seg%d" % index, start, along_x, cursor, offset - cursor, 0.0, height, thickness, material)
			index += 1
		if bottom > 0.0:
			_wall_piece(node, "Sill%d" % index, start, along_x, offset, width, 0.0, bottom, thickness, material)
			index += 1
		if top < height:
			_wall_piece(node, "Lintel%d" % index, start, along_x, offset, width, top, height, thickness, material)
			index += 1
		cursor = offset + width
	if cursor < length:
		_wall_piece(node, "Seg%d" % index, start, along_x, cursor, length - cursor, 0.0, height, thickness, material)
	return node


func _wall_piece(parent: Node3D, node_name: String, start: Vector3, along_x: bool, offset: float, length: float, bottom: float, top: float, thickness: float, material: Material) -> void:
	var center_along: float = offset + length * 0.5
	var center: Vector3 = start + (Vector3(center_along, 0, 0) if along_x else Vector3(0, 0, center_along))
	center.y = start.y + (bottom + top) * 0.5
	var size: Vector3 = Vector3(length, top - bottom, thickness) if along_x else Vector3(thickness, top - bottom, length)
	box(parent, node_name, center, size, material)


# --- Materials -----------------------------------------------------------------------------

## Named PBR material with procedural albedo variation + normal detail, saved under assets/materials.
func material(key: String) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var spec: Dictionary = _material_specs().get(key, {})
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.resource_name = key
	var color: Color = spec.get("color", Color(0.5, 0.5, 0.5))
	mat.albedo_color = color
	mat.roughness = spec.get("roughness", 0.8)
	mat.metallic = spec.get("metallic", 0.0)
	var scale: float = spec.get("scale", 1.0)
	var detail: float = spec.get("detail", 0.0)
	if detail > 0.0:
		var frequency: float = spec.get("frequency", 0.02)
		var seed_value: int = hash(key) & 0xFFFF
		mat.albedo_texture = _noise(seed_value, frequency, false, 0.0, 1.0 - detail)
		mat.normal_enabled = true
		var bump: float = spec.get("bump", 4.0)
		mat.normal_texture = _noise(seed_value + 7, frequency * 3.0, true, bump, 0.0)
		mat.normal_scale = spec.get("normal_scale", 0.6)
		mat.roughness_texture = _noise(seed_value + 13, frequency * 2.0, false, 0.0, 0.5)
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE * scale
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var emission: Color = spec.get("emission", Color.BLACK)
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = spec.get("emission_energy", 2.0)
	if spec.get("transparent", false):
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if spec.get("clearcoat", false):
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.6
	DirAccess.make_dir_recursive_absolute(MATERIAL_DIR)
	var path: String = MATERIAL_DIR + key + ".tres"
	ResourceSaver.save(mat, path)
	var saved: StandardMaterial3D = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as StandardMaterial3D
	_materials[key] = saved
	return saved


func _noise(seed_value: int, frequency: float, normal: bool, bump: float, floor_value: float) -> NoiseTexture2D:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	var texture: NoiseTexture2D = NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	texture.generate_mipmaps = true
	if normal:
		texture.as_normal_map = true
		texture.bump_strength = bump
	else:
		var ramp: Gradient = Gradient.new()
		ramp.set_color(0, Color(floor_value, floor_value, floor_value))
		ramp.set_color(1, Color.WHITE)
		texture.color_ramp = ramp
	return texture


func _material_specs() -> Dictionary:
	return {
		"concrete": {"color": Color(0.36, 0.355, 0.34), "roughness": 0.9, "detail": 0.16, "frequency": 0.012, "bump": 2.5, "scale": 0.5, "normal_scale": 0.35},
		"concrete_dark": {"color": Color(0.3, 0.3, 0.3), "roughness": 0.92, "detail": 0.18, "frequency": 0.012, "bump": 3.0, "scale": 0.5, "normal_scale": 0.35},
		"asphalt": {"color": Color(0.14, 0.14, 0.15), "roughness": 0.88, "detail": 0.25, "frequency": 0.03, "bump": 3.0, "scale": 0.35, "normal_scale": 0.22},
		"plaster": {"color": Color(0.62, 0.63, 0.61), "roughness": 0.85, "detail": 0.12, "frequency": 0.02, "bump": 1.5, "scale": 0.6, "normal_scale": 0.25},
		"plaster_blue": {"color": Color(0.3, 0.37, 0.44), "roughness": 0.8, "detail": 0.12, "frequency": 0.02, "bump": 1.5, "scale": 0.6, "normal_scale": 0.25},
		"vinyl_floor": {"color": Color(0.3, 0.31, 0.32), "roughness": 0.45, "detail": 0.25, "frequency": 0.05, "bump": 1.0, "scale": 0.8, "normal_scale": 0.2},
		"carpet": {"color": Color(0.2, 0.22, 0.26), "roughness": 1.0, "detail": 0.15, "frequency": 0.2, "bump": 2.0, "scale": 1.0, "normal_scale": 0.3},
		"ceiling_tile": {"color": Color(0.72, 0.72, 0.7), "roughness": 0.95, "detail": 0.15, "frequency": 0.3, "bump": 2.0, "scale": 1.0, "normal_scale": 0.3},
		"metal_painted": {"color": Color(0.3, 0.32, 0.34), "roughness": 0.5, "metallic": 0.6, "detail": 0.18, "frequency": 0.05, "bump": 1.5, "scale": 1.0, "normal_scale": 0.3},
		"metal_dark": {"color": Color(0.1, 0.1, 0.11), "roughness": 0.45, "metallic": 0.7, "detail": 0.12, "frequency": 0.06, "bump": 1.0, "scale": 1.0, "normal_scale": 0.2},
		"steel": {"color": Color(0.55, 0.56, 0.58), "roughness": 0.35, "metallic": 0.9, "detail": 0.1, "frequency": 0.1, "bump": 1.0, "scale": 1.0, "normal_scale": 0.2},
		"rust_red": {"color": Color(0.42, 0.16, 0.1), "roughness": 0.75, "metallic": 0.35, "detail": 0.28, "frequency": 0.03, "bump": 3.0, "scale": 0.6, "normal_scale": 0.4},
		"container_blue": {"color": Color(0.1, 0.24, 0.4), "roughness": 0.6, "metallic": 0.45, "detail": 0.3, "frequency": 0.05, "bump": 3.0, "scale": 0.6},
		"container_green": {"color": Color(0.16, 0.3, 0.2), "roughness": 0.65, "metallic": 0.45, "detail": 0.3, "frequency": 0.05, "bump": 3.0, "scale": 0.6},
		"wood": {"color": Color(0.42, 0.3, 0.19), "roughness": 0.8, "detail": 0.3, "frequency": 0.12, "bump": 3.0, "scale": 1.2},
		"desk_laminate": {"color": Color(0.2, 0.21, 0.23), "roughness": 0.55, "detail": 0.1, "frequency": 0.05, "bump": 0.8, "scale": 1.0, "normal_scale": 0.15},
		"rubber": {"color": Color(0.04, 0.04, 0.04), "roughness": 0.9},
		"plastic_black": {"color": Color(0.05, 0.05, 0.055), "roughness": 0.4},
		"glass_dark": {"color": Color(0.02, 0.03, 0.04, 0.85), "roughness": 0.05, "metallic": 0.2, "transparent": true},
		"car_white": {"color": Color(0.62, 0.63, 0.64), "roughness": 0.25, "metallic": 0.3, "clearcoat": true},
		"car_black": {"color": Color(0.03, 0.03, 0.035), "roughness": 0.25, "metallic": 0.3, "clearcoat": true},
		"screen_map": {"color": Color(0.02, 0.05, 0.07), "roughness": 0.3, "emission": Color(0.08, 0.3, 0.42), "emission_energy": 0.45},
		"screen_blue": {"color": Color(0.02, 0.05, 0.08), "roughness": 0.2, "emission": Color(0.12, 0.45, 0.7), "emission_energy": 1.6},
		"screen_amber": {"color": Color(0.05, 0.03, 0.01), "roughness": 0.2, "emission": Color(0.9, 0.55, 0.12), "emission_energy": 1.4},
		"led_green": {"color": Color(0.02, 0.1, 0.05), "emission": Color(0.1, 1.0, 0.45), "emission_energy": 3.0},
		"led_red": {"color": Color(0.1, 0.01, 0.01), "emission": Color(1.0, 0.1, 0.08), "emission_energy": 4.0},
		"led_blue": {"color": Color(0.01, 0.02, 0.1), "emission": Color(0.15, 0.3, 1.0), "emission_energy": 4.0},
		"diffuser_cool": {"color": Color(0.9, 0.93, 1.0), "roughness": 0.6, "emission": Color(0.92, 0.95, 1.0), "emission_energy": 3.5},
		"diffuser_warm": {"color": Color(1.0, 0.9, 0.75), "roughness": 0.6, "emission": Color(1.0, 0.82, 0.6), "emission_energy": 4.0},
		"sodium_lens": {"color": Color(1.0, 0.75, 0.45), "roughness": 0.3, "emission": Color(1.0, 0.62, 0.3), "emission_energy": 6.0},
		"hazard_yellow": {"color": Color(0.85, 0.65, 0.08), "roughness": 0.6, "detail": 0.2, "frequency": 0.08, "bump": 2.0, "scale": 1.0},
		"fabric_dark": {"color": Color(0.08, 0.09, 0.1), "roughness": 1.0, "detail": 0.2, "frequency": 0.5, "bump": 2.0, "scale": 1.0},
		"cardboard": {"color": Color(0.55, 0.42, 0.27), "roughness": 0.95, "detail": 0.2, "frequency": 0.2, "bump": 1.5, "scale": 1.0},
		"grass": {"color": Color(0.12, 0.17, 0.09), "roughness": 1.0, "detail": 0.35, "frequency": 0.05, "bump": 3.0, "scale": 0.4, "normal_scale": 0.3},
		"siding": {"color": Color(0.5, 0.52, 0.5), "roughness": 0.8, "detail": 0.12, "frequency": 0.04, "bump": 2.0, "scale": 0.8, "normal_scale": 0.3},
		"brick": {"color": Color(0.36, 0.18, 0.13), "roughness": 0.9, "detail": 0.3, "frequency": 0.08, "bump": 5.0, "scale": 0.7, "normal_scale": 0.5},
		"shingle": {"color": Color(0.14, 0.13, 0.13), "roughness": 0.9, "detail": 0.3, "frequency": 0.1, "bump": 4.0, "scale": 0.8, "normal_scale": 0.4},
		"paper_board": {"color": Color(0.55, 0.54, 0.5), "roughness": 0.95},
	}


# --- Light fixtures ------------------------------------------------------------------------

## Recessed LED ceiling panel with a soft shadowed spot pointing down. `at` is the ceiling surface point.
func ceiling_panel(parent: Node, node_name: String, at: Vector3, warm: bool = false, energy: float = 2.2, spot_range: float = 7.0, shadows: bool = true) -> Node3D:
	var fixture: Node3D = group(parent, node_name, at)
	var frame: BoxMesh = BoxMesh.new()
	frame.size = Vector3(1.24, 0.03, 0.64)
	mesh(fixture, "Frame", frame, Vector3(0, -0.015, 0), material("metal_painted"), Vector3.ZERO, false)
	var panel: BoxMesh = BoxMesh.new()
	panel.size = Vector3(1.16, 0.012, 0.56)
	mesh(fixture, "Diffuser", panel, Vector3(0, -0.034, 0), material("diffuser_warm" if warm else "diffuser_cool"), Vector3.ZERO, false)
	var light: SpotLight3D = own(SpotLight3D.new(), fixture, "Light") as SpotLight3D
	light.position = Vector3(0, -0.06, 0)
	light.rotation_degrees = Vector3(-90, 0, 0)
	light.light_color = Color(1.0, 0.9, 0.78) if warm else Color(0.93, 0.96, 1.0)
	light.light_energy = energy
	light.spot_range = spot_range
	light.spot_angle = 72.0
	light.spot_angle_attenuation = 0.6
	light.spot_attenuation = 0.9
	light.light_size = 0.5
	light.shadow_enabled = shadows
	light.shadow_bias = 0.04
	light.light_volumetric_fog_energy = 0.6
	# Fill so ceilings and upper walls are not pitch black above the cone.
	var fill: OmniLight3D = own(OmniLight3D.new(), fixture, "Fill") as OmniLight3D
	fill.position = Vector3(0, -0.4, 0)
	fill.light_color = light.light_color
	fill.light_energy = energy * 0.12
	fill.omni_range = spot_range * 0.6
	fill.light_volumetric_fog_energy = 0.0
	return fixture


## Industrial pendant: cable, conical steel shade and a warm bulb. `at` is the ceiling anchor.
func pendant_lamp(parent: Node, node_name: String, at: Vector3, drop: float = 1.6, energy: float = 4.0, spot_range: float = 12.0) -> Node3D:
	var fixture: Node3D = group(parent, node_name, at)
	var cable: CylinderMesh = CylinderMesh.new()
	cable.top_radius = 0.008
	cable.bottom_radius = 0.008
	cable.height = drop
	cable.radial_segments = 6
	mesh(fixture, "Cable", cable, Vector3(0, -drop * 0.5, 0), material("rubber"), Vector3.ZERO, false)
	var shade: CylinderMesh = CylinderMesh.new()
	shade.top_radius = 0.07
	shade.bottom_radius = 0.34
	shade.height = 0.28
	shade.radial_segments = 24
	shade.cap_bottom = false
	var shade_material: StandardMaterial3D = material("metal_painted").duplicate() as StandardMaterial3D
	shade_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh(fixture, "Shade", shade, Vector3(0, -drop - 0.14, 0), shade_material)
	var bulb: SphereMesh = SphereMesh.new()
	bulb.radius = 0.07
	bulb.height = 0.14
	mesh(fixture, "Bulb", bulb, Vector3(0, -drop - 0.22, 0), material("diffuser_warm"), Vector3.ZERO, false)
	var light: SpotLight3D = own(SpotLight3D.new(), fixture, "Light") as SpotLight3D
	light.position = Vector3(0, -drop - 0.3, 0)
	light.rotation_degrees = Vector3(-90, 0, 0)
	light.light_color = Color(1.0, 0.8, 0.55)
	light.light_energy = energy
	light.spot_range = spot_range
	light.spot_angle = 58.0
	light.spot_angle_attenuation = 0.8
	light.light_size = 0.12
	light.shadow_enabled = true
	light.shadow_bias = 0.05
	light.light_volumetric_fog_energy = 1.2
	return fixture


## Street lamp: pole, curved arm, cobra head with a sodium lens and a wide soft spot. `at` is the base.
func street_lamp(parent: Node, node_name: String, at: Vector3, yaw_deg: float, height: float = 7.0, energy: float = 16.0) -> Node3D:
	var lamp: Node3D = group(parent, node_name, at)
	lamp.rotation_degrees.y = yaw_deg
	cylinder(lamp, "Pole", Vector3(0, height * 0.5, 0), 0.09, height, material("metal_dark"), true, 0.06)
	cylinder(lamp, "Base", Vector3(0, 0.25, 0), 0.2, 0.5, material("concrete_dark"), false)
	var arm: CylinderMesh = CylinderMesh.new()
	arm.top_radius = 0.04
	arm.bottom_radius = 0.05
	arm.height = 1.9
	arm.radial_segments = 10
	mesh(lamp, "Arm", arm, Vector3(0, height - 0.05, -0.9), material("metal_dark"), Vector3(-80, 0, 0))
	var head: CapsuleMesh = CapsuleMesh.new()
	head.radius = 0.17
	head.height = 0.75
	mesh(lamp, "Head", head, Vector3(0, height + 0.05, -1.85), material("metal_dark"), Vector3(90, 0, 0))
	var lens: CylinderMesh = CylinderMesh.new()
	lens.top_radius = 0.13
	lens.bottom_radius = 0.13
	lens.height = 0.02
	mesh(lamp, "Lens", lens, Vector3(0, height - 0.12, -1.9), material("sodium_lens"), Vector3(0, 0, 0), false)
	var light: SpotLight3D = own(SpotLight3D.new(), lamp, "Light") as SpotLight3D
	light.position = Vector3(0, height - 0.2, -1.9)
	light.rotation_degrees = Vector3(-90, 0, 0)
	light.light_color = Color(1.0, 0.72, 0.42)
	light.light_energy = energy
	light.spot_range = height * 2.6
	light.spot_angle = 64.0
	light.spot_angle_attenuation = 0.7
	light.light_size = 0.25
	light.shadow_enabled = true
	light.shadow_bias = 0.06
	light.light_volumetric_fog_energy = 0.7
	return lamp


## Building-mounted floodlight: bracket, rounded housing and a hot lens aimed `tilt_deg` below horizontal
## towards local -Z. `at` is the mounting point on the wall.
func floodlight(parent: Node, node_name: String, at: Vector3, yaw_deg: float, tilt_deg: float = 35.0, energy: float = 14.0, range_m: float = 38.0) -> Node3D:
	var fixture: Node3D = group(parent, node_name, at)
	fixture.rotation_degrees.y = yaw_deg
	var bracket: BoxMesh = BoxMesh.new()
	bracket.size = Vector3(0.06, 0.06, 0.45)
	mesh(fixture, "Bracket", bracket, Vector3(0, 0, -0.22), material("metal_dark"))
	var head: Node3D = group(fixture, "Head", Vector3(0, 0, -0.5))
	head.rotation_degrees.x = -tilt_deg
	var housing: CylinderMesh = CylinderMesh.new()
	housing.top_radius = 0.2
	housing.bottom_radius = 0.26
	housing.height = 0.22
	housing.radial_segments = 20
	mesh(head, "Housing", housing, Vector3.ZERO, material("metal_dark"), Vector3(90, 0, 0))
	var lens: CylinderMesh = CylinderMesh.new()
	lens.top_radius = 0.22
	lens.bottom_radius = 0.22
	lens.height = 0.01
	mesh(head, "Lens", lens, Vector3(0, 0, -0.12), material("diffuser_cool"), Vector3(90, 0, 0), false)
	var light: SpotLight3D = own(SpotLight3D.new(), head, "Light") as SpotLight3D
	light.position = Vector3(0, 0, -0.2)
	light.light_color = Color(0.9, 0.93, 1.0)
	light.light_energy = energy
	light.spot_range = range_m
	light.spot_angle = 42.0
	light.spot_angle_attenuation = 1.2
	light.light_size = 0.2
	light.shadow_enabled = true
	light.shadow_bias = 0.08
	light.light_volumetric_fog_energy = 0.8
	return fixture


## Caged bulkhead wall light facing +Z of its yaw. `at` is on the wall surface.
func bulkhead(parent: Node, node_name: String, at: Vector3, yaw_deg: float, energy: float = 2.5, range_m: float = 9.0, shadows: bool = true) -> Node3D:
	var fixture: Node3D = group(parent, node_name, at)
	fixture.rotation_degrees.y = yaw_deg
	var body: CylinderMesh = CylinderMesh.new()
	body.top_radius = 0.12
	body.bottom_radius = 0.14
	body.height = 0.1
	body.radial_segments = 16
	mesh(fixture, "Body", body, Vector3(0, 0, 0.05), material("metal_dark"), Vector3(90, 0, 0))
	var glass: SphereMesh = SphereMesh.new()
	glass.radius = 0.1
	glass.height = 0.1
	glass.is_hemisphere = true
	mesh(fixture, "Glass", glass, Vector3(0, 0, 0.1), material("diffuser_warm"), Vector3(90, 0, 0), false)
	var light: OmniLight3D = own(OmniLight3D.new(), fixture, "Light") as OmniLight3D
	light.position = Vector3(0, 0, 0.35)
	light.light_color = Color(1.0, 0.8, 0.58)
	light.light_energy = energy
	light.omni_range = range_m
	light.omni_attenuation = 1.4
	light.light_size = 0.1
	light.shadow_enabled = shadows
	light.light_volumetric_fog_energy = 1.0
	return fixture


## Soft light zone the AI perception treats as "lit" (players inside are easier to spot).
func light_zone(parent: Node, node_name: String, center: Vector3, size: Vector3) -> Area3D:
	var zone: Area3D = own(Area3D.new(), parent, node_name) as Area3D
	zone.add_to_group(AIPerception.LIGHT_ZONE_GROUP, true)
	zone.position = center
	zone.collision_layer = 0
	zone.collision_mask = 0
	var shape: CollisionShape3D = own(CollisionShape3D.new(), zone, "Shape") as CollisionShape3D
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	return zone


# --- Environment ---------------------------------------------------------------------------

## Night exterior / interior environment: filmic tonemap, SSAO, SSIL, SDFGI bounce light, volumetric fog.
func environment(parent: Node, fog_density: float = 0.012, ambient: float = 0.25, sdfgi: bool = true, exposure: float = 1.0) -> WorldEnvironment:
	var world: WorldEnvironment = own(WorldEnvironment.new(), parent, "WorldEnvironment") as WorldEnvironment
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.015, 0.025, 0.05)
	sky_material.sky_horizon_color = Color(0.07, 0.08, 0.11)
	sky_material.ground_horizon_color = Color(0.05, 0.05, 0.06)
	sky_material.ground_bottom_color = Color(0.01, 0.01, 0.015)
	sky_material.sun_angle_max = 1.0
	sky_material.sky_energy_multiplier = 0.3
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = ambient
	env.ambient_light_sky_contribution = 0.35
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = exposure
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssil_enabled = true
	env.ssil_intensity = 0.8
	env.sdfgi_enabled = sdfgi
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 0.8
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.2
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(1, 1.0)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(5, 0.3)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = fog_density
	env.volumetric_fog_albedo = Color(0.55, 0.6, 0.7)
	env.volumetric_fog_emission = Color(0.004, 0.006, 0.01)
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_length = 80.0
	env.volumetric_fog_ambient_inject = 0.15
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.9
	world.environment = env
	return world


func moonlight(parent: Node, energy: float = 0.18) -> DirectionalLight3D:
	var moon: DirectionalLight3D = own(DirectionalLight3D.new(), parent, "Moonlight") as DirectionalLight3D
	moon.rotation_degrees = Vector3(-38, -35, 0)
	moon.light_color = Color(0.62, 0.72, 0.95)
	moon.light_energy = energy
	moon.light_angular_distance = 1.2
	moon.shadow_enabled = true
	moon.shadow_blur = 1.5
	moon.directional_shadow_max_distance = 80.0
	moon.light_volumetric_fog_energy = 0.4
	return moon


# --- Props ---------------------------------------------------------------------------------

## Office desk with legs, drawer unit and a monitor pair facing -Z (the operator sits on +Z side).
func desk(parent: Node, node_name: String, at: Vector3, yaw_deg: float, monitors: int = 2, screen: String = "screen_blue") -> Node3D:
	var node: Node3D = group(parent, node_name, at)
	node.rotation_degrees.y = yaw_deg
	box(node, "Top", Vector3(0, 0.76, 0), Vector3(2.4, 0.05, 1.2), material("desk_laminate"))
	for x: float in [-1.12, 1.12]:
		box(node, "Leg%d" % int(x * 10), Vector3(x, 0.37, 0), Vector3(0.06, 0.74, 1.1), material("metal_dark"), 0.0, false)
	box(node, "Drawers", Vector3(0.75, 0.36, 0.05), Vector3(0.5, 0.7, 0.9), material("metal_painted"), 0.0, false)
	var width: float = 0.62
	for i: int in monitors:
		var x: float = (float(i) - (monitors - 1) * 0.5) * (width + 0.04)
		var stand: CylinderMesh = CylinderMesh.new()
		stand.top_radius = 0.02
		stand.bottom_radius = 0.02
		stand.height = 0.22
		mesh(node, "Stand%d" % i, stand, Vector3(x, 0.89, -0.33), material("plastic_black"))
		var bezel: BoxMesh = BoxMesh.new()
		bezel.size = Vector3(width, 0.38, 0.03)
		mesh(node, "Monitor%d" % i, bezel, Vector3(x, 1.18, -0.34), material("plastic_black"), Vector3(-6, 0, 0))
		var panel: BoxMesh = BoxMesh.new()
		panel.size = Vector3(width - 0.03, 0.34, 0.005)
		mesh(node, "Screen%d" % i, panel, Vector3(x, 1.18, -0.322), material(screen), Vector3(-6, 0, 0), false)
	var keyboard: BoxMesh = BoxMesh.new()
	keyboard.size = Vector3(0.46, 0.02, 0.15)
	mesh(node, "Keyboard", keyboard, Vector3(-0.1, 0.795, 0.05), material("plastic_black"))
	return node


func server_rack(parent: Node, node_name: String, at: Vector3, yaw_deg: float) -> Node3D:
	var node: Node3D = box(parent, node_name, at + Vector3(0, 1.05, 0), Vector3(0.62, 2.1, 1.0), material("metal_dark"), yaw_deg)
	for i: int in 7:
		var strip: BoxMesh = BoxMesh.new()
		strip.size = Vector3(0.005, 0.02, 0.5)
		mesh(node, "Led%d" % i, strip, Vector3(0.315, -0.8 + i * 0.26, -0.1), material("led_green" if i % 3 != 0 else "led_blue"), Vector3.ZERO, false)
	return node


func locker_row(parent: Node, node_name: String, at: Vector3, yaw_deg: float, count: int) -> Node3D:
	var node: Node3D = group(parent, node_name, at)
	node.rotation_degrees.y = yaw_deg
	for i: int in count:
		var x: float = (float(i) - (count - 1) * 0.5) * 0.52
		var locker: Node3D = box(node, "Locker%d" % i, Vector3(x, 1.0, 0), Vector3(0.5, 2.0, 0.55), material("metal_painted"))
		var vent: BoxMesh = BoxMesh.new()
		vent.size = Vector3(0.3, 0.12, 0.01)
		mesh(locker, "Vent", vent, Vector3(0, 0.7, 0.28), material("metal_dark"))
		var handle: BoxMesh = BoxMesh.new()
		handle.size = Vector3(0.03, 0.14, 0.03)
		mesh(locker, "Handle", handle, Vector3(0.18, 0.0, 0.29), material("steel"))
	return node


## Police cruiser (body, cabin, glass, wheels, light bar). Faces -Z.
func cruiser(parent: Node, node_name: String, at: Vector3, yaw_deg: float, swat: bool = false) -> Node3D:
	var node: Node3D = group(parent, node_name, at)
	node.rotation_degrees.y = yaw_deg
	var length: float = 5.6 if swat else 4.9
	var body_height: float = 1.5 if swat else 0.75
	var paint: StandardMaterial3D = material("car_black" if swat else "car_white")
	box(node, "Body", Vector3(0, 0.35 + body_height * 0.5, 0), Vector3(1.9, body_height, length), paint)
	if not swat:
		box(node, "Cabin", Vector3(0, 1.38, 0.25), Vector3(1.72, 0.55, 2.4), material("car_black"), 0.0, false)
		var windshield: BoxMesh = BoxMesh.new()
		windshield.size = Vector3(1.68, 0.5, 0.02)
		mesh(node, "Windshield", windshield, Vector3(0, 1.36, -0.96), material("glass_dark"), Vector3(-25, 0, 0))
	var bar: BoxMesh = BoxMesh.new()
	bar.size = Vector3(0.55, 0.1, 0.25)
	var roof: float = 0.35 + body_height + (0.6 if not swat else 0.05)
	mesh(node, "BarRed", bar, Vector3(-0.3, roof, 0.3), material("led_red"), Vector3.ZERO, false)
	mesh(node, "BarBlue", bar, Vector3(0.3, roof, 0.3), material("led_blue"), Vector3.ZERO, false)
	for side: float in [-1.0, 1.0]:
		for front: float in [-1.0, 1.0]:
			var wheel: CylinderMesh = CylinderMesh.new()
			wheel.top_radius = 0.36
			wheel.bottom_radius = 0.36
			wheel.height = 0.26
			mesh(node, "Wheel%d%d" % [int(side + 1), int(front + 1)], wheel, Vector3(side * 0.9, 0.36, front * (length * 0.5 - 0.9)), material("rubber"), Vector3(0, 0, 90))
	var headlight: BoxMesh = BoxMesh.new()
	headlight.size = Vector3(0.35, 0.1, 0.02)
	for side: float in [-0.6, 0.6]:
		mesh(node, "Headlight%d" % int(side * 10 + 10), headlight, Vector3(side, 0.8, -length * 0.5 - 0.01), material("diffuser_cool"), Vector3.ZERO, false)
	return node


## 20 ft shipping container (6.06 × 2.59 × 2.44) with corrugation ribs and door bars.
func container(parent: Node, node_name: String, at: Vector3, yaw_deg: float, paint: String) -> Node3D:
	var node: Node3D = box(parent, node_name, at + Vector3(0, 1.295, 0), Vector3(2.44, 2.59, 6.06), material(paint), yaw_deg)
	for i: int in 12:
		var rib: BoxMesh = BoxMesh.new()
		rib.size = Vector3(2.47, 2.45, 0.08)
		mesh(node, "Rib%d" % i, rib, Vector3(0, 0, -2.75 + i * 0.5), material(paint))
	for x: float in [-0.5, 0.5]:
		var bar: CylinderMesh = CylinderMesh.new()
		bar.top_radius = 0.025
		bar.bottom_radius = 0.025
		bar.height = 2.4
		mesh(node, "DoorBar%d" % int(x * 10 + 10), bar, Vector3(x, 0, 3.05), material("steel"))
	return node


func crate_stack(parent: Node, node_name: String, at: Vector3, yaw_deg: float, levels: int = 2) -> Node3D:
	var node: Node3D = group(parent, node_name, at)
	node.rotation_degrees.y = yaw_deg
	box(node, "Pallet", Vector3(0, 0.07, 0), Vector3(1.2, 0.14, 1.0), material("wood"))
	for i: int in levels:
		box(node, "Crate%d" % i, Vector3(0, 0.14 + 0.45 + i * 0.9, 0), Vector3(1.1 - i * 0.1, 0.9, 0.95 - i * 0.05), material("wood" if i % 2 == 0 else "cardboard"))
	return node


func barrel(parent: Node, node_name: String, at: Vector3, paint: String = "rust_red") -> Node3D:
	return cylinder(parent, node_name, at + Vector3(0, 0.45, 0), 0.3, 0.9, material(paint))


func jersey_barrier(parent: Node, node_name: String, at: Vector3, yaw_deg: float) -> Node3D:
	var node: Node3D = box(parent, node_name, at + Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 3.0), material("concrete"), yaw_deg)
	var top: BoxMesh = BoxMesh.new()
	top.size = Vector3(0.24, 0.3, 3.0)
	mesh(node, "Top", top, Vector3(0, 0.45, 0), material("concrete"))
	return node


## Chain-link style fence line (posts + thin panel) between two points.
func fence(parent: Node, node_name: String, from: Vector3, to: Vector3, height: float = 2.4) -> Node3D:
	var node: Node3D = group(parent, node_name)
	var length: float = from.distance_to(to)
	var direction: Vector3 = (to - from).normalized()
	var yaw: float = rad_to_deg(atan2(direction.x, direction.z))
	var mid: Vector3 = (from + to) * 0.5
	var panel_material: StandardMaterial3D = material("steel").duplicate() as StandardMaterial3D
	panel_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	panel_material.albedo_color = Color(0.5, 0.52, 0.55, 0.25)
	box(node, "Panel", mid + Vector3(0, height * 0.5, 0), Vector3(0.05, height, length), panel_material, yaw)
	var posts: int = int(length / 3.0) + 1
	for i: int in posts + 1:
		var p: Vector3 = from.lerp(to, float(i) / float(posts))
		cylinder(node, "Post%d" % i, p + Vector3(0, height * 0.5, 0), 0.04, height, material("metal_dark"), false)
	return node
