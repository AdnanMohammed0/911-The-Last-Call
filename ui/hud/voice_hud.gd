## Voice indicators (top-right): a pill with the local transmit state (mic / radio / idle hint) and input
## level meter, and a stack of "who is talking" chips with a speaker or radio icon.
## Authority: LOCAL
class_name VoiceHud
extends Control

const MIC_COLOR: Color = Color(0.4, 0.92, 0.55)
const RADIO_COLOR: Color = Color(1.0, 0.72, 0.28)
const IDLE_COLOR: Color = Color(0.75, 0.77, 0.8, 0.7)

var _speaking: Dictionary[int, bool] = {}
var _radio: Dictionary[int, bool] = {}
var _pill: PanelContainer
var _icon: IconView
var _local_label: Label
var _level: ProgressBar
var _talkers: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 32)
	column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_pill = UiKit.panel(Color(0.03, 0.035, 0.045, 0.55), 20, 12, 6)
	_pill.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(_pill)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.add_child(row)
	_icon = IconView.make(&"mic", 16, IDLE_COLOR)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	_local_label = UiKit.caps("", 11, IDLE_COLOR, &"bold", 1)
	_local_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_local_label)
	_level = ProgressBar.new()
	_level.max_value = 1.0
	_level.show_percentage = false
	_level.custom_minimum_size = Vector2(46, 4)
	_level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level.add_theme_stylebox_override(&"fill", UiKit.style(MIC_COLOR, 2, 0, 0))
	row.add_child(_level)
	_talkers = VBoxContainer.new()
	_talkers.add_theme_constant_override(&"separation", 4)
	_talkers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_talkers)
	VoiceManager.speaking_changed.connect(_on_speaking_changed)
	VoiceManager.mode_changed.connect(func(_m: VoiceManager.Mode) -> void: _refresh())
	_refresh()


func _process(_delta: float) -> void:
	_level.value = clampf(inverse_lerp(-60.0, 0.0, VoiceManager.local_level_db), 0.0, 1.0)


func _on_speaking_changed(peer_id: int, speaking: bool, radio: bool) -> void:
	_speaking[peer_id] = speaking
	_radio[peer_id] = radio
	_refresh()


func _refresh() -> void:
	var me: int = multiplayer.get_unique_id()
	var colour: Color = IDLE_COLOR
	if VoiceManager.local_radio:
		_local_label.text = "RADIO"
		_icon.icon = &"radio"
		colour = RADIO_COLOR
	elif VoiceManager.local_transmitting:
		_local_label.text = "MIC LIVE"
		_icon.icon = &"mic"
		colour = MIC_COLOR
	elif not VoiceManager.has_microphone():
		_local_label.text = "NO MICROPHONE"
		_icon.icon = &"mic_off"
	else:
		var hint: String = "OPEN MIC" if VoiceManager.mode == VoiceManager.Mode.VOICE_ACTIVITY else "%s TO TALK" % GameSettings.binding_text(&"voice_ptt").to_upper()
		_local_label.text = "%s  ·  %s RADIO" % [hint, GameSettings.binding_text(&"radio_ptt").to_upper()]
		_icon.icon = &"mic"
	_icon.color = colour
	_local_label.add_theme_color_override(&"font_color", colour)
	for child: Node in _talkers.get_children():
		child.queue_free()
	for peer_id: int in _speaking:
		if not _speaking[peer_id] or peer_id == me:
			continue
		var radio: bool = _radio.get(peer_id, false)
		var chip: PanelContainer = UiKit.panel(Color(0.03, 0.035, 0.045, 0.6), 20, 12, 5)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_END
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 8)
		chip.add_child(line)
		line.add_child(IconView.make(&"radio" if radio else &"speaker", 16, RADIO_COLOR if radio else MIC_COLOR))
		line.add_child(UiKit.label(NetManager.get_player_name(peer_id), 15, GameTheme.TEXT, &"semibold"))
		_talkers.add_child(chip)
