## Builds res://scenes/field/missions/aspen_drive.tscn — a night suburban street: the target house (#22,
## enterable: living room, kitchen, bedroom, attached garage, fenced backyard), neighbouring houses, parked
## cars, street lamps and the police van extraction point. Enemy spawn points are tagged per mission kind:
## arrest (unarmed prank callers), raid (armed occupants), ambush (gunmen staged around the house).
## Run through tools/level_kit/build_levels.tscn.
## Authority: TOOLS
class_name BuildAspenDrive
extends RefCounted

const PATH: String = "res://scenes/field/missions/aspen_drive.tscn"
const WALL_H: float = 3.0


static func build() -> Error:
	var root: Node3D = Node3D.new()
	root.name = "AspenDrive"
	var kit: LevelKit = LevelKit.new(root)
	kit.environment(root, 0.014, 0.12, true, 1.9)
	kit.moonlight(root, 0.34)

	var navigation: MissionNavigation = MissionNavigation.new()
	kit.own(navigation, root, "Navigation")
	_street(kit, navigation)
	_target_house(kit, navigation)
	_neighbours(kit, navigation)

	var lights: Node3D = kit.group(root, "Lighting")
	_lights(kit, lights)

	var extraction: Node3D = kit.group(root, "Extraction", Vector3(-38, 0, 5))
	kit.cruiser(extraction, "PoliceVan", Vector3(0, 0, 0), 90.0, true)
	kit.cruiser(extraction, "Cruiser", Vector3(0, 0, 3.5), 100.0)
	var sign: Label3D = kit.own(Label3D.new(), extraction, "Sign") as Label3D
	sign.text = "EXTRACTION"
	sign.font_size = 40
	sign.pixel_size = 0.008
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color(0.95, 0.75, 0.3)
	sign.position = Vector3(0, 3.3, 0)
	kit.group(root, "Players")
	var spawns: Node3D = kit.group(root, "SpawnPoints")
	for i: int in 4:
		kit.marker(spawns, "Spawn%d" % (i + 1), Vector3(-30.0 + i * 1.6, 0.05, 6.5), -90.0)
	var spawner: PlayerSpawner = PlayerSpawner.new()
	kit.own(spawner, root, "PlayerSpawner")
	spawner.spawn_path = NodePath("../Players")
	spawner.spawn_points = spawns

	_enemies(kit, root, navigation)

	var controller: MissionController = MissionController.new()
	kit.own(controller, root, "MissionController")
	controller.extraction_point = extraction.get_node("PoliceVan") as Node3D
	controller.extraction_radius = 4.5

	var scene: PackedScene = PackedScene.new()
	var err: Error = scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, PATH)
	root.free()
	return err


static func _street(kit: LevelKit, parent: Node3D) -> void:
	var street: Node3D = kit.group(parent, "Street")
	kit.box(street, "Lawns", Vector3(0, -0.15, -4), Vector3(100, 0.2, 80), kit.material("grass"))
	kit.box(street, "Road", Vector3(0, -0.02, 5), Vector3(100, 0.06, 10), kit.material("asphalt"))
	kit.box(street, "SidewalkNorth", Vector3(0, 0.03, -0.9), Vector3(100, 0.12, 1.8), kit.material("concrete"))
	kit.box(street, "SidewalkSouth", Vector3(0, 0.03, 10.9), Vector3(100, 0.12, 1.8), kit.material("concrete"))
	for i: int in 12:
		kit.box(street, "Lane%d" % i, Vector3(-44 + i * 8, 0.02, 5), Vector3(3.0, 0.01, 0.15), kit.material("hazard_yellow"), 0.0, false)
	kit.cruiser(street, "ParkedCar1", Vector3(-12, 0, 8.8), 90.0)
	kit.cruiser(street, "ParkedCar2", Vector3(14, 0, 1.2), -90.0)
	kit.cruiser(street, "ParkedCar3", Vector3(26, 0, 8.8), 90.0)
	kit.box(street, "Driveway", Vector3(10, 0.02, -4.0), Vector3(5, 0.06, 6), kit.material("concrete"), 0.0, false)
	kit.box(street, "Walkway", Vector3(0, 0.02, -3.5), Vector3(1.4, 0.06, 5), kit.material("concrete"), 0.0, false)
	for x: float in [-45.0, 45.0]:
		kit.fence(street, "EdgeFence%d" % int(x), Vector3(x, 0, -40), Vector3(x, 0, 30))


