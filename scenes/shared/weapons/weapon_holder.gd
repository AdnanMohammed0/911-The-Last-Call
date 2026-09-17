## Player firearms (P3-01): primary + sidearm slots, hitscan fire with spread and recoil patterns, reload,
## ADS, viewmodel and FX.
##
## Flow: the owner samples input, applies spread / recoil / FX immediately (prediction) and sends
## `_rpc_fire(slot, origin, directions)`. The host validates the request (owner, alive, weapon owned, ammo,
## fire rate, origin near the eyes, pellet count, aim direction), rewinds hostiles with LagCompensation,
## resolves hits, applies damage with falloff and hit zones, then broadcasts tracers to other peers and a
## hit confirm to the shooter. Ammo and reloads are host-owned and replicated through the player's HostSync.
## Authority: HOST (loadout, ammo, hits) / OWNING PEER (input, active slot, aim, viewmodel)
class_name WeaponHolder
extends Node3D

const NO_SLOT: int = -1
## Host: accepted muzzle origin distance from the shooter's eyes (lean, latency).
const ORIGIN_TOLERANCE: float = 1.5
## Host: max angle between a shot and the shooter's replicated view direction.
const AIM_TOLERANCE_DEGREES: float = 45.0
## Host: shots may arrive bunched by jitter; accept intervals down to this fraction...
const FIRE_INTERVAL_TOLERANCE: float = 0.6
## ...but never more shots per second than the weapon allows plus this slack.
const FIRE_RATE_SLACK: int = 2
const DRAW_SECONDS: float = 0.35
const PREDICTION_HOLD_MSEC: int = 400
const HIP_POSITION: Vector3 = Vector3(0.17, -0.17, -0.5)
## ADS: sights centred, slightly closer (y is lowered by WeaponModel.sight_height).
const AIM_POSITION: Vector3 = Vector3(0.0, 0.0, -0.4)
const REMOTE_POSITION: Vector3 = Vector3(0.22, -0.32, -0.42)

## Owner: a hit was confirmed by the host (hit marker).
signal hit_confirmed(killed: bool, headshot: bool)
## Owner: a shot left the barrel locally (HUD crosshair bloom).
signal fired(slot: int)
signal loadout_changed()

# --- Replicated by HostSync (host -> everyone) ---
var primary_id: StringName = &"":
	set(value):
		primary_id = value
		_on_loadout_replicated()
var sidearm_id: StringName = &"":
	set(value):
		sidearm_id = value
		_on_loadout_replicated()
var primary_mag: int = 0
var primary_reserve: int = 0
var sidearm_mag: int = 0
var sidearm_reserve: int = 0
## Slot being reloaded on the host, or NO_SLOT.
var reloading_slot: int = NO_SLOT

# --- Replicated by ClientSync (owner -> everyone) ---
var active_slot: int = WeaponData.Slot.SIDEARM:
	set(value):
		if active_slot == value:
			return
		active_slot = value
		_draw_left = DRAW_SECONDS
		_rebuild_model()
var aiming: bool = false

# --- Owner state ---
var _next_local_fire_msec: int = 0
var _last_local_shot_msec: int = -100000
var _predicted_mag: Dictionary[int, int] = {}
var _shot_index: int = 0
var _recoil_debt: Vector2 = Vector2.ZERO
var _kick: float = 0.0
var _draw_left: float = 0.0
var _base_fov: float = 75.0
var _bob_time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# --- Host state ---
var _reload_left: float = 0.0
## sender slot -> recent accepted shot msec
var _host_shot_times: Dictionary[int, Array] = {}
var _limiter: RpcRateLimiter = RpcRateLimiter.new(40.0, 20.0)

var _player: Player
var _model: WeaponModel
var _shot_player: AudioStreamPlayer3D
var _local_shot_player: AudioStreamPlayer
var _hud: WeaponHud


