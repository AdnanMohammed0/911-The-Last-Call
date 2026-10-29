## Builds 14 Blackwater Drive: an abandoned house above a flooded basement and a dark lakeside dock.
class_name BuildLakeHouse
extends RefCounted

const PATH: String = "res://scenes/field/missions/lake_house.tscn"
const DOOR: String = "res://scenes/shared/door/door.tscn"
const WOMAN: String = "res://scenes/field/anomalies/drowned_woman.tscn"
const WATER_SHADER: Shader = preload("res://scenes/field/missions/lake_water.gdshader")


static func build() -> Error:
	var root: Node3D = Node3D.new()
	root.name = "BlackwaterLakeHouse"
	var kit: LevelKit = LevelKit.new(root)
	kit.environment(root, 0.023, 0.10, false, 1.85)
	kit.moonlight(root, 0.22)
	var navigation: MissionNavigation = MissionNavigation.new()
	kit.own(navigation, root, "Navigation")
	_land(kit, navigation)
	_house(kit, navigation)
	_basement(kit, navigation)
	_dock(kit, navigation)
	_lights(kit, root)
	_encounter(kit, root, navigation)
	_mission(kit, root, navigation)
	var scene: PackedScene = PackedScene.new()
	var result: Error = scene.pack(root)
	if result == OK:
		result = ResourceSaver.save(scene, PATH)
	root.free()
	return result


static func _land(kit: LevelKit, navigation: MissionNavigation) -> void:
	var land: Node3D = kit.group(navigation, "Land")
	var ground: Material = kit.material("grass")
	# Leave the footprint open so the basement is not blocked by the terrain slab.
	kit.box(land, "WestBank", Vector3(-21, -0.18, 0), Vector3(26, 0.3, 64), ground)
	kit.box(land, "EastBank", Vector3(21, -0.18, 0), Vector3(26, 0.3, 64), ground)
	kit.box(land, "FrontBank", Vector3(0, -0.18, 20), Vector3(16, 0.3, 24), ground)
	kit.box(land, "LakeBank", Vector3(0, -0.18, -10), Vector3(16, 0.3, 4), ground)
	kit.box(land, "BlackwaterDrive", Vector3(0, -0.01, 21), Vector3(68, 0.05, 7), kit.material("asphalt"))
	kit.box(land, "Driveway", Vector3(-3.5, 0.02, 13.5), Vector3(4, 0.04, 12), kit.material("concrete_dark"), 0.0, false)
	kit.box(land, "Walkway", Vector3(-1.0, 0.03, 9.0), Vector3(1.5, 0.04, 4), kit.material("concrete"), 0.0, false)
	kit.box(land, "AddressPost", Vector3(-6.5, 0.65, 13.2), Vector3(0.16, 1.3, 0.16), kit.material("wood"))
	kit.box(land, "AddressBox", Vector3(-6.5, 1.32, 13.2), Vector3(0.6, 0.3, 0.32), kit.material("metal_dark"), 0.0, false)
	for i: int in 10:
		var x: float = -29.0 if i < 5 else 29.0
		var z: float = -26.0 + float(i % 5) * 12.0
		_tree(kit, land, "DeadBirch%d" % i, Vector3(x, 0, z), 4.5 + float(i % 3))
	kit.fence(land, "RoadFenceWest", Vector3(-14, 0, 10), Vector3(-14, 0, 17), 1.2)
	kit.fence(land, "RoadFenceEast", Vector3(14, 0, 10), Vector3(14, 0, 17), 1.2)
	var address: Label3D = kit.own(Label3D.new(), land, "Address14") as Label3D
	address.text = "14 BLACKWATER DRIVE"
	address.font_size = 44
	address.pixel_size = 0.005
	address.position = Vector3(-6.5, 1.2, 13.2)
	address.billboard = BaseMaterial3D.BILLBOARD_ENABLED