static func _target_house(kit: LevelKit, parent: Node3D) -> void:
	var house: Node3D = kit.group(parent, "House22")
	var siding: StandardMaterial3D = kit.material("siding")
	var inner: StandardMaterial3D = kit.material("plaster")
	kit.box(house, "Floor", Vector3(0, 0.05, -13), Vector3(14.4, 0.1, 14.4), kit.material("wood"))
	kit.box(house, "Roof", Vector3(0, WALL_H + 0.2, -13), Vector3(15.5, 0.4, 15.5), kit.material("shingle"), 0.0, false)
	# Outer walls: front door + windows, back door to the yard.
	kit.wall(house, "Front", Vector3(-7, 0, -6), Vector3(7, 0, -6), WALL_H, 0.25, siding, [[3.0, 2.2, 0.9, 2.1], [6.0, 1.2, 0.0, 2.2], [9.5, 2.2, 0.9, 2.1]])
	kit.wall(house, "Back", Vector3(-7, 0, -20), Vector3(7, 0, -20), WALL_H, 0.25, siding, [[2.0, 1.2, 0.0, 2.2], [9.0, 2.0, 1.0, 2.0]])
	kit.wall(house, "West", Vector3(-7, 0, -20), Vector3(-7, 0, -6), WALL_H, 0.25, siding, [[5.0, 2.0, 1.0, 2.0]])
	kit.wall(house, "East", Vector3(7, 0, -20), Vector3(7, 0, -6), WALL_H, 0.25, siding, [[3.0, 1.2, 0.0, 2.2]])
	# Interior: living room (front) / kitchen + bedroom (back).
	kit.wall(house, "Middle", Vector3(-7, 0, -13), Vector3(7, 0, -13), WALL_H, 0.15, inner, [[2.5, 1.2, 0.0, 2.2], [9.8, 1.2, 0.0, 2.2]])
	kit.wall(house, "BedroomWall", Vector3(1, 0, -20), Vector3(1, 0, -13), WALL_H, 0.15, inner, [[4.0, 1.1, 0.0, 2.2]])
	# Furniture (cover indoors).
	kit.box(house, "Couch", Vector3(-3, 0.45, -10.5), Vector3(2.4, 0.9, 0.9), kit.material("fabric_dark"))
	kit.box(house, "CoffeeTable", Vector3(-3, 0.25, -8.8), Vector3(1.2, 0.5, 0.6), kit.material("wood"))
	kit.box(house, "TVStand", Vector3(-3, 0.4, -6.5), Vector3(1.8, 0.8, 0.4), kit.material("metal_dark"))
	kit.box(house, "Bookshelf", Vector3(-6.6, 1.0, -9), Vector3(0.4, 2.0, 1.6), kit.material("wood"))
	kit.box(house, "KitchenCounter", Vector3(-4, 0.5, -19.4), Vector3(5.5, 1.0, 0.8), kit.material("desk_laminate"))
	kit.box(house, "KitchenIsland", Vector3(-3.5, 0.5, -16), Vector3(2.4, 1.0, 1.1), kit.material("desk_laminate"))
	kit.box(house, "Fridge", Vector3(-6.4, 0.95, -17), Vector3(0.8, 1.9, 0.8), kit.material("steel"))
	kit.box(house, "Bed", Vector3(4.5, 0.3, -17.5), Vector3(2.0, 0.6, 2.4), kit.material("fabric_dark"))
	kit.box(house, "Wardrobe", Vector3(6.5, 1.0, -14.5), Vector3(0.7, 2.0, 1.6), kit.material("wood"))
	# Garage (east, open door facing the driveway).
	var garage: Node3D = kit.group(parent, "Garage")
	kit.box(garage, "Floor", Vector3(10, 0.03, -12.5), Vector3(6, 0.06, 13), kit.material("concrete"), 0.0, false)
	kit.box(garage, "Roof", Vector3(10, WALL_H + 0.1, -12.5), Vector3(6.4, 0.3, 13.4), kit.material("shingle"), 0.0, false)
	kit.wall(garage, "Front", Vector3(7, 0, -6), Vector3(13, 0, -6), WALL_H, 0.25, siding, [[0.6, 4.8, 0.0, 2.5]])
	kit.wall(garage, "Back", Vector3(7, 0, -19), Vector3(13, 0, -19), WALL_H, 0.25, siding)
	kit.wall(garage, "East", Vector3(13, 0, -19), Vector3(13, 0, -6), WALL_H, 0.25, siding)
	kit.cruiser(garage, "SuspectCar", Vector3(10, 0, -11), 0.0)
	kit.box(garage, "Workbench", Vector3(12.4, 0.45, -16), Vector3(0.8, 0.9, 3.0), kit.material("wood"))
	kit.crate_stack(garage, "Boxes", Vector3(8.2, 0, -17.8), 0.0, 2)
	# Backyard.
	var yard: Node3D = kit.group(parent, "Backyard")
	kit.fence(yard, "FenceWest", Vector3(-9, 0, -20), Vector3(-9, 0, -34))
	kit.fence(yard, "FenceEast", Vector3(13, 0, -19), Vector3(13, 0, -34))
	kit.fence(yard, "FenceBack", Vector3(-9, 0, -34), Vector3(13, 0, -34))
	kit.box(yard, "Shed", Vector3(9, 1.2, -30.5), Vector3(3.5, 2.4, 3.0), kit.material("siding"))
	kit.box(yard, "Grill", Vector3(-4, 0.5, -24), Vector3(0.8, 1.0, 0.6), kit.material("metal_dark"))
	kit.box(yard, "PatioTable", Vector3(0, 0.4, -23.5), Vector3(1.6, 0.8, 1.0), kit.material("wood"))
	kit.crate_stack(yard, "Firewood", Vector3(-7, 0, -31), 0.0, 1)


