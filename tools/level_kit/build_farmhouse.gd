## Builds the Birch Lane farmhouse for "Scratching Behind the Wall".
## Front and rear entries support loud/quiet approaches; all walkable geometry belongs to Navigation.
class_name BuildFarmhouse
extends RefCounted

const PATH: String = "res://scenes/field/missions/farmhouse.tscn"
const DOOR: String = "res://scenes/shared/door/door.tscn"
const WALL_H: float = 3.0


static func build() -> Error:
	var root: Node3D = Node3D.new()
	root.name = "BirchLaneFarmhouse"
	var kit: LevelKit = LevelKit.new(root)
	kit.environment(root, 0.012, 0.11, false, 1.85)
	kit.moonlight(root, 0.28)
	var navigation: MissionNavigation = MissionNavigation.new()
	kit.own(navigation, root, "Navigation")
	_grounds(kit, navigation)
	_house(kit, navigation)
	_outbuildings(kit, navigation)
	_lighting(kit, root)
	_mission_nodes(kit, root, navigation)
	var scene: PackedScene = PackedScene.new()
	var result: Error = scene.pack(root)
	if result == OK:
		result = ResourceSaver.save(scene, PATH)
	root.free()
	return result


static func _grounds(kit: LevelKit, navigation: MissionNavigation) -> void:
	var grounds: Node3D = kit.group(navigation, "Grounds")
	kit.box(grounds, "Ground", Vector3(0, -0.17, -4), Vector3(74, 0.3, 76), kit.material("grass"))
	kit.box(grounds, "BirchLane", Vector3(0, -0.01, 20), Vector3(74, 0.05, 8), kit.material("asphalt"))
	kit.box(grounds, "DirtDrive", Vector3(10.5, 0.015, 10), Vector3(4.5, 0.04, 20), kit.material("concrete_dark"), 0.0, false)
	kit.box(grounds, "FrontWalk", Vector3(-2.35, 0.02, 4), Vector3(1.4, 0.04, 10), kit.material("concrete"), 0.0, false)
	kit.box(grounds, "RearPath", Vector3(4.5, 0.015, -22), Vector3(1.2, 0.04, 7), kit.material("concrete_dark"), 0.0, false)
	for i: int in 8:
		var x: float = -32.0 + float(i % 4) * 20.0
		var z: float = -32.0 if i < 4 else 8.0
		if i >= 4 and x > -12.0 and x < 13.0:
			continue
		_tree(kit, grounds, "Birch%d" % i, Vector3(x, 0, z), 4.8 + float(i % 3))
	kit.fence(grounds, "WestBoundary", Vector3(-16, 0, -28), Vector3(-16, 0, 7), 1.4)
	kit.fence(grounds, "EastBoundary", Vector3(17, 0, -28), Vector3(17, 0, 6), 1.4)
	kit.fence(grounds, "RearWestFence", Vector3(-16, 0, -28), Vector3(2, 0, -28), 1.4)
	kit.fence(grounds, "RearEastFence", Vector3(7, 0, -28), Vector3(17, 0, -28), 1.4)
	kit.box(grounds, "MailboxPost", Vector3(-4.4, 0.6, 15.5), Vector3(0.15, 1.2, 0.15), kit.material("wood"))
	kit.box(grounds, "Mailbox", Vector3(-4.4, 1.25, 15.5), Vector3(0.55, 0.3, 0.32), kit.material("metal_dark"), 0.0, false)
	var address: Label3D = kit.own(Label3D.new(), grounds, "Address14") as Label3D
	address.text = "14  BIRCH LANE"
	address.font_size = 40
	address.pixel_size = 0.005
	address.position = Vector3(-4.4, 1.58, 15.5)
	address.billboard = BaseMaterial3D.BILLBOARD_ENABLED


