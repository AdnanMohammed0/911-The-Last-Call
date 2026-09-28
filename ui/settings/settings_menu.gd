## Full-screen settings menu (Video · Audio · Voice · Controls) shared by the main menu and the pause menu.
## Every change applies immediately and is saved by GameSettings. Esc or "Back" closes it.
## Authority: LOCAL
class_name SettingsMenu
extends Control

signal closed()

const LABEL_WIDTH: float = 300.0
const CONTROL_WIDTH: float = 360.0

var _rebinding_action: StringName = &""
var _rebinding_button: Button
var _bind_buttons: Dictionary[StringName, Button] = {}
var _mic_bar: ProgressBar


## Opens the menu on top of `parent` (its own CanvasLayer so it covers any HUD).
static func open_over(parent: Node) -> SettingsMenu:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	parent.add_child(layer)
	var menu: SettingsMenu = SettingsMenu.new()
	layer.add_child(menu)
	menu.closed.connect(layer.queue_free)
	return menu


func _ready() -> void:
	add_to_group(DispatchTerminal.MODAL_GROUP)
	theme = GameSettings.ui_theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Blurred, darkened copy of whatever is behind (main menu scene or the paused game).
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.012, 0.015, 0.022)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var blur: ShaderMaterial = ShaderMaterial.new()
	blur.shader = UiKit.ACRYLIC
	blur.set_shader_parameter(&"blur_lod", 4.0)
	blur.set_shader_parameter(&"tint_amount", 0.7)
	dim.material = blur
	add_child(dim)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 150)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 70)
	add_child(margin)
	var panel: PanelContainer = UiKit.glass(Color(0.03, 0.034, 0.044), 16, 0, 0, 0.82, 3.5)
	margin.add_child(panel)
	var split: HBoxContainer = HBoxContainer.new()
	split.add_theme_constant_override(&"separation", 0)
	panel.add_child(split)

	# Side rail: title + one button per page.
	var rail: PanelContainer = PanelContainer.new()
	var rail_style: StyleBoxFlat = UiKit.style(Color(1, 1, 1, 0.025), 0, 22, 30)
	rail_style.corner_radius_top_left = 16
	rail_style.corner_radius_bottom_left = 16
	rail_style.border_color = Color(1, 1, 1, 0.06)
	rail_style.border_width_right = 1
	rail.add_theme_stylebox_override(&"panel", rail_style)
	rail.custom_minimum_size = Vector2(270, 0)
	split.add_child(rail)
	var rail_box: VBoxContainer = VBoxContainer.new()
	rail_box.add_theme_constant_override(&"separation", 6)
	rail.add_child(rail_box)
	rail_box.add_child(UiKit.caps("Options", 12, GameTheme.ACCENT))
	rail_box.add_child(UiKit.label("Settings", 38, GameTheme.TEXT, &"black_italic"))
	rail_box.add_child(UiKit.spacer(18))

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override(&"separation", 14)
	split.add_child(UiKit.margin(content, 40, 30, 40, 30))
	(content.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header: HBoxContainer = HBoxContainer.new()
	content.add_child(header)
	var page_title: Label = UiKit.label("Video", 28, GameTheme.TEXT, &"bold")
	page_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(page_title)
	var back: KitButton = KitButton.make("Back", &"back", KitButton.Variant.SUBTLE, close)
	back.custom_minimum_size = Vector2(130, 44)
	header.add_child(back)
	content.add_child(UiKit.separator())

	var tabs: TabContainer = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tabs_visible = false
	content.add_child(tabs)
	_video_tab(_page(tabs, "Video"))
	_audio_tab(_page(tabs, "Audio"))
	_voice_tab(_page(tabs, "Voice"))
	_controls_tab(_page(tabs, "Controls"))

	var pages: Array[Array] = [["Video", &"monitor"], ["Audio", &"volume"], ["Voice", &"mic"], ["Controls", &"keyboard"]]
	var rail_buttons: Array[KitButton] = []
	for i: int in pages.size():
		var page: Array = pages[i]
		var page_name: String = page[0]
		var icon_name: StringName = page[1]
		var entry: KitButton = KitButton.make(page_name, icon_name, KitButton.Variant.GHOST)
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.custom_minimum_size = Vector2(0, 48)
		entry.icon_size = 20.0
		entry.toggle_mode = true
		entry.add_theme_font_size_override(&"font_size", 18)
		rail_box.add_child(entry)
		rail_buttons.append(entry)
		entry.pressed.connect(func() -> void:
			tabs.current_tab = i
			page_title.text = page_name
			for other: KitButton in rail_buttons:
				other.set_pressed_no_signal(other == entry)
				other.variant = KitButton.Variant.SUBTLE if other == entry else KitButton.Variant.GHOST
				other.icon_tint = GameTheme.ACCENT if other == entry else Color(0, 0, 0, 0)
				other.apply_variant())
	rail_box.add_child(UiKit.expand(Control.new(), false, true))
	rail_box.add_child(UiKit.paragraph("Changes apply instantly and are saved automatically.", 13, GameTheme.TEXT_FAINT))
	rail_buttons[0].pressed.emit()
	back.grab_focus.call_deferred()


func close() -> void:
	_cancel_rebind()
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if _rebinding_action != &"":
		_capture_binding(event)
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _mic_bar != null and is_instance_valid(_mic_bar):
		_mic_bar.value = clampf(inverse_lerp(-60.0, 0.0, VoiceManager.local_level_db), 0.0, 1.0)


# --- Layout helpers -----------------------------------------------------------------------------

func _page(tabs: TabContainer, page_name: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = page_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var inner: MarginContainer = MarginContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override(&"margin_right", 24)
	inner.add_theme_constant_override(&"margin_top", 8)
	scroll.add_child(inner)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override(&"separation", 6)
	inner.add_child(rows)
	return rows


func _row(parent: Container, text: String, control: Control, hint: String = "") -> void:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override(&"panel", UiKit.style(Color(1, 1, 1, 0.03), 8, 18, 10))
	parent.add_child(card)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	card.add_child(row)
	var label: Label = UiKit.label(text, 17, GameTheme.TEXT, &"medium")
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	control.custom_minimum_size = Vector2(CONTROL_WIDTH, control.custom_minimum_size.y)
	row.add_child(control)
	if hint != "":
		var hint_label: Label = Label.new()
		hint_label.text = hint
		hint_label.add_theme_color_override(&"font_color", GameTheme.TEXT_DIM)
		hint_label.add_theme_font_size_override(&"font_size", 15)
		hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(hint_label)


func _section(parent: Container, text: String) -> void:
	if parent.get_child_count() > 0:
		parent.add_child(UiKit.spacer(14))
	parent.add_child(UiKit.caps(text, 12, GameTheme.ACCENT))


func _option(items: PackedStringArray, selected: int, on_select: Callable) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	for item: String in items:
		option.add_item(item)
	option.select(selected)
	option.item_selected.connect(on_select)
	return option


func _toggle(value: bool, on_toggle: Callable) -> CheckButton:
	var toggle: CheckButton = CheckButton.new()
	toggle.button_pressed = value
	toggle.toggled.connect(on_toggle)
	return toggle


## Slider with a live value readout.
func _slider(min_value: float, max_value: float, step: float, value: float, format: String, on_change: Callable) -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 16)
	var slider: HSlider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(slider)
	var readout: Label = Label.new()
	readout.custom_minimum_size = Vector2(64, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.text = format % value
	box.add_child(readout)
	slider.value_changed.connect(func(new_value: float) -> void:
		readout.text = format % new_value
		on_change.call(new_value))
	return box


# --- Tabs -------------------------------------------------------------------------------------------

func _video_tab(page: VBoxContainer) -> void:
	_section(page, "Display")
	_row(page, "Window mode", _option(GameSettings.WINDOW_MODE_NAMES, GameSettings.window_mode,
		func(index: int) -> void: GameSettings.set_value("window_mode", index)))
	_row(page, "V-Sync", _toggle(GameSettings.vsync, func(on: bool) -> void: GameSettings.set_value("vsync", on)))
	var caps: Array[int] = [0, 30, 60, 120, 144, 165, 240]
	var cap_names: PackedStringArray = PackedStringArray()
	for cap: int in caps:
		cap_names.append("Unlimited" if cap == 0 else "%d FPS" % cap)
	_row(page, "Frame rate limit", _option(cap_names, maxi(caps.find(GameSettings.max_fps), 0),
		func(index: int) -> void: GameSettings.set_value("max_fps", caps[index])))
	_row(page, "Show FPS counter", _toggle(GameSettings.show_fps, func(on: bool) -> void: GameSettings.set_value("show_fps", on)))

	_section(page, "Graphics")
	_row(page, "Quality preset", _option(GameSettings.QUALITY_NAMES, GameSettings.quality,
		func(index: int) -> void: GameSettings.set_value("quality", index)),
		"Shadows, global illumination, fog, anti-aliasing")
	_row(page, "Render scale", _slider(50, 100, 5, GameSettings.render_scale * 100.0, "%d%%",
		func(value: float) -> void: GameSettings.set_value("render_scale", value / 100.0)), "Below 100% uses FSR 2 upscaling")
	_row(page, "Field of view", _slider(65, 100, 1, GameSettings.fov, "%d°",
		func(value: float) -> void: GameSettings.set_value("fov", value)))
	_row(page, "Brightness", _slider(50, 200, 5, GameSettings.brightness * 100.0, "%d%%",
		func(value: float) -> void: GameSettings.set_value("brightness", value / 100.0)))


func _audio_tab(page: VBoxContainer) -> void:
	_section(page, "Volume")
	for bus: StringName in GameSettings.AUDIO_BUSES:
		var bus_name: StringName = bus
		var volume: float = GameSettings.volumes.get(bus, 1.0)
		_row(page, GameSettings.AUDIO_BUSES[bus], _slider(0, 100, 1, volume * 100.0, "%d%%",
			func(value: float) -> void: GameSettings.set_volume(bus_name, value / 100.0)))


func _voice_tab(page: VBoxContainer) -> void:
	_section(page, "Microphone")
	var devices: PackedStringArray = VoiceManager.get_input_devices()
	var current: int = maxi(devices.find(VoiceManager.get_input_device()), 0)
	_row(page, "Input device", _option(devices, current, func(index: int) -> void:
		VoiceManager.set_input_device(devices[index])
		GameSettings.save_settings()))
	_row(page, "Transmit mode", _option(PackedStringArray(["Open mic (voice activity)", "Push to talk"]),
		0 if VoiceManager.mode == VoiceManager.Mode.VOICE_ACTIVITY else 1,
		func(index: int) -> void:
			if (index == 1) != (VoiceManager.mode != VoiceManager.Mode.VOICE_ACTIVITY):
				VoiceManager.toggle_mode()
			GameSettings.save_settings()))
	_row(page, "Automatic gain", _toggle(VoiceManager.auto_gain, func(on: bool) -> void:
		VoiceManager.set_auto_gain(on)
		GameSettings.save_settings()), "Boosts quiet microphones")
	_mic_bar = ProgressBar.new()
	_mic_bar.max_value = 1.0
	_mic_bar.show_percentage = false
	_mic_bar.custom_minimum_size = Vector2(0, 10)
	_mic_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row(page, "Input level", _mic_bar)
	_row(page, "Hear myself", _toggle(VoiceManager.loopback, func(on: bool) -> void: VoiceManager.loopback = on), "Mic test")


func _controls_tab(page: VBoxContainer) -> void:
	_section(page, "Mouse")
	_row(page, "Sensitivity", _slider(0.1, 3.0, 0.05, GameSettings.mouse_sensitivity, "%.2f",
		func(value: float) -> void: GameSettings.set_value("mouse_sensitivity", value)))
	_row(page, "Aim sensitivity", _slider(0.2, 1.5, 0.05, GameSettings.ads_sensitivity, "%.2f",
		func(value: float) -> void: GameSettings.set_value("ads_sensitivity", value)), "Multiplier while aiming down sights")
	_row(page, "Invert vertical look", _toggle(GameSettings.invert_y, func(on: bool) -> void: GameSettings.set_value("invert_y", on)))
	_row(page, "Toggle crouch", _toggle(GameSettings.crouch_toggle, func(on: bool) -> void: GameSettings.set_value("crouch_toggle", on)))

	_section(page, "Key bindings")
	for entry: Array in GameSettings.ACTIONS:
		var action: StringName = entry[0]
		if not InputMap.has_action(action):
			continue
		var button: Button = Button.new()
		button.text = GameSettings.binding_text(action)
		button.pressed.connect(_start_rebind.bind(action, button))
		_bind_buttons[action] = button
		var label: String = entry[1]
		_row(page, label, button)
	var reset: Button = Button.new()
	reset.text = "Reset key bindings to defaults"
	reset.pressed.connect(func() -> void:
		GameSettings.reset_keybinds()
		_refresh_bindings())
	var reset_row: HBoxContainer = HBoxContainer.new()
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(LABEL_WIDTH + 24, 0)
	reset_row.add_child(spacer)
	reset_row.add_child(reset)
	page.add_child(reset_row)


# --- Rebinding --------------------------------------------------------------------------------------

func _start_rebind(action: StringName, button: Button) -> void:
	_cancel_rebind()
	_rebinding_action = action
	_rebinding_button = button
	button.text = "Press a key or mouse button…  (Esc to cancel)"
	button.add_theme_color_override(&"font_color", GameTheme.ACCENT)


func _capture_binding(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if key != null and key.pressed and not key.echo:
		get_viewport().set_input_as_handled()
		if key.physical_keycode == KEY_ESCAPE:
			_cancel_rebind()
			return
		var bound: InputEventKey = InputEventKey.new()
		bound.physical_keycode = key.physical_keycode
		_finish_rebind(bound)
	elif mouse != null and mouse.pressed:
		get_viewport().set_input_as_handled()
		var bound_mouse: InputEventMouseButton = InputEventMouseButton.new()
		bound_mouse.button_index = mouse.button_index
		_finish_rebind(bound_mouse)


func _finish_rebind(event: InputEvent) -> void:
	var action: StringName = _rebinding_action
	_rebinding_action = &""
	if _rebinding_button != null:
		_rebinding_button.remove_theme_color_override(&"font_color")
	_rebinding_button = null
	GameSettings.rebind(action, event)
	_refresh_bindings()


func _cancel_rebind() -> void:
	if _rebinding_button != null and is_instance_valid(_rebinding_button):
		_rebinding_button.remove_theme_color_override(&"font_color")
	_rebinding_action = &""
	_rebinding_button = null
	_refresh_bindings()


func _refresh_bindings() -> void:
	for action: StringName in _bind_buttons:
		var button: Button = _bind_buttons[action]
		if is_instance_valid(button):
			button.text = GameSettings.binding_text(action)