func _ready() -> void:
	_player = get_parent() as Player
	_rng.randomize()
	_shot_player = AudioStreamPlayer3D.new()
	_shot_player.unit_size = 12.0
	_shot_player.max_distance = 140.0
	_shot_player.max_polyphony = 4
	add_child(_shot_player)
	_local_shot_player = AudioStreamPlayer.new()
	_local_shot_player.max_polyphony = 4
	_local_shot_player.volume_db = -4.0
	add_child(_local_shot_player)
	if multiplayer.is_server() and primary_id == &"" and sidearm_id == &"":
		# Players start unarmed (weapons come from the armory); a deployment carries its loadout over.
		var saved: Dictionary = MissionDirector.get_loadout(_player.peer_id)
		if not saved.is_empty():
			restore_loadout(saved)
	if not has_weapon(active_slot) and has_weapon(WeaponData.Slot.PRIMARY):
		active_slot = WeaponData.Slot.PRIMARY
	_base_fov = GameSettings.fov
	_player.get_camera().fov = _base_fov
	GameSettings.changed.connect(func(key: String) -> void:
		if key == "fov":
			_base_fov = GameSettings.fov)
	refresh_authority()


## Called by Player whenever its authority changes.
func refresh_authority() -> void:
	if not is_node_ready():
		return
	if _player.is_multiplayer_authority() and _hud == null and DisplayServer.get_name() != "headless":
		_hud = WeaponHud.new()
		_hud.holder = self
		_player.get_node(^"HUD").add_child(_hud)
	_rebuild_model()


# --- Queries -------------------------------------------------------------------------

func weapon_id(slot: int) -> StringName:
	return primary_id if slot == WeaponData.Slot.PRIMARY else sidearm_id


func weapon_data(slot: int) -> WeaponData:
	return WeaponCatalog.get_data(weapon_id(slot))


func has_weapon(slot: int) -> bool:
	return weapon_id(slot) != &""


func get_active_weapon() -> WeaponData:
	return weapon_data(active_slot)


func magazine(slot: int) -> int:
	return primary_mag if slot == WeaponData.Slot.PRIMARY else sidearm_mag


func reserve(slot: int) -> int:
	return primary_reserve if slot == WeaponData.Slot.PRIMARY else sidearm_reserve


## Owner view of the magazine: the host value, or our prediction right after firing.
func displayed_magazine(slot: int) -> int:
	if Time.get_ticks_msec() - _last_local_shot_msec < PREDICTION_HOLD_MSEC and _predicted_mag.has(slot):
		return mini(_predicted_mag[slot], magazine(slot))
	return magazine(slot)


func is_reloading() -> bool:
	return reloading_slot != NO_SLOT


## Current cone half-angle in degrees for the active weapon.
func current_spread() -> float:
	var weapon: WeaponData = get_active_weapon()
	if weapon == null:
		return 0.0
	var spread: float = weapon.aim_spread if aiming else weapon.hip_spread
	var walk: float = maxf(_player.walk_speed, 0.1)
	spread += weapon.move_spread * clampf(_player.get_horizontal_speed() / walk, 0.0, 1.5) * (0.4 if aiming else 1.0)
	if not _player.is_on_floor():
		spread += 3.0
	if _player.stance == Player.Stance.CROUCH:
		spread *= 0.75
	var class_data: ClassData = ClassCatalog.get_data(_player.class_id)
	if class_data != null and class_data.aim_stability > 0.0:
		spread /= class_data.aim_stability
	return spread


# --- Host API ------------------------------------------------------------------------

## Host: replace the loadout (armory, class defaults) and fill the ammo.
func give_loadout(loadout: Dictionary[WeaponData.Slot, StringName]) -> void:
	if not multiplayer.is_server():
		return
	var primary: StringName = loadout.get(WeaponData.Slot.PRIMARY, &"")
	var sidearm: StringName = loadout.get(WeaponData.Slot.SIDEARM, &"")
	set_weapon(WeaponData.Slot.PRIMARY, primary)
	set_weapon(WeaponData.Slot.SIDEARM, sidearm)


## Host: put `id` (or nothing) in `slot` with a full magazine and reserve.
func set_weapon(slot: int, id: StringName) -> void:
	if not multiplayer.is_server():
		return
	var data: WeaponData = WeaponCatalog.get_data(id)
	var mag: int = data.magazine_size if data != null else 0
	var spare: int = data.max_reserve if data != null else 0
	if slot == reloading_slot:
		reloading_slot = NO_SLOT
	if slot == WeaponData.Slot.PRIMARY:
		primary_mag = mag
		primary_reserve = spare
		primary_id = id if data != null else &""
	else:
		sidearm_mag = mag
		sidearm_reserve = spare
		sidearm_id = id if data != null else &""


