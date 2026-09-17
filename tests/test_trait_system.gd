## GUT tests for Trait System (P4-03).
## Run with: godot --headless -s res://addons/gut/gut_cmdln.gd -gtest=tests/test_trait_system.gd
extends GutTest

var _trait_system: TraitSystem
var _game_state: GameState
var _mock_player: Player


func before() -> void:
	_trait_system = TraitSystem.new()
	add_child_autofree(_trait_system)
	_trait_system._ready()
	
	_game_state = GameState.new()
	add_child_autofree(_game_state)
	_game_state.reset()
	
	_mock_player = Player.new()
	_mock_player.peer_id = 1
	_mock_player.class_id = &"tech"
	add_child_autofree(_mock_player)


func after() -> void:
	_trait_system = null
	_game_state = null
	_mock_player = null


## Test: TraitData catalog loads correctly
func test_trait_catalog_loading() -> void:
	var catalog: Dictionary = _trait_system.get_catalog()
	assert_true(catalog.has(&"limping"))
	assert_true(catalog.has(&"fractured_hand"))
	assert_true(catalog.has(&"concussion"))
	assert_true(catalog.has(&"scarred"))
	assert_true(catalog.has(&"ptsd"))
	assert_true(catalog.has(&"phantom_ringing"))
	assert_true(catalog.has(&"nyctophobia"))
	assert_true(catalog.has(&"hardened"))
	assert_true(catalog.has(&"community_hero"))
	assert_true(catalog.has(&"marked_by_dusk"))
	
	# Verify trait properties
	var limping: TraitData = catalog[&"limping"]
	assert_eq(limping.category, TraitData.Category.PHYSICAL)
	assert_eq(limping.duration_shifts, 2)
	assert_true(limping.stat_modifiers.has(&"move_speed"))
	assert_true(limping.stat_modifiers.has(&"noise"))
	assert_eq(limping.cure_cost, 0)


## Test: Apply trait to player
func test_apply_trait() -> void:
	var result: bool = _trait_system.apply(1, &"limping")
	assert_true(result)
	assert_true(_trait_system.has_trait(1, &"limping"))
	
	var traits: Dictionary = _trait_system.get_player_traits(1)
	assert_true(traits.has(&"limping"))
	assert_eq(traits[&"limping"].shifts_remaining, 2)
	assert_eq(traits[&"limping"].source_event, &"")


## Test: Apply trait with custom duration
func test_apply_trait_custom_duration() -> void:
	var result: bool = _trait_system.apply(1, &"limping", &"test_event", 5)
	assert_true(result)
	
	var traits: Dictionary = _trait_system.get_player_traits(1)
	assert_eq(traits[&"limping"].shifts_remaining, 5)
	assert_eq(traits[&"limping"].source_event, &"test_event")


## Test: Apply same trait twice (refreshes duration)
func test_apply_trait_refresh() -> void:
	_trait_system.apply(1, &"limping", &"", 2)
	_trait_system.apply(1, &"limping", &"", 5)
	
	var traits: Dictionary = _trait_system.get_player_traits(1)
	assert_eq(traits[&"limping"].shifts_remaining, 5)  # Should use longer duration


## Test: Remove trait
func test_remove_trait() -> void:
	_trait_system.apply(1, &"limping")
	assert_true(_trait_system.has_trait(1, &"limping"))
	
	var result: bool = _trait_system.remove(1, &"limping")
	assert_true(result)
	assert_false(_trait_system.has_trait(1, &"limping"))


## Test: Permanent trait (duration -1) doesn't expire
func test_permanent_trait_no_expire() -> void:
	_trait_system.apply(1, &"scarred")  # duration -1 = permanent
	
	# Simulate shift progression
	for i in range(10):
		_trait_system._on_shift_updated(360 * (i + 1))
	
	assert_true(_trait_system.has_trait(1, &"scarred"))
	var traits: Dictionary = _trait_system.get_player_traits(1)
	assert_eq(traits[&"scarred"].shifts_remaining, -1)