static func _closed_house(kit: LevelKit, parent: Node3D, node_name: String, center: Vector3, size: Vector3, paint: String) -> void:
	var house: Node3D = kit.group(parent, node_name, center)
	kit.box(house, "Body", Vector3(0, size.y * 0.5, 0), size, kit.material(paint))
	kit.box(house, "Roof", Vector3(0, size.y + 0.25, 0), Vector3(size.x + 1.0, 0.5, size.z + 1.0), kit.material("shingle"), 0.0, false)
	for i: int in 3:
		var window: BoxMesh = BoxMesh.new()
		window.size = Vector3(1.2, 1.0, 0.05)
		var facing: float = 1.0 if center.z < 0.0 else -1.0
		kit.mesh(house, "Window%d" % i, window, Vector3(-size.x * 0.3 + i * size.x * 0.3, 1.6, facing * (size.z * 0.5 + 0.03)),
			kit.material("screen_amber" if i == 1 else "glass_dark"), Vector3.ZERO, false)


static func _neighbours(kit: LevelKit, parent: Node3D) -> void:
	var block: Node3D = kit.group(parent, "Neighbours")
	_closed_house(kit, block, "House18", Vector3(-28, 0, -13), Vector3(12, 3.2, 12), "brick")
	_closed_house(kit, block, "House26", Vector3(28, 0, -13), Vector3(12, 3.2, 12), "siding")
	_closed_house(kit, block, "House21", Vector3(-18, 0, 22), Vector3(12, 3.2, 12), "siding")
	_closed_house(kit, block, "House25", Vector3(12, 0, 22), Vector3(14, 3.2, 12), "brick")
	kit.fence(block, "HedgeWest", Vector3(-20, 0, -6), Vector3(-20, 0, -20), 1.2)
	kit.fence(block, "HedgeEast", Vector3(20, 0, -6), Vector3(20, 0, -20), 1.2)
	kit.jersey_barrier(block, "Mailbox", Vector3(-2.5, 0, -1.6), 90.0)
	kit.barrel(block, "TrashCan1", Vector3(14.5, 0, -2.5), "container_green")
	kit.barrel(block, "TrashCan2", Vector3(15.3, 0, -2.5), "container_green")


