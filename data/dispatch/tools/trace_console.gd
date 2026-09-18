## Trace Console — Tech Operator dispatch tool for 3-tower triangulation (GAMEPLAY_MECHANICS §5.4).
## Authority: LOCAL (UI runs on client; host validates results via CallDirector).
class_name TraceConsole
extends Resource

const MIN_LOCK_TIME: float = 6.0
const MAX_LOCK_TIME: float = 10.0
const NOISE_DRIFT_SPEED: float = 0.15

enum TowerState { UNLOCKED, LOCKING, LOCKED }

## True caller location (from CallData.true_location)
@export var true_location: Vector2 = Vector2.ZERO

## Whether this is a Dead Frequency call (returns impossible location)
@export var is_dead_frequency: bool = false

## Impossible location for Dead Frequency calls
@export var dead_frequency_location: Vector2 = Vector2.ZERO

## Current dial values (0.0..1.0 each)
var dial_frequency: float = 0.0
var dial_phase: float = 0.0
var dial_gain: float = 0.0

## Target values for each tower (generated per tower)
var _tower_targets: Array[Dictionary] = []

## Current tower being locked (0, 1, 2)
var _current_tower: int = 0

## Tower states
var _tower_states: Array[TowerState] = []

## Lock progress for current tower (0.0..1.0)
var _lock_progress: float = 0.0

## Accumulated time for current tower lock
var _lock_time_accum: float = 0.0

## Required lock time for current tower
var _required_lock_time: float = 0.0

## Whether trace is active
var _is_active: bool = false

## Whether trace is complete
var _is_complete: bool = false

## Result location after trace
var _result_location: Vector2 = Vector2.ZERO

## Result radius in meters
var _result_radius: float = 0.0

## Number of towers locked
var _towers_locked: int = 0


func _init() -> void:
	_tower_states = [TowerState.UNLOCKED, TowerState.UNLOCKED, TowerState.UNLOCKED]
	_tower_targets = []
	for i in 3:
		_tower_targets.append({
			"frequency": randf(),
			"phase": randf(),
			"gain": randf(),
		})


## Starts the trace mini-game.
func start_trace(caller_location: Vector2, dead_freq: bool = false, dead_freq_loc: Vector2 = Vector2.ZERO) -> void:
	true_location = caller_location
	is_dead_frequency = dead_freq
	dead_frequency_location = dead_freq_loc
	
	_is_active = true
	_is_complete = false
	_current_tower = 0
	_lock_progress = 0.0
	_lock_time_accum = 0.0
	_towers_locked = 0
	
	# Generate new targets for each tower
	_tower_targets = []
	for i in 3:
		_tower_targets.append({
			"frequency": randf(),
			"phase": randf(),
			"gain": randf(),
		})
	
	_tower_states = [TowerState.UNLOCKED, TowerState.UNLOCKED, TowerState.UNLOCKED]
	_required_lock_time = randf_range(MIN_LOCK_TIME, MAX_LOCK_TIME)
	_tower_states[0] = TowerState.LOCKING


