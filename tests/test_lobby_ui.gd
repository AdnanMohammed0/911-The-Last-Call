extends GutTest

const MAIN_MENU_SCENE := preload("res://scenes/boot/main_menu.tscn")
const CLASS_CARD_SCENE := preload("res://scenes/boot/class_card.tscn")

var _menu: Control


func before_each() -> void:
	_menu = MAIN_MENU_SCENE.instantiate()
	add_child_autofree(_menu)


func test_main_menu_instantiates_with_all_views() -> void:
	assert_not_null(_menu, "Main menu should instantiate")
	var home_view: Control = _menu.get_node("%HomeView")
	var host_view: Control = _menu.get_node("%HostView")
	var join_view: Control = _menu.get_node("%JoinView")
	var lobby_view: Control = _menu.get_node("%LobbyView")

	assert_not_null(home_view, "HomeView should exist")
	assert_not_null(host_view, "HostView should exist")
	assert_not_null(join_view, "JoinView should exist")
	assert_not_null(lobby_view, "LobbyView should exist")

	assert_true(home_view.visible, "HomeView should be visible initially")
	assert_false(host_view.visible, "HostView should be hidden initially")
	assert_false(join_view.visible, "JoinView should be hidden initially")
	assert_false(lobby_view.visible, "LobbyView should be hidden initially")


func test_navigation_buttons_switch_views() -> void:
	var host_nav: Button = _menu.get_node("%HostNavButton")
	var join_nav: Button = _menu.get_node("%JoinNavButton")
	var back_host: Button = _menu.get_node("%BackFromHostBtn")
	var back_join: Button = _menu.get_node("%BackFromJoinBtn")

	var home_view: Control = _menu.get_node("%HomeView")
	var host_view: Control = _menu.get_node("%HostView")
	var join_view: Control = _menu.get_node("%JoinView")

	# Navigate to HostView
	host_nav.emit_signal("pressed")
	assert_false(home_view.visible, "HomeView hidden after HostNav")
	assert_true(host_view.visible, "HostView visible after HostNav")

	# Back to HomeView
	back_host.emit_signal("pressed")
	assert_true(home_view.visible, "HomeView visible after BackFromHost")
	assert_false(host_view.visible, "HostView hidden after BackFromHost")

	# Navigate to JoinView
	join_nav.emit_signal("pressed")
	assert_false(home_view.visible, "HomeView hidden after JoinNav")
	assert_true(join_view.visible, "JoinView visible after JoinNav")

	# Back to HomeView
	back_join.emit_signal("pressed")
	assert_true(home_view.visible, "HomeView visible after BackFromJoin")
	assert_false(join_view.visible, "JoinView hidden after BackFromJoin")


func test_class_cards_exist_and_bind_classes() -> void:
	var card_tech: ClassCard = _menu.get_node("%CardTech")
	var card_profiler: ClassCard = _menu.get_node("%CardProfiler")
	var card_breacher: ClassCard = _menu.get_node("%CardBreacher")
	var card_medic: ClassCard = _menu.get_node("%CardMedic")

	assert_not_null(card_tech, "CardTech should exist")
	assert_not_null(card_profiler, "CardProfiler should exist")
	assert_not_null(card_breacher, "CardBreacher should exist")
	assert_not_null(card_medic, "CardMedic should exist")

	assert_eq(card_tech.class_id, &"tech")
	assert_eq(card_profiler.class_id, &"profiler")
	assert_eq(card_breacher.class_id, &"breacher")
	assert_eq(card_medic.class_id, &"medic")


func test_standalone_class_card_state_changes() -> void:
	var card: ClassCard = CLASS_CARD_SCENE.instantiate()
	add_child_autofree(card)
	card.setup_class(&"breacher")

	var btn: Button = card.get_node("%SelectButton")
	var badge: Label = card.get_node("%StatusBadge")

	# Default available
	card.set_card_state(false, false)
	assert_false(btn.disabled, "Select button enabled when available")
	assert_string_contains(badge.text, "AVAILABLE")

	# Selected by me
	card.set_card_state(true, false)
	assert_true(btn.disabled, "Select button disabled when claimed by me")
	assert_string_contains(badge.text, "SELECTED")

	# Occupied by peer
	card.set_card_state(false, true, "Agent Smith")
	assert_true(btn.disabled, "Select button disabled when taken by peer")
	assert_string_contains(badge.text, "AGENT SMITH")
