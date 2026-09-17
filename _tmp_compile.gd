extends Node

func _ready() -> void:
	var bad: int = 0
	for path: String in _scripts("res://"):
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			print("COMPILE FAIL ", path)
			bad += 1
	for scene: String in ["res://scenes/shared/player/player.tscn", "res://ui/hud/health_hud.tscn", "res://scenes/dispatch/operations_room.tscn"]:
		if load(scene) == null:
			print("SCENE FAIL ", scene)
			bad += 1
	print("COMPILE CHECK done, failures: ", bad)
	get_tree().quit(bad)

func _scripts(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(dir_path)
	for sub: String in dir.get_directories():
		if not sub.begins_with(".") and sub != "docs" and sub != "addons":
			out.append_array(_scripts(dir_path.path_join(sub)))
	for file: String in dir.get_files():
		if file.ends_with(".gd") and not file.begins_with("_tmp"):
			out.append(dir_path.path_join(file))
	return out
