## GUT Tests for Global Meters (P4-04)
## Tests Public Trust, Station Budget, Cult Awareness and threshold effects

extends GutTest

# Loosely typed test code (mocks and dictionaries).
@warning_ignore_start("unsafe_call_argument", "unsafe_cast", "unsafe_method_access", "unsafe_property_access", "untyped_declaration", "inferred_declaration", "return_value_discarded")

var _game_state: GameState
var _call_director: CallDirector
var _loadout_manager: LoadoutManager
var _mission_director: MissionDirector
var _event_bus: EventBus

func before_each():
	_game_state = GameState.new()
	_call_director = CallDirector.new()
	_loadout_manager = LoadoutManager.new()
	_mission_director = MissionDirector.new()
	_event_bus = EventBus.new()
	
	# Add to tree so signals work
	get_tree().root.add_child(_game_state)
	get_tree().root.add_child(_call_director)
	get_tree().root.add_child(_loadout_manager)
	get_tree().root.add_child(_mission_director)
	get_tree().root.add_child(_event_bus)
	
	# Initialize
	_game_state.reset()
	_call_director.reset()
	_loadout_manager.reset()
	_mission_director.reset()

func after_each():
	_game_state.queue_free()
	_call_director.queue_free()
	_loadout_manager.queue_free()
	_mission_director.queue_free()
	_event_bus.queue_free()

# ==============================================================================
# Public Trust Tests
# ==============================================================================

func test_public_trust_default():
	assert_eq(_game_state.public_trust, 75)

func test_public_trust_increase():
	_game_state.modify_public_trust(10)
	assert_eq(_game_state.public_trust, 85)

func test_public_trust_decrease():
	_game_state.modify_public_trust(-20)
	assert_eq(_game_state.public_trust, 55)

func test_public_trust_clamp_min():
	_game_state.modify_public_trust(-100)
	assert_eq(_game_state.public_trust, 0)

func test_public_trust_clamp_max():
	_game_state.modify_public_trust(100)
	assert_eq(_game_state.public_trust, 100)

func test_public_trust_threshold_withhold_address():
	var crossed: bool = false
	var crossed_value: int = 0
	
	func _on_crossed(threshold_id: StringName, value: int):
		crossed = true
		crossed_value = value
	
	_event_bus.trust_threshold_crossed.connect(_on_crossed)
	
	# Cross below 40
	_game_state.modify_public_trust(-40)  # 75 -> 35
	
	assert_true(crossed)
	assert_eq(crossed_value, 35)

func test_public_trust_threshold_restored_address():
	var crossed: bool = false
	
	func _on_crossed(threshold_id: StringName, value: int):
		if threshold_id == &"restored_address":
			crossed = true
	
	_event_bus.trust_threshold_crossed.connect(_on_crossed)
	
	# Cross below 40 first
	_game_state.modify_public_trust(-40)
	# Cross back above 40
	_game_state.modify_public_trust(20)  # 35 -> 55
	
	assert_true(crossed)

func test_public_trust_threshold_siege_weight():
	var crossed: bool = false
	
	func _on_crossed(threshold_id: StringName, value: int):
		if threshold_id == &"siege_weight_up":
			crossed = true
	
	_event_bus.trust_threshold_crossed.connect(_on_crossed)
	
	# Cross below 20
	_game_state.modify_public_trust(-60)  # 75 -> 15
	
	assert_true(crossed)

func test_public_trust_threshold_cult_tips():
	var crossed: bool = false
	
	func _on_crossed(threshold_id: StringName, value: int):
		if threshold_id == &"cult_tips_unlocked":
			crossed = true
	
	_event_bus.trust_threshold_crossed.connect(_on_crossed)
	
	# Cross above 80
	_game_state.modify_public_trust(10)  # 75 -> 85
	
	assert_true(crossed)

# ==============================================================================
# Station Budget Tests
# ==============================================================================

func test_station_budget_default():
	assert_eq(_game_state.station_budget, 10000)

func test_station_budget_increase():
	_game_state.modify_station_budget(500)
	assert_eq(_game_state.station_budget, 10500)

func test_station_budget_decrease():
	_game_state.modify_station_budget(-2000)
	assert_eq(_game_state.station_budget, 8000)

func test_station_budget_clamp_min():
	_game_state.modify_station_budget(-15000)
	assert_eq(_game_state.station_budget, 0)

func test_station_budget_threshold_half_armory():
	var crossed: bool = false
	
	func _on_crossed(threshold_id: StringName, value: int):
		if threshold_id == &"half_armory_locked":
			crossed = true
	
	_event_bus.budget_threshold_crossed.connect(_on_crossed)
	
	# Cross below 3000
	_game_state.modify_station_budget(-7500)  # 10000 -> 2500
	
	assert_true(crossed)

