## The "funny little body" layer for player characters. Damped springs turn the capsule's real motion into
## secondary motion: hip inertia, spring lean (forward on acceleration, back on braking), bobble head,
## floppy arms, turn lag with overshoot, a waddle and springy bounce on every step, varied settle wobbles on
## sudden stops and direction flips, anticipation before setting off, dizziness after spinning, landing
## squash and rebound, flailing while falling, and idle weight shifts and fidgets.
## It never touches the capsule, camera or aim; HumanoidRig applies the outputs to its visual joints.
## Randomness only varies cosmetic reactions, so it is never replicated.
## Authority: LOCAL (purely visual)
class_name BodyDynamics
extends RefCounted


## Damped spring on a Vector3, substepped at 120 Hz so it behaves the same at any frame rate.
class Spring:
	var value: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var frequency: float = 3.0
	var damping: float = 0.5

	func _init(spring_frequency: float, spring_damping: float) -> void:
		frequency = spring_frequency
		damping = spring_damping

	func step(target: Vector3, delta: float) -> Vector3:
		var steps: int = clampi(ceili(delta * 120.0), 1, 16)
		var dt: float = delta / float(steps)
		var omega: float = TAU * frequency
		for i: int in steps:
			var acceleration: Vector3 = (target - value) * (omega * omega) - velocity * (2.0 * damping * omega)
			velocity += acceleration * dt
			value += velocity * dt
		return value

	func kick(impulse: Vector3) -> void:
		velocity += impulse

	func reset() -> void:
		value = Vector3.ZERO
		velocity = Vector3.ZERO


enum Fidget { GLANCE, SHRUG, STRETCH, SHIFT }

# --- Tuning (PlayerBody copies its exported values here) ---
## Master strength of the whole layer.
var amount: float = 1.0
## Metres the hips trail per m/s² of acceleration.
var hip_lag: float = 0.011
## Radians of spring lean per m/s² of acceleration.
var lean_gain: float = 0.011
var head_wobble: float = 1.0
var arm_flop: float = 1.0
## 0..1: how much of a sudden turn the body lags behind before catching up.
var turn_lag: float = 0.55
var dizziness: float = 1.0
var fidgets: float = 1.0
var step_bounce: float = 1.0

# --- Outputs (rig space; read by HumanoidRig every frame) ---
var hip_offset: Vector3 = Vector3.ZERO
## Extra chest rotation (pitch, twist, roll).
var lean: Vector3 = Vector3.ZERO
## Extra head rotation (pitch, yaw, roll).
var head: Vector3 = Vector3.ZERO
## Offset of relaxed hands.
var hands: Vector3 = Vector3.ZERO
## Whole-body visual yaw behind the capsule's facing.
var yaw_offset: float = 0.0
## Positive squashes, negative stretches.
var squash: float = 0.0
## 0..1 while airborne and falling (arms flail).
var flail: float = 0.0

var _hips: Spring = Spring.new(2.6, 0.5)
var _bounce: Spring = Spring.new(4.2, 0.32)
var _lean: Spring = Spring.new(2.9, 0.38)
var _head: Spring = Spring.new(2.2, 0.26)
var _hands: Spring = Spring.new(2.6, 0.3)
var _yaw: Spring = Spring.new(2.8, 0.42)
var _squash: Spring = Spring.new(4.5, 0.3)
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time: float = 0.0
var _step_index: int = 0
var _step_variation: float = 1.0
var _was_moving: bool = false
var _peak_speed: float = 0.0
var _peak_timer: float = 0.0
var _lateral_sign: float = 0.0
var _lateral_peak: float = 0.0
var _forward_sign: float = 0.0
var _forward_peak: float = 0.0
var _event_cooldown: float = 0.0
var _dizzy: float = 0.0
var _fall_time: float = 0.0
var _falling_speed: float = 0.0
var _land_cooldown: float = 0.0
var _idle_time: float = 0.0
var _fidget_timer: float = 6.0
var _fidget_kind: Fidget = Fidget.GLANCE
var _fidget_side: float = 1.0
var _fidget_age: float = 10.0


