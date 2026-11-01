## Rendered scene benchmark. Run without --headless, with --windowed.
## Pass scene path, extra hostile count, quality (0-3), render scale, and optional "sweep" or "walk" after --.
## Optional trailing flags: no_batch, bilinear, fsr1, fsr2; sweep can take a capture prefix first.
extends SceneTree

const DEFAULT_SCENE: String = "res://scenes/dispatch/operations_room.tscn"
const WARMUP_FRAMES: int = 90
const SAMPLE_FRAMES: int = 180
const WALK_FRAMES: int = 600


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene_path: String = args[0] if not args.is_empty() else DEFAULT_SCENE
	var extra_hostiles: int = maxi(int(args[1]), 0) if args.size() > 1 else 0
	var quality_value: int = clampi(int(args[2]), 0, 3) if args.size() > 2 else 2
	var scale_value: float = clampf(float(args[3]), 0.5, 1.0) if args.size() > 3 else 1.0
	var sweep: bool = args.size() > 4 and args[4] == "sweep"
	var walk: bool = args.size() > 4 and args[4] == "walk"
	var sample_count: int = WALK_FRAMES if walk else SAMPLE_FRAMES
	var settings: Node = root.get_node_or_null(^"GameSettings")
	if settings != null:
		settings.set(&"quality", quality_value)
		settings.set(&"render_scale", scale_value)
		settings.call(&"apply_all")
	if "bilinear" in args:
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	elif "fsr1" in args:
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	elif "fsr2" in args:
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("Benchmark scene missing: %s" % scene_path)
		quit(1)
		return
	var level: Node = packed.instantiate()
	if "no_batch" in args:
		var batch_node: Node = level.get_node_or_null(^"StationInterior/StationMeshBatch")
		if batch_node != null:
			batch_node.get_parent().remove_child(batch_node)
			batch_node.free()
	root.add_child(level)
	current_scene = level
	var mesh_batch: Node = level.get_node_or_null(^"StationInterior/StationMeshBatch")
	if mesh_batch != null:
		print("STATION_BATCH batches=%d meshes=%d" % [mesh_batch.get("batch_count"), mesh_batch.get("mesh_count")])
	var positions: Array[Vector3] = _walk_positions(scene_path) if walk else (_sweep_positions(scene_path) if sweep else [])
	var spawner: Node = level.find_child("EnemySpawner", true, false)
	if spawner != null:
		for i: int in extra_hostiles:
			var at: Transform3D = Transform3D(Basis(), Vector3(5.0 + float(i % 4) * 2.0, 1.0, -22.0 - float(i / 4) * 2.0))
			spawner.call(&"spawn_hostile", "res://data/ai/archetypes/thug.tres", at)
	for _i: int in WARMUP_FRAMES:
		await process_frame
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	if (sweep or walk) and camera == null:
		push_error("Camera benchmark requires an active Camera3D after scene warmup")
		quit(1)
		return
	if camera != null and not positions.is_empty():
		camera.top_level = true
		_aim_camera(camera, positions[0], positions[0] + Vector3.FORWARD)
		for _i: int in 20:
			await process_frame
	var frame_ms: Array[float] = []
	var process_ms: Array[float] = []
	var physics_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var sweep_frames: Array[Array] = []
	var sweep_draws: Array[Array] = []
	if sweep:
		for _point: Vector3 in positions:
			sweep_frames.append([])
			sweep_draws.append([])
	var last_usec: int = Time.get_ticks_usec()
	for i: int in sample_count:
		var spot: int = mini(i * positions.size() / sample_count, positions.size() - 1) if sweep and not positions.is_empty() else -1
		if spot >= 0 and camera != null:
			_aim_camera(camera, positions[spot], positions[spot] + Vector3.FORWARD)
		elif walk and camera != null:
			var at: Vector3 = _walk_at(positions, i, sample_count)
			_aim_camera(camera, at, at + Vector3.FORWARD)
		await process_frame
		var now: int = Time.get_ticks_usec()
		var elapsed_ms: float = float(now - last_usec) / 1000.0
		frame_ms.append(elapsed_ms)
		if spot >= 0:
			sweep_frames[spot].append(elapsed_ms)
		last_usec = now
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		var draws: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		draw_calls.append(draws)
		if spot >= 0:
			sweep_draws[spot].append(draws)
	frame_ms.sort()
	var slow_count: int = maxi(ceili(float(sample_count) * 0.01), 1)
	var slow_frames: Array[float] = frame_ms.slice(sample_count - slow_count, sample_count)
	var spikes: int = 0
	for frame: float in frame_ms:
		if frame > 33.333:
			spikes += 1
	print("RENDER_BENCH scene=%s mode=%s size=%s camera=%s hostiles=%d quality=%d scale=%.2f upscaler=%d frame_ms_mean=%.3f frame_ms_p95=%.3f frame_ms_p99=%.3f fps_1pct_low=%.2f spikes_gt_33ms=%d process_ms_mean=%.3f physics_ms_mean=%.3f draw_calls_mean=%.1f" % [
		scene_path, "walk" if walk else ("sweep" if sweep else "static"), DisplayServer.window_get_size(), camera != null, get_nodes_in_group(&"hostiles").size(), quality_value, scale_value, root.scaling_3d_mode,
		_mean(frame_ms), frame_ms[int(float(sample_count) * 0.95)], frame_ms[int(float(sample_count) * 0.99)], 1000.0 / _mean(slow_frames), spikes,
		_mean(process_ms), _mean(physics_ms), _mean(draw_calls)])
	for spot: int in sweep_frames.size():
		var samples: Array[float] = []
		for sample: float in sweep_frames[spot]:
			samples.append(sample)
		samples.sort()
		var draws_at_spot: Array[float] = []
		for draw: float in sweep_draws[spot]:
			draws_at_spot.append(draw)
		print("RENDER_SPOT index=%d position=%s mean=%.3f p95=%.3f draws=%.1f" % [spot, positions[spot], _mean(samples), samples[int(samples.size() * 0.95)], _mean(draws_at_spot)])
	if sweep and args.size() > 5 and args[5] != "no_batch" and camera != null and not positions.is_empty():
		for spot: int in positions.size():
			var capture_path: String = "user://%s_%d.png" % [args[5], spot]
			_aim_camera(camera, positions[spot], positions[spot] + Vector3.FORWARD)
			for _i: int in 10:
				await process_frame
			var save_error: Error = root.get_texture().get_image().save_png(capture_path)
			print("RENDER_CAPTURE path=%s error=%d" % [ProjectSettings.globalize_path(capture_path), save_error])
	quit()


