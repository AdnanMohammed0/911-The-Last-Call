extends GutTest

const FARMHOUSE: PackedScene = preload("res://scenes/field/missions/farmhouse.tscn")


func test_closet_call_uses_farmhouse_and_has_two_approaches() -> void:
	assert_eq(MissionDirector.CALL_MISSIONS[&"call_closet_monster"], BuildFarmhouse.PATH)
	var level: Node3D = FARMHOUSE.instantiate() as Node3D
	autoqfree(level)
	var house: Node3D = level.get_node("Navigation/Farmhouse") as Node3D
	var front: Door = level.get_node("Doors/FrontDoor") as Door
	var rear: Door = level.get_node("Doors/RearDoor") as Door
	assert_true(front.is_locked)
	assert_false(rear.is_locked)
	assert_not_null(house.get_node_or_null("HostagePosition"))
	assert_not_null(house.get_node_or_null("IntelNotebookPosition"))
	assert_not_null(level.get_node_or_null("Navigation/Backyard/RearApproach"))
	assert_not_null(level.get_node_or_null("Navigation/Backyard/BarnFlank"))


func test_farmhouse_has_navigation_spawns_and_extraction() -> void:
	var level: Node3D = FARMHOUSE.instantiate() as Node3D
	autoqfree(level)
	assert_not_null(level.get_node_or_null("Navigation") as MissionNavigation)
	assert_eq(level.get_node("SpawnPoints").get_child_count(), 4)
	var spawner: EnemySpawner = level.get_node("EnemySpawner") as EnemySpawner
	assert_not_null(spawner.navigation)
	assert_eq(spawner.spawn_points.get_child_count(), 6)
	var hostage_taker: EnemySpawnPoint = spawner.spawn_points.get_node("MaskedCaptiveTaker") as EnemySpawnPoint
	assert_true(hostage_taker.is_used_by(&"raid"))
	assert_false(hostage_taker.is_used_by(&"ambush"))
	var controller: MissionController = level.get_node("MissionController") as MissionController
	assert_not_null(controller.extraction_point)


func test_farmhouse_enters_scene_tree_without_scene_errors() -> void:
	var level: Node3D = FARMHOUSE.instantiate() as Node3D
	(level.get_node("Navigation") as MissionNavigation).bake_on_ready = false
	for path: String in ["PlayerSpawner", "EnemySpawner", "MissionController"]:
		var node: Node = level.get_node(path)
		level.remove_child(node)
		node.free()
	add_child_autofree(level)
	assert_true(level.is_inside_tree())
	assert_not_null(level.get_node_or_null("Doors/FrontDoor"))


func test_navigation_bakes_a_route_from_lane_to_rear_entry() -> void:
	var level: Node3D = FARMHOUSE.instantiate() as Node3D
	var nav: MissionNavigation = level.get_node("Navigation") as MissionNavigation
	nav.bake_on_ready = false
	for path: String in ["PlayerSpawner", "EnemySpawner", "MissionController"]:
		var node: Node = level.get_node(path)
		level.remove_child(node)
		node.free()
	add_child_autofree(level)
	nav.bake_now()
	await nav.navigation_ready
	await get_tree().physics_frame
	NavigationServer3D.map_force_update(level.get_world_3d().navigation_map)
	assert_gt(nav.navigation_mesh.get_polygon_count(), 0)
	var route: PackedVector3Array = NavigationServer3D.map_get_path(
		level.get_world_3d().navigation_map, Vector3(-10, 0, 15.5), Vector3(4.55, 0, -24.5), true)
	assert_gt(route.size(), 1)
	var interior_route: PackedVector3Array = NavigationServer3D.map_get_path(
		level.get_world_3d().navigation_map, Vector3(-10, 0, 15.5), Vector3(-3.5, 0, -5.0), true)
	assert_gt(interior_route.size(), 1)
	if interior_route.size() > 0:
		assert_lt(interior_route[-1].distance_to(Vector3(-3.5, 0.43, -5.0)), 1.5)
	var hostage_route: PackedVector3Array = NavigationServer3D.map_get_path(
		level.get_world_3d().navigation_map, Vector3(-10, 0, 15.5), Vector3(-6.25, 0, -17.5), true)
	assert_gt(hostage_route.size(), 1)
	if hostage_route.size() > 0:
		assert_lt(hostage_route[-1].distance_to(Vector3(-6.25, 0.43, -17.5)), 1.5)
