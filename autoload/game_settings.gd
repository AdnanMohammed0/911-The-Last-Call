## Player-facing settings saved to user://settings.cfg: video (window mode, V-Sync, FPS cap, quality preset,
## render scale, FOV, brightness), audio (bus volumes, output device), controls (sensitivity, ADS sensitivity,
## invert Y, crouch / sprint / aim toggles, key bindings), voice, language, accessibility (subtitles and sound
## captions, colour-vision assist, interface scale, reduced flashing, bodycam effect strength, jump-scare
## stingers, apparitions) and privacy (telemetry/crash reporting opt-in).
## Owns the subtitle overlay and the colour-vision filter layer.
## Applies graphics quality to every WorldEnvironment that enters the tree, and installs the shared UI theme on the root window.
## Authority: LOCAL
extends Node

enum WindowMode { WINDOWED, BORDERLESS, FULLSCREEN }
enum Quality { LOW, MEDIUM, HIGH, ULTRA }
enum ColorBlind { OFF, PROTANOPIA, DEUTERANOPIA, TRITANOPIA }
enum ScareStingers { FULL, REDUCED, OFF }

const PATH: String = "user://settings.cfg"
const QUALITY_NAMES: PackedStringArray = ["Low", "Medium", "High", "Ultra"]
const WINDOW_MODE_NAMES: PackedStringArray = ["Windowed", "Borderless fullscreen", "Exclusive fullscreen"]
const SUBTITLE_SIZE_NAMES: PackedStringArray = ["Small", "Normal", "Large", "Extra large"]
const COLOR_MODE_NAMES: PackedStringArray = ["Standard", "Blue / orange", "High contrast"]
const COLORBLIND_NAMES: PackedStringArray = ["Off", "Protanopia (red-weak)", "Deuteranopia (green-weak)", "Tritanopia (blue-weak)"]
const SCARE_NAMES: PackedStringArray = ["Full", "Reduced", "Off"]
## Reduced jump-scare stingers play this much quieter, and the strongest ones are skipped.
const REDUCED_SCARE_DB: float = -9.0
const REDUCED_SCARE_MAX_INTENSITY: float = 0.75
const COLORBLIND_SHADER: Shader = preload("res://ui/shaders/colorblind.gdshader")
const AUDIO_BUSES: Dictionary[StringName, String] = {
	&"Master": "Master volume", &"Music": "Music", &"SFX": "Effects",
	&"VoiceProximity": "Voice chat", &"VoiceRadio": "Radio", &"Phone": "Phone calls",
}
## Rebindable actions in the order the Controls tab lists them.
const ACTIONS: Array[Array] = [
	[&"move_forward", "Move forward"], [&"move_back", "Move back"], [&"move_left", "Move left"], [&"move_right", "Move right"],
	[&"jump", "Jump"], [&"sprint", "Sprint"], [&"crouch", "Crouch"], [&"lean_left", "Lean left"], [&"lean_right", "Lean right"],
	[&"interact", "Interact"], [&"shout", "Shout \"Police, hands up!\""], [&"door_peek", "Peek door"], [&"door_kick", "Kick door"], [&"flashlight", "Flashlight"],
	[&"fire", "Fire"], [&"aim", "Aim down sights"], [&"reload", "Reload"],
	[&"weapon_primary", "Primary weapon"], [&"weapon_sidearm", "Sidearm"], [&"weapon_swap", "Swap weapon"], [&"drop_weapon", "Drop weapon"],
	[&"voice_ptt", "Push to talk"], [&"radio_ptt", "Radio"],
]

## Privacy settings (synced with TelemetrySettings)
var telemetry_enabled: bool = false
var crash_reporting_enabled: bool = false
var telemetry_consent_given: bool = false

signal changed(key: String)

