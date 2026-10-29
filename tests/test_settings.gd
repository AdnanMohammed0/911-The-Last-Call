## Release UI: GameSettings key rebinding (conflicts, reset), look scaling, quality → environment, settings menu.
extends GutTest


func after_each() -> void:
	GameSettings.reset_keybinds()
	GameSettings.set_value("quality", GameSettings.Quality.HIGH)
	GameSettings.set_value("brightness", 1.0)
	GameSettings.set_value("mouse_sensitivity", 1.0)
	GameSettings.set_value("ads_sensitivity", 0.7)
	GameSettings.set_value("subtitles_enabled", true)
	GameSettings.set_value("subtitle_size", 1)
	GameSettings.set_value("color_mode", 0)
	GameSettings.set_value("reduced_horror_effects", false)


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	return event


func test_every_listed_action_exists() -> void:
	for entry: Array in GameSettings.ACTIONS:
		var action: StringName = entry[0]
		assert_true(InputMap.has_action(action), String(action))


func test_rebind_replaces_binding() -> void:
	GameSettings.rebind(&"reload", _key(KEY_G))
	assert_eq(GameSettings.binding_text(&"reload"), "G")
	var events: Array[InputEvent] = InputMap.action_get_events(&"reload")
	assert_eq(events.size(), 1)


func test_rebind_steals_conflicting_input() -> void:
	var stolen: StringName = GameSettings.rebind(&"reload", _key(KEY_F))
	assert_eq(stolen, &"interact", "F belonged to interact")
	assert_eq(GameSettings.binding_text(&"interact"), "Unbound")


func test_mouse_buttons_can_be_bound() -> void:
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	GameSettings.rebind(&"flashlight", mouse)
	assert_eq(GameSettings.binding_text(&"flashlight"), "Middle mouse")


func test_reset_restores_defaults() -> void:
	GameSettings.rebind(&"interact", _key(KEY_H))
	GameSettings.reset_keybinds()
	assert_eq(GameSettings.binding_text(&"interact"), "F")
	assert_eq(GameSettings.binding_text(&"fire"), "Left mouse")


func test_look_scale_uses_ads_multiplier() -> void:
	GameSettings.set_value("mouse_sensitivity", 2.0)
	GameSettings.set_value("ads_sensitivity", 0.5)
	assert_almost_eq(GameSettings.look_scale(false), 2.0, 0.001)
	assert_almost_eq(GameSettings.look_scale(true), 1.0, 0.001)


func test_quality_and_brightness_drive_environments() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.sdfgi_enabled = true
	env.ssil_enabled = true
	env.volumetric_fog_enabled = true
	env.tonemap_exposure = 2.0
	world.environment = env
	add_child_autofree(world)
	GameSettings.set_value("quality", GameSettings.Quality.LOW)
	assert_false(env.sdfgi_enabled)
	assert_false(env.volumetric_fog_enabled)
	assert_false(env.ssao_enabled)
	GameSettings.set_value("quality", GameSettings.Quality.ULTRA)
	assert_true(env.sdfgi_enabled, "authored SDFGI comes back")
	assert_true(env.ssil_enabled)
	GameSettings.set_value("brightness", 1.5)
	assert_almost_eq(env.tonemap_exposure, 3.0, 0.001, "brightness scales the authored exposure")


func test_settings_menu_builds_all_tabs_and_closes() -> void:
	var menu: SettingsMenu = SettingsMenu.new()
	add_child_autofree(menu)
	var tabs: TabContainer = menu.find_children("*", "TabContainer", true, false)[0] as TabContainer
	assert_eq(tabs.get_tab_count(), 6, "General, Video, Audio, Voice, Controls, Accessibility")
	assert_gt(menu._bind_buttons.size(), 15, "a rebind button per action")
	watch_signals(menu)
	menu.close()
	assert_signal_emitted(menu, "closed")


func test_rebind_through_menu_capture() -> void:
	var menu: SettingsMenu = SettingsMenu.new()
	add_child_autofree(menu)
	var button: Button = menu._bind_buttons[&"door_kick"]
	menu._start_rebind(&"door_kick", button)
	var press: InputEventKey = _key(KEY_B)
	press.pressed = true
	menu._capture_binding(press)
	assert_eq(GameSettings.binding_text(&"door_kick"), "B")
	assert_eq(button.text, "B")


func test_accessibility_options_change_status_colours_and_are_saved() -> void:
	var original: Color = GameSettings.indicator_color(&"danger")
	GameSettings.set_value("color_mode", 1)
	assert_ne(GameSettings.indicator_color(&"danger"), original)
	assert_ne(GameSettings.indicator_color(&"success"), GameSettings.indicator_color(&"danger"))
	GameSettings.set_value("subtitle_size", 2)
	GameSettings.set_value("reduced_horror_effects", true)
	var config := ConfigFile.new()
	assert_eq(config.load(GameSettings.PATH), OK)
	var saved_color: int = config.get_value("accessibility", "color_mode")
	var saved_size: int = config.get_value("accessibility", "subtitle_size")
	var saved_reduction: bool = config.get_value("accessibility", "reduced_horror_effects")
	assert_eq(saved_color, 1)
	assert_eq(saved_size, 2)
	assert_true(saved_reduction)


func test_dialogue_subtitles_follow_setting_and_deduplicate_updates() -> void:
	var captions := DialogueSubtitles.new()
	add_child_autofree(captions)
	EventBus.dialogue_node_changed.emit(&"opening", &"caller", "Someone is outside the window.", [])
	assert_true(captions.visible)
	assert_eq(captions._line.text, "Someone is outside the window.")
	var first_timer: float = captions._seconds_left
	EventBus.dialogue_node_changed.emit(&"opening", &"caller", "Someone is outside the window.", [])
	assert_almost_eq(captions._seconds_left, first_timer, 0.01)
	GameSettings.set_value("subtitle_size", 2)
	assert_eq(captions._line.get_theme_font_size(&"font_size"), 28)
	GameSettings.set_value("subtitles_enabled", false)
	assert_false(captions.visible)


func test_missing_audio_output_uses_system_default() -> void:
	var original: String = GameSettings.output_device
	GameSettings.set_value("output_device", "not-a-connected-output")
	assert_eq(AudioServer.output_device, "Default")
	GameSettings.set_value("output_device", original)
