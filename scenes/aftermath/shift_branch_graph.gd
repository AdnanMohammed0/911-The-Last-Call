## One call's choice tree. All branches are drawn, but only the route actually taken is revealed.
class_name ShiftBranchGraph
extends Control

const OPTIONS: Array[String] = ["prank", "genuine", "ambush", "paranormal", "ignore"]
const GRAPH_SCALE: float = 1.5
const DARK: Color = Color("111d27")
const MUTED: Color = Color("718796")
const TEXT: Color = Color("e7f0ed")
const CYAN: Color = Color("65d1d0")
const AMBER: Color = Color("f4b65a")

var branch: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(900, 520) * GRAPH_SCALE
	show_branch(branch)


func show_branch(value: Dictionary) -> void:
	branch = value.duplicate(true)
	if not is_node_ready():
		return
	for child: Node in get_children():
		child.queue_free()
	if branch.is_empty():
		_card("NO CALL SELECTED", "Complete a shift to inspect its decisions.", Vector2(275, 215), Vector2(350, 95), false, true)
		queue_redraw()
		return
	var chosen: String = branch.get("verdict", "")
	var missed: bool = chosen.is_empty()
	_card("INCOMING CALL", str(branch.get("title", "Unknown call")), Vector2(28, 212), Vector2(215, 104), true, false)
	for index: int in OPTIONS.size():
		var option: String = OPTIONS[index]
		var taken: bool = option == chosen
		_card(option.to_upper(), "TAKEN" if taken else "LOCKED · UNEXPLORED",
			Vector2(320, 25 + index * 95), Vector2(210, 76), taken, false)
	var actual: String = branch.get("actual", "")
	var result: String = str(branch.get("outcome", "No outcome recorded"))
	if result.length() > 155:
		result = result.left(152) + "..."
	var heading: String = "CALL MISSED" if missed else ("MATCHED THE TRUTH" if chosen == actual else "ASSESSMENT DIVERGED")
	var detail: String = result if missed else ("Actual: %s\n%s" % [actual.capitalize(), result])
	_card(heading, detail, Vector2(625, 192), Vector2(245, 155), not missed and chosen == actual, not missed and chosen != actual)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * GRAPH_SCALE)
	for x: int in range(0, 900, 40):
		for y: int in range(0, 520, 40):
			draw_circle(Vector2(x, y), 1.0, Color("22313b"))
	if branch.is_empty():
		return
	var chosen: String = branch.get("verdict", "")
	var source: Vector2 = Vector2(243, 264)
	for index: int in OPTIONS.size():
		var target: Vector2 = Vector2(320, 63 + index * 95)
		var taken: bool = OPTIONS[index] == chosen
		var color: Color = CYAN if taken else MUTED
		var width: float = 3.0 if taken else 1.0
		draw_line(source, Vector2(275, source.y), color, width, true)
		draw_line(Vector2(275, source.y), Vector2(275, target.y), color, width, true)
		draw_line(Vector2(275, target.y), target, color, width, true)
		if taken:
			var to_result: Vector2 = Vector2(625, 269)
			draw_line(Vector2(530, target.y), Vector2(575, target.y), CYAN, 3.0, true)
			draw_line(Vector2(575, target.y), Vector2(575, to_result.y), CYAN, 3.0, true)
			draw_line(Vector2(575, to_result.y), to_result, CYAN, 3.0, true)
	if chosen.is_empty():
		draw_line(source, Vector2(280, 490), AMBER, 2.0, true)
		draw_line(Vector2(280, 490), Vector2(590, 490), AMBER, 2.0, true)
		draw_line(Vector2(590, 490), Vector2(590, 269), AMBER, 2.0, true)
		draw_line(Vector2(590, 269), Vector2(625, 269), AMBER, 2.0, true)


func _card(title: String, subtitle: String, at: Vector2, extent: Vector2, active: bool, warning: bool) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = at * GRAPH_SCALE
	panel.size = extent
	panel.custom_minimum_size = extent
	panel.scale = Vector2.ONE * GRAPH_SCALE
	panel.clip_contents = true
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("17323a") if active else DARK
	style.border_color = CYAN if active else (AMBER if warning else MUTED)
	style.set_border_width_all(2 if active or warning else 1)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for edge: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 10)
	panel.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)
	stack.add_child(_label(title, 15, CYAN if active else (AMBER if warning else MUTED)))
	stack.add_child(_label(subtitle, 12, TEXT if active or warning else MUTED))


func _label(value: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
