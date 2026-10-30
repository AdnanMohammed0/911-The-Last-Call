## Station Siege horde mode (P4-09): wave data, the station wiring and navmesh (every entry reaches the
## operations room), the host flow (breach -> countdown -> waves -> held), the wipe (station overrun), the
## blackout and the trigger conditions.
extends GutTest

const STATION: String = "res://scenes/dispatch/operations_room.tscn"
const SIEGE: PackedScene = preload("res://scenes/dispatch/siege/station_siege.tscn")
const PLAN: SiegePlan = preload("res://data/siege/station_siege_plan.tres")
const THUG: ArchetypeData = preload("res://data/ai/archetypes/thug.tres")

var _world: Node3D
var _trust_before: int = 0
var _cult_before: int = 0
var _shift_running_before: bool = false
var _phase_before: GameState.Phase


func before_each() -> void:
	FlagSystem.reset()
	MissionDirector.scene_changes_enabled = false
	Career.persist = false
	_trust_before = MissionDirector.public_trust
	_cult_before = GameState.cult_awareness
	_shift_running_before = CallDirector.shift_running
	_phase_before = GameState.phase
	_world = Node3D.new()
	add_child_autofree(_world)


func after_each() -> void:
	FlagSystem.reset()
	MissionDirector.scene_changes_enabled = true
	MissionDirector.public_trust = _trust_before
	GameState.public_trust = _trust_before
	GameState.cult_awareness = _cult_before
	CallDirector.shift_running = _shift_running_before
	GameState.phase = _phase_before
	TraitSystem.reset_player(1)
	Career.reset()


## A flat yard with the siege on it: two quick waves of two thugs, entries 10 m out.
func _siege_on_floor(waves: int = 2) -> StationSiege:
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Yard"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40, 0.2, 40)
	shape.shape = box
	floor_body.add_child(shape)
	_world.add_child(floor_body)
	floor_body.position = Vector3(0, -0.1, 0)
	var lamps: Node3D = Node3D.new()
	lamps.name = "Lamps"
	var lamp: OmniLight3D = OmniLight3D.new()
	lamps.add_child(lamp)
	_world.add_child(lamps)
	var siege: StationSiege = SIEGE.instantiate() as StationSiege
	siege.auto_start = false
	siege.nav_sources = [NodePath("../Yard")]
	siege.power_roots = [NodePath("../Lamps")]
	siege.doors_path = NodePath()
	var plan: SiegePlan = SiegePlan.new()
	for i: int in waves:
		var wave: SiegeWave = SiegeWave.new()
		wave.archetypes = [THUG]
		wave.counts = [2]
		wave.intermission_sec = 1.0
		wave.spawn_interval_sec = 0.1
		plan.waves.append(wave)
	siege.plan = plan
	_world.add_child(siege)
	siege.defend_point.position = Vector3.ZERO
	var corners: Array[Vector3] = [Vector3(10, 0, 10), Vector3(-10, 0, 10), Vector3(10, 0, -10), Vector3(-10, 0, -10)]
	for i: int in siege.entry_points.get_child_count():
		(siege.entry_points.get_child(i) as Node3D).position = corners[i % corners.size()]
	return siege


func _start_and_bake(siege: StationSiege) -> void:
	assert_true(siege.start(&"test"))
	if siege.state == StationSiege.State.BREACH:
		await siege.navigation.navigation_ready
	await get_tree().process_frame  # leave the navigation_ready emission before the test can end
	assert_eq(siege.state, StationSiege.State.INTERMISSION)


func _run_wave(siege: StationSiege) -> Array[HostileAgent]:
	siege.step(1.1)
	assert_eq(siege.state, StationSiege.State.WAVE)
	for i: int in 6:
		siege.step(0.15)
		await get_tree().process_frame
	var spawned: Array[HostileAgent] = []
	for child: Node in siege.enemies_root.get_children():
		var hostile: HostileAgent = child as HostileAgent
		if hostile != null and hostile.is_active():
			spawned.append(hostile)
	return spawned