var window_mode: WindowMode = WindowMode.BORDERLESS
var vsync: bool = true
var max_fps: int = 0
var quality: Quality = Quality.HIGH
var render_scale: float = 1.0
var fov: float = 80.0
var brightness: float = 1.0
var volumes: Dictionary[StringName, float] = {}
var mouse_sensitivity: float = 1.0
var ads_sensitivity: float = 0.7
var invert_y: bool = false
var crouch_toggle: bool = false
var show_fps: bool = false
var output_device: String = "Default"
var subtitles_enabled: bool = true
var subtitle_size: int = 1
var color_mode: int = 0
var reduced_horror_effects: bool = false
## UI language, applied by the Localization autoload (see data/localization/ui_*.loc).
var language: String = "en"
var toggle_sprint: bool = false
var toggle_aim: bool = false

# --- Accessibility (subtitles_enabled, subtitle_size, color_mode, reduced_horror_effects are above) ---
var subtitle_background: float = 0.6
var subtitle_speaker_names: bool = true
var sound_captions: bool = true
var colorblind_mode: ColorBlind = ColorBlind.OFF
var colorblind_strength: float = 1.0
## Multiplies every 2D interface (window content scale).
var ui_scale: float = 1.0
## Stops strobing and flickering lights (faulty fluorescents, ringing phone lamps, ON AIR blink).
var reduce_flashing: bool = false
## 0..1 strength of the bodycam film look and the sanity distortion.
var screen_effects: float = 1.0
var scare_stingers: ScareStingers = ScareStingers.FULL
## Shadow-figure hallucinations; off turns them into a sound cue only.
var apparitions: bool = true

## Subtitles and sound captions (always present; hidden when there is nothing to show).
var subtitle_overlay: SubtitleOverlay

## Shared UI theme. Controls under a CanvasLayer do not inherit the window theme, so menus assign it.
var ui_theme: Theme

var _default_events: Dictionary[StringName, Array] = {}
var _fps_label: Label
var _colorblind_layer: CanvasLayer
var _colorblind_rect: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for entry: Array in ACTIONS:
		var action: StringName = entry[0]
		if InputMap.has_action(action):
			_default_events[action] = InputMap.action_get_events(action).duplicate()
	for bus: StringName in AUDIO_BUSES:
		volumes[bus] = 1.0
	load_settings()
	GamepadControls.install_defaults()
	ui_theme = GameTheme.build()
	if DisplayServer.get_name() != "headless":
		get_tree().root.theme = ui_theme
	get_tree().node_added.connect(_on_node_added)
	subtitle_overlay = SubtitleOverlay.new()
	subtitle_overlay.name = "SubtitleOverlay"
	add_child(subtitle_overlay)
	_colorblind_layer = CanvasLayer.new()
	_colorblind_layer.name = "ColorVision"
	_colorblind_layer.layer = 126
	add_child(_colorblind_layer)
	_colorblind_rect = ColorRect.new()
	_colorblind_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_colorblind_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var colorblind_material: ShaderMaterial = ShaderMaterial.new()
	colorblind_material.shader = COLORBLIND_SHADER
	_colorblind_rect.material = colorblind_material
	_colorblind_layer.add_child(_colorblind_rect)
	apply_all()


# --- Persistence ---------------------------------------------------------------------------

