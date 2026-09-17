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

	# Verify 4 player spawn points for 4 classes
	assert_not_null(instance.get_node_or_null("SpawnPoints/Spawn1_Tech"), "Tech Operator desk spawn")
	assert_not_null(instance.get_node_or_null("SpawnPoints/Spawn2_Profiler"), "Profiler desk spawn")
	assert_not_null(instance.get_node_or_null("SpawnPoints/Spawn3_Breacher"), "Breacher desk spawn")
	assert_not_null(instance.get_node_or_null("SpawnPoints/Spawn4_Medic"), "Medic desk spawn")

	# Verify 3 interactive networked doors
	var d1: Door = instance.get_node_or_null("Doors/Door_OpsToCorridor") as Door
	var d2: Door = instance.get_node_or_null("Doors/Door_CorridorToArmory") as Door
	var d3: Door = instance.get_node_or_null("Doors/Door_CorridorToParking") as Door
	assert_not_null(d1, "Door from Ops to Corridor should exist")
	assert_not_null(d2, "Door from Corridor to Armory should exist")
	assert_not_null(d3, "Door from Corridor to Parking should exist")
	if d2 != null:
		assert_false(d2.is_locked, "Armory door should be unlocked for open station movement")


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
