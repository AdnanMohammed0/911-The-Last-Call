## Hostile human AI (GAMEPLAY_MECHANICS §8): archetype stats, perception, behavior tree, navigation,
## host-side hitscan fire, morale / surrender, death. Clients only see replicated position, facing,
## animation state and hit points.
## Authority: HOST (spawned by EnemySpawner)
class_name HostileAgent
extends CharacterBody3D

const GROUP: StringName = &"hostiles"
const ARRIVE_DISTANCE: float = 0.8
const MELEE_RANGE: float = 1.9
const MELEE_COOLDOWN: float = 1.1
const BURST_PAUSE: float = 0.7
const PEEK_SECONDS: float = 1.6
const HIDE_SECONDS: float = 1.2
const SEARCH_SWEEP_SECONDS: float = 15.0
const INVESTIGATE_WAIT_SECONDS: float = 4.0
const FLANK_DISTANCE: float = 8.0
const FLANK_COOLDOWN: float = 10.0
const LOUD_BREACH_RADIUS: float = 25.0
const HOSTAGE_HEARING_DISTANCE: float = 15.0
const GUNSHOT_NOISE: float = 60.0
## Seconds before the first shot at a newly seen target.
const REACTION_SECONDS: float = 0.45
## Seconds of continuous tracking until aim is fully settled.
const AIM_SETTLE_SECONDS: float = 1.4
## After being hit, how long an exposed shooter prioritises reaching cover.
const UNDER_FIRE_SECONDS: float = 2.5
const SUPPRESS_MEMORY_SECONDS: float = 3.0
const STRAFE_INTERVAL: float = 1.6
const ARREST_HOLD_SECONDS: float = 2.0
const HIT_ZONES: Array[HealthComponent.HitZone] = [
	HealthComponent.HitZone.TORSO, HealthComponent.HitZone.TORSO, HealthComponent.HitZone.TORSO,
	HealthComponent.HitZone.TORSO, HealthComponent.HitZone.TORSO, HealthComponent.HitZone.TORSO,
	HealthComponent.HitZone.ARM, HealthComponent.HitZone.LEG, HealthComponent.HitZone.LEG,
	HealthComponent.HitZone.HEAD,
]

signal died()
signal surrendered()
signal hostage_executed()
signal arrested(by_peer: int)

@export var archetype: ArchetypeData
## Optional patrol route: its Node3D children are visited in order.
@export var patrol_route: Node3D

# --- Replicated (Sync) ---
var anim_state: StringName = &"idle"
var hp: float = 100.0
var is_dead: bool = false
var is_surrendered: bool = false
var is_arrested: bool = false:
	set(value):
		is_arrested = value
		if is_node_ready():
			_apply_arrested()
var sync_position: Vector3 = Vector3.ZERO
var sync_yaw: float = 0.0

# --- Host state ---
var squad: AISquad = null
var morale: float = 50.0
var ammo: int = 0
var hostage_alive: bool = true
var negotiated: bool = false
var reinforcements_called: bool = false
var cover: CoverPoint = null

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_fire_time: float = 0.0
var _burst_left: int = 0
var _move_target: Vector3 = Vector3.INF
var _run: bool = false
var _aim_target: Vector3 = Vector3.INF
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _patrol_index: int = 0
var _aim_player: Player = null
var _aim_tracked: float = 0.0
var _aim_seen_at: float = -100.0
var _under_fire_until: float = -100.0
var _last_attacker_peer: int = 0
var _last_attacker_at: float = -100.0
var _next_strafe_at: float = 0.0
var _search_points: Array[Vector3] = []
## True when this suspect was killed after giving up (or unarmed) — unlawful for the mission report.
var killed_unlawfully: bool = false
var _arrest_point: Interactable

@onready var perception: AIPerception = $Perception
@onready var runner: BTRunner = $BTRunner
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var eye: Node3D = $Eye
@onready var _body: Node3D = $Body


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(LagCompensation.GROUP)
	if archetype == null:
		archetype = load("res://data/ai/archetypes/thug.tres") as ArchetypeData
	hp = archetype.max_hp
	morale = archetype.morale
	ammo = archetype.magazine
	_rng.randomize()
	_apply_color()
	sync_position = global_position
	sync_yaw = rotation.y
	_arrest_point = HostileArrest.create(self)
	if multiplayer.is_server():
		runner.tree = HostileBrains.build(archetype)
		EventBus.noise_event.connect(_on_noise_for_hostage)
	else:
		runner.enabled = false


