## Builds res://scenes/field/missions/warehouse_raid.tscn — the "Harbor Warehouse" response: a fenced night
## yard of shipping containers around a two-storey warehouse (shelving aisles, office, loading doors),
## two AI squads with patrols, lit zones for AI perception, and the police van extraction point.
## Run through tools/level_kit/build_levels.tscn.
## Authority: TOOLS
class_name BuildWarehouseRaid
extends RefCounted

const PATH: String = "res://scenes/field/missions/warehouse_raid.tscn"
const ROOF: float = 8.0


static func build() -> Error:
	var root: Node3D = Node3D.new()
	root.name = "WarehouseRaid"
	var kit: LevelKit = LevelKit.new(root)
	kit.environment(root, 0.01, 0.2, true, 1.8)
	kit.moonlight(root, 0.32)

	var navigation: MissionNavigation = MissionNavigation.new()
	kit.own(navigation, root, "Navigation")
	_yard(kit, navigation)
	_warehouse(kit, navigation)

	var lights: Node3D = kit.group(root, "Lighting")
	_lights(kit, lights)

	# Extraction van + spawns.
	var extraction: Node3D = kit.group(root, "Extraction", Vector3(0, 0, 27))
	kit.cruiser(extraction, "PoliceVan", Vector3(0, 0, 2.5), 180.0, true)
	kit.cruiser(extraction, "Cruiser", Vector3(-5, 0, 3.5), 160.0)
	var sign: Label3D = kit.own(Label3D.new(), extraction, "Sign") as Label3D
	sign.text = "EXTRACTION"
	sign.font_size = 40
	sign.pixel_size = 0.008
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color(0.95, 0.75, 0.3)
	sign.position = Vector3(0, 3.3, 2.5)
	kit.group(root, "Players")
	var spawns: Node3D = kit.group(root, "SpawnPoints")
	for i: int in 4:
		kit.marker(spawns, "Spawn%d" % (i + 1), Vector3(-3.0 + i * 2.0, 0.05, 19.5), 0.0)
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


static func _yard(kit: LevelKit, parent: Node3D) -> void:
	var yard: Node3D = kit.group(parent, "Yard")
	kit.box(yard, "Ground", Vector3(0, -0.15, 2), Vector3(84, 0.2, 76), kit.material("asphalt"))
	# Perimeter with the south gate open.
	kit.fence(yard, "FenceWest", Vector3(-38, 0, -36), Vector3(-38, 0, 36))
	kit.fence(yard, "FenceEast", Vector3(38, 0, -36), Vector3(38, 0, 36))
	kit.fence(yard, "FenceNorth", Vector3(-38, 0, -36), Vector3(38, 0, -36))
	kit.fence(yard, "FenceSouthW", Vector3(-38, 0, 36), Vector3(-7, 0, 36))
	kit.fence(yard, "FenceSouthE", Vector3(7, 0, 36), Vector3(38, 0, 36))
	# Container stacks — the main cover in the yard.
	kit.container(yard, "ContainerW1", Vector3(-27, 0, -1), 0.0, "container_blue")
	kit.container(yard, "ContainerW1Top", Vector3(-27, 2.59, -1), 0.0, "container_green")
	kit.container(yard, "ContainerW2", Vector3(-19, 0, 8), 90.0, "container_green")
	kit.container(yard, "ContainerW3", Vector3(-30, 0, 14), 12.0, "rust_red")
	kit.container(yard, "ContainerE1", Vector3(15, 0, 5), 0.0, "rust_red")
	kit.container(yard, "ContainerE2", Vector3(23, 0, -2), 90.0, "container_blue")
	kit.container(yard, "ContainerE2Top", Vector3(23, 2.59, -2), 90.0, "rust_red")
	kit.container(yard, "ContainerE3", Vector3(27, 0, 12), 0.0, "container_green")
	# The suspects' box truck parked in front of the loading doors.
	var truck: Node3D = kit.group(yard, "BoxTruck", Vector3(-4, 0, 3))
	truck.rotation_degrees.y = 18.0
	kit.box(truck, "Cargo", Vector3(0, 1.75, 1.0), Vector3(2.4, 2.6, 5.2), kit.material("paper_board"))
	kit.box(truck, "Cab", Vector3(0, 1.2, -2.55), Vector3(2.3, 1.9, 1.9), kit.material("car_white"))
	kit.box(truck, "Chassis", Vector3(0, 0.45, -0.4), Vector3(2.2, 0.3, 7.2), kit.material("metal_dark"))
	for z: float in [-2.6, 1.0, 2.6]:
		for x: float in [-1.0, 1.0]:
			var wheel: CylinderMesh = CylinderMesh.new()
			wheel.top_radius = 0.45
			wheel.bottom_radius = 0.45
			wheel.height = 0.3
			kit.mesh(truck, "Wheel%d%d" % [int(z * 10 + 30), int(x + 1)], wheel, Vector3(x * 1.05, 0.45, z), kit.material("rubber"), Vector3(0, 0, 90))
	# Low cover.
	kit.jersey_barrier(yard, "BarrierGate1", Vector3(-9, 0, 30), 90.0)
	kit.jersey_barrier(yard, "BarrierGate2", Vector3(9, 0, 29), 75.0)
	kit.jersey_barrier(yard, "BarrierMid", Vector3(4, 0, 14), 0.0)
	kit.jersey_barrier(yard, "BarrierMid2", Vector3(-12, 0, 18), 90.0)
	kit.crate_stack(yard, "Pallets1", Vector3(7, 0, -3), 10.0, 2)
	kit.crate_stack(yard, "Pallets2", Vector3(-13, 0, -2), -5.0, 1)
	kit.crate_stack(yard, "Pallets3", Vector3(18, 0, 16), 30.0, 2)
	kit.crate_stack(yard, "Pallets4", Vector3(-24, 0, 22), 0.0, 1)
	for i: int in 4:
		kit.barrel(yard, "Barrel%d" % i, Vector3(10.5 + (i % 2) * 0.7, 0, -4.5 + (i / 2) * 0.7), "rust_red" if i % 3 else "container_blue")
	# Loading dock apron.
	kit.box(yard, "DockApron", Vector3(0, 0.0, -6.5), Vector3(40, 0.12, 3.0), kit.material("concrete"), 0.0, false)


