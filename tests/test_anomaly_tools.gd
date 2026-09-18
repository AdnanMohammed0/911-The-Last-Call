## GUT tests for Anomaly Tools (P3-15).
## Run with: godot --headless -s res://addons/gut/gut_cmdln.gd -gtest=tests/test_anomaly_tools.gd
extends GutTest

# Loosely typed test code (mocks and dictionaries).
@warning_ignore_start("unsafe_call_argument", "unsafe_cast", "unsafe_method_access", "unsafe_property_access", "untyped_declaration", "inferred_declaration", "return_value_discarded")

var _emf_reader: EMFReader
var _salt_canister: SaltCanister
var _tone_emitter: SpectralToneEmitter
var _remains: RemainsInteraction
var _shovel: ShovelTool
var _mock_anomaly: Node
var _mock_player: Player


func before() -> void:
	# Create mock anomaly
	_mock_anomaly = Node.new()
	_mock_anomaly.name = "TestAnomaly"
	_mock_anomaly.add_to_group("anomalies")
	_mock_anomaly.global_position = Vector3(0, 0, 0)
	
	# Create mock player
	_mock_player = Player.new()
	_mock_player.peer_id = 1
	_mock_player.global_position = Vector3(5, 0, 5)
	_mock_player.class_id = &"medic"
	add_child_autofree(_mock_player)
	
	# Create EMF Reader
	_emf_reader = EMFReader.new()
	_mock_player.add_child(_emf_reader)
	
	# Create Salt Canister
	_salt_canister = SaltCanister.new()
	_mock_player.add_child(_salt_canister)
	
	# Create Spectral Tone Emitter
	_tone_emitter = SpectralToneEmitter.new()
	_mock_player.add_child(_tone_emitter)
	
	# Create Remains Interaction
	_remains = RemainsInteraction.new()
	_remains.global_position = Vector3(10, 0, 10)
	add_child_autofree(_remains)
	
	# Create Shovel Tool
	_shovel = ShovelTool.new()
	_mock_player.add_child(_shovel)


func after() -> void:
	_emf_reader = null
	_salt_canister = null
	_tone_emitter = null
	_remains = null
	_shovel = null
	_mock_anomaly = null
	_mock_player = null


# --- EMF Reader Tests ---

func test_emf_reader_initial_state() -> void:
	assert_false(_emf_reader.is_anomaly_nearby())
	assert_eq(_emf_reader.get_emf_level(), 0)


func test_emf_reader_detects_anomaly() -> void:
	# Add EMF level to mock anomaly
	_mock_anomaly.emf_level = 5
	
	# Update EMF reader
	_emf_reader._scan_for_anomalies()
	
	assert_eq(_emf_reader.get_emf_level(), 5)
	assert_true(_emf_reader.is_anomaly_nearby())


func test_emf_reader_accuracy_penalty_non_medic() -> void:
	var emf_reader: EMFReader = EMFReader.new()
	var player: Player = Player.new()
	player.class_id = &"tech"  # Not medic
	player.global_position = Vector3(5, 0, 5)
	player.add_child(emf_reader)
	add_child_autofree(player)
	
	_mock_anomaly.emf_level = 5
	emf_reader._scan_for_anomalies()
	
	# Non-medics get 50% accuracy, so level 5 -> 2
	assert_eq(emf_reader.get_emf_level(), 2)


# --- Salt Canister Tests ---

func test_salt_canister_deploy() -> void:
	# Mock LoadoutManager
	var loadout_mgr: LoadoutManager = LoadoutManager.new()
	add_child_autofree(loadout_mgr)
	loadout_mgr._ready()
	
	# Add salt canister to loadout
	loadout_mgr.purchase_gear(1, &"salt_canister", &"medic")
	
	assert_true(_salt_canister.deploy())
	assert_not_null(_salt_canister._active_line)


func test_salt_canister_no_ammo() -> void:
	var loadout_mgr: LoadoutManager = LoadoutManager.new()
	add_child_autofree(loadout_mgr)
	loadout_mgr._ready()
	
	# Don't add salt canister to loadout
	assert_false(_salt_canister.deploy())


