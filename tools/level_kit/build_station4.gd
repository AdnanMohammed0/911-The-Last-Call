## Builds res://scenes/dispatch/operations_room.tscn — Blackvale County 911, Station 4:
## operations room (dispatch desks, servers, supervisor office), security corridor, armory (weapon racks,
## vest lockers, ammo, briefing table, garage deploy door) and the parking lot.
## Keeps the node contract other systems rely on (Geometry/*, SpawnPoints/Spawn*_<Class>, Doors/*,
## DispatchSetup, Players, PlayerSpawner). Run through tools/level_kit/build_levels.tscn.
## Authority: TOOLS
class_name BuildStation4
extends RefCounted

const PATH: String = "res://scenes/dispatch/operations_room.tscn"
const HEIGHT: float = 3.4


static func build() -> Error:
	var root: Node3D = Node3D.new()
	root.name = "Station4_OperationsRoom"
	var kit: LevelKit = LevelKit.new(root)
	kit.environment(root, 0.008, 0.16, true, 1.5)
	kit.moonlight(root, 0.3)

	var geometry: Node3D = kit.group(root, "Geometry")
	_operations_room(kit, kit.group(geometry, "OperationsRoom"))
	_corridor(kit, kit.group(geometry, "SecurityCorridor"))
	_armory(kit, kit.group(geometry, "Armory"))
	_parking(kit, kit.group(geometry, "ParkingLot"))

	var doors: Node3D = kit.group(root, "Doors")
	var door_scene: String = "res://scenes/shared/door/door.tscn"
	kit.instance(door_scene, doors, "Door_OpsToCorridor", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-2, 0, 0)))
	kit.instance(door_scene, doors, "Door_CorridorToArmory", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(2, 0, -1)))
	kit.instance(door_scene, doors, "Door_CorridorToParking", Transform3D(Basis.IDENTITY, Vector3(0, 0, 10)))

	var labels: Node3D = kit.group(root, "Labels3D")
	_label(kit, labels, "LabelOpsDoor", "OPERATIONS", Vector3(-1.78, 2.75, 0), 90.0, 22)
	_label(kit, labels, "LabelArmoryDoor", "ARMORY", Vector3(1.78, 2.75, -1), -90.0, 22)
	_label(kit, labels, "LabelParkingDoor", "SALLY PORT", Vector3(0, 2.75, 9.78), 180.0, 22)
	_label(kit, labels, "LabelSignStation", "BLACKVALE COUNTY 911  ·  STATION 4", Vector3(0, 3.1, 10.25), 0.0, 34)
	_label(kit, labels, "LabelDeploy", "GARAGE  ·  DEPLOY", Vector3(13.7, 3.05, -1), -90.0, 26)

	kit.instance("res://scenes/dispatch/dispatch_setup.tscn", root, "DispatchSetup", Transform3D.IDENTITY)
	kit.group(root, "Players")
	var spawns: Node3D = kit.group(root, "SpawnPoints")
	kit.marker(spawns, "Spawn1_Tech", Vector3(-14, 0.05, -0.6), 0.0)
	kit.marker(spawns, "Spawn2_Profiler", Vector3(-10, 0.05, -0.6), 0.0)
	kit.marker(spawns, "Spawn3_Breacher", Vector3(-14, 0.05, 0.6), 180.0)
	kit.marker(spawns, "Spawn4_Medic", Vector3(-10, 0.05, 0.6), 180.0)
	var spawner: PlayerSpawner = PlayerSpawner.new()
	kit.own(spawner, root, "PlayerSpawner")
	spawner.spawn_path = NodePath("../Players")
	spawner.spawn_points = spawns

	var scene: PackedScene = PackedScene.new()
	var err: Error = scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, PATH)
	root.free()
	return err


static func _label(kit: LevelKit, parent: Node, node_name: String, text: String, at: Vector3, yaw_deg: float, size: int) -> void:
	var label: Label3D = kit.own(Label3D.new(), parent, node_name) as Label3D
	label.text = text
	label.font_size = size
	label.pixel_size = 0.006
	label.outline_size = 0
	label.modulate = Color(0.86, 0.88, 0.9)
	label.position = at
	label.rotation_degrees.y = yaw_deg


static func _floor_and_roof(kit: LevelKit, parent: Node, center_x: float, center_z: float, size_x: float, size_z: float, floor_key: String) -> void:
	kit.box(parent, "Floor", Vector3(center_x, -0.1, center_z), Vector3(size_x, 0.2, size_z), kit.material(floor_key))
	kit.box(parent, "Ceiling", Vector3(center_x, HEIGHT + 0.1, center_z), Vector3(size_x, 0.2, size_z), kit.material("ceiling_tile"))