static func _tree(kit: LevelKit, parent: Node3D, name: String, at: Vector3, height: float) -> void:
	var tree: Node3D = kit.group(parent, name, at)
	kit.cylinder(tree, "Trunk", Vector3(0, height * 0.5, 0), 0.18, height, kit.material("wood"), false)
	for i: int in 3:
		var branch: Node3D = kit.box(tree, "Branch%d" % i,
			Vector3(0.5 if i % 2 == 0 else -0.5, height * (0.55 + i * 0.11), 0),
			Vector3(1.6, 0.1, 0.1), kit.material("wood"), 25.0 if i % 2 == 0 else -30.0, false)
		branch.rotation_degrees.z = 22.0 if i % 2 == 0 else -18.0


static func _house(kit: LevelKit, navigation: MissionNavigation) -> void:
	var house: Node3D = kit.group(navigation, "House")
	var doors: Node3D = kit.group(navigation.get_parent(), "Doors")
	var siding: Material = kit.material("siding")
	var plaster: Material = kit.material("plaster_blue")
	var wood: Material = kit.material("wood")
	# Four upper slabs leave an actual opening for the ramp into the basement.
	kit.box(house, "FloorLeft", Vector3(-2.65, 0.04, 0), Vector3(10.7, 0.08, 16), wood)
	kit.box(house, "FloorRightFront", Vector3(5.35, 0.04, 6.5), Vector3(5.3, 0.08, 3), wood)
	kit.box(house, "FloorRightRear", Vector3(5.35, 0.04, -5.6), Vector3(5.3, 0.08, 4.8), wood)
	kit.box(house, "FloorRightEdge", Vector3(6.9, 0.04, 2), Vector3(2.2, 0.08, 6), wood)
	kit.box(house, "Porch", Vector3(-1.0, 0.04, 9.0), Vector3(5.5, 0.08, 3), wood)
	kit.wall(house, "Front", Vector3(-8, 0, 8), Vector3(8, 0, 8), 3.2, 0.24, siding,
		[[2.0, 1.7, 0.9, 2.2], [6.1, 1.8, 0.0, 2.2], [12.0, 1.7, 0.9, 2.2]])
	kit.wall(house, "Back", Vector3(-8, 0, -8), Vector3(8, 0, -8), 3.2, 0.24, siding,
		[[2.0, 1.7, 0.9, 2.2], [9.1, 1.8, 0.0, 2.2]])
	kit.wall(house, "West", Vector3(-8, 0, -8), Vector3(-8, 0, 8), 3.2, 0.24, siding,
		[[3.0, 1.7, 0.9, 2.2], [11.2, 1.7, 0.9, 2.2]])
	kit.wall(house, "East", Vector3(8, 0, -8), Vector3(8, 0, 8), 3.2, 0.24, siding,
		[[3.0, 1.7, 0.9, 2.2], [11.2, 1.7, 0.9, 2.2]])
	_gable(kit, house, "FrontGable", 8.0)
	_gable(kit, house, "RearGable", -8.0)
	kit.wall(house, "BedroomPartition", Vector3(-8, 0, -1), Vector3(2.7, 0, -1), 3.2, 0.14, plaster,
		[[4.2, 1.8, 0.0, 2.2]])
	_place_door(kit, doors, "FrontDoor", Vector3(-1.0, 0, 8), 180.0, true)
	_place_door(kit, doors, "BackDoor", Vector3(2.0, 0, -8), 0.0, false)
	# Only visual roof pieces: no collision ceiling over the ramp or navmesh.
	var roof: BoxMesh = BoxMesh.new()
	roof.size = Vector3(8.8, 0.24, 17.5)
	kit.mesh(house, "RoofWest", roof, Vector3(-4.0, 4.1, 0), kit.material("shingle"), Vector3(0, 0, 17))
	kit.mesh(house, "RoofEast", roof, Vector3(4.0, 4.1, 0), kit.material("shingle"), Vector3(0, 0, -17))
	var glass: Material = kit.material("glass_dark")
	kit.box(house, "FrontGlass1", Vector3(-5.15, 1.55, 8.02), Vector3(1.7, 1.3, 0.035), glass, 0.0, false)
	kit.box(house, "FrontGlass2", Vector3(4.85, 1.55, 8.02), Vector3(1.7, 1.3, 0.035), glass, 0.0, false)
	kit.box(house, "BackGlass", Vector3(-5.15, 1.55, -8.02), Vector3(1.7, 1.3, 0.035), glass, 0.0, false)
	kit.box(house, "Sofa", Vector3(-5.0, 0.42, 3.3), Vector3(2.6, 0.84, 0.85), kit.material("fabric_dark"))
	kit.box(house, "CoffeeTable", Vector3(-5.0, 0.28, 1.9), Vector3(1.4, 0.56, 0.8), wood)
	kit.box(house, "KitchenCounter", Vector3(7.3, 0.5, -5.5), Vector3(0.7, 1.0, 3.2), kit.material("desk_laminate"))
	kit.box(house, "Bed", Vector3(-4.8, 0.3, -5.2), Vector3(2.1, 0.6, 2.3), kit.material("fabric_dark"))
	kit.box(house, "Cabinet", Vector3(-7.5, 0.9, -2.1), Vector3(0.5, 1.8, 1.5), wood)
	kit.box(house, "BrokenPhone", Vector3(-5.0, 0.6, 1.9), Vector3(0.35, 0.08, 0.22), kit.material("plastic_black"), 0.0, false)
	var ramp: Node3D = kit.box(house, "BasementRamp", Vector3(4.25, -1.2, 1.5), Vector3(2.2, 0.18, 8.0), wood)
	ramp.rotation_degrees.x = -19.3
	kit.box(house, "RampRailWest", Vector3(2.95, -0.35, 1.5), Vector3(0.12, 0.7, 7.4), kit.material("wood"), 0.0, false)
	kit.box(house, "RampRailEast", Vector3(5.55, -0.35, 1.5), Vector3(0.12, 0.7, 7.4), kit.material("wood"), 0.0, false)


