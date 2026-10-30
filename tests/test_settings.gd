## Release UI: GameSettings key rebinding (conflicts, reset), look scaling, quality → environment, settings menu,
## and the P4-14 accessibility options (subtitles, colour vision, comfort and content, motor toggles).
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
	for key: String in ["subtitles_enabled", "sound_captions", "subtitle_speaker_names", "apparitions"]:
		GameSettings.set(key, true)
	for key: String in ["reduce_flashing", "toggle_sprint", "toggle_aim"]:
		GameSettings.set(key, false)
	GameSettings.set("colorblind_mode", GameSettings.ColorBlind.OFF)
	GameSettings.set("colorblind_strength", 1.0)
	GameSettings.set("screen_effects", 1.0)
	GameSettings.set("scare_stingers", GameSettings.ScareStingers.FULL)
	GameSettings.set_value("ui_scale", 1.0)
	CallDirector.handset_owner_peer_id = 0


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
	var keyboard_count: int = 0
	for event: InputEvent in events:
		if event is InputEventKey:
			keyboard_count += 1
	assert_eq(keyboard_count, 1)


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
	var captions: SubtitleOverlay = GameSettings.subtitle_overlay
	EventBus.dialogue_node_changed.emit(&"opening", &"caller", "Someone is outside the window.", [])
	assert_string_ends_with(captions.visible_line(), "Someone is outside the window.")
	var first_timer: float = captions._line_time
	captions._process(0.5)
	EventBus.dialogue_node_changed.emit(&"opening", &"caller", "Someone is outside the window.", [])
	assert_almost_eq(captions._line_time, first_timer - 0.5, 0.01, "a re-synced node does not restart the timer")
	GameSettings.set_value("subtitle_size", 2)
	var label: RichTextLabel = captions._line_label
	assert_eq(label.get_theme_font_size(&"normal_font_size"), SubtitleOverlay.FONT_SIZES[2])
	EventBus.call_ended.emit(&"opening_call", &"resolved")
	assert_eq(captions.visible_line(), "", "the line clears when the call ends")
	EventBus.dialogue_node_changed.emit(&"next", &"caller", "Hello?", [])
	GameSettings.set_value("subtitles_enabled", false)
	assert_eq(captions.visible_line(), "")


func test_missing_audio_output_uses_system_default() -> void:
	var original: String = GameSettings.output_device
	GameSettings.set_value("output_device", "not-a-connected-output")
	assert_eq(AudioServer.output_device, "Default")
	GameSettings.set_value("output_device", original)
# --- Accessibility (P4-14) -------------------------------------------------------------------------

func test_accessibility_settings_survive_save_and_load() -> void:
	GameSettings.set_value("subtitle_size", 3)
	GameSettings.set_value("colorblind_mode", GameSettings.ColorBlind.TRITANOPIA)
	GameSettings.set_value("scare_stingers", GameSettings.ScareStingers.OFF)
	GameSettings.set_value("toggle_sprint", true)
	GameSettings.set("subtitle_size", 0)
	GameSettings.set("colorblind_mode", GameSettings.ColorBlind.OFF)
	GameSettings.set("scare_stingers", GameSettings.ScareStingers.FULL)
	GameSettings.set("toggle_sprint", false)
	GameSettings.load_settings()
	assert_eq(GameSettings.subtitle_size, 3)
	assert_eq(GameSettings.colorblind_mode, GameSettings.ColorBlind.TRITANOPIA)
	assert_eq(GameSettings.scare_stingers, GameSettings.ScareStingers.OFF)
	assert_true(GameSettings.toggle_sprint)


func test_colour_vision_filter_follows_mode_and_strength() -> void:
	var layer: CanvasLayer = GameSettings.get_node(^"ColorVision") as CanvasLayer
	assert_false(layer.visible, "no filter pass while the assist is off")
	GameSettings.set_value("colorblind_mode", GameSettings.ColorBlind.DEUTERANOPIA)
	GameSettings.set_value("colorblind_strength", 0.6)
	assert_true(layer.visible)
	var material: ShaderMaterial = (layer.get_child(0) as ColorRect).material as ShaderMaterial
	var mode: int = material.get_shader_parameter(&"mode")
	var strength: float = material.get_shader_parameter(&"strength")
	assert_eq(mode, 2)
	assert_almost_eq(strength, 0.6, 0.001)


func test_subtitles_show_speaker_and_respect_toggles() -> void:
	var overlay: SubtitleOverlay = GameSettings.subtitle_overlay
	overlay.show_line("Caller", "Someone is in the house.")
	assert_eq(overlay.visible_line(), "Caller: Someone is in the house.")
	GameSettings.set_value("subtitle_speaker_names", false)
	overlay.show_line("Caller", "Please hurry.")
	assert_eq(overlay.visible_line(), "Please hurry.")
	GameSettings.set_value("subtitles_enabled", false)
	assert_eq(overlay.visible_line(), "", "turning subtitles off clears the line")
	overlay.show_line("Caller", "Hello?")
	assert_eq(overlay.visible_line(), "")