static func _tree(kit: LevelKit, parent: Node3D, name: String, at: Vector3, height: float) -> void:
	var tree: Node3D = kit.group(parent, name, at)
	kit.cylinder(tree, "Trunk", Vector3(0, height * 0.5, 0), 0.2, height, kit.material("wood"), false)
	var crown: SphereMesh = SphereMesh.new()
	crown.radius = 1.7
	crown.height = 3.2
	crown.radial_segments = 8
	crown.rings = 4
	kit.mesh(tree, "Crown", crown, Vector3(0, height + 0.5, 0), kit.material("container_green"))


static func _house(kit: LevelKit, navigation: MissionNavigation) -> void:
	var house: Node3D = kit.group(navigation, "Farmhouse")
	var doors: Node3D = kit.group(navigation.get_parent(), "Doors")
	var siding: Material = kit.material("siding")
	var plaster: Material = kit.material("plaster")
	kit.box(house, "Floor", Vector3(0, 0.04, -10), Vector3(16, 0.08, 18), kit.material("wood"))
	kit.box(house, "FrontPorch", Vector3(-2.3, 0.06, 0.65), Vector3(5.0, 0.12, 3.3), kit.material("wood"))
	kit.box(house, "BackSteps", Vector3(4.55, 0.06, -20.2), Vector3(2.3, 0.12, 2.3), kit.material("wood"))
	kit.wall(house, "FrontWall", Vector3(-8, 0, -1), Vector3(8, 0, -1), WALL_H, 0.24, siding,
		[[1.8, 1.8, 0.9, 2.2], [4.8, 1.8, 0.0, 2.2], [11.0, 1.8, 0.9, 2.2]])
	kit.wall(house, "RearWall", Vector3(-8, 0, -19), Vector3(8, 0, -19), WALL_H, 0.24, siding,
		[[2.0, 1.5, 0.9, 2.2], [11.65, 1.8, 0.0, 2.2]])
	kit.wall(house, "WestWall", Vector3(-8, 0, -19), Vector3(-8, 0, -1), WALL_H, 0.24, siding,
		[[3.0, 1.7, 0.9, 2.2], [12.2, 1.7, 0.9, 2.2]])
	kit.wall(house, "EastWall", Vector3(8, 0, -19), Vector3(8, 0, -1), WALL_H, 0.24, siding,
		[[4.0, 1.7, 0.9, 2.2], [13.0, 1.7, 0.9, 2.2]])
	_gable(kit, house, "FrontGable", -1.0)
	_gable(kit, house, "RearGable", -19.0)
	var glass: Material = kit.material("glass_dark")
	kit.box(house, "FrontWestGlass", Vector3(-5.3, 1.55, -0.98), Vector3(1.8, 1.3, 0.035), glass, 0.0, false)
	kit.box(house, "FrontEastGlass", Vector3(3.9, 1.55, -0.98), Vector3(1.8, 1.3, 0.035), glass, 0.0, false)
	kit.box(house, "RearGlass", Vector3(-5.25, 1.55, -19.02), Vector3(1.5, 1.3, 0.035), glass, 0.0, false)
	kit.box(house, "WestBedroomGlass", Vector3(-8.02, 1.55, -15.15), Vector3(0.035, 1.3, 1.7), glass, 0.0, false)
	kit.box(house, "WestLivingGlass", Vector3(-8.02, 1.55, -5.95), Vector3(0.035, 1.3, 1.7), glass, 0.0, false)
	kit.box(house, "EastServiceGlass", Vector3(8.02, 1.55, -14.15), Vector3(0.035, 1.3, 1.7), glass, 0.0, false)
	kit.box(house, "EastKitchenGlass", Vector3(8.02, 1.55, -5.15), Vector3(0.035, 1.3, 1.7), glass, 0.0, false)
	# Living/dining area in front, bedrooms and service rooms in back.
	kit.wall(house, "CenterWall", Vector3(-8, 0, -10), Vector3(8, 0, -10), WALL_H, 0.14, plaster,
		[[3.95, 1.8, 0.0, 2.2], [10.65, 1.8, 0.0, 2.2]])
	kit.wall(house, "RearDivider", Vector3(1, 0, -19), Vector3(1, 0, -10), WALL_H, 0.14, plaster,
		[[2.45, 1.8, 0.0, 2.2]])
	# A walk-in closet is the staged hostage room, reachable through the bedroom.
	kit.wall(house, "ClosetWest", Vector3(-7.7, 0, -18.7), Vector3(-7.7, 0, -15.0), WALL_H, 0.13, plaster)
	kit.wall(house, "ClosetFront", Vector3(-7.7, 0, -15.0), Vector3(-4.7, 0, -15.0), WALL_H, 0.13, plaster,
		[[0.55, 1.8, 0.0, 2.2]])
	kit.wall(house, "ClosetEast", Vector3(-4.7, 0, -18.7), Vector3(-4.7, 0, -15.0), WALL_H, 0.13, plaster)
	kit.box(house, "ClosetBack", Vector3(-6.2, 1.5, -18.7), Vector3(3.0, 3.0, 0.13), plaster)
	_place_door(kit, doors, "FrontDoor", Vector3(-2.3, 0, -1), 0.0, true)
	_place_door(kit, doors, "RearDoor", Vector3(4.55, 0, -19), 180.0, false)
	_place_door(kit, doors, "BedroomDoor", Vector3(-3.15, 0, -10), 0.0, false)
	_place_door(kit, doors, "ClosetDoor", Vector3(-6.25, 0, -15), 0.0, false)
	# Four roof planes read as an old gable without adding collision over the playable rooms.
	var roof: BoxMesh = BoxMesh.new()
	roof.size = Vector3(8.9, 0.23, 19.0)
	kit.mesh(house, "RoofWest", roof, Vector3(-4.0, 4.05, -10), kit.material("shingle"), Vector3(0, 0, 18))
	kit.mesh(house, "RoofEast", roof, Vector3(4.0, 4.05, -10), kit.material("shingle"), Vector3(0, 0, -18))
	_furnish(kit, house)
	var hostage: Marker3D = kit.marker(house, "HostagePosition", Vector3(-6.25, 0.05, -17.5))
	hostage.add_to_group(&"farmhouse_hostage_position", true)
	kit.marker(house, "IntelNotebookPosition", Vector3(-5.9, 0.78, -12.6))