func test_plan_waves_escalate_within_the_ai_budget() -> void:
	assert_eq(PLAN.waves.size(), 5)
	var previous: int = 0
	for wave: SiegeWave in PLAN.waves:
		assert_gte(wave.total(), previous, "waves never get smaller")
		previous = wave.total()
		assert_lte(wave.max_alive, 12)
		assert_ne(wave.announcement, "")
		for archetype: ArchetypeData in wave.archetypes:
			assert_not_null(archetype)
	assert_eq(PLAN.waves[0].intermission_sec, 45.0, "the first countdown leaves time for the armory")
	var final_ids: Array[StringName] = []
	for archetype: ArchetypeData in PLAN.waves[4].archetypes:
		final_ids.append(archetype.id)
	assert_true(&"ambush_leader" in final_ids, "the lieutenant leads the last assault")
	assert_eq(PLAN.total_hostiles(), 4 + 6 + 6 + 8 + 8)


func test_roster_interleaves_archetypes() -> void:
	var roster: Array[ArchetypeData] = PLAN.waves[1].roster()
	assert_eq(roster.size(), 6)
	var ids: Array[StringName] = []
	for archetype: ArchetypeData in roster:
		ids.append(archetype.id)
	assert_eq(ids[0], &"thug")
	assert_eq(ids[1], &"cultist_gunman")
	assert_eq(ids[2], &"thug")
	assert_eq(ids[3], &"cultist_gunman")


func test_station_hosts_the_siege() -> void:
	var station: Node3D = (load(STATION) as PackedScene).instantiate() as Node3D
	autoqfree(station)
	var siege: StationSiege = station.get_node_or_null("StationSiege") as StationSiege
	assert_not_null(siege)
	assert_eq(siege.plan, PLAN)
	assert_eq(siege.entry_points.get_child_count(), 4)
	for path: NodePath in siege.nav_sources + siege.power_roots + [siege.doors_path]:
		assert_not_null(siege.get_node_or_null(path), "%s exists in the station" % path)
	assert_false(siege.navigation.bake_on_ready, "the station only bakes when the siege begins")


func test_every_entry_reaches_the_operations_room() -> void:
	var station: Node3D = (load(STATION) as PackedScene).instantiate() as Node3D
	for path: String in ["PlayerSpawner", "DispatchSetup"]:
		var node: Node = station.get_node_or_null(path)
		if node != null:
			station.remove_child(node)
			node.free()
	var siege: StationSiege = station.get_node("StationSiege") as StationSiege
	siege.auto_start = false
	add_child_autofree(station)
	for path: NodePath in siege.nav_sources:
		siege.get_node(path).add_to_group(StationSiege.NAV_SOURCE_GROUP)
	siege.navigation.bake_now()
	await siege.navigation.navigation_ready
	var map: RID = siege.navigation.get_navigation_map()
	for i: int in 4:  # let the navigation map sync the freshly baked station
		await get_tree().physics_frame
	NavigationServer3D.map_force_update(map)
	var goal: Vector3 = NavigationServer3D.map_get_closest_point(map, siege.defend_point.global_position)
	assert_lt(goal.distance_to(siege.defend_point.global_position), 1.0, "the operations room is on the navmesh")
	for marker: Node in siege.entry_points.get_children():
		var entry: Vector3 = (marker as Node3D).global_position
		var start: Vector3 = NavigationServer3D.map_get_closest_point(map, entry)
		assert_lt(start.distance_to(entry), 1.5, "%s is on the navmesh" % marker.name)
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, goal, true)
		assert_gt(path.size(), 1)
		assert_lt(path[path.size() - 1].distance_to(goal), 1.0, "%s reaches the operations room" % marker.name)