static func _operations_room(kit: LevelKit, room: Node3D) -> void:
	_floor_and_roof(kit, room, -10, 0, 16.4, 12.4, "carpet")
	var wall: StandardMaterial3D = kit.material("plaster_blue")
	kit.wall(room, "WallWest", Vector3(-18, 0, -6), Vector3(-18, 0, 6), HEIGHT, 0.3, wall)
	kit.wall(room, "WallNorth", Vector3(-18, 0, -6), Vector3(-2, 0, -6), HEIGHT, 0.3, wall)
	# South wall looks out over the lot through three tall windows.
	kit.wall(room, "WallSouth", Vector3(-18, 0, 6), Vector3(-2, 0, 6), HEIGHT, 0.3, wall,
		[[2.0, 2.4, 1.0, 2.5], [6.8, 2.4, 1.0, 2.5], [11.6, 2.4, 1.0, 2.5]])
	for i: int in 3:
		kit.box(room, "Window%d" % i, Vector3(-18 + 3.2 + i * 4.8, 1.75, 6), Vector3(2.4, 1.5, 0.04), kit.material("glass_dark"))
	kit.wall(room, "WallEast", Vector3(-2, 0, -6), Vector3(-2, 0, 6), HEIGHT, 0.3, wall, [[4.9, 2.2, 0.0, 2.4]])
	# Baseboards.
	kit.box(room, "BaseNorth", Vector3(-10, 0.06, -5.83), Vector3(16, 0.12, 0.04), kit.material("rubber"), 0.0, false)
	kit.box(room, "BaseWest", Vector3(-17.83, 0.06, 0), Vector3(0.04, 0.12, 12), kit.material("rubber"), 0.0, false)

	# Dispatch floor: four consoles in two rows facing each other (DispatchSetup holds the terminals).
	kit.desk(room, "DeskTech", Vector3(-14, 0, -2), 0.0, 2)
	kit.desk(room, "DeskProfiler", Vector3(-10, 0, -2), 0.0, 2, "screen_amber")
	kit.desk(room, "DeskBreacher", Vector3(-14, 0, 2), 180.0, 1)
	kit.desk(room, "DeskMedic", Vector3(-10, 0, 2), 180.0, 2)
	kit.box(room, "DeskBreacher_TacMap", Vector3(-14, 0.8, 2), Vector3(1.6, 0.02, 0.9), kit.material("screen_blue"), 0.0, false)

	# Supervisor office behind a glass partition.
	kit.box(room, "SupervisorPartition", Vector3(-5.5, 1.7, -4.1), Vector3(0.08, 3.4, 3.8), kit.material("glass_dark"))
	kit.box(room, "PartitionFrame", Vector3(-5.5, 0.5, -4.1), Vector3(0.12, 1.0, 3.8), kit.material("metal_painted"))
	kit.desk(room, "SupervisorDesk", Vector3(-3.8, 0, -4.5), 0.0, 1)

	for i: int in 3:
		kit.server_rack(room, "ServerRack%d" % (i + 1), Vector3(-17.4, 0, -3 + i * 3), 0.0)
	# County map wall (dim emissive) and a paper case board.
	var map_board: Node3D = kit.box(room, "CountyWallMap", Vector3(-11, 1.9, -5.8), Vector3(7, 2.0, 0.06), kit.material("screen_map"), 0.0, false)
	(map_board.get_node("Mesh") as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	kit.box(room, "CaseBoard", Vector3(-11, 1.7, 5.8), Vector3(4.2, 1.4, 0.05), kit.material("paper_board"), 0.0, false)

	var lights: Node3D = kit.group(room, "Lighting")
	kit.ceiling_panel(lights, "PanelTech", Vector3(-14, HEIGHT, -2), false, 2.2, 6.5)
	kit.ceiling_panel(lights, "PanelProfiler", Vector3(-10, HEIGHT, -2), false, 2.2, 6.5)
	kit.ceiling_panel(lights, "PanelBreacher", Vector3(-14, HEIGHT, 2), false, 2.2, 6.5)
	kit.ceiling_panel(lights, "PanelMedic", Vector3(-10, HEIGHT, 2), false, 2.2, 6.5)
	kit.ceiling_panel(lights, "PanelSupervisor", Vector3(-3.8, HEIGHT, -3.8), true, 1.6, 6.0)
	kit.ceiling_panel(lights, "PanelServers", Vector3(-16.4, HEIGHT, 0), false, 1.4, 5.5, false)
	kit.ceiling_panel(lights, "PanelEntry", Vector3(-5, HEIGHT, 2.5), false, 1.6, 5.5, false)


static func _corridor(kit: LevelKit, corridor: Node3D) -> void:
	_floor_and_roof(kit, corridor, 0, 2, 3.7, 16.4, "vinyl_floor")
	var wall: StandardMaterial3D = kit.material("plaster")
	kit.wall(corridor, "WallNorth", Vector3(-2, 0, -6), Vector3(2, 0, -6), HEIGHT, 0.3, wall)
	kit.wall(corridor, "WallEast", Vector3(2, 0, -6), Vector3(2, 0, 10), HEIGHT, 0.3, wall, [[3.9, 2.2, 0.0, 2.4]])
	kit.wall(corridor, "WallWestSouth", Vector3(-2, 0, 6), Vector3(-2, 0, 10), HEIGHT, 0.3, wall)
	kit.wall(corridor, "WallSouth", Vector3(-2, 0, 10), Vector3(2, 0, 10), HEIGHT, 0.3, wall, [[0.9, 2.2, 0.0, 2.4]])
	kit.box(corridor, "BreakerPanelBox", Vector3(-1.8, 1.5, 5), Vector3(0.12, 0.8, 0.55), kit.material("metal_painted"))
	kit.box(corridor, "Bench", Vector3(-1.6, 0.25, 7.5), Vector3(0.5, 0.5, 1.8), kit.material("metal_dark"))
	var lights: Node3D = kit.group(corridor, "Lighting")
	kit.ceiling_panel(lights, "PanelNorth", Vector3(0, HEIGHT, -3), true, 1.0, 5.0)
	kit.ceiling_panel(lights, "PanelMid", Vector3(0, HEIGHT, 2.5), true, 0.7, 5.0, false)
	kit.ceiling_panel(lights, "PanelSouth", Vector3(0, HEIGHT, 7.5), true, 1.0, 5.0)


static func _armory(kit: LevelKit, armory: Node3D) -> void:
	_floor_and_roof(kit, armory, 8, -1, 12.4, 10.4, "concrete")
	var wall: StandardMaterial3D = kit.material("concrete_dark")
	kit.wall(armory, "WallNorth", Vector3(2, 0, -6), Vector3(14, 0, -6), HEIGHT, 0.3, wall)
	kit.wall(armory, "WallSouth", Vector3(2, 0, 4), Vector3(14, 0, 4), HEIGHT, 0.3, wall)
	kit.wall(armory, "WallEast", Vector3(14, 0, -6), Vector3(14, 0, 4), HEIGHT, 0.3, wall, [[3.1, 3.8, 0.0, 3.0]])
	kit.box(armory, "HazardStripe", Vector3(13.2, 0.005, -1), Vector3(1.2, 0.01, 3.8), kit.material("hazard_yellow"), 0.0, false)

	# Weapon wall: steel backboard with racked rifles, shotguns and SMGs.
	kit.box(armory, "WeaponRackBoard", Vector3(8, 1.55, -5.78), Vector3(9.0, 2.0, 0.08), kit.material("metal_painted"), 0.0, false)
	var racks: Array = [[&"rifle", 4.6], [&"rifle", 6.3], [&"shotgun", 8.0], [&"shotgun", 9.7], [&"smg", 11.4]]
	var index: int = 0
	for rack: Array in racks:
		var item: ArmoryItem = ArmoryItem.new()
		item.kind = ArmoryItem.Kind.WEAPON
		item.weapon_id = rack[0]
		kit.own(item, armory, "WeaponRack_%s_%d" % [rack[0], index])
		var x: float = rack[1]
		item.position = Vector3(x, 1.45, -5.55)
		index += 1
	# Vest lockers along the south wall.
	kit.locker_row(armory, "Lockers", Vector3(6.5, 0, 3.55), 180.0, 7)
	for i: int in 2:
		var vest: ArmoryItem = ArmoryItem.new()
		vest.kind = ArmoryItem.Kind.ARMOR
		kit.own(vest, armory, "ArmorLocker%d" % i)
		vest.position = Vector3(5.2 + i * 2.6, 1.3, 3.05)
	# Ammunition.
	kit.crate_stack(armory, "AmmoCratesStack", Vector3(12.4, 0, 2.6), 0.0, 2)
	var ammo: ArmoryItem = ArmoryItem.new()
	ammo.kind = ArmoryItem.Kind.AMMO
	kit.own(ammo, armory, "AmmoCrate")
	ammo.position = Vector3(10.6, 0.25, 2.9)
	kit.box(armory, "AmmoTable", Vector3(10.6, 0.0, 2.9), Vector3(1.0, 0.02, 0.6), kit.material("metal_dark"), 0.0, false)

	# Briefing table with the tactical projection.
	kit.box(armory, "TacticalBriefingTable", Vector3(8, 0.45, -1.4), Vector3(3.2, 0.9, 1.8), kit.material("metal_dark"))
	kit.box(armory, "TableProjectorSurface", Vector3(8, 0.91, -1.4), Vector3(2.9, 0.02, 1.5), kit.material("screen_map"), 0.0, false)

	# Garage roll-up door: the deploy point.
	var garage: Node3D = kit.group(armory, "GarageDoor", Vector3(14, 0, -1))
	kit.box(garage, "Shutter", Vector3(0, 1.5, 0), Vector3(0.12, 3.0, 3.8), kit.material("metal_painted"))
	for i: int in 10:
		var slat: BoxMesh = BoxMesh.new()
		slat.size = Vector3(0.14, 0.04, 3.8)
		kit.mesh(garage, "Slat%d" % i, slat, Vector3(-0.01, 0.15 + i * 0.3, 0), kit.material("metal_dark"))
	var deploy: DeployDoor = DeployDoor.new()
	deploy.prompt_text = "Deploy"
	kit.own(deploy, garage, "DeployDoor")
	deploy.position = Vector3(-0.4, 1.4, 0)
	var deploy_shape: CollisionShape3D = kit.own(CollisionShape3D.new(), deploy, "Shape") as CollisionShape3D
	var deploy_box: BoxShape3D = BoxShape3D.new()
	deploy_box.size = Vector3(0.5, 2.6, 3.6)
	deploy_shape.shape = deploy_box
	var status: OmniLight3D = kit.own(OmniLight3D.new(), deploy, "StatusLight") as OmniLight3D
	status.position = Vector3(0, 1.75, 0)
	status.light_color = Color(1.0, 0.25, 0.2)
	status.light_energy = 1.5
	status.omni_range = 3.5
	var beacon: SphereMesh = SphereMesh.new()
	beacon.radius = 0.09
	beacon.height = 0.18
	kit.mesh(deploy, "Beacon", beacon, Vector3(0.1, 1.75, 0), kit.material("led_red"), Vector3.ZERO, false)

	var lights: Node3D = kit.group(armory, "Lighting")
	for row: int in 2:
		for col: int in 3:
			kit.ceiling_panel(lights, "Panel%d%d" % [row, col], Vector3(4.5 + col * 3.5, HEIGHT, -3.5 + row * 4.5), false, 1.8, 6.5, row == 0)


static func _parking(kit: LevelKit, lot: Node3D) -> void:
	kit.box(lot, "AsphaltGround", Vector3(3, -0.15, 12), Vector3(64, 0.2, 58), kit.material("asphalt"))
	kit.box(lot, "Sidewalk", Vector3(-2, 0.02, 11.2), Vector3(32, 0.12, 2.4), kit.material("concrete"))
	kit.box(lot, "RoofStation", Vector3(-2, HEIGHT + 0.35, 2), Vector3(32.6, 0.3, 16.6), kit.material("concrete_dark"), 0.0, false)
	# Parking bay lines.
	for i: int in 6:
		kit.box(lot, "BayLine%d" % i, Vector3(-9 + i * 3.4, 0.0, 19), Vector3(0.1, 0.02, 4.8), kit.material("paper_board"), 0.0, false)
	kit.cruiser(lot, "Cruiser1", Vector3(-7.3, 0, 19), 180.0)
	kit.cruiser(lot, "Cruiser2", Vector3(-3.9, 0, 19), 180.0)
	kit.cruiser(lot, "SWAT_Van", Vector3(8, 0, 20), 180.0, true)
	kit.fence(lot, "FenceSouth", Vector3(-26, 0, 38), Vector3(-4, 0, 38))
	kit.fence(lot, "FenceSouthB", Vector3(6, 0, 38), Vector3(30, 0, 38))
	kit.fence(lot, "FenceEast", Vector3(30, 0, -10), Vector3(30, 0, 38))
	kit.fence(lot, "FenceWest", Vector3(-26, 0, -10), Vector3(-26, 0, 38))
	kit.jersey_barrier(lot, "BarrierGateL", Vector3(-6, 0, 36), 90.0)
	kit.jersey_barrier(lot, "BarrierGateR", Vector3(8, 0, 36), 90.0)
	var lights: Node3D = kit.group(lot, "Lighting")
	kit.street_lamp(lights, "StreetLight1", Vector3(-12, 0, 24), -90.0)
	kit.street_lamp(lights, "StreetLight2", Vector3(18, 0, 24), 90.0)
	kit.street_lamp(lights, "StreetLight3", Vector3(3, 0, 34), 0.0)
	kit.bulkhead(lights, "SallyPortLamp", Vector3(0, 2.9, 10.18), 0.0, 2.2, 8.0)
	kit.bulkhead(lights, "OpsWindowLamp", Vector3(-10, 2.9, 6.18), 0.0, 1.2, 6.0, false)
