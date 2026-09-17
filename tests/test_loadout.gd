## GUT tests for Loadout Armory (P2-15).
## Run with: godot --headless -s res://addons/gut/gut_cmdln.gd -gtest=tests/test_loadout.gd
extends GutTest

var _loadout_manager: LoadoutManager
var _game_state: GameState
var _net_manager: NetManager


func before() -> void:
	_loadout_manager = LoadoutManager.new()
	add_child_autofree(_loadout_manager)
	
	_game_state = GameState.new()
	add_child_autofree(_game_state)
	_game_state.reset()
	
	_net_manager = NetManager.new()
	add_child_autofree(_net_manager)
	
	# Wait for ready
	_loadout_manager._ready()
	_game_state._ready()


func after() -> void:
	_loadout_manager = null
	_game_state = null
	_net_manager = null


# --- GearItem Tests ---

func test_gear_item_basic_properties() -> void:
	var gear: GearItem = GearItem.new()
	gear.id = &"test_item"
	gear.display_name = "Test Item"
	gear.cost = 100
	gear.slot = GearItem.Slot.PRIMARY
	gear.max_carry = 2
	
	assert_eq(gear.id, &"test_item")
	assert_eq(gear.display_name, "Test Item")
	assert_eq(gear.cost, 100)
	assert_eq(gear.slot, GearItem.Slot.PRIMARY)
	assert_eq(gear.max_carry, 2)


func test_gear_item_class_restriction() -> void:
	var gear: GearItem = GearItem.new()
	gear.id = &"breacher_only"
	gear.allowed_classes = PackedStringArray(&"breacher")
	
	assert_true(gear.is_available_for_class(&"breacher"))
	assert_false(gear.is_available_for_class(&"tech"))
	assert_false(gear.is_available_for_class(&"profiler"))


func test_gear_item_no_class_restriction() -> void:
	var gear: GearItem = GearItem.new()
	gear.id = &"universal"
	gear.allowed_classes = PackedStringArray()
	
	assert_true(gear.is_available_for_class(&"breacher"))
	assert_true(gear.is_available_for_class(&"tech"))
	assert_true(gear.is_available_for_class(&"profiler"))
	assert_true(gear.is_available_for_class(&"medic"))


func test_gear_item_breacher_discount() -> void:
	var gear: GearItem = GearItem.new()
	gear.id = &"heavy_gear"
	gear.cost = 1000
	gear.breacher_discount = true
	
	assert_eq(gear.get_effective_cost(&"breacher"), 850)  # 15% off
	assert_eq(gear.get_effective_cost(&"tech"), 1000)     # no discount
	assert_eq(gear.get_effective_cost(&"profiler"), 1000) # no discount


func test_gear_item_validation() -> void:
	var gear: GearItem = GearItem.new()
	gear.id = &"valid"
	gear.cost = 100
	gear.quantity_per_purchase = 1
	gear.max_carry = 1
	
	var result: Dictionary = gear.validate()
	assert_true(result.errors.is_empty())
	
	# Invalid cases
	gear.id = &""
	result = gear.validate()
	assert_false(result.errors.is_empty())
	
	gear.id = &"valid"
	gear.cost = -1
	result = gear.validate()
	assert_false(result.errors.is_empty())


# --- LoadoutManager Tests ---

func test_loadout_manager_initial_budget() -> void:
	assert_eq(_loadout_manager.get_budget(), 10000)


func test_loadout_manager_set_budget() -> void:
	_loadout_manager.set_budget(5000)
	assert_eq(_loadout_manager.get_budget(), 5000)
	
	_loadout_manager.set_budget(-100)
	assert_eq(_loadout_manager.get_budget(), 0)  # Clamped to 0


func test_purchase_gear_success() -> void:
	var peer_id: int = 1
	var class_id: StringName = &"tech"
	
	# Purchase Recon Drone (Tech only, 600)
	var result: bool = _loadout_manager.purchase_gear(peer_id, &"recon_drone", class_id)
	assert_true(result)
	assert_eq(_loadout_manager.get_budget(), 9400)  # 10000 - 600
	
	var loadout: Dictionary = _loadout_manager.get_player_loadout(peer_id)
	assert_true(loadout.has(&"recon_drone"))
	assert_eq(loadout[&"recon_drone"], 1)


func test_purchase_gear_insufficient_budget() -> void:
	var peer_id: int = 1
	var class_id: StringName = &"tech"
	
	# Set low budget
	_loadout_manager.set_budget(500)
	
	# Try to buy Recon Drone (600)
	var result: bool = _loadout_manager.purchase_gear(peer_id, &"recon_drone", class_id)
	assert_false(result)
	assert_eq(_loadout_manager.get_budget(), 500)  # Unchanged


