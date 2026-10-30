## Team report shown between shifts. Reads the host's frozen snapshot, never live call state.
class_name ShiftReport
extends Control

const BG: Color = Color("091018")
const CARD: Color = Color("13212b")
const LINE: Color = Color("28414c")
const TEXT: Color = Color("e7f0ed")
const MUTED: Color = Color("93a7aa")
const AMBER: Color = Color("f4b65a")
const CYAN: Color = Color("67d4d5")

var _continue_button: Button
var _flowchart_button: Button


func _ready() -> void:
	_build(MissionDirector.last_shift_report)
	if OS.has_feature("demo"):
		_continue_button.text = "DEMO COMPLETE  ·  MAIN MENU  →"
	if GameState.phase != GameState.Phase.AFTERMATH:
		_continue_button.disabled = true
	elif not multiplayer.is_server():
		_continue_button.disabled = true
		_continue_button.text = "WAITING FOR TEAM LEADER"


func _build(report: Dictionary) -> void:
	var background: ColorRect = ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	add_child(margin)
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	margin.add_child(page)
	var header: HBoxContainer = HBoxContainer.new()
	page.add_child(header)
	var heading: VBoxContainer = VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	heading.add_child(_label("STATION 4  /  AFTER ACTION REPORT", 13, CYAN))
	var completed_shift: int = report.get("shift", MissionDirector.shift_number)
	heading.add_child(_label("SHIFT %02d COMPLETE" % completed_shift, 34, TEXT))
	var count: int = report.get("handled", 0)
	var total: int = report.get("total", 0)
	header.add_child(_label("%d / %d CALLS HANDLED" % [count, total], 15, AMBER))

	var meters: Dictionary = report.get("meters", {})
	var deltas: Dictionary = report.get("deltas", {})
	var meter_row: HBoxContainer = HBoxContainer.new()
	meter_row.add_theme_constant_override("separation", 12)
	page.add_child(meter_row)
	var trust: int = meters.get("trust", 0)
	var trust_delta: int = deltas.get("trust", 0)
	var budget: int = meters.get("budget", 0)
	var budget_delta: int = deltas.get("budget", 0)
	var awareness: int = meters.get("awareness", 0)
	var awareness_delta: int = deltas.get("awareness", 0)
	_meter_card(meter_row, "PUBLIC TRUST", trust, trust_delta, "", false)
	_meter_card(meter_row, "STATION BUDGET", budget, budget_delta, "$", false)
	_meter_card(meter_row, "CULT AWARENESS", awareness, awareness_delta, "", true)

	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	page.add_child(columns)
	var timeline: VBoxContainer = _section(columns, "SHIFT TIMELINE", true)
	var events: Array = report.get("events", [])
	if events.is_empty():
		timeline.add_child(_label("No calls or field responses recorded this shift.", 15, MUTED))
	else:
		for item: Dictionary in events:
			var minute: int = item.get("minute", 0)
			var event_row: HBoxContainer = HBoxContainer.new()
			event_row.add_theme_constant_override("separation", 14)
			timeline.add_child(event_row)
			var stamp: Label = _label("%02d:%02d" % [minute / 60, minute % 60], 14, CYAN)
			stamp.custom_minimum_size.x = 52
			event_row.add_child(stamp)
			var event_text: VBoxContainer = VBoxContainer.new()
			event_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			event_row.add_child(event_text)
			event_text.add_child(_label(str(item.get("title", "EVENT")), 16, TEXT))
			event_text.add_child(_label(str(item.get("detail", "")), 13, MUTED, true))
			timeline.add_child(_divider())

	var notes_column: VBoxContainer = VBoxContainer.new()
	notes_column.custom_minimum_size.x = 310
	notes_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notes_column.add_theme_constant_override("separation", 14)
	columns.add_child(notes_column)
	var traits: VBoxContainer = _section(notes_column, "TRAITS GAINED", false)
	var gained_traits: Array = report.get("traits", [])
	_add_list(traits, gained_traits, "No new traits this shift.", AMBER)
	var leads: VBoxContainer = _section(notes_column, "LEADS & EVIDENCE", false)
	var leads_found: Array = report.get("leads", [])
	_add_list(leads, leads_found, "No new leads recorded.", CYAN)

	var footer: HBoxContainer = HBoxContainer.new()
	page.add_child(footer)
	var next_text: Label = _label("Training Night and Shift 1 complete. Thanks for playing the demo." if OS.has_feature("demo") else "The next shift begins when the team leader continues.", 14, MUTED)
	next_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(next_text)
	_flowchart_button = Button.new()
	_flowchart_button.text = "VIEW FLOWCHART"
	_flowchart_button.custom_minimum_size = Vector2(175, 48)
	_flowchart_button.pressed.connect(_open_flowchart)
	footer.add_child(_flowchart_button)
	_continue_button = Button.new()
	_continue_button.text = "CONTINUE TO NEXT SHIFT  →"
	_continue_button.custom_minimum_size = Vector2(270, 48)
	_continue_button.add_theme_color_override("font_color", BG)
	_continue_button.add_theme_stylebox_override("normal", _style(AMBER, AMBER))
	_continue_button.add_theme_stylebox_override("hover", _style(Color("ffd07b"), Color("ffd07b")))
	_continue_button.pressed.connect(_finish_demo if OS.has_feature("demo") else MissionDirector.continue_after_report)
	footer.add_child(_continue_button)


