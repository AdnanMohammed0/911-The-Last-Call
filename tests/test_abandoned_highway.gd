extends GutTest

const HIGHWAY: PackedScene = preload("res://scenes/field/missions/abandoned_highway.tscn")


func test_meat_truck_routes_to_highway_with_two_approaches() -> void:
	assert_eq(MissionDirector.CALL_MISSIONS[&"call_meat_truck"], BuildHighway.PATH)
	var level: Node3D = HIGHWAY.instantiate() as Node3D
	autoqfree(level)
	assert_not_null(level.get_node_or_null("Navigation/Highway/OldHighway9"))
	assert_not_null(level.get_node_or_null("Navigation/Highway/FlankDirtRoad"))
	assert_not_null(level.get_node_or_null("Navigation/MeatTruck/ReeferBox"))
	assert_eq(level.get_node("SpawnPoints").get_child_count(), 4)
	assert_not_null((level.get_node("MissionController") as MissionController).extraction_point)
	assert_eq(level.get_node("EnemySpawnPoints").get_child_count(), 4)


func test_rpg_set_piece_has_control_and_unmanned_cruiser() -> void:
	var level: Node3D = HIGHWAY.instantiate() as Node3D
	autoqfree(level)
	var event: HighwayRpgSetPiece = level.get_node("RpgSetPiece") as HighwayRpgSetPiece
	var control: HighwayDecoyControl = level.get_node("RpgSetPiece/RemoteDriveUplink") as HighwayDecoyControl
	assert_eq(control.set_piece, event)
	assert_not_null(event.trigger)
	assert_not_null(event.cruiser)
	assert_not_null(event.launch_point)
	assert_not_null(event.projectile)
	assert_not_null(event.blast)
	assert_eq(HighwayRpgSetPiece.CRUISER_LOSS, 3000)


func test_rpg_miss_after_tech_diverts_cruiser() -> void:
	var level: Node3D = _level_without_spawners()
	var event: HighwayRpgSetPiece = level.get_node("RpgSetPiece") as HighwayRpgSetPiece
	var original_budget: int = GameState.station_budget
	event._sync_armed()
	assert_true(event.is_armed())
	assert_true((level.get_node("RpgSetPiece/RemoteDriveUplink") as HighwayDecoyControl)._can_interact(1))
	event.divert_cruiser()
	assert_true(event.was_diverted())
	event._strike()
	assert_true(event.is_resolved())
	assert_eq(GameState.station_budget, original_budget)
	await get_tree().create_timer(0.6).timeout
	assert_true(event.cruiser.visible)


func test_rpg_hit_charges_budget_once() -> void:
	var level: Node3D = _level_without_spawners()
	var event: HighwayRpgSetPiece = level.get_node("RpgSetPiece") as HighwayRpgSetPiece
	var original_budget: int = GameState.station_budget
	GameState.station_budget = 10000
	event._sync_armed()
	event._strike()
	assert_eq(GameState.station_budget, 7000)
	event._strike()
	assert_eq(GameState.station_budget, 7000)
	await get_tree().create_timer(0.6).timeout
	assert_false(event.cruiser.visible)
	var body: StaticBody3D = event.cruiser.get_node("Body") as StaticBody3D
	assert_true((body.get_node("Shape") as CollisionShape3D).disabled)
	GameState.station_budget = original_budget


func test_navmesh_reaches_road_and_flank_of_truck() -> void:
	var level: Node3D = HIGHWAY.instantiate() as Node3D
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
	var map: RID = level.get_world_3d().navigation_map
	for target: Vector3 in [Vector3(-16, 0, -28), Vector3(-3, 0, -17), Vector3(7, 0, -29)]:
		var route: PackedVector3Array = NavigationServer3D.map_get_path(map, Vector3(-4, 0, 37), target, true)
		assert_gt(route.size(), 1)
		if route.size() > 0:
			assert_lt(route[-1].distance_to(target), 2.0)


func _level_without_spawners() -> Node3D:
	var level: Node3D = HIGHWAY.instantiate() as Node3D
	(level.get_node("Navigation") as MissionNavigation).bake_on_ready = false
	for path: String in ["PlayerSpawner", "EnemySpawner", "MissionController"]:
		var node: Node = level.get_node(path)
		level.remove_child(node)
		node.free()
	add_child_autofree(level)
	return level
