extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/shared/player/player.tscn")


func before_each() -> void:
	MissionDirector.reset()
	GameSettings.set_value("reduced_horror_effects", false)


func after_each() -> void:
	MissionDirector.reset()
	GameSettings.set_value("reduced_horror_effects", false)


func test_bodycam_is_field_only_and_tracks_sanity() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	var bodycam: FieldBodycamHud = player.get_node("HUD/FieldBodycamHud") as FieldBodycamHud
	assert_not_null(bodycam)
	bodycam._process(0.0)
	assert_false(bodycam.visible)
	assert_eq(FieldBodycamHud.sanity_intensity(100.0), 0.0)
	assert_gt(FieldBodycamHud.sanity_intensity(25.0), 0.0)
	MissionDirector._sync_state(MissionDirector.State.DEPLOYED, MissionDirector.HIGHWAY,
		&"call_meat_truck", &"ambush", 1.5, "Flank the gunmen")
	player.sanity = 25.0
	bodycam._process(0.0)
	assert_true(bodycam.visible)
	assert_true(bodycam._post_process.visible)
	assert_eq(bodycam.get_child(0), bodycam._post_process, "scene effect renders below readable HUD text")
	assert_gt(bodycam._frame.size.x, 100.0)
	assert_gt(bodycam._frame.size.y, 100.0)
	assert_false(bodycam._timestamp.text.is_empty())
	assert_true(bodycam._sanity_overlay.visible)
	var disturbed: float = bodycam._post_material.get_shader_parameter(&"sanity_strength")
	assert_gt(disturbed, 0.0)
	assert_string_contains(bodycam._site.text, "HIGHWAY")
	player.sanity = 100.0
	bodycam._process(0.0)
	assert_false(bodycam._sanity_overlay.visible)
	var calm: float = bodycam._post_material.get_shader_parameter(&"sanity_strength")
	assert_almost_eq(calm, 0.0, 0.001)
	bodycam.post_process_enabled = false
	bodycam._process(0.0)
	assert_false(bodycam._post_process.visible)
	assert_true(bodycam.visible, "disabling the image pass keeps the bodycam frame and metadata")
	MissionDirector.reset()
	bodycam._process(0.0)
	assert_false(bodycam.visible)


func test_objective_switches_to_field_ticker() -> void:
	var hud: ObjectiveHud = ObjectiveHud.new()
	add_child_autofree(hud)
	assert_true(hud._tracker.visible)
	assert_false(hud._field_ticker.visible)
	MissionDirector._sync_state(MissionDirector.State.DEPLOYED, MissionDirector.FARMHOUSE,
		&"call_closet_monster", &"raid", 1.0, "Rescue the hostage")
	assert_false(hud._tracker.visible)
	assert_true(hud._field_ticker.visible)
	assert_string_contains(hud._field_text.text, "Rescue the hostage")
	MissionDirector._sync_hostiles(2, 3)
	assert_string_contains(hud._field_text.text, "Suspects 2/3")
	MissionDirector.reset()
	hud._refresh()
	assert_true(hud._tracker.visible)
	assert_false(hud._field_ticker.visible)


func test_player_keeps_radio_and_existing_vitals() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	autoqfree(player)
	assert_not_null(player.get_node_or_null("HUD/VoiceHud"))
	assert_not_null(player.get_node_or_null("HUD/StatusHud"))
	assert_not_null(player.get_node_or_null("HUD/HealthHud"))
	assert_not_null(player.get_node_or_null("HUD/ObjectiveHud"))
	assert_not_null(player.get_node_or_null("HUD/DialogueSubtitles"))


func test_reduced_horror_effects_hide_distortion_but_keep_field_frame() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	var bodycam: FieldBodycamHud = player.get_node("HUD/FieldBodycamHud") as FieldBodycamHud
	MissionDirector._sync_state(MissionDirector.State.DEPLOYED, MissionDirector.HIGHWAY,
		&"call_meat_truck", &"ambush", 1.5, "Flank the gunmen")
	player.sanity = 15.0
	GameSettings.set_value("reduced_horror_effects", true)
	bodycam._process(0.0)
	assert_true(bodycam.visible)
	assert_false(bodycam._post_process.visible)
	assert_false(bodycam._sanity_overlay.visible)
	assert_true(bodycam._frame.visible)
