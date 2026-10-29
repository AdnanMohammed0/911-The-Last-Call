extends GutTest

const LIGHTING_SCRIPT = preload("res://scenes/field/missions/mission_lighting.gd")
const MAP_SCENES := {
	"warehouse": "res://scenes/field/missions/warehouse_raid.tscn",
	"aspen": "res://scenes/field/missions/aspen_drive.tscn",
	"farmhouse": "res://scenes/field/missions/farmhouse.tscn",
	"lake": "res://scenes/field/missions/lake_house.tscn",
	"highway": "res://scenes/field/missions/abandoned_highway.tscn",
}


func test_every_mission_has_its_lighting_profile() -> void:
	for map_name: String in MAP_SCENES:
		var scene := load(str(MAP_SCENES[map_name])) as PackedScene
		assert_not_null(scene, map_name)
		if scene == null:
			continue
		var level := scene.instantiate()
		autoqfree(level)
		var world := level.get_node("WorldEnvironment") as WorldEnvironment
		assert_eq(str(world.get_script()), str(LIGHTING_SCRIPT), map_name)
		assert_eq(str(world.get("profile")), map_name, map_name)


func test_profiles_choose_one_bounce_method_and_distinct_fog() -> void:
	var densities: Array[float] = []
	for map_name: String in ["warehouse", "aspen", "farmhouse", "lake", "highway"]:
		var env := Environment.new()
		LIGHTING_SCRIPT.apply_profile(env, map_name)
		assert_false(env.sdfgi_enabled and env.ssil_enabled, map_name)
		assert_true(env.volumetric_fog_enabled, map_name)
		assert_lte(env.volumetric_fog_length, 65.0, map_name)
		densities.append(env.volumetric_fog_density)
	assert_eq(densities.size(), 5)
	assert_gt(densities[3], densities[0], "lake fog is thicker than warehouse haze")


func test_only_feature_lights_cast_local_shadows() -> void:
	var root := Node3D.new()
	var world: WorldEnvironment = LIGHTING_SCRIPT.new()
	world.set("profile", "warehouse")
	world.environment = Environment.new()
	root.add_child(world)
	var fixtures := Node3D.new()
	fixtures.name = "Lighting"
	root.add_child(fixtures)
	var flood := Node3D.new()
	flood.name = "FloodWest"
	fixtures.add_child(flood)
	var flood_light := SpotLight3D.new()
	flood.add_child(flood_light)
	var door := Node3D.new()
	door.name = "DoorLamp"
	fixtures.add_child(door)
	var door_light := OmniLight3D.new()
	door.add_child(door_light)
	add_child_autofree(root)
	assert_true(flood_light.shadow_enabled)
	assert_true(flood_light.distance_fade_enabled)
	assert_false(door_light.shadow_enabled)
