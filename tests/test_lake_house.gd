extends GutTest

const LAKE_HOUSE: PackedScene = preload("res://scenes/field/missions/lake_house.tscn")


func test_cut_line_routes_to_lake_house_with_anomaly_and_burial() -> void:
	assert_eq(MissionDirector.CALL_MISSIONS[&"call_cut_line"], BuildLakeHouse.PATH)
	var level: Node3D = LAKE_HOUSE.instantiate() as Node3D
	autoqfree(level)
	assert_not_null(level.get_node_or_null("Navigation/House/BasementRamp"))
	assert_not_null(level.get_node_or_null("Navigation/Basement/EMFHotspot"))
	assert_not_null(level.get_node_or_null("Navigation/Dock"))
	var woman: DrownedWoman = level.get_node("Encounter/DrownedWoman") as DrownedWoman
	var flood: LakeWater = level.get_node("Encounter/BasementWater") as LakeWater
	var remains: RemainsInteraction = level.get_node("Encounter/ShoreRemains") as RemainsInteraction
	assert_not_null(woman.zone)
	assert_eq(flood.anomaly, woman)
	assert_eq(remains.get_completion_flag(), &"lake_house_cleared")
	assert_eq(level.get_node("SpawnPoints").get_child_count(), 4)
	assert_not_null((level.get_node("MissionController") as MissionController).extraction_point)


func test_water_shader_tracks_rise_and_recede() -> void:
	var level: Node3D = LAKE_HOUSE.instantiate() as Node3D
	autoqfree(level)
	var flood: LakeWater = level.get_node("Encounter/BasementWater") as LakeWater
	var material: ShaderMaterial = flood.surface.material_override as ShaderMaterial
	assert_not_null(material)
	flood.set_level(0.5)
	assert_almost_eq(flood.surface.position.y, (flood.low_height + flood.high_height) * 0.5, 0.001)
	@warning_ignore("unsafe_cast")
	var shader_rise: float = material.get_shader_parameter(&"rise_fraction") as float
	assert_almost_eq(shader_rise, 0.5, 0.001)
	flood.set_level(1.0)
	assert_almost_eq(flood.surface.position.y, flood.high_height, 0.001)
	flood.set_level(0.0)
	assert_almost_eq(flood.surface.position.y, flood.low_height, 0.001)


func test_navigation_reaches_the_flooded_basement() -> void:
	var level: Node3D = LAKE_HOUSE.instantiate() as Node3D
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
		level.get_world_3d().navigation_map, Vector3(-11, 0, 16), Vector3(-3, -2.5, -5), true)
	assert_gt(route.size(), 1)
	if route.size() > 0:
		assert_lt(route[-1].distance_to(Vector3(-3, -2.1, -5)), 1.5)


func test_basement_water_listens_to_the_drowned_woman() -> void:
	var level: Node3D = LAKE_HOUSE.instantiate() as Node3D
	(level.get_node("Navigation") as MissionNavigation).bake_on_ready = false
	for path: String in ["PlayerSpawner", "EnemySpawner", "MissionController"]:
		var node: Node = level.get_node(path)
		level.remove_child(node)
		node.free()
	add_child_autofree(level)
	var woman: DrownedWoman = level.get_node("Encounter/DrownedWoman") as DrownedWoman
	var flood: LakeWater = level.get_node("Encounter/BasementWater") as LakeWater
	var remains: RemainsInteraction = level.get_node("Encounter/ShoreRemains") as RemainsInteraction
	woman.water_level_changed.emit(0.8)
	assert_almost_eq(flood.target_level, 0.8, 0.001)
	remains.burial_completed.emit(&"lake_house_cleared")
	assert_eq(woman.fsm.current, DrownedWoman.BANISHED)
	assert_eq(flood.target_level, 0.0)