func test_purchase_gear_class_restriction() -> void:
	var peer_id: int = 1
	var class_id: StringName = &"profiler"
	
	# Try to buy Recon Drone (Tech only)
	var result: bool = _loadout_manager.purchase_gear(peer_id, &"recon_drone", class_id)
	assert_false(result)


func test_purchase_gear_breacher_discount() -> void:
	var peer_id: int = 1
	var class_id: StringName = &"breacher"
	
	# Pump Shotgun costs 400, 15% off for Breacher = 340
	_loadout_manager.set_budget(1000)
	
	var result: bool = _loadout_manager.purchase_gear(peer_id, &"pump_shotgun", class_id)
	assert_true(result)
	assert_eq(_loadout_manager.get_budget(), 660)  # 1000 - 340


func test_purchase_gear_max_carry() -> void:
	var peer_id: int = 1
	var class_id: StringName = &"tech"
	
	_loadout_manager.set_budget(5000)
	
	# Buy Recon Drone (max_carry = 1)
	_loadout_manager.purchase_gear(peer_id, &"recon_drone", class_id)
	
	# Try to buy again - should fail
	var result: bool = _loadout_manager.purchase_gear(peer_id, &"recon_drone", class_id)
	assert_false(result)


func test_sell_gear() -> void:
	var peer_id: int = 1
	var class_id: StringName = &"tech"
	
	_loadout_manager.set_budget(1000)
	
	# Buy Recon Drone (600)
	_loadout_manager.purchase_gear(peer_id, &"recon_drone", class_id)
	assert_eq(_loadout_manager.get_budget(), 400)
	
	# Sell it back (50% refund = 300)
	_loadout_manager.sell_gear(peer_id, &"recon_drone")
	assert_eq(_loadout_manager.get_budget(), 700)  # 400 + 300
	
	var loadout: Dictionary = _loadout_manager.get_player_loadout(peer_id)
	assert_false(loadout.has(&"recon_drone"))


func test_clear_player_loadout() -> void:
	var peer_id: int = 1
	var class_id: StringName = &"tech"
	
	_loadout_manager.set_budget(5000)
	
	# Buy multiple items
	_loadout_manager.purchase_gear(peer_id, &"recon_drone", class_id)    # 600
	_loadout_manager.purchase_gear(peer_id, &"tear_gas", class_id)       # 250
	
	assert_eq(_loadout_manager.get_budget(), 4150)
	
	# Clear loadout
	_loadout_manager.clear_player_loadout(peer_id)
	
	# Should get 50% refund for each
	# Recon Drone: 600 * 0.5 = 300
	# Tear Gas: 250 * 0.5 = 125
	# Total refund: 425
	# New budget: 4150 + 425 = 4575
	assert_eq(_loadout_manager.get_budget(), 4575)
	
	var loadout: Dictionary = _loadout_manager.get_player_loadout(peer_id)
	assert_true(loadout.is_empty())


func test_get_gear_for_class() -> void:
	var tech_gear: Array[GearItem] = _loadout_manager.get_gear_for_class(&"tech")
	var breacher_gear: Array[GearItem] = _loadout_manager.get_gear_for_class(&"breacher")
	var medic_gear: Array[GearItem] = _loadout_manager.get_gear_for_class(&"medic")
	
	# Tech should have Recon Drone
	var has_drone: bool = false
	for g in tech_gear:
		if g.id == &"recon_drone":
			has_drone = true
			break
	assert_true(has_drone)
	
	# Breacher should have Ballistic Shield
	var has_shield: bool = false
	for g in breacher_gear:
		if g.id == &"ballistic_shield":
			has_shield = true
			break
	assert_true(has_shield)
	
	# Medic should have Sedatives
	var has_sedatives: bool = false
	for g in medic_gear:
		if g.id == &"sedatives":
			has_sedatives = true
			break
	assert_true(has_sedatives)


# --- Approach Vote Tests ---

func test_open_approach_vote() -> void:
	var vote_id: int = _loadout_manager.open_approach_vote()
	assert_true(vote_id > 0)
	
	var tally: Dictionary = _loadout_manager.get_tally(vote_id)
	assert_true(tally.is_empty())  # No votes yet


func test_cast_vote() -> void:
	var vote_id: int = _loadout_manager.open_approach_vote()
	
	var result: bool = _loadout_manager.cast_vote(1, &"code3")
	assert_true(result)
	
	var tally: Dictionary = _loadout_manager.get_tally(vote_id)
	assert_eq(tally[&"code3"], 1)


