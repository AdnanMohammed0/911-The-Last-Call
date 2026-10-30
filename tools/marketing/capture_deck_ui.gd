## Captures 1280x800 UI checks without Steam Deck hardware.
extends Node


func _ready() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var preset: String = args[0] if not args.is_empty() else "menu"
	if preset not in ["menu", "settings"]:
		push_error("Use -- menu or -- settings")
		get_tree().quit(1)
		return
	GameSettings.quality = GameSettings.Quality.LOW
	GameSettings.ui_scale = 1.0
	GameSettings.apply_all()
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 800)
	get_window().content_scale_size = Vector2i(1280, 800)
	var scene: PackedScene = load("res://scenes/boot/main_menu.tscn") as PackedScene
	var menu: Control = scene.instantiate() as Control
	get_tree().root.add_child(menu)
	for frame: int in 25:
		await get_tree().process_frame
	if preset == "settings":
		SettingsMenu.open_over(menu)
		for frame: int in 12:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder: String = "res://docs/release/steam_deck/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var image: Image = get_viewport().get_texture().get_image()
	if image.get_size() != Vector2i(1280, 800):
		push_error("Launch with --resolution 1280x800 --windowed and pass --windowed after --")
		get_tree().quit(1)
		return
	var error: Error = image.save_png(folder + preset + ".png")
	print("DECK UI %s %s %s" % [preset, image.get_size(), error_string(error)])
	get_tree().quit(0 if error == OK else 1)
