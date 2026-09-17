## Generates CoverPoints along the border of a baked navmesh wherever a wall stands right next to it.
## Border edges = polygon edges used by only one polygon. Along each, every `spacing` metres, short rays
## in 8 directions look for a wall at crouch height (LOW cover) and head height (HIGH cover).
## Authority: HOST
class_name CoverGenerator
extends RefCounted

const WALL_PROBE: float = 0.9
const LOW_PROBE_HEIGHT: float = 0.7
const HIGH_PROBE_HEIGHT: float = 1.5


## Adds CoverPoint children to `region` and returns how many were created.
static func generate(region: NavigationRegion3D, spacing: float = 1.6) -> int:
	var mesh: NavigationMesh = region.navigation_mesh
	if mesh == null or mesh.get_polygon_count() == 0:
		return 0
	var vertices: PackedVector3Array = mesh.get_vertices()
	var edge_uses: Dictionary = {}
	for p: int in mesh.get_polygon_count():
		var polygon: PackedInt32Array = mesh.get_polygon(p)
		for i: int in polygon.size():
			var a: int = polygon[i]
			var b: int = polygon[(i + 1) % polygon.size()]
			var key: Vector2i = Vector2i(mini(a, b), maxi(a, b))
			var uses: int = edge_uses.get(key, 0)
			edge_uses[key] = uses + 1

	var world: World3D = region.get_world_3d()
	var placed: PackedVector3Array = PackedVector3Array()
	var created: int = 0
	for key: Variant in edge_uses:
		var uses: int = edge_uses[key]
		if uses != 1:
			continue
		var edge: Vector2i = key
		var start: Vector3 = region.global_transform * vertices[edge.x]
		var end: Vector3 = region.global_transform * vertices[edge.y]
		var steps: int = maxi(int(start.distance_to(end) / spacing), 1)
		for s: int in range(steps + 1):
			# Navmesh vertices float up to ~2 cells above the real floor: snap down before probing.
			var point: Vector3 = _snap_to_floor(world, start.lerp(end, float(s) / steps))
			if _near_existing(placed, point, spacing * 0.9):
				continue
			var found: Array = _probe_wall(world, point)
			if found.is_empty():
				continue
			var cover: CoverPoint = CoverPoint.new()
			cover.name = "Cover_%d" % created
			cover.height = found[0]
			cover.wall_normal = found[1]
			region.add_child(cover)
			cover.global_position = point
			placed.append(point)
			created += 1
	return created


## [CoverPoint.Height, wall_normal] when a wall is right next to `point`, else [].
static func _probe_wall(world: World3D, point: Vector3) -> Array:
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	for i: int in 8:
		var direction: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0)
		var low_from: Vector3 = point + Vector3(0, LOW_PROBE_HEIGHT, 0)
		var low: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(low_from, low_from + direction * WALL_PROBE, 1))
		if low.is_empty():
			continue
		var normal: Vector3 = low["normal"]
		normal.y = 0.0
		if normal.length() < 0.5:
			continue  # sloped / floor hit, not a wall
		var high_from: Vector3 = point + Vector3(0, HIGH_PROBE_HEIGHT, 0)
		var high: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(high_from, high_from + direction * WALL_PROBE, 1))
		return [CoverPoint.Height.HIGH if not high.is_empty() else CoverPoint.Height.LOW, normal.normalized()]
	return []


static func _snap_to_floor(world: World3D, point: Vector3) -> Vector3:
	var from: Vector3 = point + Vector3(0, 0.5, 0)
	var hit: Dictionary = world.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, point - Vector3(0, 2.0, 0), 1))
	if hit.is_empty():
		return point
	var floor_point: Vector3 = hit["position"]
	return floor_point


static func _near_existing(placed: PackedVector3Array, point: Vector3, min_distance: float) -> bool:
	for existing: Vector3 in placed:
		if existing.distance_to(point) < min_distance:
			return true
	return false
