## Profiler's VSA workstation. The waveform is authored from StressProfile; the Phone bus only
## supplies visual spectrum energy. Tag requests are resolved by the host in CallDirector.
class_name VsaMiniGame
extends Control

@warning_ignore_start("unsafe_cast")

const READABILITY := preload("res://ui/kit/ui_readability.gd")
const CYAN: Color = Color(0.34, 0.85, 0.92)
const AMBER: Color = Color(1.0, 0.72, 0.25)
const DIM: Color = Color(0.56, 0.67, 0.72)
const TAG_TYPES: Array[StringName] = [&"loop", &"tremor_flat", &"tremor_high", &"emf_hum", &"background_isolate"]
const TAG_LABELS: Array[String] = ["Repeated loop", "Flat tremor", "High stress", "EMF interference", "Background cue"]

signal tag_requested(time_seconds: float, tag_type: StringName)
signal closed()

var _vsa: VoiceStressAnalyzer = null
var _waveform: Control
var _time_label: Label
var _readout: Label
var _spectrum: Label
var _feedback: Label
var _tag_choice: OptionButton
var _isolate: CheckButton
var _selected_time: float = 0.0
var _duration: float = 60.0
var _dragging: bool = false
var _spectrum_elapsed: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	READABILITY.enlarge_text(self)
	CallDirector.vsa_tag_result.connect(_on_tag_result)


func open(vsa: VoiceStressAnalyzer) -> void:
	_vsa = vsa
	_duration = maxf(1.0, vsa.total_call_duration)
	_selected_time = clampf(vsa.current_playback_time, 0.0, _duration)
	_isolate.button_pressed = false
	_vsa.toggle_background_isolate(false)
	_spectrum_elapsed = 0.0
	_feedback.text = "Drag the scan window across the waveform, then choose a tag. Wrong tags cost caller patience."
	_feedback.add_theme_color_override(&"font_color", DIM)
	visible = true
	_update_readout()
	_waveform.queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	_dragging = false
	if _vsa != null:
		_vsa.toggle_background_isolate(false)
	closed.emit()


func _process(delta: float) -> void:
	if visible and _vsa != null:
		_spectrum_elapsed += delta
		if _spectrum_elapsed >= 0.1:
			_spectrum_elapsed = 0.0
			_update_spectrum()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0.005, 0.012, 0.02, 0.97)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)

	var frame: PanelContainer = UiKit.glass(Color(0.025, 0.045, 0.06), 14, 0, 0, 0.94, 3.0, Color(CYAN, 0.25))
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 36
	frame.offset_top = 32
	frame.offset_right = -36
	frame.offset_bottom = -32
	add_child(frame)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	frame.add_child(UiKit.margin(column, 22, 18, 22, 18))

	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	var heading: VBoxContainer = VBoxContainer.new()
	header.add_child(heading)
	heading.add_child(UiKit.caps("PROFILER / AUDIO FORENSICS", 11, CYAN, &"bold", 2))
	heading.add_child(UiKit.label("Voice Stress Analyzer", 26, Color.WHITE, &"bold"))
	header.add_child(UiKit.expand(Control.new()))
	var exit_button: KitButton = KitButton.make("Back to CAD", &"close", KitButton.Variant.SUBTLE, close)
	header.add_child(exit_button)

	column.add_child(UiKit.caps("RECORDED LINE  ·  DRAG TO SCRUB", 11, DIM, &"bold", 2))
	_waveform = Control.new()
	_waveform.custom_minimum_size = Vector2(0, 210)
	_waveform.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_waveform.mouse_filter = Control.MOUSE_FILTER_STOP
	_waveform.draw.connect(_draw_waveform)
	_waveform.gui_input.connect(_wave_input)
	column.add_child(_waveform)
	_time_label = UiKit.label("SCAN 00:00", 16, CYAN, &"bold")
	column.add_child(_time_label)

	var readings: HBoxContainer = HBoxContainer.new()
	readings.add_theme_constant_override("separation", 18)
	readings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(readings)
	var read_card: PanelContainer = _card()
	read_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	readings.add_child(read_card)
	var read_box: VBoxContainer = VBoxContainer.new()
	read_box.add_theme_constant_override("separation", 10)
	read_card.add_child(read_box)
	read_box.add_child(UiKit.caps("STRESS READOUT", 11, CYAN, &"bold", 2))
	_readout = UiKit.label("", 17, Color(0.86, 0.95, 0.96), &"medium")
	read_box.add_child(_readout)
	var spectrum_card: PanelContainer = _card()
	spectrum_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	readings.add_child(spectrum_card)
	var spectrum_box: VBoxContainer = VBoxContainer.new()
	spectrum_box.add_theme_constant_override("separation", 10)
	spectrum_card.add_child(spectrum_box)
	spectrum_box.add_child(UiKit.caps("PHONE BUS / LIVE SPECTRUM", 11, CYAN, &"bold", 2))
	_spectrum = UiKit.label("", 16, Color(0.82, 0.92, 0.95), &"medium")
	spectrum_box.add_child(_spectrum)
	_isolate = CheckButton.new()
	_isolate.text = "Isolate background audio"
	_isolate.toggled.connect(_on_isolate_toggled)
	spectrum_box.add_child(_isolate)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	_tag_choice = OptionButton.new()
	_tag_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for label: String in TAG_LABELS:
		_tag_choice.add_item(label)
	actions.add_child(_tag_choice)
	var tag_button: KitButton = KitButton.make("Tag evidence", &"target", KitButton.Variant.PRIMARY, _request_tag)
	tag_button.custom_minimum_size = Vector2(190, 48)
	actions.add_child(tag_button)
	_feedback = UiKit.label("", 14, DIM, &"medium")
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_feedback)


