## In-game pause menu (Esc): the game keeps running behind a blurred screen (online co-op). Torn ink sidebar
## with the session state and brush-stroke actions (resume, settings, leave, quit); a glass "Comms" card on
## the right for the voice mode, microphone, input level and mic test.
## Authority: LOCAL (only the owning player's HUD is visible)
class_name PauseMenu
extends Control

const TORN_EDGE: Shader = preload("res://ui/shaders/torn_edge.gdshader")

@export var player: Player

var _resume_button: BrushButton
var _leave_button: BrushButton
var _quit_button: BrushButton
var _settings_button: BrushButton
var _session_label: Label
var _objective_label: Label
var _voice_mode_button: KitButton
var _mic_device_option: OptionButton
var _mic_level_bar: ProgressBar
var _mic_status_label: Label
var _auto_gain_check: CheckButton
var _hear_myself_check: CheckButton
var _sidebar: Control
var _comms: Control


func _ready() -> void:
	theme = GameSettings.ui_theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_resume_button.pressed.connect(close)
	_settings_button.pressed.connect(_on_settings_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_voice_mode_button.pressed.connect(_on_voice_mode_pressed)
	_mic_device_option.item_selected.connect(_on_mic_device_selected)
	_auto_gain_check.toggled.connect(VoiceManager.set_auto_gain)
	_hear_myself_check.toggled.connect(func(on: bool) -> void: VoiceManager.loopback = on)


func _build() -> void:
	var blur: ColorRect = ColorRect.new()
	blur.color = Color(0.015, 0.018, 0.025)
	blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = UiKit.ACRYLIC
	material.set_shader_parameter(&"blur_lod", 3.6)
	material.set_shader_parameter(&"tint_amount", 0.5)
	blur.material = material
	add_child(blur)

	_sidebar = Control.new()
	_sidebar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sidebar)
	var ink: ColorRect = ColorRect.new()
	ink.anchor_bottom = 1.0
	ink.offset_right = 900
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink_material: ShaderMaterial = ShaderMaterial.new()
	ink_material.shader = TORN_EDGE
	ink_material.set_shader_parameter(&"edge", 0.62)
	ink.material = ink_material
	_sidebar.add_child(ink)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	column.anchor_bottom = 1.0
	column.offset_left = 96
	column.offset_top = 110
	column.offset_right = 96 + 520
	column.offset_bottom = -60
	_sidebar.add_child(column)
	column.add_child(UiKit.caps("Game paused", 13, GameTheme.ACCENT))
	column.add_child(UiKit.label("STAND BY", 76, GameTheme.TEXT, &"black_italic"))
	_session_label = UiKit.label("", 16, GameTheme.TEXT_DIM, &"medium")
	column.add_child(_session_label)
	_objective_label = UiKit.paragraph("", 15, GameTheme.TEXT_FAINT)
	_objective_label.custom_minimum_size = Vector2(440, 0)
	column.add_child(_objective_label)
	column.add_child(UiKit.spacer(36))
	_resume_button = _brush(column, "Resume")
	_settings_button = _brush(column, "Settings")
	_leave_button = _brush(column, "Leave to main menu")
	_quit_button = _brush(column, "Quit to desktop")
	column.add_child(UiKit.expand(Control.new(), false, true))
	var hint: HBoxContainer = HBoxContainer.new()
	hint.add_theme_constant_override(&"separation", 10)
	hint.add_child(UiKit.key_cap("Esc", 12))
	hint.add_child(UiKit.caps("Resume", 12, GameTheme.TEXT_DIM, &"bold", 2))
	column.add_child(hint)

	_comms = _build_comms()
	add_child(_comms)


func _brush(parent: Container, text: String) -> BrushButton:
	var button: BrushButton = BrushButton.make(text, Callable(), 28)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(button)
	return button


