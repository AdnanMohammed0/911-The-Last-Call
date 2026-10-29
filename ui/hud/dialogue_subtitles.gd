## Local captions for scripted dispatch dialogue while the CAD screen is closed.
class_name DialogueSubtitles
extends Control

var _speaker: Label
var _line: Label
var _seconds_left: float = 0.0
var _last_node: StringName = &""
var _last_line: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.name = "CaptionPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -380.0
	panel.offset_right = 380.0
	panel.offset_top = -148.0
	panel.offset_bottom = -76.0
	panel.add_theme_stylebox_override(&"panel", UiKit.style(Color(0.01, 0.015, 0.025, 0.88), 8, 20, 10))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 2)
	panel.add_child(column)
	_speaker = UiKit.caps("", 13, GameTheme.WARNING, &"bold", 1)
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_speaker)
	_line = UiKit.label("", 22, Color.WHITE, &"medium")
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_line.add_theme_constant_override(&"outline_size", 4)
	column.add_child(_line)
	_apply_size()
	visible = false
	EventBus.dialogue_node_changed.connect(_on_dialogue_node)
	EventBus.call_ended.connect(_on_call_ended)
	GameSettings.changed.connect(_on_setting_changed)


func _on_dialogue_node(node_id: StringName, speaker: StringName, line: String, _choices: Array) -> void:
	if not GameSettings.subtitles_enabled or line.is_empty():
		return
	if node_id == _last_node and line == _last_line:
		return
	_last_node = node_id
	_last_line = line
	_speaker.text = String(speaker).to_upper()
	_line.text = line
	_seconds_left = clampf(line.length() / 14.0, 4.0, 9.0)
	visible = true


func _on_call_ended(_call_id: StringName, _reason: StringName) -> void:
	_last_node = &""
	_last_line = ""
	_seconds_left = 0.0
	visible = false


func _on_setting_changed(key: String) -> void:
	if key == "subtitle_size":
		_apply_size()
	elif key == "subtitles_enabled" and not GameSettings.subtitles_enabled:
		visible = false


func _apply_size() -> void:
	var font_size: int = 22
	match GameSettings.subtitle_size:
		0: font_size = 17
		2: font_size = 28
	_line.add_theme_font_size_override(&"font_size", font_size)


func _process(delta: float) -> void:
	if _seconds_left <= 0.0:
		return
	_seconds_left = maxf(_seconds_left - delta, 0.0)
	if _seconds_left <= 0.0:
		visible = false
