## Capture real 1920x1080 gameplay frames for Steam. Run with -- <preset>.
extends Node

const OUTPUT: String = "res://marketing/steam/screenshots/"
const SCENES: Dictionary[String, String] = {
	"station": "res://scenes/dispatch/operations_room.tscn",
	"cad": "res://scenes/dispatch/operations_room.tscn",
	"vsa": "res://scenes/dispatch/operations_room.tscn",
	"records": "res://scenes/dispatch/operations_room.tscn",
	"case_board": "res://scenes/dispatch/operations_room.tscn",
	"farmhouse": "res://scenes/field/missions/farmhouse.tscn",
	"lake_house": "res://scenes/field/missions/lake_house.tscn",
	"highway": "res://scenes/field/missions/abandoned_highway.tscn",
}


func _ready() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var raw_preset: String = args[0] if not args.is_empty() else ""
	var clip: bool = raw_preset.begins_with("clip_")
	var preset: String = raw_preset.trim_prefix("clip_") if clip else raw_preset
	if not SCENES.has(preset):
		push_error("Unknown store capture preset: %s" % raw_preset)
		get_tree().quit(1)
		return
	get_window().size = Vector2i(1280, 720) if clip else Vector2i(1920, 1080)
	GameSettings.show_fps = false
	GameSettings.subtitles_enabled = false
	GameSettings.brightness = 1.6 if preset in ["farmhouse", "lake_house", "highway"] else 1.0
	var packed: PackedScene = load(SCENES[preset]) as PackedScene
	var scene: Node3D = packed.instantiate() as Node3D
	get_tree().root.add_child(scene)
	for frame: int in 25:
		await get_tree().process_frame
	GameSettings.apply_all()
	var player: Player = Player.find_by_peer(get_tree(), 1)
	if player != null:
		player.set_physics_process(false)
		player.set_input_enabled(false)
		if preset in ["farmhouse", "lake_house", "highway"]:
			player.flashlight_on = true
	var shot_camera: Camera3D = null
	if preset in ["cad", "vsa", "records", "case_board"]:
		var computer: DispatchComputer = scene.get_tree().get_first_node_in_group(&"dispatch_computers") as DispatchComputer
		if computer != null:
			computer._start_using(1)
			var desktop: StationOS = StationOS.find(get_tree())
			if desktop != null:
				CallDirector.ring_call(&"call_closet_monster")
				CallDirector.request_answer_call(&"call_closet_monster")
				desktop.open_app(&"cad")
				var terminal: DispatchTerminal = DispatchTerminal.find(get_tree())
				if terminal != null:
					match preset:
						"vsa": terminal._open_vsa()
						"records": terminal._open_records()
						"case_board": terminal._open_case_board()
	else:
		var camera: Camera3D = player.get_camera() if player != null else Camera3D.new()
		shot_camera = camera
		if camera.get_parent() == null:
			scene.add_child(camera)
		camera.current = true
		var position: Vector3 = Vector3.ZERO
		var target: Vector3 = Vector3.ZERO
		match preset:
			"station":
				position = Vector3(8, 2.15, -27)
				target = Vector3(8, 1.7, -20)
			"farmhouse":
				position = Vector3(-9, 2.1, 13)
				target = Vector3(-9, 2.0, -3)
			"lake_house":
				position = Vector3(-11, 2.1, 14)
				target = Vector3(-10, 1.7, -3)
			"highway":
				position = Vector3(-5, 2.1, 35)
				target = Vector3(-5, 1.8, 8)
		camera.global_position = position
		camera.look_at(target, Vector3.UP)
	for frame: int in 20:
		await get_tree().process_frame
	if clip:
		var frames_dir: String = "res://marketing/steam/trailer/frames/" + preset + "/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(frames_dir))
		for index: int in 72:
			if shot_camera != null:
				shot_camera.global_position += Vector3(0.004, 0.0, -0.014)
				shot_camera.rotate_y(0.0008)
			await RenderingServer.frame_post_draw
			var frame_image: Image = get_viewport().get_texture().get_image()
			var frame_error: Error = frame_image.save_jpg(frames_dir + "%04d.jpg" % index, 0.9)
			if frame_error != OK:
				push_error("Clip frame failed: %s" % error_string(frame_error))
				get_tree().quit(1)
				return
		print("CLIP %s 72 frames 1280x720" % preset)
		get_tree().quit()
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = OUTPUT + preset + ".png"
	var error: Error = image.save_png(path)
	print("CAPTURE %s %s %s" % [preset, image.get_size(), error_string(error)])
	get_tree().quit(0 if error == OK else 1)