static func _lights(kit: LevelKit, lights: Node3D) -> void:
	for i: int in 4:
		var x: float = -36.0 + i * 24.0
		kit.street_lamp(lights, "LampNorth%d" % i, Vector3(x, 0, -2.2), 180.0, 6.5, 12.0)
		kit.light_zone(lights, "LitNorth%d" % i, Vector3(x, 1.5, 2), Vector3(12, 3, 10))
	for i: int in 3:
		var x: float = -24.0 + i * 24.0
		kit.street_lamp(lights, "LampSouth%d" % i, Vector3(x, 0, 12.2), 0.0, 6.5, 12.0)
	kit.bulkhead(lights, "PorchLight", Vector3(0, 2.4, -5.85), 0.0, 1.8, 7.0)
	kit.bulkhead(lights, "GarageLight", Vector3(10, 2.7, -5.85), 0.0, 1.5, 7.0, false)
	kit.bulkhead(lights, "YardLight", Vector3(-2, 2.4, -20.15), 180.0, 1.6, 9.0)
	kit.ceiling_panel(lights, "LivingRoomLamp", Vector3(-3, WALL_H, -9.5), true, 2.6, 7.0)
	kit.ceiling_panel(lights, "HallLamp", Vector3(2, WALL_H, -11.5), true, 1.6, 6.0, false)
	kit.ceiling_panel(lights, "KitchenLamp", Vector3(-3.5, WALL_H, -16.5), true, 2.2, 6.5, false)
	kit.ceiling_panel(lights, "BedroomLamp", Vector3(4.5, WALL_H, -16.5), true, 1.4, 6.0, false)
	kit.pendant_lamp(lights, "GaragePendant", Vector3(10, WALL_H, -13), 0.9, 2.2, 7.0)
	kit.light_zone(lights, "LitLiving", Vector3(-3, 1.5, -9.5), Vector3(8, 3, 6))


static func _enemies(kit: LevelKit, root: Node3D, navigation: MissionNavigation) -> void:
	var squad_house: AISquad = AISquad.new()
	kit.own(squad_house, root, "SquadHouse")
	var squad_street: AISquad = AISquad.new()
	kit.own(squad_street, root, "SquadStreet")
	kit.group(root, "Enemies")
	var patrol: Node3D = kit.group(root, "PatrolYard")
	for p: Vector3 in [Vector3(-5, 0, -26), Vector3(8, 0, -26), Vector3(8, 0, -14), Vector3(-2, 0, -22)]:
		kit.marker(patrol, "P%d" % patrol.get_child_count(), p)

	var points: Node3D = kit.group(root, "EnemySpawnPoints")
	var plan: Array = [
		# Prank callers hiding at home.
		["Prankster", "prankster", Vector3(-3, 0.1, -9.5), "SquadHouse", "", [&"arrest"]],
		["PranksterFriend", "prankster", Vector3(4, 0.1, -16), "SquadHouse", "", [&"arrest"]],
		# Armed occupants for a genuine call.
		["Occupant", "thug", Vector3(-2, 0.1, -15.5), "SquadHouse", "", [&"raid"]],
		["OccupantGarage", "thug", Vector3(11, 0.1, -15), "SquadHouse", "", [&"raid"]],
		["OccupantYard", "cultist_gunman", Vector3(0, 0.1, -27), "SquadHouse", "PatrolYard", [&"raid"]],
		# The ambush: the house is bait, gunmen wait in the garage, the yard and across the street.
		["AmbushLeader", "ambush_leader", Vector3(3, 0.1, -17), "SquadHouse", "", [&"ambush"]],
		["AmbushLiving", "cultist_gunman", Vector3(-5, 0.1, -8), "SquadHouse", "", [&"ambush"]],
		["AmbushGarage", "cultist_gunman", Vector3(12, 0.1, -12), "SquadHouse", "", [&"ambush"]],
		["AmbushYard", "cultist_gunman", Vector3(-6, 0.1, -28), "SquadHouse", "PatrolYard", [&"ambush"]],
		["AmbushAcross1", "cultist_gunman", Vector3(-10, 0.1, 15), "SquadStreet", "", [&"ambush"]],
		["AmbushAcross2", "cultist_gunman", Vector3(4, 0.1, 15.5), "SquadStreet", "", [&"ambush"]],
		["AmbushZealot", "zealot", Vector3(18, 0.1, -9), "SquadStreet", "", [&"ambush"]],
	]
	for entry: Array in plan:
		var point: EnemySpawnPoint = EnemySpawnPoint.new()
		var point_name: String = entry[0]
		kit.own(point, points, point_name)
		var at: Vector3 = entry[2]
		point.position = at
		point.archetype = load("res://data/ai/archetypes/%s.tres" % entry[1]) as ArchetypeData
		point.squad = NodePath("../../%s" % entry[3])
		var route: String = entry[4]
		if route != "":
			point.patrol_route = NodePath("../../%s" % route)
		var kinds: Array[StringName] = []
		for kind: StringName in entry[5]:
			kinds.append(kind)
		point.mission_kinds = kinds

	var spawner: EnemySpawner = EnemySpawner.new()
	kit.own(spawner, root, "EnemySpawner")
	spawner.spawn_path = NodePath("../Enemies")
	spawner.spawn_points = points
	spawner.navigation = navigation