## Host: re-apply a loadout saved by MissionDirector across a level change.
func restore_loadout(saved: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var primary: StringName = saved.get("primary", &"")
	var sidearm: StringName = saved.get("sidearm", &"")
	set_weapon(WeaponData.Slot.PRIMARY, primary)
	set_weapon(WeaponData.Slot.SIDEARM, sidearm)
	var primary_mag_saved: int = saved.get("primary_mag", primary_mag)
	var primary_reserve_saved: int = saved.get("primary_reserve", primary_reserve)
	var sidearm_mag_saved: int = saved.get("sidearm_mag", sidearm_mag)
	var sidearm_reserve_saved: int = saved.get("sidearm_reserve", sidearm_reserve)
	_set_ammo(WeaponData.Slot.PRIMARY, primary_mag_saved, primary_reserve_saved)
	_set_ammo(WeaponData.Slot.SIDEARM, sidearm_mag_saved, sidearm_reserve_saved)
	var armor: float = saved.get("armor", 0.0)
	_player.get_health().armor = armor


## Host: top up reserves (ammo crates).
func refill_ammo() -> void:
	if not multiplayer.is_server():
		return
	for slot: int in [WeaponData.Slot.PRIMARY, WeaponData.Slot.SIDEARM]:
		var data: WeaponData = weapon_data(slot)
		if data != null:
			_set_ammo(slot, data.magazine_size, data.max_reserve)


## Host: validate and resolve one trigger pull. Returns true when accepted.
func host_fire(sender: int, slot: int, origin: Vector3, directions: PackedVector3Array, rewind_msec: int) -> bool:
	if not multiplayer.is_server():
		return false
	if sender != _player.peer_id:
		RpcGuard.reject("fire", sender, "not the owner")
		return false
	var weapon: WeaponData = weapon_data(slot)
	if weapon == null:
		RpcGuard.reject("fire", sender, "no weapon in slot")
		return false
	if not _player.get_health().is_alive() or _player.grabbed_by_anomaly:
		return false
	if reloading_slot == slot or magazine(slot) <= 0:
		return false
	if directions.size() != weapon.pellets:
		RpcGuard.reject("fire", sender, "pellet count")
		return false
	if origin.distance_to(_player.get_eye_position()) > ORIGIN_TOLERANCE:
		RpcGuard.reject("fire", sender, "origin too far from eyes")
		return false
	var view: Vector3 = Vector3.FORWARD.rotated(Vector3.RIGHT, _player.sync_pitch).rotated(Vector3.UP, _player.sync_yaw)
	var min_dot: float = cos(deg_to_rad(AIM_TOLERANCE_DEGREES))
	for direction: Vector3 in directions:
		if not direction.is_normalized() or direction.dot(view) < min_dot:
			RpcGuard.reject("fire", sender, "direction")
			return false
	if not _accept_fire_rate(slot, weapon):
		RpcGuard.reject("fire", sender, "fire rate")
		return false

	_set_ammo(slot, magazine(slot) - 1, reserve(slot))
	var ends: PackedVector3Array = PackedVector3Array()
	var any_hit: bool = false
	var killed: bool = false
	var headshot: bool = false
	for direction: Vector3 in directions:
		var hit: Dictionary = resolve_shot(origin, direction, weapon.max_range, rewind_msec)
		var end: Vector3 = hit["end"]
		ends.append(end)
		var target_object: Object = hit.get("target")
		var target: HostileAgent = target_object as HostileAgent
		if target == null:
			continue
		var distance: float = hit["distance"]
		var zone: HealthComponent.HitZone = hit["zone"]
		var was_alive: bool = not target.is_dead
		target.take_damage(weapon.damage_at(distance), zone, sender)
		any_hit = true
		headshot = headshot or zone == HealthComponent.HitZone.HEAD
		killed = killed or (was_alive and target.is_dead)
	if NoiseSystem != null:
		NoiseSystem.emit_gunshot(origin, weapon.noise_radius, sender)
	else:
		EventBus.noise_event.emit(origin, weapon.noise_radius, sender)
	_broadcast_fire(sender, slot, origin, ends)
	if any_hit:
		if sender == multiplayer.get_unique_id():
			hit_confirmed.emit(killed, headshot)
		else:
			_rpc_hit_confirm.rpc_id(sender, killed, headshot)
	return true


## Host: start reloading `slot`. Returns true when a reload began.
func host_reload(sender: int, slot: int) -> bool:
	if not multiplayer.is_server() or sender != _player.peer_id:
		return false
	var weapon: WeaponData = weapon_data(slot)
	if weapon == null or is_reloading() or not _player.get_health().is_alive():
		return false
	if magazine(slot) >= weapon.magazine_size or reserve(slot) <= 0:
		return false
	reloading_slot = slot
	_reload_left = weapon.reload_seconds
	return true


## Host: advance a running reload (called every physics frame; tests drive it directly).
func host_tick(delta: float) -> void:
	if reloading_slot == NO_SLOT:
		return
	if active_slot != reloading_slot or not _player.get_health().is_alive():
		reloading_slot = NO_SLOT
		return
	_reload_left -= delta
	if _reload_left > 0.0:
		return
	var weapon: WeaponData = weapon_data(reloading_slot)
	if weapon != null:
		var moved: int = mini(weapon.magazine_size - magazine(reloading_slot), reserve(reloading_slot))
		_set_ammo(reloading_slot, magazine(reloading_slot) + moved, reserve(reloading_slot) - moved)
	reloading_slot = NO_SLOT


## Host: world ray + lag-compensated hostile capsules. Returns {end, distance, target?, zone?}.
func resolve_shot(origin: Vector3, direction: Vector3, max_range: float, rewind_msec: int) -> Dictionary:
	var exclude: Array[RID] = []
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var body: CollisionObject3D = node as CollisionObject3D
		if body != null:
			exclude.append(body.get_rid())
	var hostiles: Array[Node] = get_tree().get_nodes_in_group(LagCompensation.GROUP)
	for node: Node in hostiles:
		var body: CollisionObject3D = node as CollisionObject3D
		if body != null:
			exclude.append(body.get_rid())
	var wall_distance: float = max_range
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * max_range, 0xFFFFFFFF, exclude)
	var world_hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	if not world_hit.is_empty():
		var point: Vector3 = world_hit["position"]
		wall_distance = origin.distance_to(point)
	var result: Dictionary = {"end": origin + direction * wall_distance, "distance": wall_distance}
	var best: float = wall_distance
	for node: Node in hostiles:
		var hostile: HostileAgent = node as HostileAgent
		if hostile == null or hostile.is_dead:
			continue
		var feet: Vector3 = LagCompensation.position_at(hostile, rewind_msec)
		var distance: float = Ballistics.ray_capsule(origin, direction, feet)
		if distance < best:
			best = distance
			var point: Vector3 = origin + direction * distance
			result = {"end": point, "distance": distance, "target": hostile,
				"zone": Ballistics.zone_for_point(feet, point, hostile.rotation.y)}
	return result


