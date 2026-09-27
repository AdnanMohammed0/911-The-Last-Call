extends GutTest

const OPS_ROOM_PATH: String = "res://scenes/dispatch/operations_room.tscn"
const ARMORY_PATH: String = "res://scenes/loadout/armory.tscn"


func test_operations_room_scene_loads_and_instantiates() -> void:
	var packed := load(OPS_ROOM_PATH) as PackedScene
	assert_not_null(packed, "Operations room scene file should load")
	if packed == null:
		return

	var instance := packed.instantiate()
	assert_not_null(instance, "Operations room should instantiate")
	if instance == null:
		return
	add_child_autofree(instance)

	# Verify 4 main grey-box zones exist
	var has_ops: bool = instance.get_node_or_null("Geometry/OperationsRoom") != null
	var has_corridor: bool = instance.get_node_or_null("Geometry/SecurityCorridor") != null
	var has_armory: bool = instance.get_node_or_null("Geometry/Armory") != null
	var has_parking: bool = instance.get_node_or_null("Geometry/ParkingLot") != null
	assert_true(has_ops, "Station 4 should contain Operations Room geometry")
	assert_true(has_corridor, "Station 4 should contain Security Corridor geometry")
	assert_true(has_armory, "Station 4 should contain Armory geometry")
	assert_true(has_parking, "Station 4 should contain Parking Lot geometry")

	# Verify 4 player spawn points for 4 classes and their floor height
	var s1: Node3D = instance.get_node_or_null("SpawnPoints/Spawn1_Tech") as Node3D
	var s2: Node3D = instance.get_node_or_null("SpawnPoints/Spawn2_Profiler") as Node3D
	var s3: Node3D = instance.get_node_or_null("SpawnPoints/Spawn3_Breacher") as Node3D
	var s4: Node3D = instance.get_node_or_null("SpawnPoints/Spawn4_Medic") as Node3D
	assert_not_null(s1, "Tech Operator desk spawn")
	assert_not_null(s2, "Profiler desk spawn")
	assert_not_null(s3, "Breacher desk spawn")
	assert_not_null(s4, "Medic desk spawn")
	if s1 != null:
		assert_gt(s1.position.y, 0.25, "Spawn point Y should be above ground floor level")
		assert_gte(s1.position.y, 0.85, "Spawn point Y should be at or above station floor level")
		assert_gt(s1.position.x, 0.0, "Spawn point X should be inside the building")
		assert_lt(s1.position.z, -17.0, "Spawn point Z should be inside the Briefing room")

	# Verify dedicated floor collision exists to prevent player from falling
	var floor_col: StaticBody3D = instance.get_node_or_null("Geometry/OperationsRoom/OperationsRoomFloor") as StaticBody3D
	assert_not_null(floor_col, "Dedicated operations room floor collider should exist to prevent falling")
	var wing_floor: StaticBody3D = instance.get_node_or_null("Geometry/WingSafetyFloor") as StaticBody3D
	assert_not_null(wing_floor, "Station wing safety floor collider should exist")

	# One main dispatch desk with the single main computer (the other desks are bought as workstations)
	assert_not_null(instance.get_node_or_null("Geometry/OperationsRoom/MainDesk"), "MainDesk should exist")
	assert_not_null(instance.get_node_or_null("Geometry/OperationsRoom/MainPhone"), "MainPhone should exist")
	assert_not_null(instance.get_node_or_null("Geometry/OperationsRoom/SupervisorDesk"), "SupervisorDesk should exist")
	assert_not_null(instance.get_node_or_null("Geometry/OperationsRoom/Lighting"), "Dramatic Lighting should exist")
	for removed: String in ["DeskProfiler", "DeskBreacher", "DeskMedic", "LaptopTech", "LaptopSupervisor"]:
		assert_null(instance.get_node_or_null("Geometry/OperationsRoom/" + removed), "%s was replaced by StationMart workstations" % removed)
	var computers: int = 0
	for node: Node in instance.find_children("*", "Area3D", true, false):
		if node is DispatchComputer:
			computers += 1
	assert_eq(computers, 1, "exactly one computer before any workstation is bought")
	assert_not_null(instance.get_node_or_null("DispatchSetup/MainComputer") as DispatchComputer, "the single main computer")
	assert_not_null(instance.get_node_or_null("DispatchSetup/TerminalLayer/StationOS") as StationOS, "Station OS desktop")
	assert_not_null(instance.get_node_or_null("DispatchSetup/TerminalLayer/DispatchTerminal") as DispatchTerminal, "911 CAD app")
	assert_not_null(instance.get_node_or_null("StationFurniture") as StationFurniture, "armory, garage and bought furniture")


func test_station_layout_builds_armory_and_garage() -> void:
	Economy.persist = false
	Economy.reset()
	var instance: Node = (load(OPS_ROOM_PATH) as PackedScene).instantiate()
	add_child_autofree(instance)
	await wait_frames(2)
	var furniture: StationFurniture = instance.get_node("StationFurniture") as StationFurniture
	assert_not_null(furniture.get_node_or_null("Fixtures/Garage/DeployPoint/DeployDoor") as DeployDoor, "deploy point at the garage shutter")
	var pistol: Node3D = furniture.item_node(&"rack_pistol")
	assert_not_null(pistol, "starter pistol rack")
	assert_not_null(furniture.item_node(&"ammo_crate"), "starter ammo crate")
	assert_not_null(furniture.item_node(&"kevlar_vest"), "starter vest locker")
	assert_null(furniture.item_node(&"rack_rifle"), "rifle rack must be bought first")
	assert_true((furniture.get_node("LockedRacks/rack_rifle") as Node3D).visible, "locked rifle slot shows its price")
	# Buying items makes them appear.
	Economy.money = 100000
	assert_eq(Economy.host_purchase(&"rack_rifle"), "")
	assert_eq(Economy.host_purchase(&"workstation"), "")
	assert_not_null(furniture.item_node(&"rack_rifle"))
	assert_false((furniture.get_node("LockedRacks/rack_rifle") as Node3D).visible)
	var station: Node3D = furniture.item_node(&"workstation", 0)
	assert_not_null(station.get_node_or_null("Computer") as DispatchComputer, "bought workstation has a computer")
	Economy.reset()
	await wait_frames(1)
	assert_null(furniture.item_node(&"workstation", 0), "reset removes bought furniture")


func test_armory_loadout_scene_loads_and_instantiates() -> void:
	var packed := load(ARMORY_PATH) as PackedScene
	assert_not_null(packed, "Armory scene file should load")
	if packed == null:
		return

	var instance := packed.instantiate()
	assert_not_null(instance, "Armory should instantiate")
	if instance == null:
		return
	add_child_autofree(instance)

	assert_not_null(instance.get_node_or_null("Geometry/ArmoryCSG/TacticalBriefingTable"), "Tactical briefing table should exist")
	assert_not_null(instance.get_node_or_null("Geometry/ArmoryCSG/RequisitionCounter"), "Requisition counter should exist")
	assert_not_null(instance.get_node_or_null("PlayerSpawner"), "Player spawner should exist")
	assert_not_null(instance.get_node_or_null("SpawnPoints"), "Spawn points container should exist")