func test_salt_canister_cooldown() -> void:
	var loadout_mgr: LoadoutManager = LoadoutManager.new()
	add_child_autofree(loadout_mgr)
	loadout_mgr._ready()
	loadout_mgr.purchase_gear(1, &"salt_canister", &"medic")
	
	# First deploy
	assert_true(_salt_canister.deploy())
	
	# Second deploy immediately should fail due to cooldown
	assert_false(_salt_canister.deploy())


# --- Spectral Tone Emitter Tests ---

func test_tone_emitter_start_channel() -> void:
	# Create mock anomaly in range
	var anomaly: Node = Node.new()
	anomaly.name = "TestAnomaly"
	anomaly.add_to_group("anomalies")
	anomaly.global_position = Vector3(5, 0, 5)
	add_child(anomaly)
	
	# Add method to mock anomaly
	anomaly.on_reverse_tone_complete = func() -> void: pass
	
	assert_true(_tone_emitter.start_channel())
	assert_true(_tone_emitter.is_channeling())
	assert_eq(_tone_emitter.get_uses_remaining(), 1)


func test_tone_emitter_no_anomaly_in_range() -> void:
	assert_false(_tone_emitter.start_channel())


func test_tone_emitter_uses_remaining() -> void:
	var anomaly: Node = Node.new()
	anomaly.name = "TestAnomaly"
	anomaly.add_to_group("anomalies")
	anomaly.global_position = Vector3(5, 0, 5)
	anomaly.on_reverse_tone_complete = func() -> void: pass
	add_child(anomaly)
	
	_tone_emitter.start_channel()
	assert_eq(_tone_emitter.get_uses_remaining(), 1)
	
	_tone_emitter.start_channel()
	assert_eq(_tone_emitter.get_uses_remaining(), 0)
	
	# Third attempt should fail
	assert_false(_tone_emitter.start_channel())


# --- Remains Interaction Tests ---

func test_remains_initial_state() -> void:
	assert_true(_remains.is_available())
	assert_eq(_remains.get_completion_flag(), &"lake_house_cleared")


func test_remains_burial_requires_shovel() -> void:
	# Mock LoadoutManager
	var loadout_mgr: LoadoutManager = LoadoutManager.new()
	add_child_autofree(loadout_mgr)
	loadout_mgr._ready()
	
	# Try to interact without shovel
	_remains._on_interacted(1)
	
	# Should not start burial (no shovel)
	assert_eq(_remains._burial_state, 0)


func test_remains_burial_with_shovel() -> void:
	var loadout_mgr: LoadoutManager = LoadoutManager.new()
	add_child_autofree(loadout_mgr)
	loadout_mgr._ready()
	
	# Add shovel to loadout
	loadout_mgr.purchase_gear(1, &"shovel", &"medic")
	
	_remains._on_interacted(1)
	
	assert_eq(_remains._burial_state, 1)
	assert_true(_remains._dig_timer != null)


# --- Shovel Tool Tests ---

func test_shovel_start_dig() -> void:
	var target: Node = Node.new()
	target.on_bones_buried = func() -> void: pass
	add_child(target)
	
	assert_true(_shovel.start_dig(target))
	assert_true(_shovel.is_digging())


func test_shovel_dig_completes() -> void:
	var target: Node = Node.new()
	target.on_bones_buried = func() -> void: pass
	add_child(target)
	
	_shovel.start_dig(target)
	
	# Simulate time passing
	for i in range(50):
		_shovel._physics_process(0.1)
	
	assert_false(_shovel.is_digging())


func test_shovel_interrupted_by_movement() -> void:
	var target: Node = Node.new()
	target.on_bones_buried = func() -> void: pass
	add_child(target)
	
	_shovel.start_dig(target)
	
	# Move player
	var player: Player = Player.new()
	player.global_position = Vector3(100, 0, 100)
	_shovel._owner = player
	_shovel._dig_start_pos = Vector3(0, 0, 0)
	
	_shovel._physics_process(0.1)
	
	assert_false(_shovel.is_digging())