## Movement math stays responsive across physics tick rates; secondary motion never changes the capsule.
extends GutTest


func _simulate(target: Vector2, frames: int, start: Vector2 = Vector2.ZERO) -> Vector2:
	var velocity: Vector2 = start
	for i: int in frames:
		velocity = Player.steer_horizontal(velocity, target, 1.0 / float(frames), true,
			20.0, 26.0, 30.0, 14.0, 5.0)
	return velocity


func test_acceleration_reaches_target_without_speed_overshoot_at_common_tick_rates() -> void:
	for frames: int in [30, 60, 120]:
		var result: Vector2 = _simulate(Vector2(3.5, 0.0), frames)
		assert_almost_eq(result.x, 3.5, 0.001)
		assert_almost_eq(result.y, 0.0, 0.001)


func test_reversal_and_braking_are_crisp_but_inertial() -> void:
	var forward: Vector2 = Vector2(3.5, 0.0)
	var reversed: Vector2 = Player.steer_horizontal(forward, Vector2(-3.5, 0.0), 0.1,
		true, 20.0, 26.0, 30.0, 14.0, 5.0)
	assert_lt(reversed.x, 1.0)
	assert_gt(reversed.x, 0.0)
	var stopped: Vector2 = Player.steer_horizontal(forward, Vector2.ZERO, 0.1,
		true, 20.0, 26.0, 30.0, 14.0, 5.0)
	assert_gt(stopped.x, 0.0)
	assert_lt(stopped.x, 1.0)
	assert_almost_eq(_simulate(Vector2.ZERO, 60, forward).length(), 0.0, 0.001)


func test_air_steering_is_weaker_than_ground_steering() -> void:
	var target: Vector2 = Vector2(3.5, 0.0)
	var ground: Vector2 = Player.steer_horizontal(Vector2.ZERO, target, 0.1,
		true, 20.0, 26.0, 30.0, 14.0, 5.0)
	var air: Vector2 = Player.steer_horizontal(Vector2.ZERO, target, 0.1,
		false, 20.0, 26.0, 30.0, 14.0, 5.0)
	assert_gt(ground.length(), air.length())


func test_visual_spring_settles_with_similar_result_across_render_rates() -> void:
	var rig: HumanoidRig = HumanoidRig.new()
	var at_30: Vector2 = Vector2.ZERO
	var at_120: Vector2 = Vector2.ZERO
	for i: int in 30:
		at_30 = rig._spring(at_30, 0.1, 1.0 / 30.0)
	for i: int in 120:
		at_120 = rig._spring(at_120, 0.1, 1.0 / 120.0)
	assert_almost_eq(at_30.x, at_120.x, 0.003)
	assert_almost_eq(at_30.x, 0.1, 0.005)
	rig.free()


func test_landing_impulse_affects_only_visual_nodes() -> void:
	var player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	var camera: Camera3D = player.get_camera()
	var before: Transform3D = camera.transform
	var body: PlayerBody = player.get_node(^"Body") as PlayerBody
	body.land(5.0)
	assert_gt(body.rig._landing_impulse, 0.0)
	assert_eq(camera.transform, before)


func test_run_has_distinct_speed_and_player_only_exaggeration() -> void:
	var player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	assert_gt(player.sprint_speed / player.walk_speed, 1.6)
	var body: PlayerBody = player.get_node(^"Body") as PlayerBody
	assert_eq(body.rig.run_exaggeration, body.run_exaggeration)
	assert_gt(body.rig.run_exaggeration, 1.0)


func test_unarmed_hands_show_only_for_local_play_without_weapon_or_menu() -> void:
	var player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	var view: PlayerMotionView = player.get_node(^"Head/Camera3D/MotionView") as PlayerMotionView
	view._process(1.0 / 60.0)
	assert_true(view.visible)
	assert_eq(view.get_child_count(), 2)
	player.get_input().enabled = false
	view._process(1.0 / 60.0)
	assert_false(view.visible)
	player.get_input().enabled = true
	player.get_weapons().set_weapon(WeaponData.Slot.SIDEARM, &"pistol")
	view._process(1.0 / 60.0)
	assert_false(view.visible)


# --- Cartoon body (BodyDynamics) -----------------------------------------------------------------

## Walks forward for `walk_time`, then releases input; returns per-frame lean pitch and the final state.
func _walk_and_stop(rate: int, walk_time: float, total: float) -> Dictionary:
	var dynamics: BodyDynamics = BodyDynamics.new()
	dynamics.set_seed(7)
	var dt: float = 1.0 / float(rate)
	var velocity: Vector2 = Vector2.ZERO
	var phase: float = 0.0
	var pitches: Array[float] = []
	var t: float = 0.0
	while t < total:
		var target: Vector2 = Vector2(0.0, -3.5) if t < walk_time else Vector2.ZERO
		var next: Vector2 = Player.steer_horizontal(velocity, target, dt, true, 24.0, 26.0, 30.0, 14.0, 5.0)
		var accel: Vector2 = (next - velocity) / dt
		velocity = next
		var speed: float = velocity.length()
		phase += dt * TAU * (1.0 + speed * 0.29)
		dynamics.update(dt, Vector3(velocity.x, 0.0, velocity.y), Vector3(accel.x, 0.0, accel.y), 0.0, phase,
			clampf(speed / 3.5, 0.0, 1.5), 0.0, 1.0)
		pitches.append(dynamics.lean.x)
		t += dt
	return {"pitches": pitches, "dynamics": dynamics}