func _init() -> void:
	_rng.randomize()
	_fidget_timer = _rng.randf_range(4.0, 8.0)


## Fixed variation sequence (tests and replays); by default every body is randomised.
func set_seed(value: int) -> void:
	_rng.seed = value
	_fidget_timer = _rng.randf_range(4.0, 8.0)


## Snap back to rest (teleports, respawns).
func reset() -> void:
	for spring: Spring in [_hips, _bounce, _lean, _head, _hands, _yaw, _squash]:
		spring.reset()
	_dizzy = 0.0
	_fall_time = 0.0
	hip_offset = Vector3.ZERO
	lean = Vector3.ZERO
	head = Vector3.ZERO
	hands = Vector3.ZERO
	yaw_offset = 0.0
	squash = 0.0
	flail = 0.0


## Landing compression and rebound; `impact_speed` in m/s downwards.
func land(impact_speed: float) -> void:
	if _land_cooldown > 0.0:
		return
	_land_cooldown = 0.25
	var impact: float = clampf((impact_speed - 1.0) / 6.0, 0.0, 1.0) * amount
	_bounce.kick(Vector3(0, -1.6 * impact, 0))
	_squash.kick(Vector3(0, 3.5 * impact, 0))
	_head.kick(Vector3(-3.0 * impact, 0, _rng.randf_range(-1.5, 1.5) * impact))
	_hands.kick(Vector3(0, -1.2 * impact, 0))


## `velocity` is local (x right, y up, -z forward); `accel` its planar change in m/s²; `yaw_delta` the
## capsule's turn this frame; `phase` / `gait` / `run` come from the rig's walk cycle; `calm` (0..1) tones
## everything down while aiming, crouching or in scripted poses.
func update(delta: float, velocity: Vector3, accel: Vector3, yaw_delta: float, phase: float, gait: float,
		run: float, calm: float) -> void:
	if delta <= 0.0:
		return
	_time += delta
	_event_cooldown = maxf(_event_cooldown - delta, 0.0)
	_land_cooldown = maxf(_land_cooldown - delta, 0.0)
	var k: float = amount * calm
	var speed: float = Vector2(velocity.x, velocity.z).length()
	var yaw_rate: float = yaw_delta / delta
	var moving: float = clampf(gait, 0.0, 1.2)

	_detect_reactions(delta, velocity, speed, k)
	_update_air(delta, velocity.y, k)
	_update_steps(phase, moving, run, k)
	_update_dizzy(delta, yaw_rate)
	_update_idle(delta, speed, k)

	# Turn lag: the body keeps part of a sudden turn behind it, then catches up with a small overshoot.
	var retain: float = turn_lag * clampf(k, 0.0, 1.0)
	_yaw.value.x = clampf(_yaw.value.x - yaw_delta * retain, -0.6, 0.6)
	yaw_offset = _yaw.step(Vector3.ZERO, delta).x

	# Hip inertia, waddle over the stance foot and idle weight shifting.
	var lag: Vector3 = Vector3(-accel.x, 0.0, -accel.z) * hip_lag * k
	lag = lag.limit_length(0.1)
	var waddle: float = cos(phase) * 0.034 * moving * (1.0 + run * 0.35) * _step_variation * k
	var idle: float = 1.0 - clampf(speed / 0.5, 0.0, 1.0)
	var shift: float = (sin(_time * 0.37) * 0.6 + sin(_time * 0.91 + 1.3) * 0.4) * 0.02 * idle * fidgets * k
	shift += _fidget_envelope(Fidget.SHIFT) * _fidget_side * 0.045 * k
	var dizzy_sway: float = sin(_time * 3.1) * 0.03 * _dizzy * dizziness
	_hips.step(lag + Vector3(waddle + shift + dizzy_sway, 0.0, 0.0), delta)
	_bounce.step(Vector3.ZERO, delta)
	hip_offset = _hips.value + Vector3(0.0, clampf(_bounce.value.y, -0.12, 0.08), 0.0)

	# Spring lean: into acceleration, back on braking, into turns; overshoots on the way back to neutral.
	var lean_target: Vector3 = Vector3(
		clampf(accel.z * lean_gain, -0.22, 0.22),
		clampf(-yaw_rate * 0.025, -0.16, 0.16),
		clampf(-accel.x * lean_gain + yaw_rate * speed * 0.016, -0.26, 0.26)) * k
	lean_target.x += _fidget_envelope(Fidget.STRETCH) * 0.14 * k
	lean_target.z += _fidget_envelope(Fidget.SHRUG) * _fidget_side * 0.08 * k
	lean_target.z += sin(_time * 3.1 + 0.6) * 0.07 * _dizzy * dizziness
	lean = _lean.step(lean_target, delta)

	# Bobble head: counters the lean, nods with the bounce and lags turns.
	var head_target: Vector3 = Vector3(-lean.x * 0.75 + _bounce.velocity.y * 0.08, -yaw_offset * 0.5,
		-lean.z * 0.9) * head_wobble
	head_target.y += _fidget_envelope(Fidget.GLANCE) * _fidget_side * 0.45 * k
	head_target.x += sin(_time * 6.4) * 0.11 * _dizzy * dizziness
	head_target.z += cos(_time * 6.4) * 0.11 * _dizzy * dizziness
	head = _head.step(head_target, delta).clamp(Vector3(-0.45, -0.6, -0.45), Vector3(0.45, 0.6, 0.45))

	# Floppy arms: hands trail acceleration and flail while falling.
	var hand_target: Vector3 = Vector3(-accel.x * 0.007, 0.0, -accel.z * 0.009) * arm_flop * k
	hand_target += Vector3(0.0, flail * 0.32 + sin(_time * 14.0) * 0.07 * flail, -flail * 0.06) * arm_flop
	hand_target.y += _fidget_envelope(Fidget.STRETCH) * 0.08 * k
	hands = _hands.step(hand_target.limit_length(0.3), delta)

	# Squash on footfalls and landings, stretch while rising.
	var stretch: float = -clampf(velocity.y * 0.025, 0.0, 0.08) * k
	squash = clampf(_squash.step(Vector3(0, stretch, 0), delta).y, -0.12, 0.18)