func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(PATH) != OK:
		return
	window_mode = config.get_value("video", "window_mode", window_mode)
	vsync = config.get_value("video", "vsync", vsync)
	max_fps = config.get_value("video", "max_fps", max_fps)
	quality = config.get_value("video", "quality", quality)
	render_scale = config.get_value("video", "render_scale", render_scale)
	fov = config.get_value("video", "fov", fov)
	brightness = config.get_value("video", "brightness", brightness)
	show_fps = config.get_value("video", "show_fps", show_fps)
	output_device = config.get_value("audio", "output_device", output_device)
	subtitles_enabled = config.get_value("accessibility", "subtitles_enabled", subtitles_enabled)
	var stored_subtitle_size: int = config.get_value("accessibility", "subtitle_size", subtitle_size)
	var stored_color_mode: int = config.get_value("accessibility", "color_mode", color_mode)
	subtitle_size = clampi(stored_subtitle_size, 0, SUBTITLE_SIZE_NAMES.size() - 1)
	color_mode = clampi(stored_color_mode, 0, 2)
	reduced_horror_effects = config.get_value("accessibility", "reduced_horror_effects", reduced_horror_effects)
	for bus: StringName in AUDIO_BUSES:
		volumes[bus] = config.get_value("audio", String(bus), 1.0)
	mouse_sensitivity = config.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	ads_sensitivity = config.get_value("controls", "ads_sensitivity", ads_sensitivity)
	invert_y = config.get_value("controls", "invert_y", invert_y)
	crouch_toggle = config.get_value("controls", "crouch_toggle", crouch_toggle)
	toggle_sprint = config.get_value("controls", "toggle_sprint", toggle_sprint)
	toggle_aim = config.get_value("controls", "toggle_aim", toggle_aim)
	subtitle_background = config.get_value("accessibility", "subtitle_background", subtitle_background)
	subtitle_speaker_names = config.get_value("accessibility", "subtitle_speaker_names", subtitle_speaker_names)
	sound_captions = config.get_value("accessibility", "sound_captions", sound_captions)
	colorblind_mode = config.get_value("accessibility", "colorblind_mode", colorblind_mode)
	colorblind_strength = config.get_value("accessibility", "colorblind_strength", colorblind_strength)
	ui_scale = config.get_value("accessibility", "ui_scale", ui_scale)
	reduce_flashing = config.get_value("accessibility", "reduce_flashing", reduce_flashing)
	screen_effects = config.get_value("accessibility", "screen_effects", screen_effects)
	scare_stingers = config.get_value("accessibility", "scare_stingers", scare_stingers)
	apparitions = config.get_value("accessibility", "apparitions", apparitions)
	if config.has_section("keybinds"):
		for key: String in config.get_section_keys("keybinds"):
			var events: Array = config.get_value("keybinds", key, [])
			var action: StringName = StringName(key)
			if not InputMap.has_action(action):
				continue
			InputMap.action_erase_events(action)
			for event: Variant in events:
				if not (event is InputEvent):
					continue
				var event_object: Object = event
				var input_event: InputEvent = event_object as InputEvent
				if input_event != null:
					InputMap.action_add_event(action, input_event)
	if config.has_section("voice"):
		var mic: String = config.get_value("voice", "input_device", "")
		if mic != "":
			VoiceManager.set_input_device(mic)
		var auto_gain: bool = config.get_value("voice", "auto_gain", VoiceManager.auto_gain)
		VoiceManager.set_auto_gain(auto_gain)
		VoiceManager.manual_gain_db = config.get_value("voice", "mic_gain_db", VoiceManager.manual_gain_db)
		var push_to_talk: bool = config.get_value("voice", "push_to_talk", false)
		if push_to_talk != (VoiceManager.mode != VoiceManager.Mode.VOICE_ACTIVITY):
			VoiceManager.toggle_mode()

	if config.has_section("language"):
		language = config.get_value("language", "locale", language)

	if config.has_section("privacy"):
		telemetry_enabled = config.get_value("privacy", "telemetry_enabled", false)
		crash_reporting_enabled = config.get_value("privacy", "crash_reporting_enabled", false)
		telemetry_consent_given = config.get_value("privacy", "consent_given", false)

	# Sync with TelemetrySettings if available
	if TelemetryManager.instance != null and TelemetryManager.instance.settings != null:
		var ts: TelemetrySettings = TelemetryManager.instance.settings
		ts.has_consented = telemetry_consent_given
		ts.telemetry_enabled = telemetry_enabled
		ts.crash_reporting_enabled = crash_reporting_enabled


