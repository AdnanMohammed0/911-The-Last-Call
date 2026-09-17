## P3-08: vision cone (lit / dark), walls, flashlight detection, hearing, awareness decay and callouts.
extends GutTest

var _world: Node3D
var _agent: CharacterBody3D
var _perception: AIPerception
var _player: Player


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	_agent = CharacterBody3D.new()
	_world.add_child(_agent)
	_agent.global_position = Vector3.ZERO           # looks down -Z
	_perception = AIPerception.new()
	_perception.tick_rate = 1000.0
	_agent.add_child(_perception)
	_player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	_world.add_child(_player)
	_player.set_physics_process(false)
	_player.set_process(false)
	await wait_physics_frames(2)


func _place_player(position: Vector3) -> void:
	_player.global_position = position
	_player.sync_position = position
	_player.rotation.y = 0.0                         # player also looks down -Z (away from the AI)


func _add_wall(center: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)
	body.global_position = center


func _add_light_zone(center: Vector3, size: Vector3) -> void:
	var zone: Area3D = Area3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	zone.add_child(shape)
	zone.add_to_group(AIPerception.LIGHT_ZONE_GROUP)
	_world.add_child(zone)
	zone.global_position = center


func _sense_for(seconds: float) -> void:
	var steps: int = int(seconds / 0.1)
	for i: int in steps:
		_perception.sense(0.1)


func test_lit_player_in_front_escalates_to_combat() -> void:
	_add_light_zone(Vector3(0, 1, -12), Vector3(6, 4, 6))
	_place_player(Vector3(0, 0, -12))
	await wait_physics_frames(2)
	_sense_for(3.0)
	assert_eq(_perception.level, AIPerception.Level.COMBAT)
	assert_eq(_perception.target, _player)


func test_dark_player_beyond_eight_metres_is_not_seen() -> void:
	_place_player(Vector3(0, 0, -12))
	await wait_physics_frames(2)
	_sense_for(3.0)
	assert_eq(_perception.level, AIPerception.Level.UNAWARE)
	_place_player(Vector3(0, 0, -5))
	await wait_physics_frames(2)
	_sense_for(3.0)
	assert_gt(_perception.awareness, 0.3, "seen in the dark at 5 m")


func test_player_behind_is_outside_the_cone() -> void:
	_add_light_zone(Vector3(0, 1, 6), Vector3(6, 4, 6))
	_place_player(Vector3(0, 0, 6))
	await wait_physics_frames(2)
	_sense_for(3.0)
	assert_eq(_perception.awareness, 0.0)


func test_wall_blocks_sight() -> void:
	_add_light_zone(Vector3(0, 1, -12), Vector3(6, 4, 6))
	_add_wall(Vector3(0, 1.5, -6), Vector3(6, 3, 0.4))
	_place_player(Vector3(0, 0, -12))
	await wait_physics_frames(2)
	_sense_for(3.0)
	assert_eq(_perception.awareness, 0.0)


func test_flashlight_beam_on_ai_is_instant_detection() -> void:
	_place_player(Vector3(0, 0, -20))
	_player.rotation.y = PI                          # player faces the AI
	_player.flashlight_on = true
	await wait_physics_frames(2)
	_perception.sense(0.1)
	assert_eq(_perception.level, AIPerception.Level.COMBAT)


func test_noise_in_range_makes_ai_suspicious_and_remembers_position() -> void:
	EventBus.noise_event.emit(Vector3(3, 0, 3), 10.0, 1)
	assert_true(_perception.level >= AIPerception.Level.SUSPICIOUS)
	assert_eq(_perception.last_noise_position, Vector3(3, 0, 3))


func test_noise_out_of_range_is_ignored() -> void:
	EventBus.noise_event.emit(Vector3(30, 0, 30), 4.0, 1)
	assert_eq(_perception.awareness, 0.0)


func test_loud_voice_is_heard_further_than_whisper() -> void:
	EventBus.voice_noise.emit(1, Vector3(0, 0, -15), 0.05)
	assert_eq(_perception.awareness, 0.0, "whisper at 15 m")
	EventBus.voice_noise.emit(1, Vector3(0, 0, -15), 1.0)
	assert_gt(_perception.awareness, 0.0, "shout at 15 m")


func test_awareness_decays_when_nothing_is_perceived() -> void:
	EventBus.noise_event.emit(Vector3(1, 0, 1), 10.0, 1)
	var before: float = _perception.awareness
	_sense_for(5.0)
	assert_lt(_perception.awareness, before)


func test_callout_after_one_and_a_half_seconds_of_combat() -> void:
	var callouts: Array[Vector3] = []
	var on_callout: Callable = func(_peer: int, position: Vector3) -> void: callouts.append(position)
	_perception.callout.connect(on_callout)
	_perception.alert(Vector3(0, 0, -10))
	_sense_for(1.0)
	assert_eq(callouts.size(), 0)
	_sense_for(1.0)
	assert_eq(callouts.size(), 1)


func test_host_emits_footstep_noise_when_player_moves() -> void:
	var radii: Array[float] = []
	var on_noise: Callable = func(_pos: Vector3, radius: float, _peer: int) -> void: radii.append(radius)
	EventBus.noise_event.connect(on_noise)
	_player.apply_class(ClassCatalog.get_data(&"breacher"))
	_player._emit_footstep_noise(0.0)
	_player.global_position += Vector3(0, 0, -1.5)  # 3 m/s = walking
	_player._emit_footstep_noise(0.5)
	EventBus.noise_event.disconnect(on_noise)
	assert_eq(radii.size(), 1)
	assert_almost_eq(radii[0], 4.0 * 1.6, 0.01, "breacher walk is louder")
