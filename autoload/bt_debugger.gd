## Behavior tree debugger overlay (F4, host only): live tree trace of the AI nearest to the local camera
## (Tab cycles agents), plus its blackboard. Colour: green SUCCESS, red FAILURE, yellow RUNNING.
## Authority: LOCAL (reads host-side AI state; clients have no trees to show)
extends CanvasLayer

const TOGGLE_KEY: Key = KEY_F4
const CYCLE_KEY: Key = KEY_TAB

var _panel: PanelContainer
var _label: RichTextLabel
var _selected: BTRunner = null
var _refresh: float = 0.0


func _ready() -> void:
	layer = 101
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -440.0
	_panel.offset_top = 12.0
	_panel.offset_right = -12.0
	_panel.offset_bottom = 620.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.72)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.fit_content = true
	_label.add_theme_font_size_override("normal_font_size", 14)
	_panel.add_child(_label)
	add_child(_panel)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == TOGGLE_KEY:
		visible = not visible
		get_viewport().set_input_as_handled()
	elif visible and key.physical_keycode == CYCLE_KEY:
		_cycle()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh += delta
	if _refresh < 0.1:
		return
	_refresh = 0.0
	if _selected == null or not is_instance_valid(_selected):
		_selected = _nearest_runner()
	_label.text = build_report(_selected)


static func build_report(runner: BTRunner) -> String:
	if runner == null:
		return "[b]BT debugger[/b] (F4)\nNo AI agents running on this machine (AI runs on the host)."
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[b]%s[/b]  status: %s   (Tab: next agent)" % [runner.agent.name, BTNode.Status.keys()[runner.last_status]])
	for entry: Dictionary in runner.blackboard.last_trace:
		var node: BTNode = entry["node"]
		var status: BTNode.Status = entry["status"]
		var depth: int = entry["depth"]
		var color: String = ["#6f6", "#f66", "#ff6"][status]
		lines.append("%s[color=%s]%s %s[/color]" % ["    ".repeat(depth), color, ["✔", "✘", "…"][status], node.get_display_name()])
	lines.append("\n[b]Blackboard[/b]")
	for key: Variant in runner.blackboard.data:
		lines.append("%s = %s" % [key, str(runner.blackboard.data[key]).left(60)])
	return "\n".join(lines)


func _nearest_runner() -> BTRunner:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var best: BTRunner = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(BTRunner.GROUP):
		var runner: BTRunner = node as BTRunner
		var agent_3d: Node3D = runner.agent as Node3D
		if agent_3d == null:
			continue
		var distance: float = camera.global_position.distance_to(agent_3d.global_position) if camera != null else 0.0
		if distance < best_distance:
			best_distance = distance
			best = runner
	return best


func _cycle() -> void:
	var runners: Array[Node] = get_tree().get_nodes_in_group(BTRunner.GROUP)
	if runners.is_empty():
		_selected = null
		return
	var index: int = runners.find(_selected)
	_selected = runners[(index + 1) % runners.size()] as BTRunner