## Test: Trait expires after duration shifts
func test_trait_expires() -> void:
	_trait_system.apply(1, &"limping")  # 2 shifts
	
	# First shift
	_trait_system._on_shift_updated(360)
	assert_true(_trait_system.has_trait(1, &"limping"))
	assert_eq(_trait_system.get_shifts_remaining(1, &"limping"), 1)
	
	# Second shift
	_trait_system._on_shift_updated(720)
	assert_true(_trait_system.has_trait(1, &"limping"))
	assert_eq(_trait_system.get_shifts_remaining(1, &"limping"), 0)
	
	# Third shift - should be removed
	_trait_system._on_shift_updated(1080)
	assert_false(_trait_system.has_trait(1, &"limping"))


## Test: Trait stat modifiers applied to player
func test_trait_stat_modifiers() -> void:
	var player: Player = Player.new()
	player.peer_id = 1
	player.move_speed_multiplier = 1.0
	player.noise_multiplier = 1.0
	add_child_autofree(player)
	
	# Apply limping trait
	_trait_system.apply(1, &"limping")
	
	# Check modifiers applied
	assert_almost_eq(player.move_speed_multiplier, 0.7, 0.01)  # 1.0 - 0.3
	assert_almost_eq(player.noise_multiplier, 1.4, 0.01)      # 1.0 + 0.4


## Test: Trait stat modifiers removed when trait removed
func test_trait_stat_modifiers_removed() -> void:
	var player: Player = Player.new()
	player.peer_id = 1
	player.move_speed_multiplier = 1.0
	player.noise_multiplier = 1.0
	add_child_autofree(player)
	
	_trait_system.apply(1, &"limping")
	assert_almost_eq(player.move_speed_multiplier, 0.7, 0.01)
	
	_trait_system.remove(1, &"limping")
	assert_almost_eq(player.move_speed_multiplier, 1.0, 0.01)
	assert_almost_eq(player.noise_multiplier, 1.0, 0.01)


## Test: PTSD sanity drain multiplier
func test_ptsd_sanity_drain() -> void:
	var player: Player = Player.new()
	player.peer_id = 1
	add_child_autofree(player)
	
	_trait_system.apply(1, &"ptsd")
	
	# Verify trait is active
	assert_true(_trait_system.has_trait(1, &"ptsd"))
	assert_true(_trait_system.has_trait(1, &"ptsd"))


## Test: Trait hook handling
func test_trait_hook_handling() -> void:
	var player: Player = Player.new()
	player.peer_id = 1
	add_child_autofree(player)
	
	_trait_system.apply(1, &"phantom_ringing")
	
	# Test hook handling
	var result: bool = player.handle_trait_hook(&"phantom_ringing")
	assert_true(result)


## Test: Apply trait from Player method
func test_player_apply_trait() -> void:
	var player: Player = Player.new()
	player.peer_id = 1
	add_child_autofree(player)
	
	var result: bool = player.apply_trait(&"limping", &"test_source")
	assert_true(result)
	assert_true(player.has_trait(&"limping"))
	
	var traits: Dictionary = player.get_active_traits()
	assert_true(traits.has(&"limping"))
	assert_eq(traits[&"limping"].source_event, &"test_source")


## Test: TraitSystem reset_player
func test_reset_player() -> void:
	_trait_system.apply(1, &"limping")
	_trait_system.apply(1, &"ptsd")
	
	assert_true(_trait_system.has_trait(1, &"limping"))
	assert_true(_trait_system.has_trait(1, &"ptsd"))
	
	_trait_system.reset_player(1)
	
	assert_false(_trait_system.has_trait(1, &"limping"))
	assert_false(_trait_system.has_trait(1, &"ptsd"))


## Test: TraitData validation
func test_trait_data_validation() -> void:
	var limping: TraitData = _trait_system.get_catalog()[&"limping"]
	var result: Dictionary = limping.validate()
	assert_true(result.errors.is_empty())
	
	# Test invalid trait
	var bad_trait: TraitData = TraitData.new()
	bad_trait.id = &""
	var bad_result: Dictionary = bad_trait.validate()
	assert_false(bad_result.errors.is_empty())