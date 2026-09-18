## station_map.gd — Runtime collision and static environment builder for map.glb.
## Generates trimesh static collision bodies for all structural meshes (floors, walls, stairs, roads)
## so players and physics objects can walk and collide throughout the police station.
class_name StationMap
extends Node3D

const COLLISION_KEYWORDS: Array[String] = [
	"floor", "wall", "road", "sidewalk", "ground", "stair", "ramp", "pillar", "entrance", "reception",
	"cell", "block", "roof", "trim", "door"
]


func _ready() -> void:
	_generate_collisions()
	_ensure_safety_floor()


func _generate_collisions() -> void:
	var mesh_instances: Array[Node] = find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_instances:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var nm: String = mi.name.to_lower()
		var should_collide: bool = false
		for kw: String in COLLISION_KEYWORDS:
			if kw in nm:
				should_collide = true
				break
		if should_collide:
			var has_body: bool = false
			for child: Node in mi.get_children():
				if child is StaticBody3D:
					has_body = true
					break
			if not has_body:
				mi.create_trimesh_collision()


func _ensure_safety_floor() -> void:
	# Continuous safety floor collider under the ground floor to prevent any seam slipping
	if get_node_or_null("SafetyGroundFloor") != null:
		return
	var sb: StaticBody3D = StaticBody3D.new()
	sb.name = "SafetyGroundFloor"
	sb.collision_layer = 1
	sb.collision_mask = 0
	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Shape"
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(140.0, 0.2, 140.0)
	col.shape = box_shape
	col.position = Vector3(0, 0.15, 0)
	sb.add_child(col)
	add_child(sb)