func _card() -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.style(Color(0.04, 0.08, 0.10), 10, 15, 13, Color(CYAN, 0.15), 1))
	return card


func _draw_waveform() -> void:
	if _waveform.size.x <= 1.0:
		return
	var area: Rect2 = Rect2(Vector2.ZERO, _waveform.size)
	_waveform.draw_rect(area, Color(0.012, 0.026, 0.037))
	for grid: int in range(1, 10):
		var x: float = area.size.x * float(grid) / 10.0
		_waveform.draw_line(Vector2(x, 0), Vector2(x, area.size.y), Color(CYAN, 0.08), 1.0)
	var mid: float = area.size.y * 0.5
	_waveform.draw_line(Vector2(0, mid), Vector2(area.size.x, mid), Color(CYAN, 0.20), 1.0)
	if _vsa == null:
		return
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(201):
		var fraction: float = float(i) / 200.0
		var read: Dictionary = _vsa.get_stress_readout(fraction * _duration)
		var tremor: float = (read.get("tremor_level", 0.0) as float)
		var pitch: float = (read.get("pitch_variance", 0.0) as float)
		var wave: float = sin(fraction * 158.0) * 0.65 + sin(fraction * 391.0) * 0.25 + sin(fraction * 49.0) * 0.1
		points.append(Vector2(fraction * area.size.x, mid - wave * (12.0 + 55.0 * tremor + 18.0 * pitch)))
	_waveform.draw_polyline(points, CYAN, 2.0, true)
	var cursor_x: float = _selected_time / _duration * area.size.x
	var window_width: float = maxf(12.0, area.size.x * 3.0 / _duration)
	_waveform.draw_rect(Rect2(cursor_x - window_width * 0.5, 0, window_width, area.size.y), Color(AMBER, 0.12))
	_waveform.draw_line(Vector2(cursor_x, 0), Vector2(cursor_x, area.size.y), AMBER, 2.0)
	_waveform.draw_rect(area, Color(CYAN, 0.25), false, 1.0)


func _wave_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
			if button.pressed:
				_select_at(button.position.x)
	elif event is InputEventMouseMotion and _dragging:
		_select_at((event as InputEventMouseMotion).position.x)


func _select_at(x: float) -> void:
	_selected_time = clampf(x / maxf(_waveform.size.x, 1.0) * _duration, 0.0, _duration)
	_update_readout()
	_waveform.queue_redraw()


func _update_readout() -> void:
	if _vsa == null:
		return
	var read: Dictionary = _vsa.get_stress_readout(_selected_time)
	_time_label.text = "SCAN %02d:%02d  /  %02d:%02d" % [int(_selected_time) / 60, int(_selected_time) % 60, int(_duration) / 60, int(_duration) % 60]
	_readout.text = "TREMOR   %3d%%\nPITCH       %3d%%\nPULSE       %d BPM\nLOOP        %s\nEMF         %s" % [
		roundi((read.get("tremor_level", 0.0) as float) * 100.0),
		roundi((read.get("pitch_variance", 0.0) as float) * 100.0),
		(read.get("estimated_bpm", 80) as int),
		"REPEATED" if read.get("is_loop", false) else "clear",
		"ANOMALY" if read.get("emf_detected", false) else "clear",
	]
	_update_spectrum()


func _update_spectrum() -> void:
	if _vsa == null:
		return
	var live_time: float = _vsa.current_playback_time
	_vsa.update_playback_time(_selected_time)
	var bands: Dictionary = _vsa.get_live_spectrum_bands()
	_vsa.update_playback_time(live_time)
	_spectrum.text = "VOICE       %s\nTREMOR   %s\nLOW FREQ %s\nAMBIENT   %s" % [
		_bar((bands.get("voice_band", 0.0) as float)),
		_bar((bands.get("micro_tremor", 0.0) as float)),
		_bar((bands.get("emf_hum", 0.0) as float)),
		_bar((bands.get("treble", 0.0) as float)),
	]


func _bar(value: float) -> String:
	var filled: int = clampi(roundi(value * 10.0), 0, 10)
	return "▰".repeat(filled) + "▱".repeat(10 - filled)


func _on_isolate_toggled(enabled: bool) -> void:
	if _vsa != null:
		_vsa.toggle_background_isolate(enabled)
		_update_spectrum()


func _request_tag() -> void:
	if _vsa == null:
		return
	var tag_type: StringName = TAG_TYPES[_tag_choice.selected]
	if tag_type == &"background_isolate" and not _isolate.button_pressed:
		_feedback.text = "Enable background isolation before tagging a room cue."
		_feedback.add_theme_color_override(&"font_color", AMBER)
		return
	_feedback.text = "Sending tag to dispatch host…"
	_feedback.add_theme_color_override(&"font_color", DIM)
	tag_requested.emit(_selected_time, tag_type)


func _on_tag_result(result: Dictionary) -> void:
	if not visible:
		return
	var success: bool = result.get("success", false) == true
	_feedback.text = "%s  %s" % ["EVIDENCE SAVED ·" if success else "TAG REJECTED ·", str(result.get("reason", "Unknown result"))]
	_feedback.add_theme_color_override(&"font_color", CYAN if success else AMBER)