func test_sudden_stop_skids_back_overshoots_forward_and_settles() -> void:
	var result: Dictionary = _walk_and_stop(60, 1.2, 4.0)
	var pitches: Array[float] = result["pitches"]
	var after_stop: Array[float] = pitches.slice(72, 150)
	var back: float = after_stop.max()
	var forward: float = after_stop.min()
	assert_gt(back, 0.05, "braking leans the body back")
	assert_lt(forward, -0.02, "then it overshoots forward")
	var dynamics: BodyDynamics = result["dynamics"]
	assert_lt(absf(dynamics.lean.x), 0.02, "and settles back to neutral")
	assert_lt(dynamics.hip_offset.length(), 0.03)


func test_cartoon_body_matches_across_frame_rates() -> void:
	var slow: Dictionary = _walk_and_stop(30, 1.2, 3.0)
	var fast: Dictionary = _walk_and_stop(120, 1.2, 3.0)
	var slow_pitches: Array[float] = slow["pitches"]
	var fast_pitches: Array[float] = fast["pitches"]
	var slow_peak: float = slow_pitches.max()
	var fast_peak: float = fast_pitches.max()
	assert_almost_eq(slow_peak, fast_peak, 0.06, "peak lean is frame-rate independent")
	var slow_body: BodyDynamics = slow["dynamics"]
	var fast_body: BodyDynamics = fast["dynamics"]
	assert_almost_eq(slow_body.lean.x, fast_body.lean.x, 0.02)


func test_chaotic_input_stays_bounded_and_finite() -> void:
	var dynamics: BodyDynamics = BodyDynamics.new()
	dynamics.set_seed(3)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var velocity: Vector2 = Vector2.ZERO
	var phase: float = 0.0
	for i: int in 1200:
		var dt: float = rng.randf_range(1.0 / 144.0, 1.0 / 20.0)
		var target: Vector2 = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() * 6.0
		var next: Vector2 = Player.steer_horizontal(velocity, target, dt, true, 24.0, 26.0, 30.0, 14.0, 5.0)
		var accel: Vector2 = (next - velocity) / dt
		velocity = next
		phase += dt * TAU * 2.5
		dynamics.update(dt, Vector3(velocity.x, rng.randf_range(-6.0, 4.0), velocity.y), Vector3(accel.x, 0.0, accel.y),
			rng.randf_range(-0.4, 0.4), phase, 1.0, 1.0, 1.0)
		for value: float in [dynamics.lean.x, dynamics.lean.z, dynamics.head.x, dynamics.yaw_offset, dynamics.squash,
				dynamics.hip_offset.length(), dynamics.hands.length()]:
			assert_false(is_nan(value))
		if i % 50 == 0:
			assert_lt(absf(dynamics.lean.x), 0.6)
			assert_lt(absf(dynamics.lean.z), 0.6)
			assert_lt(absf(dynamics.yaw_offset), 0.61)
			assert_lt(dynamics.hip_offset.length(), 0.25)
			assert_lt(dynamics.hands.length(), 0.45)


func test_sharp_turn_lags_then_swings_round() -> void:
	var dynamics: BodyDynamics = BodyDynamics.new()
	dynamics.set_seed(5)
	var dt: float = 1.0 / 60.0
	dynamics.update(dt, Vector3.ZERO, Vector3.ZERO, 1.2, 0.0, 0.0, 0.0, 1.0)
	assert_lt(dynamics.yaw_offset, -0.3, "the body stays behind a sudden turn")
	var crossed: bool = false
	for i: int in 180:
		dynamics.update(dt, Vector3.ZERO, Vector3.ZERO, 0.0, 0.0, 0.0, 0.0, 1.0)
		crossed = crossed or dynamics.yaw_offset > 0.005
	assert_true(crossed, "and overshoots as it catches up")
	assert_lt(absf(dynamics.yaw_offset), 0.01)


func test_only_players_get_the_cartoon_body() -> void:
	var player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	var body: PlayerBody = player.get_node(^"Body") as PlayerBody
	assert_not_null(body.rig.dynamics)
	var plain: HumanoidRig = HumanoidRig.new()
	assert_null(plain.dynamics, "hostiles keep their grounded motion")
	plain.free()


func test_cartoon_motion_never_moves_the_capsule_or_camera() -> void:
	var player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	add_child_autofree(player)
	player.set_physics_process(false)
	var body: PlayerBody = player.get_node(^"Body") as PlayerBody
	var camera_before: Transform3D = player.get_camera().transform
	var player_before: Transform3D = player.global_transform
	for i: int in 30:
		body.rig.global_position += Vector3(0.0, 0.0, -0.08)
		body.rig._process(1.0 / 60.0)
	assert_eq(player.global_transform, player_before)
	assert_eq(player.get_camera().transform, camera_before)