func is_active() -> bool:
	return not is_dead and not is_surrendered


func get_time() -> float:
	return runner.blackboard.time


# --- Host API -------------------------------------------------------------------

## Host: damage from players (weapons P3-01, explosions, abilities).
func take_damage(amount: float, zone: HealthComponent.HitZone = HealthComponent.HitZone.TORSO, source_peer: int = 0) -> void:
	if not multiplayer.is_server() or is_dead or is_arrested:
		return
	hp = maxf(hp - amount * HealthComponent.ZONE_MULTIPLIERS[zone], 0.0)
	var shooter: Player = Player.find_by_peer(get_tree(), source_peer)
	perception.alert(shooter.global_position if shooter != null else global_position)
	if runner != null and runner.blackboard != null:
		_under_fire_until = get_time() + UNDER_FIRE_SECONDS
		if source_peer != 0:
			_last_attacker_peer = source_peer
			_last_attacker_at = get_time()
	if hp <= 0.0:
		killed_unlawfully = is_surrendered or not archetype.armed
		die(source_peer)


## Host: a player shouted "Police! Hands up!" at us. Frightened or hurt suspects give up.
func demand_surrender(player_armed: bool, officers_in_view: int) -> void:
	if not multiplayer.is_server() or not is_active() or archetype.fanatic:
		return
	var pressure: float = 10.0 + (18.0 if player_armed else 0.0) + 22.0 * (1.0 - hp / maxf(archetype.max_hp, 1.0))
	pressure += 8.0 * maxi(officers_in_view - 1, 0)
	if not archetype.armed:
		pressure += 25.0
	elif ammo <= 0:
		pressure += 15.0
	change_morale(-pressure, &"demand_surrender")
	perception.alert(global_position)
	if morale < archetype.surrender_threshold:
		negotiated = true


## Host: cuff a surrendered suspect.
func arrest(by_peer: int) -> bool:
	if not multiplayer.is_server() or not is_surrendered or is_arrested or is_dead:
		return false
	is_arrested = true
	anim_state = &"arrested"
	_stop()
	runner.enabled = false
	arrested.emit(by_peer)
	EventBus.suspect_arrested.emit(self, by_peer)
	return true


func _apply_arrested() -> void:
	if is_arrested:
		collision_layer = 0
		if _arrest_point != null:
			_arrest_point.enabled = false
		_body.scale.y = 0.75


func change_morale(amount: float, _reason: StringName) -> void:
	if not is_dead:
		morale = clampf(morale + amount, 0.0, 100.0)


func die(_by_peer: int = 0) -> void:
	if is_dead:
		return
	is_dead = true
	anim_state = &"dead"
	_stop()
	runner.reset()
	runner.enabled = false
	CoverQuery.release_all(self)
	if squad != null:
		squad.release_flank_token(self)
	collision_layer = 0
	died.emit()
	EventBus.hostile_killed.emit(self, _by_peer)


# --- Conditions -----------------------------------------------------------------

func cond_should_surrender(_bb: BTBlackboard) -> bool:
	if is_surrendered:
		return true
	if archetype.fanatic or morale >= archetype.surrender_threshold:
		return false
	return perception.visible_player_count >= 2 or negotiated


func cond_should_flee(_bb: BTBlackboard) -> bool:
	return not archetype.fanatic and hp < archetype.max_hp * 0.25 and morale < 40.0


func cond_in_combat(_bb: BTBlackboard) -> bool:
	return perception.level == AIPerception.Level.COMBAT


func cond_searching(_bb: BTBlackboard) -> bool:
	return perception.level == AIPerception.Level.SEARCHING


func cond_suspicious(_bb: BTBlackboard) -> bool:
	return perception.level == AIPerception.Level.SUSPICIOUS


## Taking hits away from cover: break contact first.
func cond_exposed_under_fire(bb: BTBlackboard) -> bool:
	return get_time() < _under_fire_until and not cond_in_cover(bb)