static func _warehouse(kit: LevelKit, parent: Node3D) -> void:
	var building: Node3D = kit.group(parent, "Warehouse")
	var wall: StandardMaterial3D = kit.material("metal_painted")
	var block: StandardMaterial3D = kit.material("concrete_dark")
	kit.box(building, "Slab", Vector3(0, -0.05, -19), Vector3(40.6, 0.1, 22.6), kit.material("concrete"))
	kit.box(building, "Roof", Vector3(0, ROOF + 0.15, -19), Vector3(41, 0.3, 23), kit.material("metal_dark"), 0.0, false)
	# South facade: roll-up loading door, personnel door, clerestory windows.
	kit.wall(building, "WallSouth", Vector3(-20, 0, -8), Vector3(20, 0, -8), ROOF, 0.3, wall,
		[[8.0, 6.0, 0.0, 4.6], [20.0, 1.4, 0.0, 2.3], [26.0, 8.0, 5.0, 6.4]])
	kit.box(building, "SouthWindows", Vector3(10, 5.7, -8), Vector3(8, 1.4, 0.04), kit.material("glass_dark"))
	kit.wall(building, "WallNorth", Vector3(-20, 0, -30), Vector3(20, 0, -30), ROOF, 0.3, wall, [[25.0, 4.0, 0.0, 3.4]])
	kit.wall(building, "WallWest", Vector3(-20, 0, -30), Vector3(-20, 0, -8), ROOF, 0.3, wall, [[6.0, 6.0, 5.0, 6.4]])
	kit.box(building, "WestWindows", Vector3(-20, 5.7, -21), Vector3(0.04, 1.4, 6), kit.material("glass_dark"))
	kit.wall(building, "WallEast", Vector3(20, 0, -30), Vector3(20, 0, -8), ROOF, 0.3, wall, [[10.0, 1.6, 0.0, 2.3]])
	# Concrete plinth wall band.
	kit.box(building, "PlinthSouthW", Vector3(-13.9, 0.6, -7.8), Vector3(12.2, 1.2, 0.1), block, 0.0, false)
	kit.box(building, "PlinthSouthE", Vector3(9, 0.6, -7.8), Vector3(22, 1.2, 0.1), block, 0.0, false)

	# Shelving aisles (steel racks loaded with crates) — long sightlines broken into lanes.
	for row: int in 3:
		var z: float = -26.0 + row * 4.6
		var rack: Node3D = kit.group(building, "Rack%d" % row, Vector3(-9, 0, z))
		kit.collider(rack, "Frame", Vector3(0, 1.6, 0), Vector3(11, 3.2, 1.1))
		for post: int in 5:
			for side: float in [-0.52, 0.52]:
				kit.box(rack, "Post%d%d" % [post, int(side > 0)], Vector3(-5.4 + post * 2.7, 1.6, side), Vector3(0.08, 3.2, 0.08), kit.material("steel"), 0.0, false)
		for level: int in 3:
			kit.box(rack, "Shelf%d" % level, Vector3(0, 0.1 + level * 1.1, 0), Vector3(11.2, 0.06, 1.2), kit.material("hazard_yellow"), 0.0, false)
			for slot: int in 4:
				if (row + level + slot) % 3 == 0:
					continue
				kit.box(rack, "Box%d%d" % [level, slot], Vector3(-4.0 + slot * 2.6, 0.55 + level * 1.1, 0), Vector3(1.6, 0.8, 0.9), kit.material("cardboard" if slot % 2 else "wood"), 0.0, false)
	# Open floor: forklift, pallets, a meat-packing cold room silhouette.
	var forklift: Node3D = kit.group(building, "Forklift", Vector3(4, 0, -15))
	forklift.rotation_degrees.y = -30.0
	kit.box(forklift, "Body", Vector3(0, 0.8, 0), Vector3(1.2, 1.2, 2.2), kit.material("hazard_yellow"))
	kit.box(forklift, "Mast", Vector3(0, 1.6, -1.2), Vector3(0.9, 3.0, 0.15), kit.material("metal_dark"), 0.0, false)
	kit.box(forklift, "Guard", Vector3(0, 2.1, 0.2), Vector3(1.1, 0.06, 1.3), kit.material("metal_dark"), 0.0, false)
	kit.crate_stack(building, "FloorPallet1", Vector3(8, 0, -22), 0.0, 2)
	kit.crate_stack(building, "FloorPallet2", Vector3(1, 0, -26), 15.0, 1)
	kit.crate_stack(building, "FloorPallet3", Vector3(-2, 0, -11), -10.0, 2)
	kit.box(building, "ColdRoom", Vector3(4, 1.6, -27.4), Vector3(6, 3.2, 4.6), kit.material("steel"))
	# Office in the north-east corner.
	var office: Node3D = kit.group(building, "Office")
	var office_wall: StandardMaterial3D = kit.material("plaster")
	kit.wall(office, "WallWest", Vector3(12, 0, -30), Vector3(12, 0, -22), 3.2, 0.2, office_wall, [[5.0, 1.2, 0.0, 2.3]])
	kit.wall(office, "WallSouth", Vector3(12, 0, -22), Vector3(20, 0, -22), 3.2, 0.2, office_wall, [[2.0, 3.0, 1.1, 2.3]])
	kit.box(office, "OfficeWindow", Vector3(15.5, 1.7, -22), Vector3(3.0, 1.2, 0.04), kit.material("glass_dark"))
	kit.box(office, "Ceiling", Vector3(16, 3.3, -26), Vector3(8.2, 0.2, 8.2), kit.material("ceiling_tile"))
	kit.desk(office, "Desk", Vector3(16.5, 0, -27.5), 180.0, 1, "screen_amber")
	kit.locker_row(office, "Files", Vector3(19.4, 0, -25), -90.0, 3)


