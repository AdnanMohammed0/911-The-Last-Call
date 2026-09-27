## Imported-model helpers shared by level builders, the shop icon studio and the character rigs.
## Every downloaded model comes in its own units and pivot, so props are placed through `place()`: it
## instances the scene inside a wrapper, rotates it to face +Z, scales it uniformly to a real-world size on
## one axis and puts the bottom centre of its bounds on the wrapper origin.
## Authority: LOCAL (purely visual)
class_name ModelKit
extends RefCounted

enum Fit { HEIGHT, WIDTH, DEPTH, LONGEST }

## Station props: [path, fit axis, size in metres, base yaw that turns the model's front towards +Z].
const PROPS: Dictionary[StringName, Array] = {
	&"coffee_machine": ["res://assets/3D/station_props/coffee_machine.glb", Fit.HEIGHT, 0.46, 0.0],
	&"vending_machine": ["res://assets/3D/station_props/vending_machine.glb", Fit.HEIGHT, 1.9, 0.0],
	&"water_dispenser": ["res://assets/3D/station_props/water_dispenser.glb", Fit.HEIGHT, 1.3, 0.0],
	&"leather_couch": ["res://assets/3D/station_props/leather_couch.glb", Fit.WIDTH, 2.4, 0.0],
	&"leather_armchair": ["res://assets/3D/station_props/leather_armchair.glb", Fit.WIDTH, 1.1, 0.0],
	&"server_rack": ["res://assets/3D/station_props/server_rack.glb", Fit.HEIGHT, 2.05, -90.0],
	&"metal_locker": ["res://assets/3D/station_props/metal_locker.glb", Fit.HEIGHT, 1.95, 0.0],
	&"ammo_crate": ["res://assets/3D/station_props/ammo_crate.glb", Fit.WIDTH, 0.95, 0.0],
	&"plate_carrier": ["res://assets/3D/gear/plate_carrier.glb", Fit.HEIGHT, 0.62, 0.0],
	&"armored_truck": ["res://assets/3D/cars/armored_truck.glb", Fit.DEPTH, 6.2, 0.0],
	&"cruiser": ["res://assets/3D/cars/fairheaven_lt_80_cop_cruiser_-_low_poly_model.glb", Fit.WIDTH, 5.1, 90.0],
}

static var _scenes: Dictionary[String, PackedScene] = {}


## Instance prop `prop_id` (see PROPS) under `parent`. Returns the wrapper, or null when the model is missing.
static func prop(parent: Node, prop_id: StringName, node_name: String, at: Vector3 = Vector3.ZERO, yaw: float = 0.0) -> Node3D:
	if not PROPS.has(prop_id):
		return null
	var spec: Array = PROPS[prop_id]
	var path: String = spec[0]
	var fit: Fit = spec[1]
	var size: float = spec[2]
	var base_yaw: float = spec[3]
	return place(parent, path, node_name, at, yaw, fit, size, base_yaw)


## Instance `path` inside a wrapper at `at` / `yaw` (degrees). The model is turned by `base_yaw`, scaled so
## its bounds measure `size` metres along `fit` and grounded at the wrapper origin.
static func place(parent: Node, path: String, node_name: String, at: Vector3, yaw: float, fit: Fit, size: float,
		base_yaw: float = 0.0) -> Node3D:
	var model: Node3D = instance(path)
	if model == null:
		return null
	var wrapper: Node3D = Node3D.new()
	wrapper.name = node_name
	wrapper.position = at
	wrapper.rotation_degrees.y = yaw
	parent.add_child(wrapper)
	model.name = "Model"
	model.rotation_degrees.y = base_yaw
	wrapper.add_child(model)
	var box: AABB = bounds_in(model, wrapper)
	var measured: float = box.size.y
	match fit:
		Fit.WIDTH:
			measured = box.size.x
		Fit.DEPTH:
			measured = box.size.z
		Fit.LONGEST:
			measured = maxf(box.size.x, maxf(box.size.y, box.size.z))
	var factor: float = size / maxf(measured, 0.0001)
	model.scale = Vector3.ONE * factor
	box = bounds_in(model, wrapper)
	model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	return wrapper


## Bare instance of a model scene (cached), or null.
static func instance(path: String) -> Node3D:
	if not _scenes.has(path):
		if not ResourceLoader.exists(path):
			return null
		_scenes[path] = load(path) as PackedScene
	var scene: PackedScene = _scenes[path]
	if scene == null:
		return null
	return scene.instantiate() as Node3D


## Size of a placed wrapper's model (its bounds in wrapper space).
static func size_of(wrapper: Node3D) -> Vector3:
	return bounds_in(wrapper, wrapper).size


## Bounds of every mesh under `root`, expressed in `space`'s local coordinates. Works before entering the tree.
static func bounds_in(root: Node3D, space: Node3D) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node: Node in meshes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var to_space: Transform3D = relative_transform(space, mesh_instance)
		var box: AABB = to_space * mesh_instance.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


## Transform of `node` in the local space of its ancestor `ancestor` (identity if it is not an ancestor).
static func relative_transform(ancestor: Node3D, node: Node3D) -> Transform3D:
	var result: Transform3D = Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		var spatial: Node3D = current as Node3D
		if spatial != null:
			result = spatial.transform * result
		current = current.get_parent()
	return result


## Static box collider sized to the wrapper's model (optionally shrunk / grown by `pad`).
static func add_collider(wrapper: Node3D, pad: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var box: AABB = bounds_in(wrapper, wrapper)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Collider"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = (box.size + pad).max(Vector3.ONE * 0.05)
	shape.shape = box_shape
	shape.position = box.get_center()
	body.add_child(shape)
	wrapper.add_child(body)
	return body


## Render layer / shadow settings for every visual under `root`.
static func set_layers(root: Node, layers: int, cast_shadow: bool = true) -> void:
	for node: Node in [root] + root.find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		if geometry == null:
			continue
		geometry.layers = layers
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
