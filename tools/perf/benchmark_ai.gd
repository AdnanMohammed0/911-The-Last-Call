## Headless CPU benchmark for the AI test range. Rendering/GPU results require an actual display.
extends SceneTree

const SCENE: String = "res://scenes/field/test_range/ai_test_range.tscn"
const WARMUP_FRAMES: int = 90
const SAMPLE_FRAMES: int = 240
const EXTRA_AGENTS: int = 6


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load(SCENE) as PackedScene
	if packed == null:
		push_error("Benchmark scene missing: %s" % SCENE)
		quit(1)
		return
	var level: Node = packed.instantiate()
	root.add_child(level)
	current_scene = level
	var spawner: Node = level.get_node_or_null(^"EnemySpawner")
	if spawner != null:
		for i: int in EXTRA_AGENTS:
			var at: Transform3D = Transform3D(Basis(), Vector3(-12.0 + i * 4.0, 0.5, -8.0))
			spawner.call(&"spawn_hostile", "res://data/ai/archetypes/thug.tres", at)
	for i: int in WARMUP_FRAMES:
		await physics_frame
	var samples: Array[float] = []
	for i: int in SAMPLE_FRAMES:
		await physics_frame
		samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	samples.sort()
	var total: float = 0.0
	for value: float in samples:
		total += value
	print("AI_BENCH physics_ms_mean=%.3f physics_ms_p95=%.3f agents=%d" % [total / samples.size(), samples[int(samples.size() * 0.95)], get_nodes_in_group(&"hostiles").size()])
	quit()