func cond_needs_reload(_bb: BTBlackboard) -> bool:
	return not archetype.melee and ammo <= 0


func cond_in_cover(_bb: BTBlackboard) -> bool:
	if cover == null or global_position.distance_to(cover.global_position) > ARRIVE_DISTANCE * 1.5:
		return false
	var threat: Vector3 = _threat_position()
	if threat == Vector3.INF:
		return true
	return CoverQuery.is_protected(get_world_3d(), cover, threat + Vector3(0, CoverQuery.THREAT_EYE, 0), _exclude())


func cond_can_flank(bb: BTBlackboard) -> bool:
	var cooldown_until: float = bb.get_value(&"flank_cooldown_until", 0.0)
	if squad == null or get_time() < cooldown_until or perception.target == null:
		return false
	return squad.has_free_flank_token(self) and global_position.distance_to(perception.target.global_position) > 6.0


func cond_ied_in_range(_bb: BTBlackboard) -> bool:
	var nearest: Player = _nearest_player()
	return nearest != null and nearest.global_position.distance_to(global_position) <= archetype.ied_radius


func cond_can_call_reinforcements(_bb: BTBlackboard) -> bool:
	return not reinforcements_called


# --- Actions --------------------------------------------------------------------

func act_surrender(_bb: BTBlackboard) -> BTNode.Status:
	if not is_surrendered:
		is_surrendered = true
		anim_state = &"surrender"
		ammo = 0
		_stop()
		CoverQuery.release_all(self)
		if squad != null:
			squad.release_flank_token(self)
		surrendered.emit()
		EventBus.suspect_surrendered.emit(self)
	return BTNode.Status.RUNNING   # stays surrendered until arrested (P3-05)


func act_flee(bb: BTBlackboard) -> BTNode.Status:
	if not bb.has_value(&"flee_point"):
		bb.set_value(&"flee_point", _pick_escape_point())
	anim_state = &"flee"
	var point: Vector3 = bb.get_value(&"flee_point")
	if _move_to(point, true):
		bb.erase(&"flee_point")
		return BTNode.Status.SUCCESS
	return BTNode.Status.RUNNING


func act_detonate_ied(_bb: BTBlackboard) -> BTNode.Status:
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var player: Player = node as Player
		var distance: float = player.global_position.distance_to(global_position)
		var blast: float = archetype.ied_radius * 2.0
		if distance <= blast:
			player.get_health().apply_damage(archetype.ied_damage * (1.0 - distance / blast * 0.6), HealthComponent.HitZone.TORSO)
	EventBus.noise_event.emit(global_position, GUNSHOT_NOISE, 0)
	_fx_explosion.rpc(global_position)
	die()
	return BTNode.Status.SUCCESS


func act_hold_hostage(_bb: BTBlackboard) -> BTNode.Status:
	_stop()
	anim_state = &"hostage"
	var target: Player = perception.target
	if target != null and perception.is_target_visible:
		_face(target.global_position)
		_try_fire(target)
	return BTNode.Status.RUNNING


func act_call_reinforcements(_bb: BTBlackboard) -> BTNode.Status:
	reinforcements_called = true
	anim_state = &"callout"
	for node: Node in get_tree().get_nodes_in_group(EnemySpawner.GROUP):
		var spawner: EnemySpawner = node as EnemySpawner
		spawner.spawn_reinforcements(self, archetype.reinforcements)
		break
	return BTNode.Status.SUCCESS


func act_rush_and_strike(bb: BTBlackboard) -> BTNode.Status:
	var target: Player = perception.target if perception.target != null else _nearest_player()
	if target == null:
		return BTNode.Status.FAILURE
	var distance: float = target.global_position.distance_to(global_position)
	if distance > MELEE_RANGE:
		anim_state = &"run"
		_move_to(target.global_position, true)
		return BTNode.Status.RUNNING
	_stop()
	_face(target.global_position)
	var next_strike: float = bb.get_value(&"next_strike", 0.0)
	if get_time() >= next_strike:
		bb.set_value(&"next_strike", get_time() + MELEE_COOLDOWN)
		anim_state = &"melee"
		target.get_health().apply_damage(archetype.melee_damage, HealthComponent.HitZone.TORSO)
	return BTNode.Status.RUNNING