func test_siege_runs_every_wave_and_the_station_holds() -> void:
	var siege: StationSiege = _siege_on_floor()
	CallDirector.shift_running = true
	var trust: int = MissionDirector.public_trust
	await _start_and_bake(siege)
	assert_true(FlagCondition.values_equal(FlagSystem.get_flag(StationSiege.FLAG_ACTIVE), true))
	assert_true(FlagSystem.has_event(&"station_siege_started"))
	assert_false(CallDirector.shift_running, "the phones are cut")
	assert_true(StationSiege.is_siege_running(get_tree()))
	for wave: int in 2:
		var hostiles: Array[HostileAgent] = await _run_wave(siege)
		assert_eq(hostiles.size(), 2, "wave %d spawned" % (wave + 1))
		for hostile: HostileAgent in hostiles:
			hostile.die(1)
		siege.step(0.1)
	assert_eq(siege.state, StationSiege.State.SURVIVED)
	assert_eq(FlagSystem.count_events(&"siege_wave_cleared"), 2)
	assert_true(FlagSystem.has_event(&"station_siege_survived"))
	assert_eq(siege.neutralized, 4)
	assert_true(FlagCondition.values_equal(FlagSystem.get_flag(StationSiege.FLAG_OUTCOME), StationSiege.SURVIVED))
	assert_true(FlagCondition.values_equal(FlagSystem.get_flag(StationSiege.FLAG_ACTIVE), false))
	assert_true(FlagCondition.values_equal(FlagSystem.get_flag(&"station_defended"), true), "consequence rule applied")
	assert_eq(MissionDirector.public_trust, trust + 10)
	assert_true(FlagCondition.values_equal(FlagSystem.get_flag(&"siege_waves_repelled"), 2))
	assert_true(CallDirector.shift_running, "the shift clock resumes")
	assert_false(siege.start(&"again"), "one siege per run of the state machine")


func test_wave_respects_max_alive() -> void:
	var siege: StationSiege = _siege_on_floor(1)
	siege.plan.waves[0].counts = [5]
	siege.plan.waves[0].max_alive = 2
	await _start_and_bake(siege)
	var hostiles: Array[HostileAgent] = await _run_wave(siege)
	assert_eq(hostiles.size(), 2)
	assert_eq(siege.hostiles_left, 5)
	hostiles[0].die(1)
	for i: int in 3:
		siege.step(0.15)
	assert_eq(siege.enemies_root.get_child_count(), 3, "a fallen attacker frees a slot")


func test_team_wipe_overruns_the_station() -> void:
	var siege: StationSiege = _siege_on_floor()
	var player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	player.apply_class(ClassCatalog.get_data(&"medic"))
	_world.add_child(player)
	player.set_physics_process(false)
	var trust: int = MissionDirector.public_trust
	await _start_and_bake(siege)
	player.get_health().apply_damage(1000.0)
	siege.step(0.5)
	assert_true(siege.is_running(), "a short knock-down is not a wipe")
	siege.step(siege.plan.wipe_grace_sec)
	assert_eq(siege.state, StationSiege.State.FALLEN)
	assert_true(FlagSystem.has_event(&"station_siege_fallen"))
	assert_true(FlagCondition.values_equal(FlagSystem.get_flag(&"station_overrun"), true))
	assert_eq(MissionDirector.public_trust, trust - 15)
	assert_true(player.get_health().is_alive(), "officers are back on their feet afterwards")


func test_blackout_cuts_station_lights_until_the_end() -> void:
	var siege: StationSiege = _siege_on_floor()
	var lamp: OmniLight3D = _world.get_node("Lamps").get_child(0) as OmniLight3D
	await _start_and_bake(siege)
	assert_false(lamp.visible)
	assert_true(siege.emergency_lights.visible)
	var hud: CanvasLayer = siege.get_node("SiegeHud") as CanvasLayer
	assert_true(hud.visible)
	siege._end(StationSiege.SURVIVED)
	assert_true(lamp.visible)
	assert_false(siege.emergency_lights.visible)
	assert_false(hud.visible)


func test_trigger_needs_a_reason_an_idle_team_and_no_earlier_siege() -> void:
	var siege: StationSiege = _siege_on_floor()
	GameState.phase = GameState.Phase.DISPATCH
	if not MissionDirector.is_station_siege_triggered():
		assert_false(siege.should_start(), "no cult siege yet")
	FlagSystem.set_flag(StationSiege.FLAG_PENDING, true)
	assert_true(siege.should_start())
	GameState.phase = GameState.Phase.FIELD
	assert_false(siege.should_start(), "only in the station")
	GameState.phase = GameState.Phase.DISPATCH
	siege.auto_start = true
	siege.step(StationSiege.START_DELAY_SEC + 0.1)
	assert_true(siege.is_running())
	assert_false(FlagSystem.has_flag(StationSiege.FLAG_PENDING), "the request is consumed")
	siege._end(StationSiege.SURVIVED)
	FlagSystem.set_flag(StationSiege.FLAG_PENDING, true)
	assert_false(siege.should_start(), "the station is only besieged once per campaign")