static func _gable(kit: LevelKit, house: Node3D, name: String, z: float) -> void:
	var vertices: PackedVector3Array = PackedVector3Array([
		Vector3(-8, 3.2, z), Vector3(8, 3.2, z), Vector3(0, 5.3, z),
		Vector3(0, 5.3, z), Vector3(8, 3.2, z), Vector3(-8, 3.2, z),
	])
	var normals: PackedVector3Array = PackedVector3Array([
		Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD,
		Vector3.BACK, Vector3.BACK, Vector3.BACK,
	])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	kit.mesh(house, name, mesh, Vector3.ZERO, kit.material("siding"))


static func _basement(kit: LevelKit, navigation: MissionNavigation) -> void:
	var basement: Node3D = kit.group(navigation, "Basement")
	var concrete: Material = kit.material("concrete_dark")
	kit.box(basement, "Floor", Vector3(0, -2.55, 0), Vector3(15.2, 0.1, 15.2), concrete)
	kit.wall(basement, "Front", Vector3(-7.6, -2.5, 7.6), Vector3(7.6, -2.5, 7.6), 2.5, 0.24, concrete)
	kit.wall(basement, "Back", Vector3(-7.6, -2.5, -7.6), Vector3(7.6, -2.5, -7.6), 2.5, 0.24, concrete)
	kit.wall(basement, "West", Vector3(-7.6, -2.5, -7.6), Vector3(-7.6, -2.5, 7.6), 2.5, 0.24, concrete)
	kit.wall(basement, "East", Vector3(7.6, -2.5, -7.6), Vector3(7.6, -2.5, 7.6), 2.5, 0.24, concrete)
	kit.wall(basement, "FloodedRoomDivider", Vector3(-7.6, -2.5, -2.0), Vector3(7.6, -2.5, -2.0), 2.5, 0.14, concrete,
		[[10.5, 2.4, 0.0, 2.5]])
	kit.box(basement, "StorageShelf", Vector3(-6.8, -1.5, -4.8), Vector3(0.7, 2.0, 2.3), kit.material("metal_dark"))
	kit.barrel(basement, "RustBarrel", Vector3(-4.5, -2.5, -5.6), "rust_red")
	kit.crate_stack(basement, "SoggyBoxes", Vector3(-5.8, -2.5, 4.5), 0.0, 1)
	kit.box(basement, "BreakerCabinet", Vector3(7.1, -1.5, -5.1), Vector3(0.6, 1.5, 1.1), kit.material("metal_painted"))
	kit.marker(basement, "EMFHotspot", Vector3(-3.0, -2.4, -5.0))
	kit.marker(basement, "LockedRoom", Vector3(4.2, -2.4, -3.0))