func act_reload(bb: BTBlackboard) -> BTNode.Status:
	_stop()
	anim_state = &"reload"
	if not bb.has_value(&"reload_done_at"):
		bb.set_value(&"reload_done_at", get_time() + archetype.reload_seconds)
	var done_at: float = bb.get_value(&"reload_done_at")
	if get_time() < done_at:
		return BTNode.Status.RUNNING
	bb.erase(&"reload_done_at")
	ammo = archetype.magazine
	return BTNode.Status.SUCCESS


func act_flank(bb: BTBlackboard) -> BTNode.Status:
	var target: Player = perception.target
	if target == null or squad == null or not squad.request_flank_token(self):
		return BTNode.Status.FAILURE
	if not bb.has_value(&"flank_point"):
		var to_self: Vector3 = global_position - target.global_position
		to_self.y = 0.0
		var side: Vector3 = to_self.normalized().cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var point: Vector3 = target.global_position + side * FLANK_DISTANCE + to_self.normalized() * 3.0
		bb.set_value(&"flank_point", NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, point))
	anim_state = &"run"
	var flank_point: Vector3 = bb.get_value(&"flank_point")
	if _move_to(flank_point, true):
		bb.erase(&"flank_point")
		bb.set_value(&"flank_cooldown_until", get_time() + FLANK_COOLDOWN)
		squad.release_flank_token(self)
		CoverQuery.release_all(self)
		cover = null
		return BTNode.Status.SUCCESS
	return BTNode.Status.RUNNING


func act_flank_exit(bb: BTBlackboard) -> void:
	bb.erase(&"flank_point")
	bb.set_value(&"flank_cooldown_until", get_time() + FLANK_COOLDOWN)
	if squad != null:
		squad.release_flank_token(self)


func act_peek_and_fire(bb: BTBlackboard) -> BTNode.Status:
	_stop()
	var cycle: float = fmod(get_time(), PEEK_SECONDS + HIDE_SECONDS)
	var peeking: bool = cycle < PEEK_SECONDS
	anim_state = &"aim" if peeking else &"cover"
	var target: Player = _combat_target()
	if target != null and perception.is_target_visible:
		_face(target.global_position)
		if peeking:
			_try_fire(target)
	elif peeking:
		_suppress()
	bb.set_value(&"peeking", peeking)
	return BTNode.Status.RUNNING


func act_move_to_cover(_bb: BTBlackboard) -> BTNode.Status:
	var threat: Vector3 = _threat_position()
	if threat == Vector3.INF:
		return BTNode.Status.FAILURE
	if cover == null or not cover.is_free_for(self):
		var others: Array[Vector3] = []
		for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
			var player: Player = node as Player
			if player != perception.target and player.get_health().is_alive():
				others.append(player.global_position)
		cover = CoverQuery.find_best(self, threat, others, _exclude())
		if cover == null:
			return BTNode.Status.FAILURE
		CoverQuery.claim(cover, self)
	anim_state = &"run"
	if _move_to(cover.global_position, true):
		return BTNode.Status.SUCCESS
	return BTNode.Status.RUNNING


func act_advance_and_fire(_bb: BTBlackboard) -> BTNode.Status:
	var target: Player = _combat_target()
	if target == null:
		if perception.last_known_position == Vector3.INF:
			return BTNode.Status.FAILURE
		anim_state = &"run"
		_move_to(perception.last_known_position, true)
		return BTNode.Status.RUNNING
	var distance: float = target.global_position.distance_to(global_position)
	if not perception.is_target_visible or distance > archetype.effective_range * 0.7:
		anim_state = &"walk"
		_move_to(target.global_position if perception.is_target_visible else perception.last_known_position, false)
		if not perception.is_target_visible:
			_suppress()
	else:
		# In the open and in range: side-step while shooting instead of standing still.
		anim_state = &"aim"
		if get_time() >= _next_strafe_at:
			_next_strafe_at = get_time() + STRAFE_INTERVAL * _rng.randf_range(0.7, 1.3)
			var to_target: Vector3 = (target.global_position - global_position)
			to_target.y = 0.0
			var side: Vector3 = to_target.normalized().cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
			var step: Vector3 = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, global_position + side * _rng.randf_range(1.5, 3.0))
			_move_to(step, false)
	_face(target.global_position)
	if perception.is_target_visible and distance <= archetype.effective_range:
		_try_fire(target)
	return BTNode.Status.RUNNING