func test_station_budget_threshold_no_heavy():
	var crossed: bool = false
	
	func _on_crossed(threshold_id: StringName, value: int):
		if threshold_id == &"no_heavy_gear":
			crossed = true
	
	_event_bus.budget_threshold_crossed.connect(_on_crossed)
	
	# Cross below 1000
	_game_state.modify_station_budget(-9500)  # 10000 -> 500
	
	assert_true(crossed)

# ==============================================================================
# Cult Awareness Tests
# ==============================================================================

func test_cult_awareness_default():
	assert_eq(_game_state.cult_awareness, 0)

func test_cult_awareness_increase():
	_game_state.modify_cult_awareness(25)
	assert_eq(_game_state.cult_awareness, 25)

func test_cult_awareness_decrease():
	_game_state.modify_cult_awareness(50)
	_game_state.modify_cult_awareness(-20)
	assert_eq(_game_state.cult_awareness, 30)

func test_cult_awareness_clamp_min():
	_game_state.modify_cult_awareness(-10)
	assert_eq(_game_state.cult_awareness, 0)

func test_cult_awareness_clamp_max():
	_game_state.modify_cult_awareness(150)
	assert_eq(_game_state.cult_awareness, 100)

func test_cult_awareness_threshold_counter_ambush():
	var crossed: bool = false
	
	func _on_crossed(threshold_id: StringName, value: int):
		if threshold_id == &"counter_ambush_active":
			crossed = true
	
	_event_bus.cult_threshold_crossed.connect(_on_crossed)
	
	# Cross above 60
	_game_state.modify_cult_awareness(65)
	
	assert_true(crossed)

func test_cult_awareness_threshold_station_siege():
	var crossed: bool = false
	
	func _on_crossed(threshold_id: StringName, value: int):
		if threshold_id == &"station_siege_triggered":
			crossed = true
	
	_event_bus.cult_threshold_crossed.connect(_on_crossed)
	
	# Cross above 90
	_game_state.modify_cult_awareness(95)
	
	assert_true(crossed)

# ==============================================================================
# Integration Tests
# ==============================================================================

func test_loadout_manager_budget_threshold_half_armory():
	# Set budget below 3000
	_game_state.modify_station_budget(-7500)
	
	# Process signals
	get_tree().process_frame()
	
	# Try to purchase non-basic gear (should fail)
	var success: bool = _loadout_manager.purchase_gear(1, &"pump_shotgun", &"breacher")
	assert_false(success)
	
	# Try to purchase basic gear (should succeed)
	success = _loadout_manager.purchase_gear(1, &"service_pistol", &"breacher")
	assert_true(success)

func test_loadout_manager_budget_threshold_no_heavy():
	# Set budget below 1000
	_game_state.modify_station_budget(-9500)
	
	# Process signals
	get_tree().process_frame()
	
	# Try to purchase heavy gear (should fail)
	var success: bool = _loadout_manager.purchase_gear(1, &"ballistic_shield", &"breacher")
	assert_false(success)

func test_mission_director_cult_threshold_counter_ambush():
	# Set cult awareness above 60
	_game_state.modify_cult_awareness(65)
	
	# Process signals
	get_tree().process_frame()
	
	assert_true(_mission_director.is_counter_ambush_active())

func test_mission_director_cult_threshold_station_siege():
	var announcement_received: bool = false
	
	func _on_announce(title: String, subtitle: String):
		if title == "STATION SIEGE":
			announcement_received = true
	
	_event_bus.announcement.connect(_on_announce)
	
	# Set cult awareness above 90
	_game_state.modify_cult_awareness(95)
	
	# Process signals
	get_tree().process_frame()
	
	assert_true(_mission_director.is_station_siege_triggered())
	assert_true(announcement_received)

func test_reset_clears_all_meters():
	_game_state.modify_public_trust(-50)
	_game_state.modify_station_budget(-5000)
	_game_state.modify_cult_awareness(80)
	
	_game_state.reset()
	
	assert_eq(_game_state.public_trust, 75)
	assert_eq(_game_state.station_budget, 10000)
	assert_eq(_game_state.cult_awareness, 0)

func test_global_meter_changed_signal_emitted():
	var signal_received: bool = false
	var meter_id: StringName
	var old_val: int
	var new_val: int
	
	func _on_meter_changed(m_id: StringName, old_v: int, new_v: int):
		signal_received = true
		meter_id = m_id
		old_val = old_v
		new_val = new_v
	
	_event_bus.global_meter_changed.connect(_on_meter_changed)
	
	_game_state.modify_public_trust(10)
	
	assert_true(signal_received)
	assert_eq(meter_id, &"public_trust")
	assert_eq(old_val, 75)
	assert_eq(new_val, 85)