static func _gable(kit: LevelKit, house: Node3D, name: String, z: float) -> void:
	var vertices: PackedVector3Array = PackedVector3Array([
		Vector3(-8, 3, z), Vector3(8, 3, z), Vector3(0, 5.4, z),
		Vector3(0, 5.4, z), Vector3(8, 3, z), Vector3(-8, 3, z),
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


static func _place_door(kit: LevelKit, parent: Node3D, name: String, at: Vector3, yaw: float, locked: bool) -> void:
	var transform: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), at)
	var door: Door = kit.instance(DOOR, parent, name, transform) as Door
	door.is_locked = locked
	for side: int in [-1, 1]:
		kit.box(parent, "%sJamb%d" % [name, side], at + Vector3(float(side) * 0.7, 1.1, 0),
			Vector3(0.4, 2.2, 0.24), kit.material("wood"))


static func _furnish(kit: LevelKit, house: Node3D) -> void:
	kit.box(house, "Sofa", Vector3(-4.8, 0.45, -4.6), Vector3(2.7, 0.9, 0.85), kit.material("fabric_dark"))
	kit.box(house, "CoffeeTable", Vector3(-4.8, 0.27, -6.0), Vector3(1.4, 0.54, 0.8), kit.material("wood"))
	kit.box(house, "TVConsole", Vector3(-4.8, 0.45, -8.8), Vector3(2.0, 0.9, 0.4), kit.material("wood"))
	kit.box(house, "DiningTable", Vector3(4.0, 0.42, -5.4), Vector3(2.0, 0.84, 1.2), kit.material("wood"))
	kit.box(house, "KitchenCounter", Vector3(7.3, 0.48, -7.3), Vector3(0.75, 0.96, 4.4), kit.material("desk_laminate"))
	kit.box(house, "Fridge", Vector3(7.35, 0.92, -2.2), Vector3(0.85, 1.84, 0.85), kit.material("steel"))
	kit.box(house, "BedroomBed", Vector3(-1.3, 0.3, -16.5), Vector3(2.1, 0.6, 2.4), kit.material("fabric_dark"))
	kit.box(house, "BedroomDresser", Vector3(-7.35, 0.47, -11.5), Vector3(0.65, 0.94, 1.7), kit.material("wood"))
	kit.box(house, "ServiceShelf", Vector3(7.35, 1.0, -16.0), Vector3(0.65, 2.0, 2.2), kit.material("wood"))
	kit.crate_stack(house, "StoredBoxes", Vector3(4.2, 0, -17.5), 0.0, 1)
	kit.box(house, "ClosetShelf", Vector3(-6.3, 1.8, -18.3), Vector3(2.2, 0.15, 0.45), kit.material("wood"), 0.0, false)
	# The notebook is visible on the dresser as a future authored evidence pickup.
	kit.box(house, "AmbushNotebook", Vector3(-7.35, 0.98, -11.5), Vector3(0.26, 0.04, 0.35), kit.material("paper_board"), 0.0, false)
	for i: int in 4:
		kit.box(house, "ScratchMark%d" % i, Vector3(-4.61, 1.0 + i * 0.22, -17.2), Vector3(0.025, 0.03, 0.9), kit.material("rust_red"), 0.0, false)


