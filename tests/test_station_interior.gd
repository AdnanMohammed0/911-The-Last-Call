extends GutTest

const INTERIOR: String = "res://scenes/dispatch/station/station_interior.tscn"


func _colliders(scene: Node3D) -> Array[AABB]:
	var boxes: Array[AABB] = []
	for node: Node in scene.find_children("*", "CollisionShape3D", true, false):
		var collision: CollisionShape3D = node as CollisionShape3D
		var shape: BoxShape3D = collision.shape as BoxShape3D
		if shape != null and not collision.disabled:
			boxes.append(ModelKit.relative_transform(scene, collision) * AABB(-shape.size / 2.0, shape.size))
	return boxes


func test_furniture_leaves_doors_corridor_and_spawn_points_clear() -> void:
	var interior: Node3D = (load(INTERIOR) as PackedScene).instantiate() as Node3D
	autofree(interior)
	var boxes: Array[AABB] = _colliders(interior)
	# Door width and swing/approach space, measured from the map_v13 door headers.
	var openings: Array[AABB] = [
		AABB(Vector3(16.7, 0.9, -23.5), Vector3(4.8, 2.2, 22.5)),
		AABB(Vector3(14.7, 0.9, -21.0), Vector3(2.9, 2.2, 2.7)),
		AABB(Vector3(14.7, 0.9, -14.1), Vector3(2.9, 2.2, 2.7)),
		AABB(Vector3(14.7, 0.9, -7.9), Vector3(2.9, 2.2, 2.6)),
		AABB(Vector3(21.0, 0.9, -19.4), Vector3(3.0, 2.2, 2.7)),
		AABB(Vector3(23.5, 0.9, -25.5), Vector3(2.7, 2.2, 2.7)),
		AABB(Vector3(29.0, 0.9, -7.65), Vector3(2.5, 2.2, 2.65)),
		AABB(Vector3(27.1, 0.9, -29.8), Vector3(2.7, 2.2, 2.7)),
		AABB(Vector3(51.3, 0.9, -25.4), Vector3(2.7, 2.2, 2.7)),
		AABB(Vector3(54.7, 0.9, -28.9), Vector3(2.7, 2.2, 2.5)),
		AABB(Vector3(59.5, 0.9, -31.8), Vector3(2.3, 2.2, 2.6)),
	]
	for point: Vector3 in [Vector3(6, 0.95, -23.4), Vector3(10, 0.95, -23), Vector3(6, 0.95, -22), Vector3(10, 0.95, -22)]:
		openings.append(AABB(point - Vector3(0.45, 0, 0.45), Vector3(0.9, 1.9, 0.9)))
	var blocked: Array[String] = []
	for opening: AABB in openings:
		for box: AABB in boxes:
			if opening.intersects(box):
				blocked.append("clearance %s intersects furniture %s" % [opening, box])
	assert_eq(blocked.size(), 0, "Doors, corridor and spawns stay clear: " + str(blocked))


func test_dressing_does_not_overlap_purchased_furniture() -> void:
	var previous_persist: bool = Economy.persist
	var previous_state: Dictionary = Economy._state().duplicate(true)
	Economy.persist = false
	Economy.reset()
	# Fully furnished save, including upgrades gated behind progression.
	for item: Dictionary in ShopCatalog.ITEMS:
		var item_id: StringName = item["id"]
		Economy.inventory[item_id] = item.get("max", 1)
	var interior: Node3D = (load(INTERIOR) as PackedScene).instantiate() as Node3D
	autofree(interior)
	var dressing_boxes: Array[AABB] = _colliders(interior)
	var furniture: StationFurniture = StationFurniture.new()
	add_child_autofree(furniture)
	var conflicts: Array[String] = []
	for item: Dictionary in ShopCatalog.ITEMS:
		var item_id: StringName = item["id"]
		var count: int = item.get("max", 1)
		for i: int in count:
			var prop: Node3D = furniture.item_node(item_id, i)
			assert_not_null(prop, "Fully owned item is present: %s/%d" % [item_id, i])
			if prop == null:
				continue
			for node: Node in prop.find_children("*", "CollisionShape3D", true, false):
				var collision: CollisionShape3D = node as CollisionShape3D
				if not collision.get_parent() is StaticBody3D:
					continue
				var shape: BoxShape3D = collision.shape as BoxShape3D
				if shape == null:
					continue
				var box: AABB = ModelKit.relative_transform(furniture, collision) * AABB(-shape.size / 2.0, shape.size)
				for dressing: AABB in dressing_boxes:
					var inner_box: AABB = AABB(box.position + box.size * 0.01, box.size * 0.98)
					var inner_dressing: AABB = AABB(dressing.position + dressing.size * 0.01, dressing.size * 0.98)
					if inner_box.intersects(inner_dressing):
						conflicts.append("%s conflicts at %s" % [item_id, dressing])
	Economy._apply_state(previous_state)
	Economy.persist = previous_persist
	assert_eq(conflicts.size(), 0, "StationMart furniture keeps its reserved space: " + str(conflicts))