## Stops, direction flips and setting off each get a slightly different reaction.
func _detect_reactions(delta: float, velocity: Vector3, speed: float, k: float) -> void:
	_peak_timer = maxf(_peak_timer - delta, 0.0)
	if speed >= _peak_speed or _peak_timer <= 0.0:
		_peak_speed = speed
		_peak_timer = 0.4
	var now_moving: bool = speed > 0.35
	if now_moving and not _was_moving and _event_cooldown <= 0.0:
		# Anticipation: a little dip and wind-up before going.
		_bounce.kick(Vector3(0, -0.35 * k, 0))
		_lean.kick(Vector3(0.9 * k, 0, 0))
	if not now_moving and _was_moving and _peak_speed > 1.8 and _event_cooldown <= 0.0:
		var amp: float = _rng.randf_range(0.75, 1.3) * clampf(_peak_speed / 4.0, 0.5, 1.4) * k
		var side: float = _rng.randf_range(-1.0, 1.0)
		_lean.kick(Vector3(-1.4 * amp, side * 0.8 * amp, side * 1.2 * amp))
		_head.kick(Vector3(-2.6 * amp, side * 1.4 * amp, -side * 1.6 * amp))
		_hands.kick(Vector3(side * 0.25 * amp, 0.35 * amp, -1.1 * amp))
		_squash.kick(Vector3(0, 0.8 * amp, 0))
		_event_cooldown = 0.3
	_was_moving = now_moving
	# Left/right flip: a sideways jolt with the arms flung the other way.
	var lateral: float = signf(velocity.x) if absf(velocity.x) > 0.7 else 0.0
	_lateral_peak = maxf(_lateral_peak * exp(-2.0 * delta), absf(velocity.x))
	if lateral != 0.0 and _lateral_sign != 0.0 and lateral != _lateral_sign and _lateral_peak > 1.4 and _event_cooldown <= 0.0:
		var amp: float = _rng.randf_range(0.8, 1.35) * k
		_lean.kick(Vector3(_rng.randf_range(-0.5, 0.5) * amp, lateral * 0.9 * amp, lateral * 2.4 * amp))
		_head.kick(Vector3(0, -lateral * 1.2 * amp, -lateral * 2.8 * amp))
		_hands.kick(Vector3(-lateral * 1.3 * amp, 0.25 * amp, 0))
		_event_cooldown = 0.22
	if lateral != 0.0:
		_lateral_sign = lateral
	# Forward/back reversal.
	var forward: float = signf(velocity.z) if absf(velocity.z) > 0.7 else 0.0
	_forward_peak = maxf(_forward_peak * exp(-2.0 * delta), absf(velocity.z))
	if forward != 0.0 and _forward_sign != 0.0 and forward != _forward_sign and _forward_peak > 1.6 and _event_cooldown <= 0.0:
		var amp: float = _rng.randf_range(0.8, 1.3) * k
		_lean.kick(Vector3(forward * 2.0 * amp, 0, _rng.randf_range(-0.8, 0.8) * amp))
		_head.kick(Vector3(forward * 2.4 * amp, 0, 0))
		_hands.kick(Vector3(0, 0.2 * amp, forward * 1.2 * amp))
		_event_cooldown = 0.25
	if forward != 0.0:
		_forward_sign = forward