static func _outbuildings(kit: LevelKit, navigation: MissionNavigation) -> void:
	var yard: Node3D = kit.group(navigation, "Backyard")
	kit.box(yard, "BarnFloor", Vector3(12.5, 0.03, -18), Vector3(7, 0.06, 10), kit.material("concrete"))
	kit.wall(yard, "BarnBack", Vector3(9, 0, -23), Vector3(16, 0, -23), 3.4, 0.25, kit.material("wood"))
	kit.wall(yard, "BarnEast", Vector3(16, 0, -23), Vector3(16, 0, -13), 3.4, 0.25, kit.material("wood"))
	kit.wall(yard, "BarnFront", Vector3(9, 0, -13), Vector3(16, 0, -13), 3.4, 0.25, kit.material("wood"), [[1.5, 3.5, 0.0, 2.7]])
	kit.wall(yard, "BarnWest", Vector3(9, 0, -23), Vector3(9, 0, -13), 3.4, 0.25, kit.material("wood"))
	kit.box(yard, "BarnRoof", Vector3(12.5, 3.65, -18), Vector3(7.7, 0.35, 10.7), kit.material("shingle"), 0.0, false)
	kit.crate_stack(yard, "BarnSupplies", Vector3(14.6, 0, -21), 0.0, 2)
	kit.barrel(yard, "RainBarrel", Vector3(8.2, 0, -20), "metal_dark")
	kit.box(yard, "Generator", Vector3(-11.8, 0.55, -22), Vector3(1.5, 1.1, 1.0), kit.material("metal_dark"))
	kit.box(yard, "PowerCable", Vector3(-10.0, 2.7, -19), Vector3(0.035, 0.035, 10), kit.material("plastic_black"), 0.0, false)
	kit.box(yard, "BrokenFence", Vector3(4.6, 0.4, -28.1), Vector3(2.1, 0.1, 0.14), kit.material("wood"), 0.0, false)
	kit.marker(yard, "RearApproach", Vector3(4.55, 0.05, -24.5))
	kit.marker(yard, "BarnFlank", Vector3(10.5, 0.05, -11.5))