func test_sound_captions_stack_dedupe_and_follow_hallucinations() -> void:
	var overlay: SubtitleOverlay = GameSettings.subtitle_overlay
	var before: int = overlay.caption_count()
	EventBus.hallucination.emit(&"phantom_steps", Vector3.ZERO)
	EventBus.hallucination.emit(&"phantom_steps", Vector3.ZERO)
	assert_eq(overlay.caption_count(), mini(before + 1, SubtitleOverlay.MAX_CAPTIONS), "repeats refresh, not stack")
	for text: String in ["[A]", "[B]", "[C]", "[D]"]:
		overlay.caption(text)
	assert_eq(overlay.caption_count(), SubtitleOverlay.MAX_CAPTIONS)
	GameSettings.set_value("sound_captions", false)
	var count: int = overlay.caption_count()
	overlay.caption("[E]")
	assert_eq(overlay.caption_count(), count)


func test_handset_owner_does_not_get_duplicate_subtitles() -> void:
	var overlay: SubtitleOverlay = GameSettings.subtitle_overlay
	GameSettings.set_value("subtitles_enabled", false)
	GameSettings.set_value("subtitles_enabled", true)
	CallDirector.handset_owner_peer_id = multiplayer.get_unique_id()
	EventBus.dialogue_node_changed.emit(&"n1", &"caller", "I can hear scratching.", [])
	assert_eq(overlay.visible_line(), "", "the phone UI already shows the line")
	CallDirector.handset_owner_peer_id = 0
	EventBus.dialogue_node_changed.emit(&"n2", &"dispatcher", "Stay on the line.", [])
	assert_eq(overlay.visible_line(), "Dispatcher: Stay on the line.")
	assert_between(SubtitleOverlay.reading_time("x".repeat(400)), 2.0, 8.0)


func test_scare_stinger_levels() -> void:
	assert_eq(GameSettings.scare_stinger_gain(0.9), 1.0)
	GameSettings.set_value("scare_stingers", GameSettings.ScareStingers.REDUCED)
	assert_eq(GameSettings.scare_stinger_gain(0.9), 0.0, "the loudest scares are skipped")
	assert_almost_eq(GameSettings.scare_stinger_gain(0.3), db_to_linear(GameSettings.REDUCED_SCARE_DB), 0.001)
	GameSettings.set_value("scare_stingers", GameSettings.ScareStingers.OFF)
	assert_eq(GameSettings.scare_stinger_gain(0.3), 0.0)


func test_reduce_flashing_keeps_faulty_lights_steady() -> void:
	var fixture: Node3D = Node3D.new()
	var light: OmniLight3D = OmniLight3D.new()
	light.light_energy = 2.0
	fixture.add_child(light)
	var tube: MeshInstance3D = MeshInstance3D.new()
	tube.name = "Tube"
	fixture.add_child(tube)
	var flicker: FlickerLight = FlickerLight.new()
	fixture.add_child(flicker)
	add_child_autofree(fixture)
	flicker._set_lit(false)
	GameSettings.set_value("reduce_flashing", true)
	for i: int in 30:
		flicker._process(0.1)
	assert_true(tube.visible)
	assert_eq(light.light_energy, 2.0)


func test_bodycam_effects_slider_scales_the_film_look() -> void:
	var hud: FieldBodycamHud = FieldBodycamHud.new()
	add_child_autofree(hud)
	GameSettings.set_value("screen_effects", 0.5)
	var material: ShaderMaterial = (hud.get_node(^"BodycamPostProcess") as ColorRect).material as ShaderMaterial
	var film: float = material.get_shader_parameter(&"film_strength")
	assert_almost_eq(film, hud.film_strength * 0.5, 0.001)
	GameSettings.set_value("screen_effects", 0.0)
	var aberration: float = material.get_shader_parameter(&"aberration_px")
	assert_almost_eq(aberration, 0.0, 0.001)


func test_apparitions_off_turns_shadow_figures_into_sound() -> void:
	GameSettings.set_value("apparitions", false)
	var effect: Hallucination = Hallucination.create(&"shadow_figure", Vector3.ZERO)
	add_child_autofree(effect)
	assert_eq(effect.kind, &"radio_whisper")
	assert_eq(effect.find_children("*", "MeshInstance3D", true, false).size(), 0)


func test_menu_has_accessibility_page_and_test_tone() -> void:
	var menu: SettingsMenu = SettingsMenu.new()
	add_child_autofree(menu)
	assert_not_null(menu.find_child("Accessibility", true, false))
	var tone: AudioStreamWAV = SettingsMenu.make_test_tone()
	assert_gt(tone.data.size(), 20000)