func _accept_fire_rate(slot: int, weapon: WeaponData) -> bool:
	var now: int = Time.get_ticks_msec()
	var times: Array = _host_shot_times.get(slot, [])
	while not times.is_empty():
		var oldest: int = times[0]
		if now - oldest <= 1000:
			break
		times.pop_front()
	if not times.is_empty():
		var last: int = times[times.size() - 1]
		if now - last < int(weapon.fire_interval * 1000.0 * FIRE_INTERVAL_TOLERANCE):
			return false
	if times.size() >= ceili(1.0 / weapon.fire_interval) + FIRE_RATE_SLACK:
		return false
	times.append(now)
	_host_shot_times[slot] = times
	return true


## Host: set a slot's magazine and reserve (pickups keep the ammo they were dropped with).
func set_ammo(slot: int, mag: int, spare: int) -> void:
	if multiplayer.is_server() and has_weapon(slot):
		var data: WeaponData = weapon_data(slot)
		_set_ammo(slot, clampi(mag, 0, data.magazine_size), clampi(spare, 0, data.max_reserve))


## Host: drop the weapon in `slot` on the floor (at `at`, or in front of the player). Returns true on success.
func host_drop(sender: int, slot: int, at: Vector3 = Vector3.INF) -> bool:
	if not multiplayer.is_server() or sender != _player.peer_id or not has_weapon(slot):
		return false
	var position: Vector3 = at if at != Vector3.INF else _drop_position()
	WorldItems.spawn_weapon(weapon_id(slot), magazine(slot), reserve(slot), position, _player.rotation.y + randf_range(-0.4, 0.4))
	set_weapon(slot, &"")
	return true