func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("video", "window_mode", window_mode)
	config.set_value("video", "vsync", vsync)
	config.set_value("video", "max_fps", max_fps)
	config.set_value("video", "quality", quality)
	config.set_value("video", "render_scale", render_scale)
	config.set_value("video", "fov", fov)
	config.set_value("video", "brightness", brightness)
	config.set_value("video", "show_fps", show_fps)
	config.set_value("audio", "output_device", output_device)
	config.set_value("accessibility", "subtitles_enabled", subtitles_enabled)
	config.set_value("accessibility", "subtitle_size", subtitle_size)
	config.set_value("accessibility", "color_mode", color_mode)
	config.set_value("accessibility", "reduced_horror_effects", reduced_horror_effects)
	for bus: StringName in volumes:
		config.set_value("audio", String(bus), volumes[bus])
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("controls", "ads_sensitivity", ads_sensitivity)
	config.set_value("controls", "invert_y", invert_y)
	config.set_value("controls", "crouch_toggle", crouch_toggle)
	config.set_value("controls", "toggle_sprint", toggle_sprint)
	config.set_value("controls", "toggle_aim", toggle_aim)
	config.set_value("accessibility", "subtitle_background", subtitle_background)
	config.set_value("accessibility", "subtitle_speaker_names", subtitle_speaker_names)
	config.set_value("accessibility", "sound_captions", sound_captions)
	config.set_value("accessibility", "colorblind_mode", colorblind_mode)
	config.set_value("accessibility", "colorblind_strength", colorblind_strength)
	config.set_value("accessibility", "ui_scale", ui_scale)
	config.set_value("accessibility", "reduce_flashing", reduce_flashing)
	config.set_value("accessibility", "screen_effects", screen_effects)
	config.set_value("accessibility", "scare_stingers", scare_stingers)
	config.set_value("accessibility", "apparitions", apparitions)
	for entry: Array in ACTIONS:
		var action: StringName = entry[0]
		if InputMap.has_action(action):
			config.set_value("keybinds", String(action), InputMap.action_get_events(action))
	config.set_value("voice", "input_device", VoiceManager.get_input_device())
	config.set_value("voice", "auto_gain", VoiceManager.auto_gain)
	config.set_value("voice", "mic_gain_db", VoiceManager.manual_gain_db)
	config.set_value("voice", "push_to_talk", VoiceManager.mode != VoiceManager.Mode.VOICE_ACTIVITY)
	config.set_value("language", "locale", language)
	config.set_value("privacy", "telemetry_enabled", telemetry_enabled)
	config.set_value("privacy", "crash_reporting_enabled", crash_reporting_enabled)
	config.set_value("privacy", "consent_given", telemetry_consent_given)
	config.save(PATH)


## Set a property by name, apply it and save.
func set_value(key: String, value: Variant) -> void:
	set(key, value)
	apply_all()
	save_settings()
	changed.emit(key)


func set_volume(bus: StringName, linear: float) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	_apply_audio()
	save_settings()
	changed.emit("volume")


# --- Key bindings ----------------------------------------------------------------------------

func binding_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "—"
	var names: PackedStringArray = PackedStringArray()
	for event: InputEvent in InputMap.action_get_events(action):
		if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			names.append(event_text(event))
	return " / ".join(names) if not names.is_empty() else tr("Unbound")


## Static, so it cannot use tr(); goes through the TranslationServer directly.
static func event_text(event: InputEvent) -> String:
	var key: InputEventKey = event as InputEventKey
	if key != null:
		return key.as_text_physical_keycode() if key.physical_keycode != KEY_NONE else key.as_text_keycode()
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null:
		match mouse.button_index:
			MOUSE_BUTTON_LEFT:
				return String(TranslationServer.translate("Left mouse"))
			MOUSE_BUTTON_RIGHT:
				return String(TranslationServer.translate("Right mouse"))
			MOUSE_BUTTON_MIDDLE:
				return String(TranslationServer.translate("Middle mouse"))
			MOUSE_BUTTON_WHEEL_UP:
				return String(TranslationServer.translate("Mouse wheel up"))
			MOUSE_BUTTON_WHEEL_DOWN:
				return String(TranslationServer.translate("Mouse wheel down"))
			_:
				return "Mouse %d" % mouse.button_index
	return event.as_text()


## Replace `action`'s binding with `event`. Returns the action that lost this input, if any.
func rebind(action: StringName, event: InputEvent) -> StringName:
	var stolen_from: StringName = &""
	for entry: Array in ACTIONS:
		var other: StringName = entry[0]
		if other == action or not InputMap.has_action(other):
			continue
		for existing: InputEvent in InputMap.action_get_events(other):
			if _same_input(existing, event):
				InputMap.action_erase_event(other, existing)
				stolen_from = other
	for existing: InputEvent in InputMap.action_get_events(action):
		if (existing is InputEventJoypadButton or existing is InputEventJoypadMotion) == (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, event)
	save_settings()
	changed.emit("keybinds")
	return stolen_from


