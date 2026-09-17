## Release UI: GameSettings key rebinding (conflicts, reset), look scaling, quality → environment, settings menu.
extends GutTest


func after_each() -> void:
	GameSettings.reset_keybinds()
	GameSettings.set_value("quality", GameSettings.Quality.HIGH)
	GameSettings.set_value("brightness", 1.0)
	GameSettings.set_value("mouse_sensitivity", 1.0)
	GameSettings.set_value("ads_sensitivity", 0.7)


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
	assert_eq(tabs.get_tab_count(), 4)
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