func _drop_position() -> Vector3:
	var forward: Vector3 = -_player.global_basis.z
	var from: Vector3 = _player.get_eye_position()
	var ahead: Vector3 = _player.global_position + forward * 0.9 + Vector3(0, 1.0, 0)
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	# Don't push the weapon through a wall in front of the player.
	var wall: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, ahead, 1, [_player.get_rid()]))
	if not wall.is_empty():
		ahead = _player.global_position + Vector3(0, 1.0, 0)
	var floor_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(ahead, ahead + Vector3.DOWN * 3.0, 1, [_player.get_rid()]))
	if floor_hit.is_empty():
		return _player.global_position
	var point: Vector3 = floor_hit["position"]
	return point


func _set_ammo(slot: int, mag: int, spare: int) -> void:
	if slot == WeaponData.Slot.PRIMARY:
		primary_mag = mag
		primary_reserve = spare
	else:
		sidearm_mag = mag
		sidearm_reserve = spare


func _broadcast_fire(sender: int, slot: int, origin: Vector3, ends: PackedVector3Array) -> void:
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var player: Player = node as Player
		if player == null or player.peer_id == sender or player.peer_id == multiplayer.get_unique_id():
			continue
		if player.connection_lost:
			continue
		_rpc_fx_fire.rpc_id(player.peer_id, slot, origin, ends)
	if sender != multiplayer.get_unique_id():
		_play_remote_fire(slot, ends)


# --- RPCs ----------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _rpc_fire(slot: int, origin: Vector3, directions: PackedVector3Array) -> void:
	if not RpcGuard.is_host(self):
		return
	var sender: int = RpcGuard.sender_id(self)
	if not RpcGuard.is_registered(sender) or not _limiter.allow(sender, &"fire"):
		return
	host_fire(sender, slot, origin, directions, LagCompensation.rewind_msec_for(sender))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_reload(slot: int) -> void:
	if not RpcGuard.is_host(self):
		return
	var sender: int = RpcGuard.sender_id(self)
	if RpcGuard.is_registered(sender) and _limiter.allow(sender, &"reload"):
		host_reload(sender, slot)


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_fx_fire(slot: int, _origin: Vector3, ends: PackedVector3Array) -> void:
	if RpcGuard.is_from_host(self):
		_play_remote_fire(slot, ends)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hit_confirm(killed: bool, headshot: bool) -> void:
	if RpcGuard.is_from_host(self) and _player.is_multiplayer_authority():
		hit_confirmed.emit(killed, headshot)


# --- Owner input ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		host_tick(delta)
	if _player == null or not _player.is_multiplayer_authority():
		return
	var input: PlayerInput = _player.get_input()
	if input.weapon_primary_just_pressed and has_weapon(WeaponData.Slot.PRIMARY):
		active_slot = WeaponData.Slot.PRIMARY
	elif input.weapon_sidearm_just_pressed and has_weapon(WeaponData.Slot.SIDEARM):
		active_slot = WeaponData.Slot.SIDEARM
	elif input.weapon_swap_just_pressed:
		var other: int = WeaponData.Slot.SIDEARM if active_slot == WeaponData.Slot.PRIMARY else WeaponData.Slot.PRIMARY
		if has_weapon(other):
			active_slot = other
	_draw_left = maxf(_draw_left - delta, 0.0)

	var weapon: WeaponData = get_active_weapon()
	var can_act: bool = weapon != null and _player.get_health().is_alive() and not _player.is_sprinting \
		and not _player.grabbed_by_anomaly
	aiming = can_act and input.aim_held
	if not can_act:
		return
	if input.reload_just_pressed:
		request_reload()
	if input.drop_just_pressed:
		request_drop()
		return
	var wants_fire: bool = input.fire_held if weapon.automatic else input.fire_just_pressed
	if wants_fire and _draw_left <= 0.0 and reloading_slot != active_slot:
		_try_fire_local(weapon, input.fire_just_pressed)