func act_search(bb: BTBlackboard) -> BTNode.Status:
	var goal: Vector3 = perception.last_known_position
	if goal != Vector3.INF and not bb.has_value(&"search_started"):
		anim_state = &"walk"
		if not _move_to(goal, false):
			return BTNode.Status.RUNNING
		bb.set_value(&"search_started", get_time())
	var started: float = bb.get_value(&"search_started", get_time())
	if get_time() - started < SEARCH_SWEEP_SECONDS:
		# Check the nearby corners the player could have slipped into, one after another.
		if _search_points.is_empty():
			var map: RID = get_world_3d().navigation_map
			var centre: Vector3 = goal if goal != Vector3.INF else global_position
			for i: int in 3:
				var offset: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU) * _rng.randf_range(4.0, 9.0)
				_search_points.append(NavigationServer3D.map_get_closest_point(map, centre + offset))
		anim_state = &"search"
		if _move_to(_search_points[0], false):
			_search_points.remove_at(0)
			rotation.y += _rng.randf_range(-1.2, 1.2)
		return BTNode.Status.RUNNING
	_search_points.clear()
	bb.erase(&"search_started")
	perception.awareness = AIPerception.SUSPICIOUS_AT + 0.05
	return BTNode.Status.SUCCESS


func act_investigate(bb: BTBlackboard) -> BTNode.Status:
	var goal: Vector3 = perception.last_noise_position if perception.last_noise_position != Vector3.INF else perception.last_known_position
	if goal == Vector3.INF:
		return BTNode.Status.FAILURE
	_face(goal)
	if not bb.has_value(&"investigate_arrived"):
		anim_state = &"walk"
		if not _move_to(goal, false):
			return BTNode.Status.RUNNING
		bb.set_value(&"investigate_arrived", get_time())
	anim_state = &"idle"
	var arrived: float = bb.get_value(&"investigate_arrived")
	if get_time() - arrived < INVESTIGATE_WAIT_SECONDS:
		return BTNode.Status.RUNNING
	bb.erase(&"investigate_arrived")
	perception.awareness = 0.2
	perception.last_noise_position = Vector3.INF
	return BTNode.Status.SUCCESS


func act_patrol(_bb: BTBlackboard) -> BTNode.Status:
	if patrol_route == null or patrol_route.get_child_count() == 0:
		_stop()
		anim_state = &"idle"
		return BTNode.Status.RUNNING
	var point: Node3D = patrol_route.get_child(_patrol_index % patrol_route.get_child_count()) as Node3D
	anim_state = &"walk"
	if _move_to(point.global_position, false):
		_patrol_index += 1
	return BTNode.Status.RUNNING


# --- Movement / firing ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		_update_remote(delta)
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if is_dead or _move_target == Vector3.INF:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var next: Vector3 = nav_agent.get_next_path_position()
		var direction: Vector3 = next - global_position
		direction.y = 0.0
		if direction.length() < 0.05:
			direction = _move_target - global_position
			direction.y = 0.0
		direction = direction.normalized()
		var speed: float = archetype.run_speed if _run else archetype.walk_speed
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if _aim_target == Vector3.INF and direction.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), clampf(10.0 * delta, 0.0, 1.0))
	move_and_slide()
	sync_position = global_position
	sync_yaw = rotation.y
	_aim_target = Vector3.INF
	_apply_pose(delta)


func _update_remote(delta: float) -> void:
	var weight: float = clampf(14.0 * delta, 0.0, 1.0)
	global_position = global_position.lerp(sync_position, weight) if global_position.distance_to(sync_position) < 4.0 else sync_position
	rotation.y = lerp_angle(rotation.y, sync_yaw, weight)
	_apply_pose(delta)


