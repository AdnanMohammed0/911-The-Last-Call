## Capture the live BT debugger over the AI test range for visual QA.
extends SceneTree


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var packed: PackedScene = load("res://scenes/field/test_range/ai_test_range.tscn") as PackedScene
	var level: Node = packed.instantiate()
	root.add_child(level)
	current_scene = level
	var debugger: CanvasLayer = root.get_node(^"BTDebugger") as CanvasLayer
	debugger.visible = true
	for _i: int in 120:
		await process_frame
	var label: RichTextLabel = debugger.find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel
	var image: Image = root.get_texture().get_image()
	var path: String = "user://bt_debugger_capture.png"
	var result: Error = image.save_png(path)
	print("BT_CAPTURE path=%s error=%d camera=%s agents=%d text_chars=%d" % [
		ProjectSettings.globalize_path(path), result, root.get_camera_3d() != null,
		get_nodes_in_group(&"bt_runners").size(), label.text.length()])
	quit(0 if result == OK else 1)
