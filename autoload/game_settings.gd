## Player-facing settings saved to user://settings.cfg: video (window mode, V-Sync, FPS cap, quality preset,
## render scale, FOV, brightness), audio bus volumes, controls (sensitivity, ADS sensitivity, invert Y,
## crouch toggle, key bindings) and voice. Applies graphics quality to every WorldEnvironment that enters
## the tree, and installs the shared UI theme on the root window.
## Authority: LOCAL
extends Node

enum WindowMode { WINDOWED, BORDERLESS, FULLSCREEN }
enum Quality { LOW, MEDIUM, HIGH, ULTRA }

const PATH: String = "user://settings.cfg"
const QUALITY_NAMES: PackedStringArray = ["Low", "Medium", "High", "Ultra"]
const WINDOW_MODE_NAMES: PackedStringArray = ["Windowed", "Borderless fullscreen", "Exclusive fullscreen"]
const AUDIO_BUSES: Dictionary[StringName, String] = {
	&"Master": "Master volume", &"Music": "Music", &"SFX": "Effects",
	&"VoiceProximity": "Voice chat", &"VoiceRadio": "Radio", &"Phone": "Phone calls",
}
## Rebindable actions in the order the Controls tab lists them.
const ACTIONS: Array[Array] = [
	[&"move_forward", "Move forward"], [&"move_back", "Move back"], [&"move_left", "Move left"], [&"move_right", "Move right"],
	[&"sprint", "Sprint"], [&"crouch", "Crouch"], [&"lean_left", "Lean left"], [&"lean_right", "Lean right"],
	[&"interact", "Interact"], [&"door_peek", "Peek door"], [&"door_kick", "Kick door"], [&"flashlight", "Flashlight"],
	[&"fire", "Fire"], [&"aim", "Aim down sights"], [&"reload", "Reload"],
	[&"weapon_primary", "Primary weapon"], [&"weapon_sidearm", "Sidearm"], [&"weapon_swap", "Swap weapon"],
	[&"voice_ptt", "Push to talk"], [&"radio_ptt", "Radio"],
]

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

## Shared UI theme. Controls under a CanvasLayer do not inherit the window theme, so menus assign it.
var ui_theme: Theme

var _default_events: Dictionary[StringName, Array] = {}
var _fps_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for entry: Array in ACTIONS:
		var action: StringName = entry[0]
		if InputMap.has_action(action):
			_default_events[action] = InputMap.action_get_events(action).duplicate()
	for bus: StringName in AUDIO_BUSES:
		volumes[bus] = 1.0
	load_settings()
	ui_theme = GameTheme.build()
	if DisplayServer.get_name() != "headless":
		get_tree().root.theme = ui_theme
	get_tree().node_added.connect(_on_node_added)
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
	for bus: StringName in AUDIO_BUSES:
		volumes[bus] = config.get_value("audio", String(bus), 1.0)
	mouse_sensitivity = config.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	ads_sensitivity = config.get_value("controls", "ads_sensitivity", ads_sensitivity)
	invert_y = config.get_value("controls", "invert_y", invert_y)
	crouch_toggle = config.get_value("controls", "crouch_toggle", crouch_toggle)
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
		var push_to_talk: bool = config.get_value("voice", "push_to_talk", false)
		if push_to_talk != (VoiceManager.mode != VoiceManager.Mode.VOICE_ACTIVITY):
			VoiceManager.toggle_mode()


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
	for bus: StringName in volumes:
		config.set_value("audio", String(bus), volumes[bus])
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("controls", "ads_sensitivity", ads_sensitivity)
	config.set_value("controls", "invert_y", invert_y)
	config.set_value("controls", "crouch_toggle", crouch_toggle)
	for entry: Array in ACTIONS:
		var action: StringName = entry[0]
		if InputMap.has_action(action):
			config.set_value("keybinds", String(action), InputMap.action_get_events(action))
	config.set_value("voice", "input_device", VoiceManager.get_input_device())
	config.set_value("voice", "auto_gain", VoiceManager.auto_gain)
	config.set_value("voice", "push_to_talk", VoiceManager.mode != VoiceManager.Mode.VOICE_ACTIVITY)
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
		names.append(event_text(event))
	return " / ".join(names) if not names.is_empty() else "Unbound"


static func event_text(event: InputEvent) -> String:
	var key: InputEventKey = event as InputEventKey
	if key != null:
		return key.as_text_physical_keycode() if key.physical_keycode != KEY_NONE else key.as_text_keycode()
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null:
		match mouse.button_index:
			MOUSE_BUTTON_LEFT:
				return "Left mouse"
			MOUSE_BUTTON_RIGHT:
				return "Right mouse"
			MOUSE_BUTTON_MIDDLE:
				return "Middle mouse"
			MOUSE_BUTTON_WHEEL_UP:
				return "Wheel up"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Wheel down"
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
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	save_settings()
	changed.emit("keybinds")
	return stolen_from


func reset_keybinds() -> void:
	for action: StringName in _default_events:
		InputMap.action_erase_events(action)
		for event: InputEvent in _default_events[action]:
			InputMap.action_add_event(action, event)
	save_settings()
	changed.emit("keybinds")


static func _same_input(a: InputEvent, b: InputEvent) -> bool:
	var key_a: InputEventKey = a as InputEventKey
	var key_b: InputEventKey = b as InputEventKey
	if key_a != null and key_b != null:
		return key_a.physical_keycode == key_b.physical_keycode and key_a.keycode == key_b.keycode
	var mouse_a: InputEventMouseButton = a as InputEventMouseButton
	var mouse_b: InputEventMouseButton = b as InputEventMouseButton
	return mouse_a != null and mouse_b != null and mouse_a.button_index == mouse_b.button_index


# --- Look -------------------------------------------------------------------------------------

## Multiplier for mouse look (player base sensitivity × user sensitivity × ADS factor).
func look_scale(aiming: bool) -> float:
	return mouse_sensitivity * (ads_sensitivity if aiming else 1.0)


# --- Applying ---------------------------------------------------------------------------------

func apply_all() -> void:
	_apply_display()
	_apply_audio()
	_apply_rendering()
	for node: Node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_apply_environment(node as WorldEnvironment)
	_apply_fps_counter()


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
	if world == null or world.environment == null:
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


func _on_node_added(node: Node) -> void:
	var world: WorldEnvironment = node as WorldEnvironment
	if world != null:
		_apply_environment.call_deferred(world)


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
