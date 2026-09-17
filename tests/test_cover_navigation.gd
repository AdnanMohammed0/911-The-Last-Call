## P3-09: navmesh bake per mission, cover generation and cover query rules.
extends GutTest

var _nav: MissionNavigation
var _agent: CharacterBody3D


func _box(parent: Node, center: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	parent.add_child(body)


## 40x40 floor; a low wall (1 m) and a tall wall (3 m) between the AI side (z > 0) and the threat (z < -10).
func before_each() -> void:
	_nav = MissionNavigation.new()
	_nav.bake_on_ready = false
	add_child_autofree(_nav)
	_box(_nav, Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	_box(_nav, Vector3(-6, 0.5, 0), Vector3(4, 1, 0.4))     # low wall
	_box(_nav, Vector3(6, 1.5, 0), Vector3(4, 3, 0.4))      # tall wall
	_agent = CharacterBody3D.new()
	add_child_autofree(_agent)
	_agent.global_position = Vector3(0, 0, 6)
	await wait_physics_frames(2)
	_nav.bake_now()
	await wait_for_signal(_nav.navigation_ready, 5.0)


func _points() -> Array[CoverPoint]:
	var result: Array[CoverPoint] = []
	for node: Node in get_tree().get_nodes_in_group(CoverPoint.GROUP):
		result.append(node as CoverPoint)
	return result


func test_navmesh_is_baked_and_walkable() -> void:
	assert_gt(_nav.navigation_mesh.get_polygon_count(), 0)
	assert_true(_nav.is_ready_for_ai)
	var length: float = CoverQuery.navigation_distance(_agent, Vector3(0, 0, -8))
	assert_true(length < INF and length >= 13.0, "path around/through the gap: %.1f" % length)


func test_cover_generated_next_to_walls_with_heights() -> void:
	var points: Array[CoverPoint] = _points()
	assert_gt(points.size(), 4)
	var has_low: bool = false
	var has_high: bool = false
	for point: CoverPoint in points:
		if point.global_position.x < -3.0 and point.height == CoverPoint.Height.LOW:
			has_low = true
		if point.global_position.x > 3.0 and point.height == CoverPoint.Height.HIGH:
			has_high = true
	assert_true(has_low, "low cover along the 1 m wall")
	assert_true(has_high, "high cover along the 3 m wall")


func test_best_cover_is_protected_from_threat_and_in_range() -> void:
	var threat: Vector3 = Vector3(0, 0, -11)
	var best: CoverPoint = CoverQuery.find_best(_agent, threat)
	assert_not_null(best)
	var world: World3D = _agent.get_world_3d()
	var none: Array[RID] = []
	assert_true(CoverQuery.is_protected(world, best, threat + Vector3(0, 1.5, 0), none))
	assert_true(best.global_position.z > 0.0, "on the far side of a wall from the threat")
	var distance: float = Vector2(best.global_position.x - threat.x, best.global_position.z - threat.z).length()
	assert_between(distance, CoverQuery.MIN_THREAT_DISTANCE, CoverQuery.MAX_THREAT_DISTANCE)


func test_claimed_cover_is_not_given_to_another_agent() -> void:
	var threat: Vector3 = Vector3(0, 0, -11)
	var first: CoverPoint = CoverQuery.find_best(_agent, threat)
	CoverQuery.claim(first, _agent)
	var other: CharacterBody3D = CharacterBody3D.new()
	add_child_autofree(other)
	other.global_position = Vector3(0, 0, 6)
	var second: CoverPoint = CoverQuery.find_best(other, threat)
	assert_ne(first, second)
	CoverQuery.release_all(_agent)
	assert_null(first.claimed_by)


func test_flanked_cover_is_rejected() -> void:
	var threat: Vector3 = Vector3(0, 0, -11)
	var best: CoverPoint = CoverQuery.find_best(_agent, threat)
	# A second player standing on the AI's side of the wall sees straight into that cover.
	var flanker: Array[Vector3] = [best.global_position + best.wall_normal * 6.0]
	var none: Array[RID] = []
	assert_eq(CoverQuery.score_point(_agent, best, threat, flanker, none), INF)


func test_threat_outside_engagement_band_gives_no_cover() -> void:
	assert_null(CoverQuery.find_best(_agent, Vector3(0, 0, -30)), "every cover point is more than 20 m away")
