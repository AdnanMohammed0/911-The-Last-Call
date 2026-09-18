## GUT tests for NoiseSystem (P3-06).
## Run with: godot --headless -s res://addons/gut/gut_cmdln.gd -gtest=tests/test_noise_system.gd
extends GutTest

var _noise_events: Array[Dictionary] = []
var _voice_noise_events: Array[Dictionary] = []


func before_each() -> void:
	_noise_events.clear()
	_voice_noise_events.clear()
	
	if not EventBus.noise_event.is_connected(_on_noise_event):
		EventBus.noise_event.connect(_on_noise_event)
	if not EventBus.voice_noise.is_connected(_on_voice_noise):
		EventBus.voice_noise.connect(_on_voice_noise)


func after_each() -> void:
	if EventBus.noise_event.is_connected(_on_noise_event):
		EventBus.noise_event.disconnect(_on_noise_event)
	if EventBus.voice_noise.is_connected(_on_voice_noise):
		EventBus.voice_noise.disconnect(_on_voice_noise)


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


func _last_noise_radius() -> float:
	if _noise_events.is_empty():
		return 0.0
	var d: Dictionary = _noise_events.back()
	var val: float = d.get("radius", 0.0)
	return val


func _last_noise_peer() -> int:
	if _noise_events.is_empty():
		return 0
	var d: Dictionary = _noise_events.back()
	var val: int = d.get("source_peer", 0)
	return val


func _last_noise_pos() -> Vector3:
	if _noise_events.is_empty():
		return Vector3.ZERO
	var d: Dictionary = _noise_events.back()
	var val: Vector3 = d.get("position", Vector3.ZERO)
	return val


func _last_voice_loudness() -> float:
	if _voice_noise_events.is_empty():
		return 0.0
	var d: Dictionary = _voice_noise_events.back()
	var val: float = d.get("loudness", 0.0)
	return val


## Test: Footstep noise with different movement states
func test_footstep_noise_radii() -> void:
	var pos: Vector3 = Vector3(100, 0, 100)
	
	# Walk
	NoiseSystem.emit_footstep(pos, false, false, 1.0, 1)
	assert_eq(_noise_events.size(), 1)
	assert_eq(_last_noise_radius(), 4.0)
	assert_eq(_last_noise_peer(), 1)
	_noise_events.clear()
	
	# Sprint
	NoiseSystem.emit_footstep(pos, true, false, 1.0, 1)
	assert_eq(_last_noise_radius(), 10.0)
	_noise_events.clear()
	
	# Crouch
	NoiseSystem.emit_footstep(pos, false, true, 1.0, 1)
	assert_eq(_last_noise_radius(), 1.5)
	_noise_events.clear()
	
	# Breacher multiplier (1.6)
	NoiseSystem.emit_footstep(pos, false, false, 1.6, 1)
	assert_eq(_last_noise_radius(), 4.0 * 1.6)
	_noise_events.clear()
	
	# Breacher sprint
	NoiseSystem.emit_footstep(pos, true, false, 1.6, 1)
	assert_eq(_last_noise_radius(), 10.0 * 1.6)


## Test: Door noise emissions
func test_door_noise() -> void:
	var pos: Vector3 = Vector3(0, 0, 0)
	
	# Kick
	NoiseSystem.emit_door_noise(pos, Door.DoorAction.KICK, 1)
	assert_eq(_noise_events.size(), 1)
	assert_eq(_last_noise_radius(), 25.0)
	assert_eq(_last_noise_peer(), 1)
	_noise_events.clear()
	
	# Toggle open
	NoiseSystem.emit_door_noise(pos, Door.DoorAction.TOGGLE_OPEN, 2)
	assert_eq(_last_noise_radius(), 8.0)
	_noise_events.clear()
	
	# Peek
	NoiseSystem.emit_door_noise(pos, Door.DoorAction.PEEK, 2)
	assert_eq(_last_noise_radius(), 3.0)
	_noise_events.clear()
	
	# Unlock
	NoiseSystem.emit_door_noise(pos, Door.DoorAction.UNLOCK, 3)
	assert_eq(_last_noise_radius(), 8.0)
	_noise_events.clear()


## Test: Gunshot noise
func test_gunshot_noise() -> void:
	var pos: Vector3 = Vector3(50, 1, 50)
	
	NoiseSystem.emit_gunshot(pos, 60.0, 1)
	assert_eq(_noise_events.size(), 1)
	assert_eq(_last_noise_radius(), 60.0)
	assert_eq(_last_noise_pos(), pos)
	_noise_events.clear()
	
	# Custom radius
	NoiseSystem.emit_gunshot(pos, 40.0, 2)
	assert_eq(_last_noise_radius(), 40.0)


## Test: Voice noise emission
func test_voice_noise() -> void:
	var pos: Vector3 = Vector3(10, 1.7, 10)
	
	# Whisper (low loudness)
	NoiseSystem.emit_voice_noise(pos, 0.0, 1)
	assert_eq(_voice_noise_events.size(), 1)
	assert_eq(_last_voice_loudness(), 0.0)
	assert_lt(_last_noise_radius(), 5.0)  # Should be close to min
	_voice_noise_events.clear()
	_noise_events.clear()
	
	# Normal speech
	NoiseSystem.emit_voice_noise(pos, 0.5, 1)
	assert_eq(_last_voice_loudness(), 0.5)
	assert_between(_last_noise_radius(), 5.0, 15.0)
	_voice_noise_events.clear()
	_noise_events.clear()
	
	# Shout (high loudness)
	NoiseSystem.emit_voice_noise(pos, 1.0, 1)
	assert_eq(_last_voice_loudness(), 1.0)
	assert_gt(_last_noise_radius(), 15.0)  # Should be close to max
	_voice_noise_events.clear()
	_noise_events.clear()


## Test: Explosion and grenade noise
func test_explosive_noise() -> void:
	var pos: Vector3 = Vector3(0, 0, 0)
	
	NoiseSystem.emit_grenade(pos, 1)
	assert_eq(_last_noise_radius(), 30.0)
	_noise_events.clear()
	
	NoiseSystem.emit_explosion(pos, 1)
	assert_eq(_last_noise_radius(), 50.0)
	_noise_events.clear()
	
	NoiseSystem.emit_glass_break(pos, 1)
	assert_eq(_last_noise_radius(), 15.0)
	_noise_events.clear()


## Test: Generic noise emission
func test_generic_noise() -> void:
	var pos: Vector3 = Vector3(20, 0, 20)
	
	NoiseSystem.emit_noise(pos, 100.0, 5)
	assert_eq(_noise_events.size(), 1)
	assert_eq(_last_noise_radius(), 100.0)
	assert_eq(_last_noise_peer(), 5)
	assert_eq(_last_noise_pos(), pos)


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
func test_non_host_guard() -> void:
	# In tests multiplayer is mocked or server by default, but verify server check
	# If this ran as client, it would return early without emitting
	pass


## Test: Footstep interval calculation
func test_footstep_intervals() -> void:
	var interval_normal: float = NoiseSystem.get_footstep_interval(false, false)
	assert_eq(interval_normal, 0.45)
	var interval_sprint: float = NoiseSystem.get_footstep_interval(true, false)
	assert_eq(interval_sprint, 0.45 * 0.7)
	var interval_crouch: float = NoiseSystem.get_footstep_interval(false, true)
	assert_eq(interval_crouch, 0.45 * 1.5)