## Returns true when within ARRIVE_DISTANCE of `point`.
func _move_to(point: Vector3, run: bool) -> bool:
	var flat: Vector3 = point - global_position
	flat.y = 0.0
	if flat.length() <= ARRIVE_DISTANCE:
		_stop()
		return true
	_run = run
	if _move_target.distance_to(point) > 0.3:
		_move_target = point
		nav_agent.target_position = point
	return false


func _stop() -> void:
	_move_target = Vector3.INF


func _face(point: Vector3) -> void:
	_aim_target = point
	var flat: Vector3 = point - global_position
	flat.y = 0.0
	if flat.length() > 0.05:
		rotation.y = atan2(-flat.x, -flat.z)


func _try_fire(target: Player) -> void:
	if not archetype.armed or archetype.melee or ammo <= 0:
		return
	# Aim settles while the same target stays in view; switching targets or losing sight resets it.
	var now: float = get_time()
	if target != _aim_player or now - _aim_seen_at > 0.6:
		_aim_player = target
		_aim_tracked = 0.0
		_next_fire_time = maxf(_next_fire_time, now + REACTION_SECONDS * _rng.randf_range(0.7, 1.3))
	else:
		_aim_tracked += now - _aim_seen_at
	_aim_seen_at = now
	if now < _next_fire_time:
		return
	var from: Vector3 = eye.global_position
	var aim_point: Vector3 = target.get_eye_position() - Vector3(0, 0.45, 0)
	var distance: float = from.distance_to(aim_point)
	if distance > archetype.effective_range or not perception.has_line_of_sight(from, aim_point, target):
		return
	ammo -= 1
	_burst_left -= 1
	if _burst_left <= 0:
		_burst_left = archetype.burst_size
		_next_fire_time = get_time() + archetype.fire_interval + BURST_PAUSE
	else:
		_next_fire_time = get_time() + archetype.fire_interval
	var hit_chance: float = hit_chance_against(target, distance)
	var end: Vector3 = aim_point
	if _rng.randf() <= hit_chance:
		# A settled aim lands more upper-body and head shots.
		var zone: HealthComponent.HitZone = HIT_ZONES[_rng.randi() % HIT_ZONES.size()]
		if settle_ratio() > 0.8 and _rng.randf() < 0.12 * archetype.accuracy / 0.55:
			zone = HealthComponent.HitZone.HEAD
		target.get_health().apply_damage(archetype.damage, zone, 0)
	else:
		end = aim_point + Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.6, 0.8), _rng.randf_range(-1.0, 1.0))
	EventBus.noise_event.emit(from, GUNSHOT_NOISE, 0)
	_fx_shot.rpc(from, end)


## 0..1 how settled our aim is on the current target.
func settle_ratio() -> float:
	return clampf(_aim_tracked / AIM_SETTLE_SECONDS, 0.0, 1.0)


## Chance a shot hits `target` right now: skill, settled aim, range, target speed, stance and light.
func hit_chance_against(target: Player, distance: float) -> float:
	var speed: float = Vector2(target.velocity.x, target.velocity.z).length()
	var moving: float = lerpf(1.0, 0.55, clampf(speed / 5.0, 0.0, 1.0))
	var crouch: float = 0.8 if target.stance == Player.Stance.CROUCH else 1.0
	var settle: float = lerpf(0.4, 1.25, settle_ratio())
	var range_factor: float = clampf(sqrt(12.0 / maxf(distance, 1.0)), 0.25, 1.4)
	var light: float = 1.0 if perception.is_lit(target) or target.flashlight_on else 0.75
	return clampf(archetype.accuracy * settle * range_factor * moving * crouch * light, 0.03, 0.95)


## Target to engage: whoever just shot us if we can see them, otherwise perception's pick.
func _combat_target() -> Player:
	if _last_attacker_peer != 0 and get_time() - _last_attacker_at < 4.0:
		var attacker: Player = Player.find_by_peer(get_tree(), _last_attacker_peer)
		if attacker != null and attacker.get_health().is_alive() \
				and perception.has_line_of_sight(eye.global_position, attacker.get_eye_position(), attacker):
			return attacker
	return perception.target