static func _dock(kit: LevelKit, navigation: MissionNavigation) -> void:
	var dock: Node3D = kit.group(navigation, "Dock")
	for i: int in 12:
		kit.box(dock, "Plank%d" % i, Vector3(0, 0.06, -11.0 - float(i) * 1.2), Vector3(3.0, 0.12, 1.05), kit.material("wood"))
	for z: float in [-13.0, -19.0, -25.0]:
		kit.box(dock, "PilingL%d" % int(z), Vector3(-1.45, -0.75, z), Vector3(0.22, 1.65, 0.22), kit.material("wood"))
		kit.box(dock, "PilingR%d" % int(z), Vector3(1.45, -0.75, z), Vector3(0.22, 1.65, 0.22), kit.material("wood"))
	var lake_mesh: PlaneMesh = PlaneMesh.new()
	lake_mesh.size = Vector2(80, 37)
	lake_mesh.subdivide_width = 48
	lake_mesh.subdivide_depth = 24
	var outside_water: MeshInstance3D = kit.mesh(navigation.get_parent(), "BlackwaterLake", lake_mesh,
		Vector3(0, -0.12, -30.5), _water_material(0.025), Vector3.ZERO, false)
	outside_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	kit.marker(dock, "ShoreApproach", Vector3(11.0, 0.05, -10.0))


static func _water_material(strength: float) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter(&"wave_strength", strength)
	return material


static func _place_door(kit: LevelKit, doors: Node3D, name: String, at: Vector3, yaw: float, locked: bool) -> void:
	var transform: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), at)
	var door: Door = kit.instance(DOOR, doors, name, transform) as Door
	door.is_locked = locked
	for side: int in [-1, 1]:
		kit.box(doors, "%sJamb%d" % [name, side], at + Vector3(float(side) * 0.7, 1.1, 0),
			Vector3(0.4, 2.2, 0.24), kit.material("wood"))


static func _lights(kit: LevelKit, root: Node3D) -> void:
	var lights: Node3D = kit.group(root, "Lighting")
	kit.street_lamp(lights, "RoadLight", Vector3(-15, 0, 19), 180.0, 6.0, 7.0)
	kit.bulkhead(lights, "PorchLight", Vector3(-1, 2.45, 8.2), 180.0, 0.9, 6.0, false)
	kit.ceiling_panel(lights, "LivingLamp", Vector3(-4, 3.0, 3), true, 0.7, 5.0, false)
	kit.ceiling_panel(lights, "BasementLamp", Vector3(-3, -0.08, -5), false, 0.45, 5.0, false)
	kit.bulkhead(lights, "DockLamp", Vector3(0, 1.8, -12.0), 180.0, 0.8, 7.0, false)
	for child: Node in lights.get_children():
		for light: Node in child.find_children("*", "Light3D", true, false):
			light.add_to_group(Anomaly.LIGHTS_GROUP, true)
	kit.light_zone(lights, "DarkBasement", Vector3(0, -1.2, 0), Vector3(15, 2.4, 15))


