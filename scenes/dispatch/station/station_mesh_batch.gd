## Batches repeated, static primitive decorations within each station room.
## Collision nodes stay in place; scripted or movable ancestors are excluded.
extends Node

const MIN_GROUP_SIZE: int = 4
var batch_count: int = 0
var mesh_count: int = 0


func _ready() -> void:
	var interior: Node3D = get_parent() as Node3D
	if interior == null:
		return
	var groups: Dictionary[String, Array] = {}
	for node: Node in interior.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if not _can_batch(mesh_node, interior):
			continue
		var room: Node3D = _room_for(mesh_node, interior)
		var box: BoxMesh = mesh_node.mesh as BoxMesh
		var material_id: int = mesh_node.material_override.get_instance_id() if mesh_node.material_override != null else 0
		var key: String = "%s|%.9f,%.9f,%.9f|%d|%d|%d|%d" % [
			room.name, box.size.x, box.size.y, box.size.z, material_id,
			mesh_node.cast_shadow, mesh_node.layers, mesh_node.gi_mode]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(mesh_node)
	for key: String in groups:
		var members: Array = groups[key]
		if members.size() < MIN_GROUP_SIZE:
			continue
		@warning_ignore("unsafe_cast")
		var first: MeshInstance3D = members[0] as MeshInstance3D
		var room: Node3D = _room_for(first, interior)
		var batch: MultiMesh = MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = first.mesh
		batch.instance_count = members.size()
		var to_room: Transform3D = room.global_transform.affine_inverse()
		for index: int in members.size():
			@warning_ignore("unsafe_cast")
			var item: MeshInstance3D = members[index] as MeshInstance3D
			batch.set_instance_transform(index, to_room * item.global_transform)
		var visual: MultiMeshInstance3D = MultiMeshInstance3D.new()
		visual.name = "StaticDetailBatch"
		visual.multimesh = batch
		visual.material_override = first.material_override
		visual.cast_shadow = first.cast_shadow
		visual.layers = first.layers
		visual.gi_mode = first.gi_mode
		room.add_child(visual)
		for item: MeshInstance3D in members:
			item.visible = false
		batch_count += 1
		mesh_count += members.size()


func _can_batch(item: MeshInstance3D, interior: Node3D) -> bool:
	if item.mesh == null or not item.mesh is BoxMesh or not item.is_visible_in_tree():
		return false
	if item.get_child_count() > 0 or item.material_overlay != null or item.transparency > 0.0:
		return false
	if item.visibility_range_begin > 0.0 or item.visibility_range_end > 0.0 or item.get_surface_override_material(0) != null:
		return false
	var box: BoxMesh = item.mesh as BoxMesh
	if box.material != null:
		return false
	var ancestor: Node = item
	while ancestor != interior:
		if ancestor.get_script() != null or ancestor is AnimationPlayer:
			return false
		ancestor = ancestor.get_parent()
		if ancestor == null:
			return false
	return true


func _room_for(item: Node, interior: Node3D) -> Node3D:
	var room: Node = item
	while room.get_parent() != interior:
		room = room.get_parent()
	return room as Node3D