## Updates the trace mini-game (called each frame).
## Returns true if trace state changed (tower locked or complete).
func update(delta: float, dial_freq: float, dial_ph: float, dial_gn: float) -> bool:
	if not _is_active or _is_complete:
		return false
	
	dial_frequency = dial_freq
	dial_phase = dial_ph
	dial_gain = dial_gn
	
	var state_changed: bool = false
	
	# Apply noise drift to targets
	for i: int in 3:
		if _tower_states[i] == TowerState.LOCKING:
			var f_freq: float = _tower_targets[i]["frequency"]
			var f_phase: float = _tower_targets[i]["phase"]
			var f_gain: float = _tower_targets[i]["gain"]
			_tower_targets[i]["frequency"] = fposmod(f_freq + NOISE_DRIFT_SPEED * delta * (1.0 + randf() * 0.5), 1.0)
			_tower_targets[i]["phase"] = fposmod(f_phase + NOISE_DRIFT_SPEED * delta * (1.0 + randf() * 0.5), 1.0)
			_tower_targets[i]["gain"] = fposmod(f_gain + NOISE_DRIFT_SPEED * delta * (1.0 + randf() * 0.5), 1.0)
	
	# Check alignment for current tower
	var target: Dictionary = _tower_targets[_current_tower]
	var freq_diff: float = abs(dial_frequency - target["frequency"])
	var phase_diff: float = abs(dial_phase - target["phase"])
	var gain_diff: float = abs(dial_gain - target["gain"])
	
	# Wrap-around for circular dials
	freq_diff = min(freq_diff, 1.0 - freq_diff)
	phase_diff = min(phase_diff, 1.0 - phase_diff)
	gain_diff = min(gain_diff, 1.0 - gain_diff)
	
	var alignment: float = 1.0 - (freq_diff + phase_diff + gain_diff) / 3.0
	alignment = clampf(alignment, 0.0, 1.0)
	
	# Update lock progress based on alignment
	if alignment > 0.85:
		_lock_time_accum += delta * alignment
		_lock_progress = _lock_time_accum / _required_lock_time
		_lock_progress = clampf(_lock_progress, 0.0, 1.0)
	else:
		# Drift back slowly when not aligned
		_lock_time_accum = max(0.0, _lock_time_accum - delta * 0.3)
		_lock_progress = _lock_time_accum / _required_lock_time
	
	# Check if tower locked
	if _lock_progress >= 1.0:
		_tower_states[_current_tower] = TowerState.LOCKED
		_towers_locked += 1
		_lock_progress = 0.0
		_lock_time_accum = 0.0
		
		if _towers_locked >= 3:
			_is_complete = true
			_calculate_result()
			state_changed = true
		elif _current_tower < 2:
			_current_tower += 1
			_tower_states[_current_tower] = TowerState.LOCKING
			_required_lock_time = randf_range(MIN_LOCK_TIME, MAX_LOCK_TIME)
		
		state_changed = true
	
	return state_changed


## Calculates the triangulated result location and radius.
func _calculate_result() -> void:
	if is_dead_frequency:
		_result_location = dead_frequency_location
		_result_radius = 0.0  # Exact but wrong location
	else:
		# Add some noise based on towers locked
		var noise_scale: float = 1.0
		match _towers_locked:
			1: noise_scale = 2000.0  # 2 km
			2: noise_scale = 400.0   # 400 m
			3: noise_scale = 50.0    # 50 m
		
		var noise: Vector2 = Vector2(
			(randf() - 0.5) * 2.0 * noise_scale,
			(randf() - 0.5) * 2.0 * noise_scale
		)
		_result_location = true_location + noise
		_result_radius = noise_scale


## Gets the current dial target for the active tower.
func get_current_target() -> Dictionary:
	if _current_tower < 3:
		return _tower_targets[_current_tower].duplicate()
	return {"frequency": 0.5, "phase": 0.5, "gain": 0.5}


## Gets the current tower state.
func get_tower_state(index: int) -> TowerState:
	if index < 3:
		return _tower_states[index]
	return TowerState.UNLOCKED


## Gets the number of towers locked.
func get_towers_locked() -> int:
	return _towers_locked


## Gets the current tower being locked (0-based).
func get_current_tower() -> int:
	return _current_tower


## Gets the lock progress for current tower (0.0..1.0).
func get_lock_progress() -> float:
	return _lock_progress


## Gets the result location after trace completes.
func get_result_location() -> Vector2:
	return _result_location


## Gets the result radius in meters.
func get_result_radius() -> float:
	return _result_radius


## Checks if trace is complete.
func is_trace_complete() -> bool:
	return _is_complete


## Checks if trace is active.
func is_active() -> bool:
	return _is_active


## Resets the trace console.
func reset() -> void:
	_is_active = false
	_is_complete = false
	_current_tower = 0
	_lock_progress = 0.0
	_lock_time_accum = 0.0
	_towers_locked = 0
	_tower_states = [TowerState.UNLOCKED, TowerState.UNLOCKED, TowerState.UNLOCKED]
	_result_location = Vector2.ZERO
	_result_radius = 0.0