func reset_keybinds() -> void:
	for action: StringName in _default_events:
		InputMap.action_erase_events(action)
		for event: InputEvent in _default_events[action]:
			InputMap.action_add_event(action, event)
	GamepadControls.install_defaults()
	save_settings()
	changed.emit("keybinds")


static func _same_input(a: InputEvent, b: InputEvent) -> bool:
	var key_a: InputEventKey = a as InputEventKey
	var key_b: InputEventKey = b as InputEventKey
	if key_a != null and key_b != null:
		return key_a.physical_keycode == key_b.physical_keycode and key_a.keycode == key_b.keycode
	var mouse_a: InputEventMouseButton = a as InputEventMouseButton
	var mouse_b: InputEventMouseButton = b as InputEventMouseButton
	if mouse_a != null and mouse_b != null:
		return mouse_a.button_index == mouse_b.button_index
	var joy_a: InputEventJoypadButton = a as InputEventJoypadButton
	var joy_b: InputEventJoypadButton = b as InputEventJoypadButton
	if joy_a != null and joy_b != null:
		return joy_a.button_index == joy_b.button_index
	var axis_a: InputEventJoypadMotion = a as InputEventJoypadMotion
	var axis_b: InputEventJoypadMotion = b as InputEventJoypadMotion
	return axis_a != null and axis_b != null and axis_a.axis == axis_b.axis and signf(axis_a.axis_value) == signf(axis_b.axis_value)


# --- Look -------------------------------------------------------------------------------------

## Multiplier for mouse look (player base sensitivity × user sensitivity × ADS factor).
func look_scale(aiming: bool) -> float:
	return mouse_sensitivity * (ads_sensitivity if aiming else 1.0)


## Semantic HUD colours keep meaning distinct when red/green discrimination is difficult.
func indicator_color(kind: StringName) -> Color:
	match color_mode:
		1:
			match kind:
				&"danger": return Color(1.0, 0.61, 0.20)
				&"success": return Color(0.35, 0.73, 1.0)
		2:
			match kind:
				&"danger": return Color(1.0, 0.83, 0.16)
				&"success": return Color(0.20, 0.90, 1.0)
	match kind:
		&"danger": return Color(0.96, 0.22, 0.20)
		&"success": return Color(0.55, 0.90, 0.55)
	return Color.WHITE


# --- Applying ---------------------------------------------------------------------------------

func apply_all() -> void:
	_apply_display()
	_apply_audio()
	_apply_rendering()
	for node: Node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_apply_environment(node as WorldEnvironment)
	_apply_fps_counter()
	_apply_accessibility()


## Audio output devices the driver offers ("Default" follows the system device).
func get_output_devices() -> PackedStringArray:
	return AudioServer.get_output_device_list()


## Linear volume a scare stinger should play at (0 = skip it) under the current stinger setting.
func scare_stinger_gain(intensity: float) -> float:
	match scare_stingers:
		ScareStingers.OFF:
			return 0.0
		ScareStingers.REDUCED:
			return 0.0 if intensity > REDUCED_SCARE_MAX_INTENSITY else db_to_linear(REDUCED_SCARE_DB)
	return 1.0


func _apply_accessibility() -> void:
	if DisplayServer.get_name() != "headless":
		get_tree().root.content_scale_factor = clampf(ui_scale, 0.8, 1.5)
	if _colorblind_rect != null:
		_colorblind_layer.visible = colorblind_mode != ColorBlind.OFF and colorblind_strength > 0.0
		var material: ShaderMaterial = _colorblind_rect.material as ShaderMaterial
		material.set_shader_parameter(&"mode", int(colorblind_mode))
		material.set_shader_parameter(&"strength", clampf(colorblind_strength, 0.0, 1.0))


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = max_fps
	if "--windowed" in OS.get_cmdline_user_args():
		return
	var current: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	match window_mode:
		WindowMode.WINDOWED:
			if current != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplaySettings.set_fullscreen(false)
		WindowMode.BORDERLESS:
			if current != DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		WindowMode.FULLSCREEN:
			if current != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func _apply_audio() -> void:
	var available: PackedStringArray = AudioServer.get_output_device_list()
	var selected_device: String = output_device if output_device in available else "Default"
	if AudioServer.output_device != selected_device:
		AudioServer.output_device = selected_device
	for bus: StringName in volumes:
		var index: int = AudioServer.get_bus_index(bus)
		if index >= 0:
			var linear: float = volumes[bus]
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
			AudioServer.set_bus_mute(index, linear <= 0.001)