func _finish_demo() -> void:
	if not multiplayer.is_server() or GameState.phase != GameState.Phase.AFTERMATH:
		return
	if NetManager.is_online():
		NetManager.leave_to_menu()
		return
	CallDirector.reset()
	CallDirector.registered_calls.clear()
	MissionDirector.reset()
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/boot/main_menu.tscn")


func _open_flowchart() -> void:
	var scene: PackedScene = load("res://scenes/aftermath/shift_flowchart.tscn") as PackedScene
	var view: ShiftFlowchart = scene.instantiate() as ShiftFlowchart
	view.report_data = MissionDirector.last_shift_report
	add_child(view)
	view.closed.connect(func() -> void: view.queue_free())


func _meter_card(parent: HBoxContainer, title: String, value: int, delta: int, prefix: String, danger_up: bool) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(CARD, LINE))
	parent.add_child(panel)
	var pad: MarginContainer = _pad(panel, 14)
	var stack: VBoxContainer = VBoxContainer.new()
	pad.add_child(stack)
	stack.add_child(_label(title, 12, MUTED))
	var line: HBoxContainer = HBoxContainer.new()
	stack.add_child(line)
	var number: Label = _label("%s%d" % [prefix, value], 28, TEXT)
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(number)
	var good: bool = delta < 0 if danger_up else delta > 0
	line.add_child(_label("%+d" % delta, 17, CYAN if good else (MUTED if delta == 0 else AMBER)))


func _section(parent: Container, title: String, expand: bool) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_SHRINK_BEGIN
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(CARD, LINE))
	parent.add_child(panel)
	var pad: MarginContainer = _pad(panel, 18)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 12)
	pad.add_child(stack)
	stack.add_child(_label(title, 14, AMBER))
	stack.add_child(_divider())
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	if expand:
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stack.add_child(scroll)
		scroll.add_child(content)
	else:
		stack.add_child(content)
	return content


func _add_list(parent: VBoxContainer, items: Array, empty_text: String, color: Color) -> void:
	if items.is_empty():
		parent.add_child(_label(empty_text, 14, MUTED, true))
		return
	for item: Variant in items:
		parent.add_child(_label("•  %s" % str(item), 14, color, true))


func _pad(parent: Control, amount: int) -> MarginContainer:
	var pad: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, amount)
	parent.add_child(pad)
	return pad


func _label(value: String, size: int, color: Color, wrap: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return label


func _divider() -> ColorRect:
	var line: ColorRect = ColorRect.new()
	line.color = LINE
	line.custom_minimum_size.y = 1
	return line


func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