func _build_comms() -> Control:
	var panel: PanelContainer = UiKit.glass(Color(0.035, 0.04, 0.05), 16, 26, 22, 0.72)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 90)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(440, 0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	panel.add_child(box)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 10)
	box.add_child(head)
	head.add_child(IconView.make(&"headset", 24, GameTheme.SIREN_BLUE))
	var titles: VBoxContainer = VBoxContainer.new()
	titles.add_theme_constant_override(&"separation", -2)
	head.add_child(titles)
	titles.add_child(UiKit.caps("Comms", 11, GameTheme.SIREN_BLUE))
	titles.add_child(UiKit.label("Voice & microphone", 22, GameTheme.TEXT, &"bold"))
	box.add_child(UiKit.separator())
	_voice_mode_button = KitButton.make("Voice: open mic", &"mic", KitButton.Variant.SUBTLE)
	_voice_mode_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_voice_mode_button.custom_minimum_size = Vector2(0, 44)
	box.add_child(_voice_mode_button)
	box.add_child(UiKit.caps("Input device", 11, GameTheme.TEXT_DIM))
	_mic_device_option = OptionButton.new()
	_mic_device_option.custom_minimum_size = Vector2(0, 42)
	_mic_device_option.clip_text = true
	box.add_child(_mic_device_option)
	box.add_child(UiKit.caps("Input level", 11, GameTheme.TEXT_DIM))
	_mic_level_bar = ProgressBar.new()
	_mic_level_bar.max_value = 1.0
	_mic_level_bar.show_percentage = false
	_mic_level_bar.custom_minimum_size = Vector2(0, 8)
	_mic_level_bar.add_theme_stylebox_override(&"fill", UiKit.style(GameTheme.SUCCESS, 4, 0, 0))
	box.add_child(_mic_level_bar)
	_mic_status_label = UiKit.label("", 12, GameTheme.TEXT_FAINT, &"medium")
	box.add_child(_mic_status_label)
	_auto_gain_check = CheckButton.new()
	_auto_gain_check.text = "Automatic gain"
	box.add_child(_auto_gain_check)
	_hear_myself_check = CheckButton.new()
	_hear_myself_check.text = "Hear myself (mic test)"
	box.add_child(_hear_myself_check)
	return panel


func _process(_delta: float) -> void:
	if not visible:
		return
	_mic_level_bar.value = clampf(inverse_lerp(-60.0, 0.0, VoiceManager.local_level_db), 0.0, 1.0)
	var state: String = "sending" if VoiceManager.local_transmitting else "quiet"
	_mic_status_label.text = "MIC %.0f dB  ·  NOISE %.0f dB  ·  GAIN +%.0f dB  ·  %s" % [
		VoiceManager.raw_level_db, VoiceManager.noise_floor_db, VoiceManager.current_gain_db, state.to_upper()]


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.is_multiplayer_authority():
		return
	if event.is_action_pressed(&"ui_cancel"):
		if not visible and not get_tree().get_nodes_in_group(DispatchTerminal.MODAL_GROUP).is_empty():
			return
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	player.set_input_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var leave_text: String = "Stop hosting" if NetManager.is_host() else "Leave to main menu"
	_leave_button.text = (leave_text if NetManager.is_online() else "Back to main menu").to_upper()
	_session_label.text = ("Hosting · %d officers on shift" % NetManager.roster.size()) if NetManager.is_host() \
		else ("Connected as %s" % NetManager.get_player_name(NetManager.get_local_peer_id()) if NetManager.is_online() else "Offline shift")
	var objective: String = MissionDirector.objective_text
	_objective_label.text = objective if not objective.is_empty() else "Shift %d · calls handled %d · public trust %d" % [
		MissionDirector.shift_number, MissionDirector.calls_handled, MissionDirector.public_trust]
	if NetManager.is_host() and NetManager.is_online():
		_objective_label.text += "\nStopping ends the shift for everyone."
	_voice_mode_button.text = "Voice: %s" % VoiceManager.get_mode_text()
	_mic_device_option.clear()
	var current: String = VoiceManager.get_input_device()
	for device: String in VoiceManager.get_input_devices():
		_mic_device_option.add_item(device)
		if device == current:
			_mic_device_option.select(_mic_device_option.item_count - 1)
	_auto_gain_check.set_pressed_no_signal(VoiceManager.auto_gain)
	_hear_myself_check.set_pressed_no_signal(VoiceManager.loopback)
	_resume_button.grab_focus()
	UiKit.stagger(_sidebar.get_child(1) as Control, 0.03)
	UiKit.reveal(_comms, 0.1, Vector2(24, 0))


func close() -> void:
	visible = false
	if VoiceManager.loopback:
		VoiceManager.loopback = false
		_hear_myself_check.set_pressed_no_signal(false)
	player.set_input_enabled(true)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_settings_pressed() -> void:
	var menu: SettingsMenu = SettingsMenu.open_over(self)
	visible = false
	menu.closed.connect(func() -> void:
		visible = true
		_settings_button.grab_focus())


func _on_mic_device_selected(index: int) -> void:
	VoiceManager.set_input_device(_mic_device_option.get_item_text(index))


func _on_voice_mode_pressed() -> void:
	VoiceManager.toggle_mode()
	_voice_mode_button.text = "Voice: %s" % VoiceManager.get_mode_text()


func _on_leave_pressed() -> void:
	NetManager.leave_to_menu()


func _on_quit_pressed() -> void:
	NetManager.leave_game()
	get_tree().quit()