func _apply_rendering() -> void:
	var viewport: Viewport = get_tree().root
	viewport.scaling_3d_scale = clampf(render_scale, 0.5, 1.0)
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if render_scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	match quality:
		Quality.LOW:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.positional_shadow_atlas_size = 2048
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
		Quality.MEDIUM:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.positional_shadow_atlas_size = 4096
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
		Quality.HIGH:
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.positional_shadow_atlas_size = 8192
			RenderingServer.directional_shadow_atlas_set_size(8192, true)
		Quality.ULTRA:
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.positional_shadow_atlas_size = 8192
			RenderingServer.directional_shadow_atlas_set_size(8192, true)
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality <= Quality.MEDIUM else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = quality >= Quality.HIGH
	RenderingServer.positional_soft_shadow_filter_set_quality(_shadow_filter())
	RenderingServer.directional_soft_shadow_filter_set_quality(_shadow_filter())


func _shadow_filter() -> RenderingServer.ShadowQuality:
	match quality:
		Quality.LOW:
			return RenderingServer.SHADOW_QUALITY_HARD
		Quality.MEDIUM:
			return RenderingServer.SHADOW_QUALITY_SOFT_LOW
		Quality.HIGH:
			return RenderingServer.SHADOW_QUALITY_SOFT_HIGH
	return RenderingServer.SHADOW_QUALITY_SOFT_ULTRA


func _apply_environment(world: WorldEnvironment) -> void:
	if world == null or not is_instance_valid(world) or world.environment == null:
		return
	var env: Environment = world.environment
	if not env.has_meta(&"base_exposure"):
		env.set_meta(&"base_exposure", env.tonemap_exposure)
		env.set_meta(&"authored_sdfgi", env.sdfgi_enabled)
		env.set_meta(&"authored_ssil", env.ssil_enabled)
		env.set_meta(&"authored_fog", env.volumetric_fog_enabled)
	var base: float = env.get_meta(&"base_exposure")
	var authored_sdfgi: bool = env.get_meta(&"authored_sdfgi")
	var authored_ssil: bool = env.get_meta(&"authored_ssil")
	var authored_fog: bool = env.get_meta(&"authored_fog")
	env.tonemap_exposure = base * brightness
	env.ssao_enabled = quality >= Quality.MEDIUM
	env.ssil_enabled = authored_ssil and quality >= Quality.HIGH
	env.sdfgi_enabled = authored_sdfgi and quality >= Quality.HIGH
	env.volumetric_fog_enabled = authored_fog and quality >= Quality.MEDIUM
	env.glow_enabled = quality >= Quality.MEDIUM


func _apply_environment_by_id(instance_id: int) -> void:
	var obj: Object = instance_from_id(instance_id)
	if obj != null and (obj is WorldEnvironment):
		_apply_environment(obj as WorldEnvironment)


func _on_node_added(node: Node) -> void:
	var world: WorldEnvironment = node as WorldEnvironment
	if world != null:
		_apply_environment_by_id.call_deferred(world.get_instance_id())


func _apply_fps_counter() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if show_fps and _fps_label == null:
		var layer: CanvasLayer = CanvasLayer.new()
		layer.layer = 120
		add_child(layer)
		_fps_label = Label.new()
		_fps_label.position = Vector2(12, 8)
		_fps_label.add_theme_font_size_override(&"font_size", 14)
		_fps_label.add_theme_color_override(&"font_color", GameTheme.TEXT_DIM)
		layer.add_child(_fps_label)
	if _fps_label != null:
		_fps_label.get_parent().set(&"visible", show_fps)


func _process(_delta: float) -> void:
	if _fps_label != null and show_fps:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


# --- Privacy / Telemetry Consent ----------------------------------------------------------------