## Owner: drop the active weapon.
func request_drop() -> void:
	if not has_weapon(active_slot):
		return
	if multiplayer.is_server():
		host_drop(multiplayer.get_unique_id(), active_slot)
	else:
		_rpc_drop.rpc_id(1, active_slot)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_drop(slot: int) -> void:
	if not RpcGuard.is_host(self):
		return
	var sender: int = RpcGuard.sender_id(self)
	if RpcGuard.is_registered(sender) and _limiter.allow(sender, &"drop"):
		host_drop(sender, slot)


## Owner: ask the host to reload the active weapon.
func request_reload() -> void:
	var weapon: WeaponData = get_active_weapon()
	if weapon == null or is_reloading() or magazine(active_slot) >= weapon.magazine_size or reserve(active_slot) <= 0:
		return
	_play_local(WeaponAudio.click("reload", 900.0))
	if multiplayer.is_server():
		host_reload(multiplayer.get_unique_id(), active_slot)
	else:
		_rpc_reload.rpc_id(1, active_slot)


func _try_fire_local(weapon: WeaponData, just_pressed: bool) -> void:
	var now: int = Time.get_ticks_msec()
	if now < _next_local_fire_msec:
		return
	var mag: int = displayed_magazine(active_slot)
	if mag <= 0:
		if just_pressed:
			_play_local(WeaponAudio.click("dry", 1600.0))
			_next_local_fire_msec = now + 250
			request_reload()
		return
	_next_local_fire_msec = now + int(weapon.fire_interval * 1000.0)
	if now - _last_local_shot_msec > int(weapon.recoil_reset_seconds * 1000.0):
		_shot_index = 0
	_last_local_shot_msec = now
	_predicted_mag[active_slot] = mag - 1

	var camera: Camera3D = _player.get_camera()
	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_basis.z
	var spread: float = current_spread()
	var directions: PackedVector3Array = PackedVector3Array()
	for i: int in weapon.pellets:
		directions.append(Ballistics.spread_direction(forward, spread, _rng))
	if multiplayer.is_server():
		host_fire(multiplayer.get_unique_id(), active_slot, origin, directions, 0)
	else:
		_rpc_fire.rpc_id(1, active_slot, origin, directions)

	# Local prediction: tracers to what our ray hits, sound, flash, recoil.
	var ends: PackedVector3Array = PackedVector3Array()
	for direction: Vector3 in directions:
		ends.append(_local_ray_end(origin, direction, weapon.max_range))
	_play_shot_fx(weapon, ends, true)
	_apply_recoil(weapon)
	_shot_index += 1
	fired.emit(active_slot)


func _local_ray_end(origin: Vector3, direction: Vector3, max_range: float) -> Vector3:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * max_range, 0xFFFFFFFF, [_player.get_rid()])
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return origin + direction * max_range
	var point: Vector3 = hit["position"]
	return point


func _apply_recoil(weapon: WeaponData) -> void:
	var kick: Vector2 = weapon.recoil_for_shot(_shot_index) * (0.55 if aiming else 1.0)
	if _player.stance == Player.Stance.CROUCH:
		kick *= 0.8
	kick.y += _rng.randf_range(-0.15, 0.15) * kick.x
	_rotate_view(kick)
	# Most of the vertical climb recovers once the trigger is released; horizontal drift stays.
	_recoil_debt += Vector2(kick.x * 0.7, 0.0)
	_kick = 1.0


## Pitch up by kick.x and yaw right by kick.y degrees.
func _rotate_view(kick: Vector2) -> void:
	var camera: Camera3D = _player.get_camera()
	var max_pitch: float = deg_to_rad(_player.max_pitch_degrees)
	camera.rotation.x = clampf(camera.rotation.x + deg_to_rad(kick.x), -max_pitch, max_pitch)
	_player.rotate_y(-deg_to_rad(kick.y))


# --- Visuals (all peers) -------------------------------------------------------------

func _process(delta: float) -> void:
	if _player == null:
		return
	if _player.is_multiplayer_authority():
		_update_owner_view(delta)
	_kick = move_toward(_kick, 0.0, delta * 9.0)


