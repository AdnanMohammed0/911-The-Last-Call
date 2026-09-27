## GUT tests for Anomaly Tools (P3-15).
## Run with: godot --headless -s res://addons/gut/gut_cmdln.gd -gtest=tests/test_anomaly_tools.gd
extends GutTest

# Loosely typed test code (mocks and dictionaries).
@warning_ignore_start("unsafe_call_argument", "unsafe_cast", "unsafe_method_access", "unsafe_property_access", "untyped_declaration", "inferred_declaration", "return_value_discarded")

class MockAnomaly extends Node3D:
	var emf_level: int = 0
	func get_emf_level() -> int:
		return emf_level
	func on_reverse_tone_complete() -> void:
		pass

class MockDigTarget extends Node:
	var buried: bool = false
	func on_bones_buried() -> void:
		buried = true

const PLAYER_SCENE: PackedScene = preload("res://scenes/shared/player/player.tscn")

var _emf_reader: EMFReader
var _salt_canister: SaltCanister
var _tone_emitter: SpectralToneEmitter
var _remains: RemainsInteraction
var _shovel: ShovelTool
var _mock_anomaly: MockAnomaly
var _mock_player: Player


func before_each() -> void:
	LoadoutManager.reset()
	
	# Create mock anomaly
	_mock_anomaly = MockAnomaly.new()
	_mock_anomaly.name = "TestAnomaly"
	_mock_anomaly.add_to_group("anomalies")
	add_child_autofree(_mock_anomaly)
	_mock_anomaly.global_position = Vector3(0, 0, 0)
	
	# Create mock player from scene
	_mock_player = PLAYER_SCENE.instantiate() as Player
	_mock_player.peer_id = 1
	_mock_player.class_id = &"medic"
	add_child_autofree(_mock_player)
	_mock_player.global_position = Vector3(0, 0, 0)
	
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
	add_child_autofree(_remains)
	_remains.global_position = Vector3(10, 0, 10)
	
	# Create Shovel Tool
	_shovel = ShovelTool.new()
	_mock_player.add_child(_shovel)


func after_each() -> void:
	LoadoutManager.reset()
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
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.peer_id = 2
	player.class_id = &"tech"  # Not medic
	add_child_autofree(player)
	player.global_position = Vector3(0, 0, 0)
	var emf_reader: EMFReader = EMFReader.new()
	player.add_child(emf_reader)
	
	_mock_anomaly.emf_level = 5
	emf_reader._scan_for_anomalies()
	
	# Non-medics get 50% accuracy, so level 5 -> 2
	assert_eq(emf_reader.get_emf_level(), 2)


# --- Salt Canister Tests ---

func test_salt_canister_deploy() -> void:
	# Add salt canister to loadout
	LoadoutManager.purchase_gear(1, &"salt_canister", &"medic")
	
	assert_true(_salt_canister.deploy())
	assert_not_null(_salt_canister._active_line)


func test_salt_canister_no_ammo() -> void:
	# Don't add salt canister to loadout
	assert_false(_salt_canister.deploy())


func test_salt_canister_cooldown() -> void:
	LoadoutManager.purchase_gear(1, &"salt_canister", &"medic")
	LoadoutManager.purchase_gear(1, &"salt_canister", &"medic")
	
	# First deploy
	assert_true(_salt_canister.deploy())
	
	# Second deploy immediately should fail due to cooldown
	assert_false(_salt_canister.deploy())


# --- Spectral Tone Emitter Tests ---

func test_tone_emitter_start_channel() -> void:
	var anomaly: MockAnomaly = MockAnomaly.new()
	anomaly.name = "TestAnomalyRange"
	anomaly.add_to_group("anomalies")
	add_child_autofree(anomaly)
	anomaly.global_position = Vector3(2, 0, 2)
	
	assert_true(_tone_emitter.start_channel())
	assert_true(_tone_emitter.is_channeling())
	assert_eq(_tone_emitter.get_uses_remaining(), 1)


func test_tone_emitter_no_anomaly_in_range() -> void:
	_mock_anomaly.global_position = Vector3(100, 0, 100)
	assert_false(_tone_emitter.start_channel())


func test_tone_emitter_uses_remaining() -> void:
	var anomaly: MockAnomaly = MockAnomaly.new()
	anomaly.name = "TestAnomalyUses"
	anomaly.add_to_group("anomalies")
	add_child_autofree(anomaly)
	anomaly.global_position = Vector3(2, 0, 2)
	
	assert_true(_tone_emitter.start_channel())
	assert_eq(_tone_emitter.get_uses_remaining(), 1)
	_tone_emitter._channeling = false
	
	assert_true(_tone_emitter.start_channel())
	assert_eq(_tone_emitter.get_uses_remaining(), 0)
	_tone_emitter._channeling = false
	
	# Third attempt should fail
	assert_false(_tone_emitter.start_channel())


# --- Remains Interaction Tests ---

func test_remains_initial_state() -> void:
	assert_true(_remains.is_available())
	assert_eq(_remains.get_completion_flag(), &"lake_house_cleared")


func test_remains_burial_requires_shovel() -> void:
	# Try to interact without shovel
	_remains._on_interacted(1)
	
	# Should not start burial (no shovel)
	assert_eq(_remains._burial_state, 0)


func test_remains_burial_with_shovel() -> void:
	# Add shovel to loadout
	LoadoutManager.purchase_gear(1, &"shovel", &"medic")
	
	_remains._on_interacted(1)
	
	assert_eq(_remains._burial_state, 1)
	assert_true(_remains._dig_timer != null)


# --- Shovel Tool Tests ---

func test_shovel_start_dig() -> void:
	var target: MockDigTarget = MockDigTarget.new()
	add_child_autofree(target)
	
	assert_true(_shovel.start_dig(target))
	assert_true(_shovel.is_digging())


func test_shovel_dig_completes() -> void:
	var target: MockDigTarget = MockDigTarget.new()
	add_child_autofree(target)
	
	_shovel.start_dig(target)
	
	# Simulate time passing by fast-forwarding start time
	_shovel._dig_start_time = (Time.get_ticks_msec() / 1000.0) - 5.0
	_shovel._physics_process(0.1)
	
	assert_false(_shovel.is_digging())
	assert_true(target.buried)


func test_shovel_interrupted_by_movement() -> void:
	var target: MockDigTarget = MockDigTarget.new()
	add_child_autofree(target)
	
	_shovel.start_dig(target)
	
	# Move player
	_mock_player.global_position = Vector3(100, 0, 100)
	_shovel._physics_process(0.1)
	
	assert_false(_shovel.is_digging())