static func _lights(kit: LevelKit, lights: Node3D) -> void:
	# Yard: sodium street lamps on the perimeter pointing inwards, plus lit zones for AI perception.
	kit.street_lamp(lights, "LampWest1", Vector3(-35, 0, 20), -90.0)
	kit.street_lamp(lights, "LampWest2", Vector3(-35, 0, -2), -90.0)
	kit.street_lamp(lights, "LampEast1", Vector3(35, 0, 18), 90.0)
	kit.street_lamp(lights, "LampEast2", Vector3(35, 0, -4), 90.0)
	kit.street_lamp(lights, "LampGate", Vector3(10, 0, 34), 0.0)
	# Roof floodlights wash the yard; the middle stays in half-light between the pools.
	kit.floodlight(lights, "FloodWest", Vector3(-15, 7.4, -7.8), 180.0, 30.0)
	kit.floodlight(lights, "FloodEast", Vector3(15, 7.4, -7.8), 180.0, 30.0)
	kit.street_lamp(lights, "LampYard", Vector3(2, 0, 18), 180.0)
	kit.light_zone(lights, "LitYardCenter", Vector3(2, 1.5, 21), Vector3(10, 3, 10))
	kit.light_zone(lights, "LitWest", Vector3(-31, 1.5, 20), Vector3(10, 3, 10))
	kit.light_zone(lights, "LitEast", Vector3(31, 1.5, 18), Vector3(10, 3, 10))
	kit.light_zone(lights, "LitGate", Vector3(10, 1.5, 30), Vector3(10, 3, 8))
	kit.light_zone(lights, "LitDock", Vector3(-9, 1.5, -5), Vector3(12, 3, 6))
	# Warehouse facade bulkheads.
	kit.bulkhead(lights, "DockLamp", Vector3(-9, 5.2, -7.82), 0.0, 3.0, 12.0)
	kit.bulkhead(lights, "DoorLamp", Vector3(0.7, 2.8, -7.82), 0.0, 1.6, 7.0)
	kit.bulkhead(lights, "EastDoorLamp", Vector3(20.18, 2.8, -19.2), 90.0, 1.4, 7.0, false)
	# Interior: industrial pendants; two dead fixtures leave dark pockets for flanking.
	var interior: Array = [[-14, -24], [-4, -24], [6, -24], [-14, -14], [-4, -14], [6, -14]]
	for i: int in interior.size():
		if i == 2 or i == 3:
			continue
		var spot: Array = interior[i]
		var x: float = spot[0]
		var z: float = spot[1]
		kit.pendant_lamp(lights, "Pendant%d" % i, Vector3(x, ROOF, z), 2.6, 5.0, 12.0)
	kit.light_zone(lights, "LitAisles", Vector3(-9, 1.5, -20), Vector3(14, 3, 14))
	kit.ceiling_panel(lights, "OfficePanel", Vector3(16, 3.2, -26), true, 1.4, 5.0)