func _mean(values: Array[float]) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / values.size()


func _sweep_positions(scene_path: String) -> Array[Vector3]:
	if scene_path.contains("operations_room"):
		return [Vector3(8, 2, -22), Vector3(22, 2, -22), Vector3(20, 2, -5), Vector3(-9, 2, -40)]
	return [Vector3(-3, 2, 19), Vector3(-12, 2, 9), Vector3(0, 2, -10), Vector3(15, 2, -20)]


func _walk_positions(scene_path: String) -> Array[Vector3]:
	if scene_path.contains("operations_room"):
		return [Vector3(8, 2, -22), Vector3(22, 2, -22), Vector3(20, 2, -5), Vector3(22, 2, -22), Vector3(8, 2, -22)]
	return [Vector3(-3, 2, 19), Vector3(-12, 2, 9), Vector3(0, 2, -10), Vector3(15, 2, -20), Vector3(-3, 2, 19)]


func _walk_at(positions: Array[Vector3], frame: int, total_frames: int) -> Vector3:
	var leg_count: int = positions.size() - 1
	var progress: float = float(frame) * float(leg_count) / float(total_frames - 1)
	var leg: int = mini(int(progress), leg_count - 1)
	return positions[leg].lerp(positions[leg + 1], progress - float(leg))


func _aim_camera(camera: Camera3D, at: Vector3, target: Vector3) -> void:
	camera.global_position = at
	camera.look_at(target, Vector3.UP)
