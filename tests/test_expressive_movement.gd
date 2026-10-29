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