func _update_owner_view(delta: float) -> void:
	var weapon: WeaponData = get_active_weapon()
	var camera: Camera3D = _player.get_camera()
	# Recoil recovery once the weapon has had a moment to settle.
	if weapon != null and _recoil_debt.x > 0.0 and Time.get_ticks_msec() - _last_local_shot_msec > int(weapon.fire_interval * 1000.0) + 40:
		var step: float = minf(_recoil_debt.x, weapon.recoil_recovery * delta)
		_recoil_debt.x -= step
		_rotate_view(Vector2(-step, 0.0))
	var target_fov: float = weapon.aim_fov if aiming and weapon != null else _base_fov
	camera.fov = lerpf(camera.fov, target_fov, clampf(14.0 * delta, 0.0, 1.0))
	if _model == null:
		return
	var speed: float = _player.get_horizontal_speed()
	_bob_time += delta * lerpf(0.0, 9.0, clampf(speed / 4.0, 0.0, 1.0))
	var bob: Vector3 = Vector3(sin(_bob_time) * 0.008, absf(cos(_bob_time)) * 0.01, 0.0) * (0.25 if aiming else 1.0)
	var target: Vector3 = (AIM_POSITION - Vector3(0, WeaponModel.sight_height(weapon), 0) if aiming and weapon != null else HIP_POSITION) + bob
	target.z += _kick * (0.02 if aiming else 0.045)
	var tilt: float = 0.0
	if is_reloading():
		target.y -= 0.12
		tilt = -0.8
	target.y -= _draw_left / DRAW_SECONDS * 0.25
	if _player.is_sprinting:
		target += Vector3(-0.05, -0.05, 0.02)
		tilt = -0.35
	var weight: float = clampf(16.0 * delta, 0.0, 1.0)
	_model.position = _model.position.lerp(target, weight)
	_model.rotation.x = lerpf(_model.rotation.x, tilt + _kick * 0.08, weight)


func _on_loadout_replicated() -> void:
	if not is_node_ready():
		return
	if not has_weapon(active_slot):
		if _player.is_multiplayer_authority():
			for slot: int in [WeaponData.Slot.PRIMARY, WeaponData.Slot.SIDEARM]:
				if has_weapon(slot):
					active_slot = slot
					break
	_rebuild_model()
	loadout_changed.emit()


func _rebuild_model() -> void:
	if not is_node_ready() or DisplayServer.get_name() == "headless":
		return
	if _model != null:
		_model.queue_free()
		_model = null
	var weapon: WeaponData = get_active_weapon()
	if weapon == null:
		return
	var local: bool = _player.is_multiplayer_authority()
	_model = WeaponModel.build(weapon, 1)
	for child: Node in _model.get_children():
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh != null and local:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.position = HIP_POSITION if local else REMOTE_POSITION
	_player.get_camera().add_child(_model)


func _play_remote_fire(slot: int, ends: PackedVector3Array) -> void:
	var weapon: WeaponData = weapon_data(slot)
	if weapon != null:
		_play_shot_fx(weapon, ends, false)


func _play_shot_fx(weapon: WeaponData, ends: PackedVector3Array, local: bool) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var stream: AudioStreamWAV = WeaponAudio.gunshot(String(weapon.id), clampf(float(weapon.pellets - 1) / 8.0 + weapon.damage / 120.0, 0.0, 1.0))
	if local:
		_play_local(stream)
	else:
		_shot_player.global_position = _player.get_eye_position()
		_shot_player.stream = stream
		_shot_player.pitch_scale = _rng.randf_range(0.95, 1.05)
		_shot_player.play()
	var from: Vector3 = _model.muzzle.global_position if _model != null and _model.muzzle != null else _player.get_eye_position()
	var scene_root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	WeaponFx.muzzle_flash(scene_root, from)
	for end: Vector3 in ends:
		WeaponFx.tracer(scene_root, from, end)
		WeaponFx.impact(scene_root, end)


func _play_local(stream: AudioStream) -> void:
	if DisplayServer.get_name() == "headless" or _local_shot_player == null:
		return
	_local_shot_player.stream = stream
	_local_shot_player.pitch_scale = _rng.randf_range(0.96, 1.04)
	_local_shot_player.play()
