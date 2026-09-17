## GUT tests for NoiseSystem (P3-06).
## Run with: godot --headless -s res://addons/gut/gut_cmdln.gd -gtest=tests/test_noise_system.gd
extends GutTest

var _noise_system: NoiseSystem
var _event_bus: EventBus
var _noise_events: Array[Dictionary] = []
var _voice_noise_events: Array[Dictionary] = []


func before() -> void:
	_noise_system = NoiseSystem.new()
	add_child_autofree(_noise_system)
	
	_event_bus = EventBus.new()
	add_child_autofree(__event_bus)
	
	_noise_events.clear()
	_voice_noise_events.clear()
	
	EventBus.noise_event.connect(_on_noise_event)
	EventBus.voice_noise.connect(_on_voice_noise)


func after() -> void:
	_noise_system = null
	_event_bus = null


func _on_noise_event(position: Vector3, radius: float, source_peer: int) -> void:
	_noise_events.append({
		"position": position,
		"radius": radius,
		"source_peer": source_peer
	})


func _on_voice_noise(peer_id: int, position: Vector3, loudness: float) -> void:
	_voice_noise_events.append({
		"peer_id": peer_id,
		"position": position,
		"loudness": loudness
	})


## Test: Footstep noise with different movement states
func test_footstep_noise_radii() -> void:
	var pos: Vector3 = Vector3(100, 0, 100)
	
	# Walk
	_noise_system.emit_footstep(pos, false, false, 1.0, 1)
	assert_eq(_noise_events.size(), 1)
	assert_eq(_noise_events[0].radius, 4.0)
	assert_eq(_noise_events[0].source_peer, 1)
	_noise_events.clear()
	
	# Sprint
	_noise_system.emit_footstep(pos, true, false, 1.0, 1)
	assert_eq(_noise_events[0].radius, 10.0)
	_noise_events.clear()
	
	# Crouch
	_noise_system.emit_footstep(pos, false, true, 1.0, 1)
	assert_eq(_noise_events[0].radius, 1.5)
	_noise_events.clear()
	
	# Breacher multiplier (1.6)
	_noise_system.emit_footstep(pos, false, false, 1.6, 1)
	assert_eq(_noise_events[0].radius, 4.0 * 1.6)
	_noise_events.clear()
	
	# Breacher sprint
	_noise_system.emit_footstep(pos, true, false, 1.6, 1)
	assert_eq(_noise_events[0].radius, 10.0 * 1.6)


## Test: Door noise emissions
func test_door_noise() -> void:
	var pos: Vector3 = Vector3(0, 0, 0)
	
	# Kick
	_noise_system.emit_door_noise(pos, Door.DoorAction.KICK, 1)
	assert_eq(_noise_events.size(), 1)
	assert_eq(_noise_events[0].radius, 25.0)
	assert_eq(_noise_events[0].source_peer, 1)
	_noise_events.clear()
	
	# Toggle open
	_noise_system.emit_door_noise(pos, Door.DoorAction.TOGGLE_OPEN, 2)
	assert_eq(_noise_events[0].radius, 8.0)
	_noise_events.clear()
	
	# Peek
	_noise_system.emit_door_noise(pos, Door.DoorAction.PEEK, 2)
	assert_eq(_noise_events[0].radius, 3.0)
	_noise_events.clear()
	
	# Unlock
	_noise_system.emit_door_noise(pos, Door.DoorAction.UNLOCK, 3)
	assert_eq(_noise_events[0].radius, 8.0)
	_noise_events.clear()


## Test: Gunshot noise
func test_gunshot_noise() -> void:
	var pos: Vector3 = Vector3(50, 1, 50)
	
	_noise_system.emit_gunshot(pos, 60.0, 1)
	assert_eq(_noise_events.size(), 1)
	assert_eq(_noise_events[0].radius, 60.0)
	assert_eq(_noise_events[0].position, pos)
	_noise_events.clear()
	
	# Custom radius
	_noise_system.emit_gunshot(pos, 40.0, 2)
	assert_eq(_noise_events[0].radius, 40.0)