## Show the telemetry consent dialog (call from main menu on first launch).
func show_telemetry_consent_dialog() -> void:
	if telemetry_consent_given:
		return  # Already consented (or declined)

	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Privacy & Telemetry"
	dialog.min_size = Vector2(500, 350)

	var vbox: VBoxContainer = VBoxContainer.new()
	dialog.add_child(vbox)

	var label: Label = Label.new()
	label.text = (
		"Help us improve 911: The Last Call by sharing anonymous usage data.\n\n" +
		"[b]What we collect (only if you opt in):[/b]\n" +
		"• Session length, shift progression, endings reached\n" +
		"• Call outcomes, mission success/failure rates\n" +
		"• Performance metrics (FPS, latency, crashes)\n" +
		"• Hardware info (GPU, CPU, OS) — no personal identifiers\n\n" +
		"[b]Crash Reporting:[/b]\n" +
		"Automatically send crash logs and stack traces to help us fix bugs.\n" +
		"Includes game state at time of crash (shift, phase, meters).\n\n" +
		"[b]Your Privacy:[/b]\n" +
		"• No personal data, Steam ID, IP addresses, or voice recordings\n" +
		"• Data is aggregated and anonymous\n" +
		"• You can change this anytime in Settings → Privacy\n" +
		"• Request data deletion at any time (GDPR compliant)\n\n" +
		"Do you want to help us make the game better?"
	)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(label)

	var hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(hbox)

	var opt_in_btn: Button = Button.new()
	opt_in_btn.text = "Yes, Send Anonymous Data"
	opt_in_btn.custom_minimum_size = Vector2(0, 40)
	opt_in_btn.pressed.connect(Callable(self, "_on_telemetry_consent").bind(true, true))
	hbox.add_child(opt_in_btn)

	var opt_in_crashes_only: Button = Button.new()
	opt_in_crashes_only.text = "Crash Reports Only"
	opt_in_crashes_only.custom_minimum_size = Vector2(0, 40)
	opt_in_crashes_only.pressed.connect(Callable(self, "_on_telemetry_consent").bind(false, true))
	hbox.add_child(opt_in_crashes_only)

	var opt_out_btn: Button = Button.new()
	opt_out_btn.text = "No Thanks"
	opt_out_btn.custom_minimum_size = Vector2(0, 40)
	opt_out_btn.pressed.connect(Callable(self, "_on_telemetry_consent").bind(false, false))
	hbox.add_child(opt_out_btn)

	dialog.popup_centered()


func _on_telemetry_consent(telemetry: bool, crashes: bool) -> void:
	telemetry_consent_given = true
	telemetry_enabled = telemetry
	crash_reporting_enabled = crashes

	# Apply to TelemetryManager
	if TelemetryManager.instance != null and TelemetryManager.instance.settings != null:
		TelemetryManager.instance.settings.set_consent(telemetry, crashes)
		TelemetryManager.instance.set_telemetry_enabled(telemetry)
		TelemetryManager.instance.set_crash_reporting_enabled(crashes)

	save_settings()


## Toggle telemetry from Settings menu.
func set_telemetry_enabled(enabled: bool) -> void:
	if not telemetry_consent_given:
		show_telemetry_consent_dialog()
		return
	telemetry_enabled = enabled
	if TelemetryManager.instance != null:
		TelemetryManager.instance.set_telemetry_enabled(enabled)
	save_settings()
	changed.emit("telemetry")


## Toggle crash reporting from Settings menu.
func set_crash_reporting_enabled(enabled: bool) -> void:
	if not telemetry_consent_given:
		show_telemetry_consent_dialog()
		return
	crash_reporting_enabled = enabled
	if TelemetryManager.instance != null:
		TelemetryManager.instance.set_crash_reporting_enabled(enabled)
	save_settings()
	changed.emit("crash_reporting")


## Request data deletion (GDPR).
func request_data_deletion() -> void:
	if TelemetryManager.instance != null:
		TelemetryManager.instance.request_data_deletion()
	telemetry_enabled = false
	crash_reporting_enabled = false
	telemetry_consent_given = false
	save_settings()
