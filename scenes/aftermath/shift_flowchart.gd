## Read-only decision map for the completed shift; any peer may inspect it locally.
class_name ShiftFlowchart
extends Control

signal closed()

const BG: Color = Color("091018")
const PANEL: Color = Color("13212b")
const TEXT: Color = Color("e7f0ed")
const MUTED: Color = Color("93a7aa")
const CYAN: Color = Color("67d4d5")
const AMBER: Color = Color("f4b65a")

var report_data: Dictionary = {}
var _entries: Array = []
var _call_list: VBoxContainer
var _graph: ShiftBranchGraph
var _selected_index: int = 0


func _ready() -> void:
	if report_data.is_empty():
		report_data = MissionDirector.last_shift_report
	_entries = report_data.get("branches", [])
	_build()
	_select_call(0)


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background: ColorRect = ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var pad: MarginContainer = MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 24)
	add_child(pad)
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	pad.add_child(page)
	var header: HBoxContainer = HBoxContainer.new()
	page.add_child(header)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(_label("STATION 4  /  DECISION MAP", 13, CYAN))
	var shift: int = report_data.get("shift", MissionDirector.shift_number)
	titles.add_child(_label("SHIFT %02d FLOWCHART" % shift, 30, TEXT))
	var back: Button = Button.new()
	back.text = "←  BACK TO REPORT"
	back.custom_minimum_size = Vector2(190, 42)
	back.pressed.connect(func() -> void: closed.emit())
	header.add_child(back)
	var hint: Label = _label("Select a call to inspect its chosen route. Grey routes were not taken this shift.", 14, MUTED)
	page.add_child(hint)
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	page.add_child(body)
	var sidebar: PanelContainer = _panel()
	sidebar.custom_minimum_size.x = 350
	body.add_child(sidebar)
	var side_pad: MarginContainer = _pad(sidebar, 14)
	var side_stack: VBoxContainer = VBoxContainer.new()
	side_stack.add_theme_constant_override("separation", 10)
	side_pad.add_child(side_stack)
	side_stack.add_child(_label("CALLS THIS SHIFT", 13, AMBER))
	var side_scroll: ScrollContainer = ScrollContainer.new()
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_stack.add_child(side_scroll)
	_call_list = VBoxContainer.new()
	_call_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_call_list.add_theme_constant_override("separation", 7)
	side_scroll.add_child(_call_list)
	var graph_panel: PanelContainer = _panel()
	graph_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(graph_panel)
	var graph_scroll: ScrollContainer = ScrollContainer.new()
	graph_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	graph_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	graph_panel.add_child(graph_scroll)
	_graph = ShiftBranchGraph.new()
	graph_scroll.add_child(_graph)
	page.add_child(_label("CYAN  /  ROUTE TAKEN       GREY  /  LOCKED       AMBER  /  MISSED OR DIVERGED", 12, MUTED))


func _select_call(index: int) -> void:
	_selected_index = clampi(index, 0, maxi(_entries.size() - 1, 0))
	for child: Node in _call_list.get_children():
		child.queue_free()
	if _entries.is_empty():
		_call_list.add_child(_label("No calls recorded.", 14, MUTED))
		_graph.show_branch({})
		return
	for i: int in _entries.size():
		var item: Dictionary = _entries[i]
		var button: Button = Button.new()
		var minute: int = item.get("minute", 0)
		button.text = "%02d:%02d  %s" % [minute / 60, minute % 60, str(item.get("title", "Call"))]
		button.tooltip_text = str(item.get("title", "Call"))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 42
		button.add_theme_color_override("font_color", CYAN if i == _selected_index else TEXT)
		button.pressed.connect(_select_call.bind(i))
		_call_list.add_child(button)
	var selected: Dictionary = _entries[_selected_index]
	_graph.show_branch(selected)


func _panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = Color("28414c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _pad(parent: Control, amount: int) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, amount)
	parent.add_child(margin)
	return margin


func _label(value: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