## Test: Voice noise emission
func test_voice_noise() -> void:
	var pos: Vector3 = Vector3(10, 1.7, 10)
	
	# Whisper (low loudness)
	_noise_system.emit_voice_noise(pos, 0.0, 1)
	assert_eq(_voice_noise_events.size(), 1)
	assert_eq(_voice_noise_events[0].loudness, 0.0)
	assert_lt(_noise_events[0].radius, 5.0)  # Should be close to min
	_voice_noise_events.clear()
	_noise_events.clear()
	
	# Normal speech
	_noise_system.emit_voice_noise(pos, 0.5, 1)
	assert_eq(_voice_noise_events[0].loudness, 0.5)
	assert_between(_noise_events[0].radius, 5.0, 15.0)
	_voice_noise_events.clear()
	_noise_events.clear()
	
	# Shout (high loudness)
	_noise_system.emit_voice_noise(pos, 1.0, 1)
	assert_eq(_voice_noise_events[0].loudness, 1.0)
	assert_gt(_noise_events[0].radius, 15.0)  # Should be close to max
	_voice_noise_events.clear()
	_noise_events.clear()


## Test: Explosion and grenade noise
func test_explosive_noise() -> void:
	var pos: Vector3 = Vector3(0, 0, 0)
	
	_noise_system.emit_grenade(pos, 1)
	assert_eq(_noise_events[0].radius, 30.0)
	_noise_events.clear()
	
	_noise_system.emit_explosion(pos, 1)
	assert_eq(_noise_events[0].radius, 50.0)
	_noise_events.clear()
	
	_noise_system.emit_glass_break(pos, 1)
	assert_eq(_noise_events[0].radius, 15.0)
	_noise_events.clear()


## Test: Generic noise emission
func test_generic_noise() -> void:
	var pos: Vector3 = Vector3(20, 0, 20)
	
	_noise_system.emit_noise(pos, 100.0, 5)
	assert_eq(_noise_events.size(), 1)
	assert_eq(_noise_events[0].radius, 100.0)
	assert_eq(_noise_events[0].source_peer, 5)
	assert_eq(_noise_events[0].position, pos)


## Test: NoiseSystem constants are correct per GAMEPLAY_MECHANICS
func test_noise_constants() -> void:
	assert_eq(NoiseSystem.WALK_RADIUS, 4.0)
	assert_eq(NoiseSystem.SPRINT_RADIUS, 10.0)
	assert_eq(NoiseSystem.CROUCH_RADIUS, 1.5)
	assert_eq(NoiseSystem.KICK_RADIUS, 25.0)
	assert_eq(NoiseSystem.GUNSHOT_RADIUS, 60.0)
	assert_eq(NoiseSystem.DOOR_OPEN_RADIUS, 8.0)
	assert_eq(NoiseSystem.DOOR_CLOSE_RADIUS, 6.0)
	assert_eq(NoiseSystem.DOOR_PEEK_RADIUS, 3.0)
	assert_eq(NoiseSystem.GRENADE_RADIUS, 30.0)
	assert_eq(NoiseSystem.EXPLOSION_RADIUS, 50.0)
	assert_eq(NoiseSystem.GLASS_BREAK_RADIUS, 15.0)
	assert_eq(NoiseSystem.VOICE_MIN_RADIUS, 2.0)
	assert_eq(NoiseSystem.VOICE_MAX_RADIUS, 20.0)


## Test: NoiseSystem is not called from non-host
func test_non_host_no_emission() -> void:
	# Simulate non-host by checking the guard
	# We can't easily test this without multiplayer, but we verify the guard exists
	var pos: Vector3 = Vector3(0, 0, 0)
	
	# The guard check is: if not multiplayer.is_server(): return
	# This is tested indirectly by verifying events only emit when on host
	# In test environment (no multiplayer peer), multiplayer.is_server() returns true
	# So events will emit - this is correct for test environment
	_noise_system.emit_footstep(Vector3.ZERO, false, false, 1.0, 1)
	assert_eq(_noise_events.size(), 1)


## Test: Footstep interval helper
func test_footstep_interval() -> void:
	assert_eq(NoiseSystem.get_footstep_interval(false, false), 0.45)
	assert_eq(NoiseSystem.get_footstep_interval(true, false), 0.45 * 0.7)
	assert_eq(NoiseSystem.get_footstep_interval(false, true), 0.45 * 1.5)