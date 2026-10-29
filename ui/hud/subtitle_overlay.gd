## Subtitles and sound captions, drawn above every HUD and below menus. Voiced call lines
## (EventBus.dialogue_node_changed) show with the speaker's name, except for the player holding the handset,
## whose phone UI already shows them. Sound captions describe audio-only cues: the phone ringing and the
## per-peer hallucinations.
## Size, background, speaker names and captions follow GameSettings.
## Authority: LOCAL
class_name SubtitleOverlay
extends CanvasLayer

const FONT_SIZES: Array[int] = [18, 24, 30, 38]
const MAX_CAPTIONS: int = 3
const HALLUCINATION_CAPTIONS: Dictionary[StringName, String] = {
	&"phantom_steps": "[Footsteps close behind you]",
	&"phantom_ring": "[A phone rings somewhere]",
	&"radio_whisper": "[Whispering over the radio]",
	&"shadow_figure": "[Something moves at the edge of the light]",
}

var _column: VBoxContainer
var _line_panel: PanelContainer
var _line_label: RichTextLabel
var _line_time: float = 0.0
var _line_text: String = ""
var _captions: Array[Dictionary] = []


func _ready() -> void:
	layer = 95   # Above every HUD (computer screen 49-50, notices 90), below menus (100).
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root: Control = Control.new()
	root.name = "Subtitles"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_column = VBoxContainer.new()
	_column.anchor_left = 0.15
	_column.anchor_right = 0.85
	_column.anchor_top = 1.0
	_column.anchor_bottom = 1.0
	_column.offset_top = -330.0
	_column.offset_bottom = -110.0
	_column.alignment = BoxContainer.ALIGNMENT_END
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 6)
	root.add_child(_column)
	_line_panel = _make_panel()
	_line_label = _line_panel.get_child(0) as RichTextLabel
	_column.add_child(_line_panel)
	_line_panel.visible = false
	EventBus.dialogue_node_changed.connect(_on_dialogue)
	EventBus.hallucination.connect(_on_hallucination)
	EventBus.call_ring.connect(func(_id: StringName, _data: CallData) -> void: caption("[Phone ringing]"))
	EventBus.call_ended.connect(func(_id: StringName, _reason: StringName) -> void: clear_line())
	GameSettings.changed.connect(_on_settings_changed)
	_apply_style()


## Spoken line from `speaker` (empty = unattributed). Replaces the previous line.
func show_line(speaker: String, text: String, duration: float = -1.0) -> void:
	if not GameSettings.subtitles_enabled or text.strip_edges() == "":
		return
	if _line_panel.visible and text == _line_text:
		return   # The same dialogue node re-synced: keep the timer running.
	_line_text = text
	var shown: String = text
	if GameSettings.subtitle_speaker_names and speaker != "":
		shown = "[color=#f5b544]%s:[/color] %s" % [speaker, text]
	_line_label.text = "[center]%s[/center]" % shown
	_line_time = duration if duration > 0.0 else reading_time(text)
	_line_panel.visible = true


## Sound caption such as "[Phone ringing]"; up to MAX_CAPTIONS stack above the spoken line.
func caption(text: String, duration: float = 3.0) -> void:
	if not GameSettings.subtitles_enabled or not GameSettings.sound_captions:
		return
	for entry: Dictionary in _captions:
		if entry["text"] == text:
			entry["time"] = duration
			return
	if _captions.size() >= MAX_CAPTIONS:
		var oldest: Dictionary = _captions.pop_front()
		var oldest_panel: Control = oldest["panel"]
		oldest_panel.queue_free()
	var panel: PanelContainer = _make_panel()
	(panel.get_child(0) as RichTextLabel).text = "[center][i]%s[/i][/center]" % tr(text)
	_column.add_child(panel)
	_column.move_child(panel, _column.get_child_count() - 2)
	_captions.append({"text": text, "time": duration, "panel": panel})
	_style_panel(panel)


func clear_line() -> void:
	_line_panel.visible = false
	_line_text = ""


func visible_line() -> String:
	return _line_label.get_parsed_text() if _line_panel.visible else ""


func caption_count() -> int:
	return _captions.size()


## Seconds a line stays up: enough to read it at a relaxed pace.
static func reading_time(text: String) -> float:
	return clampf(1.6 + text.length() * 0.055, 2.0, 8.0)


func _process(delta: float) -> void:
	if _line_panel.visible:
		_line_time -= delta
		if _line_time <= 0.0:
			clear_line()
	for i: int in range(_captions.size() - 1, -1, -1):
		var entry: Dictionary = _captions[i]
		var left: float = entry["time"]
		left -= delta
		entry["time"] = left
		if left <= 0.0:
			var expired: Control = entry["panel"]
			expired.queue_free()
			_captions.remove_at(i)


func _on_dialogue(_node_id: StringName, speaker: StringName, line: String, _choices: Array) -> void:
	if multiplayer.has_multiplayer_peer() and CallDirector.handset_owner_peer_id == multiplayer.get_unique_id():
		return
	show_line(speaker_name(speaker), line)


func _on_hallucination(kind: StringName, _position: Vector3) -> void:
	var text: String = HALLUCINATION_CAPTIONS.get(kind, "[Strange noise]")
	caption(text)


static func speaker_name(speaker: StringName) -> String:
	match speaker:
		&"caller":
			var call: CallData = CallDirector.active_call
			return call.caller_name if call != null and call.caller_name != "" else TranslationServer.translate("Caller")
		&"dispatcher":
			return TranslationServer.translate("Dispatcher")
		&"system", &"":
			return ""
	return TranslationServer.translate("Unknown voice")


func _on_settings_changed(_key: String) -> void:
	_apply_style()
	if not GameSettings.subtitles_enabled:
		_line_panel.visible = false


func _make_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(760, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	_style_panel(panel)
	return panel


func _style_panel(panel: PanelContainer) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, GameSettings.subtitle_background)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override(&"panel", style)
	var label: RichTextLabel = panel.get_child(0) as RichTextLabel
	var size: int = FONT_SIZES[clampi(GameSettings.subtitle_size, 0, FONT_SIZES.size() - 1)]
	for font_key: StringName in [&"normal_font_size", &"italics_font_size", &"bold_font_size"]:
		label.add_theme_font_size_override(font_key, size)
	label.add_theme_color_override(&"default_color", Color(0.96, 0.96, 0.94))
	label.add_theme_constant_override(&"outline_size", 6)
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))


func _apply_style() -> void:
	if _line_panel == null:
		return
	_style_panel(_line_panel)
	for entry: Dictionary in _captions:
		var panel: PanelContainer = entry["panel"]
		_style_panel(panel)
