## Rendered scene benchmark. Run without --headless, with --windowed.
## Pass scene path, extra hostile count, optional quality (0-3), and render scale after --.
extends SceneTree

const DEFAULT_SCENE: String = "res://scenes/dispatch/operations_room.tscn"
const WARMUP_FRAMES: int = 90
const SAMPLE_FRAMES: int = 180


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
	var settings: Node = root.get_node_or_null(^"GameSettings")
	if settings != null:
		settings.set(&"quality", quality_value)
		settings.set(&"render_scale", scale_value)
		settings.call(&"apply_all")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("Benchmark scene missing: %s" % scene_path)
		quit(1)
		return
	var level: Node = packed.instantiate()
	root.add_child(level)
	current_scene = level
	var spawner: Node = level.find_child("EnemySpawner", true, false)
	if spawner != null:
		for i: int in extra_hostiles:
			var at: Transform3D = Transform3D(Basis(), Vector3(5.0 + float(i % 4) * 2.0, 1.0, -22.0 - float(i / 4) * 2.0))
			spawner.call(&"spawn_hostile", "res://data/ai/archetypes/thug.tres", at)
	for _i: int in WARMUP_FRAMES:
		await process_frame
	var frame_ms: Array[float] = []
	var process_ms: Array[float] = []
	var physics_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var last_usec: int = Time.get_ticks_usec()
	for _i: int in SAMPLE_FRAMES:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frame_ms.append(float(now - last_usec) / 1000.0)
		last_usec = now
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	frame_ms.sort()
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	print("RENDER_BENCH scene=%s size=%s camera=%s hostiles=%d quality=%d scale=%.2f frame_ms_mean=%.3f frame_ms_p95=%.3f frame_ms_p99=%.3f process_ms_mean=%.3f physics_ms_mean=%.3f draw_calls_mean=%.1f" % [
		scene_path, DisplayServer.window_get_size(), camera != null, get_nodes_in_group(&"hostiles").size(), quality_value, scale_value,
		_mean(frame_ms), frame_ms[int(SAMPLE_FRAMES * 0.95)], frame_ms[int(SAMPLE_FRAMES * 0.99)],
		_mean(process_ms), _mean(physics_ms), _mean(draw_calls)])
	quit()


func _mean(values: Array[float]) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / values.size()