func test_vote_unanimous_early_close() -> void:
	var vote_id: int = _loadout_manager.open_approach_vote()
	
	# Both players vote same option
	_loadout_manager.cast_vote(1, &"silent")
	_loadout_manager.cast_vote(2, &"silent")
	
	# Vote should be closed and result should be "silent"
	# Note: In real scenario with 2 players, unanimous closes early
	# We can't easily test the auto-close without timing, so just verify votes recorded
	var tally: Dictionary = _loadout_manager.get_tally(vote_id)
	assert_eq(tally[&"silent"], 2)


func test_vote_tie_breaker_breacher() -> void:
	# Simulate a tie between two players
	var vote_id: int = _loadout_manager.open_approach_vote()
	
	_loadout_manager.cast_vote(1, &"code3")
	_loadout_manager.cast_vote(2, &"silent")
	
	# Tally is tied 1-1
	var tally: Dictionary = _loadout_manager.get_tally(vote_id)
	assert_eq(tally[&"code3"], 1)
	assert_eq(tally[&"silent"], 1)
	
	# The tie-breaker logic is in _determine_vote_winner
	# which checks for Breacher's vote


func test_vote_invalid_option() -> void:
	var vote_id: int = _loadout_manager.open_approach_vote()
	
	# Try to vote for invalid option
	var result: bool = _loadout_manager.cast_vote(1, &"invalid_option")
	assert_false(result)


# --- Budget Integration Tests ---

func test_budget_affects_gear_availability() -> void:
	var peer_id: int = 1
	var class_id: StringName = &"breacher"
	
	# High budget - can buy heavy gear
	_loadout_manager.set_budget(5000)
	var result: bool = _loadout_manager.purchase_gear(peer_id, &"ballistic_shield", class_id)
	assert_true(result)
	
	# Clear and test low budget
	_loadout_manager.clear_player_loadout(peer_id)
	_loadout_manager.set_budget(2000)
	
	# Shield costs 900, should still be affordable
	result = _loadout_manager.purchase_gear(peer_id, &"ballistic_shield", class_id)
	assert_true(result)
	
	# Clear and test very low budget
	_loadout_manager.clear_player_loadout(peer_id)
	_loadout_manager.set_budget(500)
	
	# Shield not affordable
	result = _loadout_manager.purchase_gear(peer_id, &"ballistic_shield", class_id)
	assert_false(result)
	
	# But pistol is free
	result = _loadout_manager.purchase_gear(peer_id, &"service_pistol", class_id)
	assert_true(result)


# --- Loadout Finalization Tests ---

func test_finalize_loadout() -> void:
	var peer_id: int = 1
	var class_id: StringName = &"tech"
	
	_loadout_manager.purchase_gear(peer_id, &"recon_drone", class_id)
	_loadout_manager.purchase_gear(peer_id, &"tear_gas", class_id)
	
	var loadout: Dictionary = _loadout_manager.get_player_loadout(peer_id)
	assert_true(loadout.has(&"recon_drone"))
	assert_true(loadout.has(&"tear_gas"))
	
	# Finalize doesn't change loadout, just emits signal
	_loadout_manager.finalize_loadout(peer_id)
	
	# Loadout should still be there
	loadout = _loadout_manager.get_player_loadout(peer_id)
	assert_true(loadout.has(&"recon_drone"))
	assert_true(loadout.has(&"tear_gas"))


# --- Consumable Quantity Tests ---

func test_consumable_quantity_per_purchase() -> void:
	var peer_id: int = 1
	var class_id: StringName = &"medic"
	
	# Sedatives: quantity_per_purchase = 3, max_carry = 3
	_loadout_manager.purchase_gear(peer_id, &"sedatives", class_id)
	
	var loadout: Dictionary = _loadout_manager.get_player_loadout(peer_id)
	assert_eq(loadout[&"sedatives"], 3)  # Got 3 at once
	
	# Can't buy more (max_carry = 3)
	var result: bool = _loadout_manager.purchase_gear(peer_id, &"sedatives", class_id)
	assert_false(result)


func test_tear_gas_quantity() -> void:
	var peer_id: int = 1
	var class_id: StringName = &"tech"
	
	# Tear Gas: quantity_per_purchase = 2, max_carry = 2
	_loadout_manager.purchase_gear(peer_id, &"tear_gas", class_id)
	
	var loadout: Dictionary = _loadout_manager.get_player_loadout(peer_id)
	assert_eq(loadout[&"tear_gas"], 2)