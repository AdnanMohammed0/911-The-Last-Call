## Smoke check run from an exported demo PCK with --main-pack and -s.
extends SceneTree


func _initialize() -> void:
	_verify.call_deferred()


func _verify() -> void:
	if BuildInfo.channel() != "demo" or BuildInfo.version() != BuildInfo.DEMO_VERSION:
		push_error("Demo pack has wrong channel/version: %s" % BuildInfo.label())
		quit(1)
		return
	var demo_dir: String = "res://data/calls/demo"
	var demo_paths: PackedStringArray = CallValidator._find_resources(demo_dir)
	var playable: int = 0
	for path: String in demo_paths:
		var call: CallData = load(path) as CallData
		if call != null and CallValidator.is_playable(call):
			playable += 1
	if playable != 15 or not ResourceLoader.exists("res://data/training/training_call.tres"):
		push_error("Wrong demo content: directory=%s, playable=%d" % [demo_dir, playable])
		quit(1)
		return
	print("DEMO PACK OK: %s, %d curated calls and Training Night" % [BuildInfo.label(), playable])
	quit()
