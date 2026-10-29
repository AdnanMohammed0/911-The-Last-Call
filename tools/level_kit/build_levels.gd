## Entry point: `godot --headless --path . res://tools/level_kit/build_levels.tscn` rebuilds the authored
## maps from the level kit. Runs as a scene (not `-s`) so scripts that use autoloads can be attached.
## Authority: TOOLS
extends Node


func _ready() -> void:
	var station: Error = BuildStation4.build()
	print("BUILD operations_room: ", error_string(station))
	DirAccess.make_dir_recursive_absolute("res://scenes/field/missions")
	var warehouse: Error = BuildWarehouseRaid.build()
	print("BUILD warehouse_raid: ", error_string(warehouse))
	var suburb: Error = BuildAspenDrive.build()
	print("BUILD aspen_drive: ", error_string(suburb))
	var farmhouse: Error = BuildFarmhouse.build()
	print("BUILD farmhouse: ", error_string(farmhouse))
	var lake_house: Error = BuildLakeHouse.build()
	print("BUILD lake_house: ", error_string(lake_house))
	get_tree().quit(0 if station == OK and warehouse == OK and suburb == OK and farmhouse == OK and lake_house == OK else 1)