static func _enemies(kit: LevelKit, root: Node3D, navigation: MissionNavigation) -> void:
	var squad_yard: AISquad = AISquad.new()
	kit.own(squad_yard, root, "SquadYard")
	var squad_warehouse: AISquad = AISquad.new()
	kit.own(squad_warehouse, root, "SquadWarehouse")
	kit.group(root, "Enemies")
	var patrol: Node3D = kit.group(root, "PatrolYard")
	for p: Vector3 in [Vector3(-12, 0, 10), Vector3(9, 0, 11), Vector3(12, 0, -3), Vector3(-10, 0, -3)]:
		kit.marker(patrol, "P%d" % patrol.get_child_count(), p)
	var patrol_inside: Node3D = kit.group(root, "PatrolWarehouse")
	for p: Vector3 in [Vector3(-2, 0, -12), Vector3(-2, 0, -28), Vector3(10, 0, -19)]:
		kit.marker(patrol_inside, "P%d" % patrol_inside.get_child_count(), p)

	var points: Node3D = kit.group(root, "EnemySpawnPoints")
	var plan: Array = [
		["YardThug", "thug", Vector3(-12, 0, 9), "SquadYard", "PatrolYard"],
		["YardGunman1", "cultist_gunman", Vector3(-22, 0, 2), "SquadYard", ""],
		["YardGunman2", "cultist_gunman", Vector3(17, 0, 10), "SquadYard", ""],
		["YardThug2", "thug", Vector3(19, 0, -6), "SquadYard", ""],
		["DockGunman", "cultist_gunman", Vector3(-9, 0, -10), "SquadWarehouse", "PatrolWarehouse"],
		["AisleZealot", "zealot", Vector3(-4, 0, -21), "SquadWarehouse", ""],
		["Leader", "ambush_leader", Vector3(2, 0, -24), "SquadWarehouse", ""],
		["AisleGunman", "cultist_gunman", Vector3(-15, 0, -18), "SquadWarehouse", ""],
		["OfficeGunman", "cultist_gunman", Vector3(16, 0, -25), "SquadWarehouse", ""],
		["AmbushRoof", "cultist_gunman", Vector3(-26, 0, 6), "SquadYard", "", [&"ambush"]],
		["AmbushContainers", "cultist_gunman", Vector3(25, 0, 6), "SquadYard", "", [&"ambush"]],
		["AmbushZealot", "zealot", Vector3(-6, 0, -16), "SquadWarehouse", "", [&"ambush"]],
		["AmbushDock", "thug", Vector3(8, 0, -9.5), "SquadWarehouse", "", [&"ambush"]],
		["SquatterOffice", "prankster", Vector3(16, 0, -26), "SquadWarehouse", "", [&"arrest"]],
		["SquatterAisle", "prankster", Vector3(-12, 0, -23.5), "SquadWarehouse", "", [&"arrest"]],
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
		if entry.size() > 5:
			var kinds: Array[StringName] = []
			for kind: StringName in entry[5]:
				kinds.append(kind)
			point.mission_kinds = kinds

	var spawner: EnemySpawner = EnemySpawner.new()
	kit.own(spawner, root, "EnemySpawner")
	spawner.spawn_path = NodePath("../Enemies")
	spawner.spawn_points = points
	spawner.navigation = navigation