## Pin the target down: short bursts at the last known position while it is out of sight.
func _suppress() -> void:
	if not archetype.armed or archetype.melee or ammo <= 0 or get_time() < _next_fire_time:
		return
	if perception.last_known_position == Vector3.INF or perception.time_since_seen > SUPPRESS_MEMORY_SECONDS:
		return
	var from: Vector3 = eye.global_position
	var point: Vector3 = perception.last_known_position + Vector3(_rng.randf_range(-0.8, 0.8), _rng.randf_range(0.6, 1.6), _rng.randf_range(-0.8, 0.8))
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, point, 1, _exclude())
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = point
	if not hit.is_empty():
		end = hit["position"]
		if from.distance_to(end) < 2.0:
			return   # our own cover is in the way
	ammo -= 1
	_next_fire_time = get_time() + archetype.fire_interval * 2.5
	_face(perception.last_known_position)
	EventBus.noise_event.emit(from, GUNSHOT_NOISE, 0)
	_fx_shot.rpc(from, end)


func _threat_position() -> Vector3:
	if perception.target != null:
		return perception.target.global_position
	return perception.last_known_position


func _nearest_player() -> Player:
	var best: Player = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var player: Player = node as Player
		if player == null or not player.get_health().is_alive():
			continue
		var distance: float = player.global_position.distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = player
	return best


func _pick_escape_point() -> Vector3:
	var threat: Vector3 = _threat_position()
	var map: RID = get_world_3d().navigation_map
	var best: Vector3 = global_position
	var best_distance: float = -1.0
	for i: int in 12:
		var candidate: Vector3 = global_position + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 12.0) * 15.0
		candidate = NavigationServer3D.map_get_closest_point(map, candidate)
		var distance: float = candidate.distance_to(threat) if threat != Vector3.INF else candidate.distance_to(global_position)
		if distance > best_distance:
			best_distance = distance
			best = candidate
	return best


## Bodies that must not count as cover or block firing lines: ourselves and every player
## (a ray towards a player's eye would otherwise stop at that player's own capsule).
func _exclude() -> Array[RID]:
	var rids: Array[RID] = [get_rid()]
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var player: Player = node as Player
		if player != null:
			rids.append(player.get_rid())
	return rids


## Hostage taker: a loud breach nearby may get the hostage executed (GAMEPLAY §8.1).
func _on_noise_for_hostage(position: Vector3, radius: float, _source_peer: int) -> void:
	if archetype.hostage_execute_chance <= 0.0 or not hostage_alive or not is_active():
		return
	if radius < LOUD_BREACH_RADIUS or position.distance_to(global_position) > HOSTAGE_HEARING_DISTANCE:
		return
	if _rng.randf() < archetype.hostage_execute_chance:
		hostage_alive = false
		hostage_executed.emit()
		EventBus.hostage_executed.emit(self)


# --- Visuals (all peers) ----------------------------------------------------------

func _apply_color() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = archetype.color
	for child: Node in _body.get_children():
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh != null and mesh.name != "Head":
			mesh.material_override = material


func _apply_pose(delta: float) -> void:
	var lie: float = -1.45 if anim_state == &"dead" else 0.0
	var kneel: float = 0.7 if anim_state == &"surrender" else 1.0
	_body.rotation.x = lerpf(_body.rotation.x, lie, clampf(6.0 * delta, 0.0, 1.0))
	_body.scale.y = lerpf(_body.scale.y, kneel, clampf(6.0 * delta, 0.0, 1.0))


@rpc("authority", "call_local", "unreliable")
func _fx_shot(from: Vector3, to: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()
	var line: MeshInstance3D = MeshInstance3D.new()
	line.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.85, 0.4)
	line.material_override = material
	line.top_level = true
	add_child(line)
	get_tree().create_timer(0.06).timeout.connect(line.queue_free)


@rpc("authority", "call_local", "reliable")
func _fx_explosion(position: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var flash: OmniLight3D = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.6, 0.2)
	flash.light_energy = 8.0
	flash.omni_range = 10.0
	flash.top_level = true
	get_parent().add_child(flash)
	flash.global_position = position + Vector3(0, 1, 0)
	get_tree().create_timer(0.25).timeout.connect(flash.queue_free)