static func _lighting(kit: LevelKit, root: Node3D) -> void:
	var lights: Node3D = kit.group(root, "Lighting")
	kit.street_lamp(lights, "LaneLamp", Vector3(-13, 0, 18), 180.0, 6.0, 8.0)
	kit.bulkhead(lights, "PorchLight", Vector3(-2.3, 2.55, -0.85), 0.0, 1.6, 7.0, false)
	kit.bulkhead(lights, "RearLight", Vector3(4.55, 2.55, -19.15), 180.0, 0.5, 6.0, false)
	kit.ceiling_panel(lights, "LivingLamp", Vector3(-4.0, 2.9, -5.0), true, 1.6, 6.0, false)
	kit.ceiling_panel(lights, "KitchenLamp", Vector3(4.5, 2.9, -5.5), true, 1.2, 5.0, false)
	kit.ceiling_panel(lights, "BedroomLamp", Vector3(-2.0, 2.9, -15.0), true, 0.7, 5.0, false)
	kit.light_zone(lights, "LitPorch", Vector3(-2.3, 1.5, 0.7), Vector3(6, 3, 6))
	kit.light_zone(lights, "DarkCloset", Vector3(-6.2, 1.2, -17.0), Vector3(3.0, 2.4, 3.5))


static func _mission_nodes(kit: LevelKit, root: Node3D, navigation: MissionNavigation) -> void:
	var extraction: Node3D = kit.group(root, "Extraction", Vector3(-7.0, 0, 19.5))
	kit.cruiser(extraction, "PoliceVan", Vector3.ZERO, 90.0, true)
	kit.group(root, "Players")
	var spawns: Node3D = kit.group(root, "SpawnPoints")
	for i: int in 4:
		kit.marker(spawns, "Spawn%d" % (i + 1), Vector3(-10.0 + float(i) * 1.4, 0.05, 15.5), 180.0)
	var player_spawner: PlayerSpawner = PlayerSpawner.new()
	kit.own(player_spawner, root, "PlayerSpawner")
	player_spawner.spawn_path = NodePath("../Players")
	player_spawner.spawn_points = spawns
	var squad: AISquad = AISquad.new()
	kit.own(squad, root, "SquadHouse")
	kit.group(root, "Enemies")
	var points: Node3D = kit.group(root, "EnemySpawnPoints")
	_enemy_point(kit, points, "MaskedCaptiveTaker", "hostage_taker", Vector3(-2.7, 0.05, -13.2), [&"raid"])
	_enemy_point(kit, points, "BarnLookout", "thug", Vector3(12.4, 0.05, -18), [&"raid"])
	_enemy_point(kit, points, "PrankCaller", "prankster", Vector3(-2.7, 0.05, -13.2), [&"arrest"])
	_enemy_point(kit, points, "AmbushBedroom", "cultist_gunman", Vector3(-2.7, 0.05, -13.2), [&"ambush"])
	_enemy_point(kit, points, "AmbushBarn", "cultist_gunman", Vector3(12.4, 0.05, -18), [&"ambush"])
	_enemy_point(kit, points, "AmbushFront", "thug", Vector3(-12.0, 0.05, 1.0), [&"ambush"])
	var enemy_spawner: EnemySpawner = EnemySpawner.new()
	kit.own(enemy_spawner, root, "EnemySpawner")
	enemy_spawner.spawn_path = NodePath("../Enemies")
	enemy_spawner.spawn_points = points
	enemy_spawner.navigation = navigation
	var controller: MissionController = MissionController.new()
	kit.own(controller, root, "MissionController")
	controller.extraction_point = extraction.get_node("PoliceVan") as Node3D
	controller.extraction_radius = 4.5


static func _enemy_point(kit: LevelKit, points: Node3D, name: String, archetype_name: String, at: Vector3, kinds: Array[StringName]) -> void:
	var point: EnemySpawnPoint = EnemySpawnPoint.new()
	kit.own(point, points, name)
	point.position = at
	point.archetype = load("res://data/ai/archetypes/%s.tres" % archetype_name) as ArchetypeData
	point.squad = NodePath("../../SquadHouse")
	point.mission_kinds = kinds