func _update_air(delta: float, vertical: float, k: float) -> void:
	if vertical < -2.2:
		_fall_time += delta
		_falling_speed = maxf(_falling_speed, -vertical)
	elif _fall_time > 0.0:
		if vertical > -0.6:
			land(_falling_speed)
			_fall_time = 0.0
			_falling_speed = 0.0
	flail = lerpf(flail, clampf((_fall_time - 0.3) / 0.4, 0.0, 1.0) * k, 1.0 - exp(-6.0 * delta))


## A springy dip on every footfall, each step a little different.
func _update_steps(phase: float, moving: float, run: float, k: float) -> void:
	var index: int = floori((phase + PI * 0.5) / PI)
	if index == _step_index:
		return
	_step_index = index
	_step_variation = _rng.randf_range(0.82, 1.2)
	if moving < 0.15:
		return
	var strength: float = moving * (1.0 + run * 0.7) * step_bounce * k * _step_variation
	_bounce.kick(Vector3(0, -0.85 * strength, 0))
	_squash.kick(Vector3(0, 1.5 * strength, 0))
	_head.kick(Vector3(-0.45 * strength, 0, _rng.randf_range(-0.3, 0.3) * strength))


func _update_dizzy(delta: float, yaw_rate: float) -> void:
	if absf(yaw_rate) > 5.0:
		_dizzy = minf(_dizzy + delta * 0.7, 1.0)
	else:
		_dizzy *= exp(-0.55 * delta)


func _update_idle(delta: float, speed: float, k: float) -> void:
	_fidget_age += delta
	if speed > 0.2 or k < 0.3:
		_idle_time = 0.0
		return
	_idle_time += delta
	_fidget_timer -= delta
	if _fidget_timer <= 0.0 and _idle_time > 1.5:
		_fidget_timer = _rng.randf_range(5.0, 11.0)
		_fidget_kind = _rng.randi_range(0, Fidget.size() - 1) as Fidget
		_fidget_side = -1.0 if _rng.randf() < 0.5 else 1.0
		_fidget_age = 0.0


## 0 → 1 → 0 over the 1.6 s of the current idle fidget (0 for other kinds).
func _fidget_envelope(kind: Fidget) -> float:
	if kind != _fidget_kind or _fidget_age > 1.6:
		return 0.0
	return sin(_fidget_age / 1.6 * PI) * fidgets