static func _encounter(kit: LevelKit, root: Node3D, _navigation: MissionNavigation) -> void:
	var encounter: Node3D = kit.group(root, "Encounter")
	var zone: Area3D = kit.own(Area3D.new(), encounter, "HauntedZone") as Area3D
	zone.position = Vector3(0, -0.5, 0)
	zone.collision_layer = 0
	zone.collision_mask = 1
	var zone_shape: CollisionShape3D = kit.own(CollisionShape3D.new(), zone, "Shape") as CollisionShape3D
	var zone_box: BoxShape3D = BoxShape3D.new()
	zone_box.size = Vector3(22, 7, 23)
	zone_shape.shape = zone_box
	var basement_trigger: Area3D = kit.own(Area3D.new(), encounter, "BasementTrigger") as Area3D
	basement_trigger.position = Vector3(0, -1.65, 0)
	basement_trigger.collision_layer = 0
	basement_trigger.collision_mask = 1
	var trigger_shape: CollisionShape3D = kit.own(CollisionShape3D.new(), basement_trigger, "Shape") as CollisionShape3D
	var trigger_box: BoxShape3D = BoxShape3D.new()
	trigger_box.size = Vector3(14, 1.5, 14)
	trigger_shape.shape = trigger_box
	var woman: DrownedWoman = kit.instance(WOMAN, encounter, "DrownedWoman",
		Transform3D(Basis.IDENTITY, Vector3(-3, -2.45, -4.5))) as DrownedWoman
	woman.zone = zone
	for i: int in 5:
		var points: Array[Vector3] = [Vector3(-5, -2.45, -5), Vector3(5, -2.45, -5),
			Vector3(-5, -2.45, 4), Vector3(-5, 0.05, -5), Vector3(5, 0.05, -4)]
		var marker: Marker3D = kit.marker(encounter, "DarkNode%d" % i, points[i])
		marker.add_to_group(Anomaly.DARK_NODES_GROUP, true)
	var remains: RemainsInteraction = RemainsInteraction.new()
	kit.own(remains, encounter, "ShoreRemains")
	remains.position = Vector3(11.0, 0.05, -10.0)
	var remains_shape: CollisionShape3D = kit.own(CollisionShape3D.new(), remains, "Shape") as CollisionShape3D
	var remains_box: BoxShape3D = BoxShape3D.new()
	remains_box.size = Vector3(1.0, 0.6, 1.0)
	remains_shape.shape = remains_box
	var flood: LakeWater = LakeWater.new()
	kit.own(flood, encounter, "BasementWater")
	flood.anomaly = woman
	var water_mesh: PlaneMesh = PlaneMesh.new()
	water_mesh.size = Vector2(14.7, 14.7)
	water_mesh.subdivide_width = 24
	water_mesh.subdivide_depth = 24
	var surface: MeshInstance3D = kit.mesh(flood, "Surface", water_mesh, Vector3.ZERO,
		_water_material(0.045), Vector3.ZERO, false)
	flood.surface = surface
	var events: LakeHouseEvents = LakeHouseEvents.new()
	kit.own(events, encounter, "LakeHouseEvents")
	events.anomaly = woman
	events.basement_trigger = basement_trigger
	events.remains = remains


static func _mission(kit: LevelKit, root: Node3D, navigation: MissionNavigation) -> void:
	var extraction: Node3D = kit.group(root, "Extraction", Vector3(-10, 0, 20.5))
	kit.cruiser(extraction, "PoliceVan", Vector3.ZERO, 90.0, true)
	kit.group(root, "Players")
	var spawns: Node3D = kit.group(root, "SpawnPoints")
	for i: int in 4:
		kit.marker(spawns, "Spawn%d" % (i + 1), Vector3(-12.5 + float(i) * 1.4, 0.05, 16), 180.0)
	var player_spawner: PlayerSpawner = PlayerSpawner.new()
	kit.own(player_spawner, root, "PlayerSpawner")
	player_spawner.spawn_path = NodePath("../Players")
	player_spawner.spawn_points = spawns
	kit.group(root, "Enemies")
	var points: Node3D = kit.group(root, "EnemySpawnPoints")
	var enemy_spawner: EnemySpawner = EnemySpawner.new()
	kit.own(enemy_spawner, root, "EnemySpawner")
	enemy_spawner.spawn_path = NodePath("../Enemies")
	enemy_spawner.spawn_points = points
	enemy_spawner.navigation = navigation
	var controller: MissionController = MissionController.new()
	kit.own(controller, root, "MissionController")
	controller.extraction_point = extraction.get_node("PoliceVan") as Node3D
	controller.extraction_radius = 4.5
