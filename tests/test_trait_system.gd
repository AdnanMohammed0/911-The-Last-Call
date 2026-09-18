## GUT tests for Trait System (P4-03).
## Run with: godot --headless -s res://addons/gut/gut_cmdln.gd -gtest=tests/test_trait_system.gd
extends GutTest


func before_each() -> void:
	TraitSystem.reset_player(1)


func after_each() -> void:
	TraitSystem.reset_player(1)


func _spawn_player(peer_id: int = 1) -> Player:
	var packed: PackedScene = load("res://scenes/shared/player/player.tscn") as PackedScene
	var player: Player = packed.instantiate() as Player
	player.peer_id = peer_id
	player.class_id = &"tech"
	add_child_autofree(player)
	return player


## Test: TraitData catalog loads correctly
func test_trait_catalog_loading() -> void:
	var catalog: Dictionary = TraitSystem.get_catalog()
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
	_spawn_player(1)
	var result: bool = TraitSystem.apply(1, &"limping")
	assert_true(result)
	assert_true(TraitSystem.has_trait(1, &"limping"))
	
	var traits: Dictionary = TraitSystem.get_player_traits(1)
	assert_true(traits.has(&"limping"))
	var limping_data: Dictionary = traits.get(&"limping", {})
	var shifts: int = limping_data.get("shifts_remaining", 0)
	var source: StringName = limping_data.get("source_event", &"")
	assert_eq(shifts, 2)
	assert_eq(source, &"")


## Test: Apply trait with custom duration
func test_apply_trait_custom_duration() -> void:
	_spawn_player(1)
	var result: bool = TraitSystem.apply(1, &"limping", &"test_event", 5)
	assert_true(result)
	
	var traits: Dictionary = TraitSystem.get_player_traits(1)
	var limping_data: Dictionary = traits.get(&"limping", {})
	var shifts: int = limping_data.get("shifts_remaining", 0)
	var source: StringName = limping_data.get("source_event", &"")
	assert_eq(shifts, 5)
	assert_eq(source, &"test_event")


## Test: Apply same trait twice (refreshes duration)
func test_apply_trait_refresh() -> void:
	_spawn_player(1)
	TraitSystem.apply(1, &"limping", &"", 2)
	TraitSystem.apply(1, &"limping", &"", 5)
	
	var traits: Dictionary = TraitSystem.get_player_traits(1)
	var limping_data: Dictionary = traits.get(&"limping", {})
	var shifts: int = limping_data.get("shifts_remaining", 0)
	assert_eq(shifts, 5)  # Should use longer duration


## Test: Remove trait
func test_remove_trait() -> void:
	_spawn_player(1)
	TraitSystem.apply(1, &"limping")
	assert_true(TraitSystem.has_trait(1, &"limping"))
	
	var result: bool = TraitSystem.remove(1, &"limping")
	assert_true(result)
	assert_false(TraitSystem.has_trait(1, &"limping"))


## Test: Permanent trait (duration -1) doesn't expire
func test_permanent_trait_no_expire() -> void:
	_spawn_player(1)
	TraitSystem.apply(1, &"scarred")  # duration -1 = permanent
	
	# Simulate shift progression
	for i in range(10):
		TraitSystem._on_shift_updated(360 * (i + 1))
	
	assert_true(TraitSystem.has_trait(1, &"scarred"))
	var traits: Dictionary = TraitSystem.get_player_traits(1)
	var scarred_data: Dictionary = traits.get(&"scarred", {})
	var shifts: int = scarred_data.get("shifts_remaining", 0)
	assert_eq(shifts, -1)


## Test: Trait expires after duration shifts
func test_trait_expires() -> void:
	_spawn_player(1)
	TraitSystem.apply(1, &"limping")  # 2 shifts
	
	# First shift
	TraitSystem._on_shift_updated(360)
	assert_true(TraitSystem.has_trait(1, &"limping"))
	assert_eq(TraitSystem.get_shifts_remaining(1, &"limping"), 1)
	
	# Second shift (duration 2 expires)
	TraitSystem._on_shift_updated(720)
	assert_false(TraitSystem.has_trait(1, &"limping"))


## Test: Trait stat modifiers applied to player
func test_trait_stat_modifiers() -> void:
	var player: Player = _spawn_player(1)
	player.move_speed_multiplier = 1.0
	player.noise_multiplier = 1.0
	
	# Apply limping trait
	TraitSystem.apply(1, &"limping")
	
	# Check modifiers applied
	assert_almost_eq(player.move_speed_multiplier, 0.7, 0.01)  # 1.0 - 0.3
	assert_almost_eq(player.noise_multiplier, 1.4, 0.01)      # 1.0 + 0.4


## Test: Trait stat modifiers removed when trait removed
func test_trait_stat_modifiers_removed() -> void:
	var player: Player = _spawn_player(1)
	player.move_speed_multiplier = 1.0
	player.noise_multiplier = 1.0
	
	TraitSystem.apply(1, &"limping")
	assert_almost_eq(player.move_speed_multiplier, 0.7, 0.01)
	
	TraitSystem.remove(1, &"limping")
	assert_almost_eq(player.move_speed_multiplier, 1.0, 0.01)
	assert_almost_eq(player.noise_multiplier, 1.0, 0.01)


## Test: PTSD sanity drain multiplier
func test_ptsd_sanity_drain() -> void:
	_spawn_player(1)
	TraitSystem.apply(1, &"ptsd")
	assert_true(TraitSystem.has_trait(1, &"ptsd"))


## Test: Trait hook handling
func test_trait_hook_handling() -> void:
	var player: Player = _spawn_player(1)
	TraitSystem.apply(1, &"phantom_ringing")
	var result: bool = player.handle_trait_hook(&"phantom_ringing")
	assert_true(result)


## Test: Apply trait from Player method
func test_player_apply_trait() -> void:
	var player: Player = _spawn_player(1)
	var result: bool = player.apply_trait(&"limping", &"test_source")
	assert_true(result)
	assert_true(player.has_trait(&"limping"))
	
	var traits: Dictionary = player.get_active_traits()
	assert_true(traits.has(&"limping"))
	var limping_data: Dictionary = traits.get(&"limping", {})
	var source: StringName = limping_data.get("source_event", &"")
	assert_eq(source, &"test_source")


## Test: TraitSystem reset_player
func test_reset_player() -> void:
	_spawn_player(1)
	TraitSystem.apply(1, &"limping")
	TraitSystem.apply(1, &"ptsd")
	
	assert_true(TraitSystem.has_trait(1, &"limping"))
	assert_true(TraitSystem.has_trait(1, &"ptsd"))
	
	TraitSystem.reset_player(1)
	
	assert_false(TraitSystem.has_trait(1, &"limping"))
	assert_false(TraitSystem.has_trait(1, &"ptsd"))


## Test: TraitData validation
func test_trait_data_validation() -> void:
	var catalog: Dictionary = TraitSystem.get_catalog()
	var limping: TraitData = catalog[&"limping"]
	var result: Dictionary = limping.validate()
	var errs: PackedStringArray = result.get("errors", PackedStringArray())
	assert_true(errs.is_empty())
	
	# Test invalid trait
	var bad_trait: TraitData = TraitData.new()
	bad_trait.id = &""
	var bad_result: Dictionary = bad_trait.validate()
	var bad_errs: PackedStringArray = bad_result.get("errors", PackedStringArray())
	assert_false(bad_errs.is_empty())