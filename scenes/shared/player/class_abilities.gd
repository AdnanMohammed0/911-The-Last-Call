## Field abilities. Owner sends only a slot; host checks class, health, range, inventory and cooldown.
class_name ClassAbilities
extends Node

const DRONE_LIFETIME_MS: int = 45000
const DRONE_COOLDOWN_MS: int = 120000
const MEGAPHONE_COOLDOWN_MS: int = 60000
const DOOR_REACH: float = 3.2

signal ability_used(slot: int, label: String)

var shield_raised: bool = false
var shield_hp: float = 600.0
var ram_uses: int = 3
var tone_uses: int = 2
var _tear_uses: int = 2
var _next_use: Dictionary[int, int] = {}
var _next_kick_msec: int = 0
var _player: Player
var _drone: Node3D = null
var _drone_started: int = 0
var _drone_origin: Vector3 = Vector3.ZERO
var _drone_forward: Vector3 = Vector3.FORWARD
var _drone_sync: float = 0.0
var _marked_until: Dictionary[NodePath, int] = {}
var _gas_until: int = 0
var _gas_position: Vector3 = Vector3.ZERO
var _gas_scan_clock: float = 0.0
var sedated_until_msec: int = 0
var _salt: SaltCanister = null
var _tone: SpectralToneEmitter = null


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		return
	if _player.class_id == &"medic":
		_salt = SaltCanister.new()
		_salt.name = "SaltCanister"
		add_child(_salt)
		_salt.salt_line_deployed.connect(_on_salt_line_deployed)
		_tone = SpectralToneEmitter.new()
		_tone.name = "SpectralToneEmitter"
		add_child(_tone)


func sample_input() -> void:
	if _player == null or not _player.is_multiplayer_authority() or not _player.get_health().is_alive():
		return
	for slot: int in 3:
		if Input.is_action_just_pressed(&"ability_%d" % (slot + 1)):
			request(slot)


func request(slot: int) -> void:
	if slot < 0 or slot > 2:
		return
	if multiplayer.is_server():
		host_use(slot)
	else:
		_request.rpc_id(1, slot)


@rpc("any_peer", "call_remote", "reliable")
func _request(slot: int) -> void:
	if multiplayer.is_server() and _player != null and multiplayer.get_remote_sender_id() == _player.peer_id \
			and RpcGuard.is_registered(_player.peer_id):
		host_use(slot)


func host_use(slot: int) -> bool:
	if not multiplayer.is_server() or _player == null or not _player.get_health().is_alive() or slot < 0 or slot > 2:
		return false
	if Time.get_ticks_msec() < _next_use.get(slot, 0):
		return false
	var used: bool = false
	match _player.class_id:
		&"tech":
			used = _tech(slot)
		&"profiler":
			used = _profiler(slot)
		&"breacher":
			used = _breacher(slot)
		&"medic":
			used = _medic(slot)
	if used:
		ability_used.emit(slot, ability_label(_player.class_id, slot))
	return used


static func ability_label(class_id: StringName, slot: int) -> String:
	match class_id:
		&"tech":
			return ["Recon drone", "Hack e-lock", ""].get(slot) if slot < 3 else ""
		&"profiler":
			return ["Megaphone", "Tear gas", ""].get(slot) if slot < 3 else ""
		&"breacher":
			return ["Ballistic shield", "Battering ram", ""].get(slot) if slot < 3 else ""
		&"medic":
			return ["Sedative", "Salt line", "Reverse tone"].get(slot) if slot < 3 else ""
	return ""


func _tech(slot: int) -> bool:
	if slot == 0:
		if _drone != null or not _has_gear(&"recon_drone"):
			return false
		_drone_started = Time.get_ticks_msec()
		_drone_origin = _player.global_position + Vector3.UP * 2.0
		_drone_forward = -_player.get_camera().global_basis.z
		_drone_forward.y = 0.0
		_drone_forward = _drone_forward.normalized()
		_spawn_drone.rpc(_drone_origin)
		_next_use[slot] = _drone_started + DRONE_COOLDOWN_MS
		return true
	if slot == 1:
		var door: Door = _find_door(_drone.global_position if _drone != null else _player.get_eye_position(), 3.0)
		if door == null or not door.is_locked or door.required_key_id == &"":
			return false
		door.interact(Door.DoorAction.UNLOCK, _player.global_position, _player.peer_id)
		_next_use[slot] = Time.get_ticks_msec() + 3000
		return true
	return false


func _profiler(slot: int) -> bool:
	if slot == 0:
		var affected: int = 0
		for node: Node in get_tree().get_nodes_in_group(HostileAgent.GROUP):
			var hostile: HostileAgent = node as HostileAgent
			if hostile != null and hostile.is_active() and hostile.global_position.distance_to(_player.global_position) <= 15.0:
				hostile.change_morale(-25.0, &"megaphone")
				hostile.demand_surrender(false, 2)
				affected += 1
		if affected == 0:
			return false
		EventBus.noise_event.emit(_player.global_position, 25.0, _player.peer_id)
		_next_use[slot] = Time.get_ticks_msec() + MEGAPHONE_COOLDOWN_MS
		return true
	if slot == 1:
		if _tear_uses <= 0 or not LoadoutManager.consume_gear(_player.peer_id, &"tear_gas"):
			return false
		_tear_uses -= 1
		_gas_position = _player.global_position - _player.get_camera().global_basis.z * 5.0
		_gas_until = Time.get_ticks_msec() + 8000
		_show_gas.rpc(_gas_position)
		_next_use[slot] = Time.get_ticks_msec() + 1000
		return true
	return false


func _breacher(slot: int) -> bool:
	if slot == 0:
		if shield_hp <= 0.0 or not _has_gear(&"ballistic_shield"):
			return false
		_set_shield.rpc(not shield_raised)
		return true
	if slot == 1:
		if ram_uses <= 0 or not _has_gear(&"battering_ram"):
			return false
		var door: Door = _find_door(_player.get_eye_position(), DOOR_REACH)
		if door == null or not door.is_reinforced:
			return false
		door.interact(Door.DoorAction.RAM, _player.global_position, _player.peer_id)
		ram_uses -= 1
		_next_use[slot] = Time.get_ticks_msec() + 3000
		return true
	return false


func _medic(slot: int) -> bool:
	if slot == 0:
		if _player.sanity >= _player.max_sanity or not LoadoutManager.consume_gear(_player.peer_id, &"sedatives"):
			return false
		_player.restore_sanity(35.0)
		_apply_sedative.rpc()
		_next_use[slot] = Time.get_ticks_msec() + 1000
		return true
	if slot == 1 and _salt != null:
		return _salt.deploy()
	if slot == 2 and _tone != null and tone_uses > 0 and _has_gear(&"spectral_tone_emitter"):
		if _tone.start_channel():
			tone_uses -= 1
			return true
	return false


@rpc("authority", "call_local", "reliable")
func _apply_sedative() -> void:
	sedated_until_msec = Time.get_ticks_msec() + 20000


func _has_gear(gear_id: StringName) -> bool:
	var loadout: Dictionary = LoadoutManager.get_player_loadout(_player.peer_id)
	return loadout.get(gear_id, 0) > 0


func _find_door(origin: Vector3, reach: float) -> Door:
	var to: Vector3 = origin - _player.get_camera().global_basis.z * reach
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, to, 1 | 8, [_player.get_rid()])
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Object = hit.get("collider", null)
	var node: Node = collider as Node
	while node != null and not node is Door:
		node = node.get_parent()
	return node as Door


func blocks_bullet(from: Vector3) -> bool:
	if not shield_raised or shield_hp <= 0.0 or from == Vector3.INF:
		return false
	var incoming: Vector3 = from - _player.global_position
	incoming.y = 0.0
	return incoming.length() > 0.1 and (-_player.global_basis.z).dot(incoming.normalized()) >= 0.5


func absorb_bullet(amount: float) -> void:
	shield_hp = maxf(shield_hp - amount, 0.0)
	if shield_hp <= 0.0:
		_set_shield.rpc(false)


func spend_kick() -> bool:
	if not multiplayer.is_server() or _player == null or _player.class_id != &"breacher" or not _player.get_health().is_alive():
		return false
	var now: int = Time.get_ticks_msec()
	if now < _next_kick_msec:
		return false
	_next_kick_msec = now + 4000
	return true


@rpc("authority", "call_local", "reliable")
func _set_shield(raised: bool) -> void:
	shield_raised = raised
	var old: MeshInstance3D = _player.get_node_or_null(^"ShieldVisual") as MeshInstance3D
	if old != null:
		old.queue_free()
	if not raised:
		return
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "ShieldVisual"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.8, 1.2, 0.08)
	mesh.mesh = box
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.22, 0.3, 0.65)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = material
	_player.add_child(mesh)
	mesh.position = Vector3(0.0, 1.0, -0.55)


@rpc("authority", "call_local", "reliable")
func _spawn_drone(at: Vector3) -> void:
	if _drone != null:
		_drone.queue_free()
	_drone = Node3D.new()
	_drone.name = "ReconDrone"
	add_child(_drone)
	_drone.top_level = true
	_drone.global_position = at
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var body: SphereMesh = SphereMesh.new()
	body.radius = 0.22
	body.height = 0.44
	mesh.mesh = body
	_drone.add_child(mesh)


@rpc("authority", "call_local", "unreliable")
func _move_drone(at: Vector3) -> void:
	if _drone != null:
		_drone.global_position = at


@rpc("authority", "call_local", "reliable")
func _remove_drone() -> void:
	if _drone != null:
		_drone.queue_free()
		_drone = null


func _process(delta: float) -> void:
	if not multiplayer.is_server() or _player == null:
		return
	if _drone != null:
		var elapsed: float = (Time.get_ticks_msec() - _drone_started) / 1000.0
		if elapsed >= 45.0:
			_remove_drone.rpc()
		else:
			var at: Vector3 = _drone_origin + _drone_forward * minf(elapsed * 2.0, 18.0)
			at += Vector3.UP * sin(elapsed * 2.0) * 0.25
			_drone.global_position = at
			_drone_sync += delta
			if _drone_sync >= 0.1:
				_drone_sync = 0.0
				_move_drone.rpc(at)
				for node: Node in get_tree().get_nodes_in_group(HostileAgent.GROUP):
					var hostile: HostileAgent = node as HostileAgent
					if hostile != null and hostile.is_active() and hostile.global_position.distance_to(at) <= 12.0:
						var path: NodePath = hostile.get_path()
						if Time.get_ticks_msec() >= _marked_until.get(path, 0):
							_marked_until[path] = Time.get_ticks_msec() + 10000
							_mark_enemy.rpc(path)
	if _gas_until > Time.get_ticks_msec():
		_gas_scan_clock += delta
		if _gas_scan_clock >= 0.2:
			_gas_scan_clock = 0.0
			for node: Node in get_tree().get_nodes_in_group(HostileAgent.GROUP):
				var hostile: HostileAgent = node as HostileAgent
				if hostile != null and hostile.global_position.distance_to(_gas_position) <= 6.0:
					hostile.gas_until_msec = _gas_until


@rpc("authority", "call_local", "reliable")
func _mark_enemy(path: NodePath) -> void:
	var hostile: Node3D = get_node_or_null(path) as Node3D
	if hostile == null:
		return
	var label: Label3D = Label3D.new()
	label.text = "MARKED"
	label.modulate = Color(1.0, 0.2, 0.18)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.2
	hostile.add_child(label)
	get_tree().create_timer(10.0).timeout.connect(func() -> void:
		if is_instance_valid(label):
			label.queue_free())


@rpc("authority", "call_local", "reliable")
func _show_gas(at: Vector3) -> void:
	var cloud: MeshInstance3D = MeshInstance3D.new()
	cloud.name = "TearGasCloud"
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 6.0
	sphere.height = 12.0
	cloud.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.65, 0.76, 0.62, 0.15)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud.material_override = material
	var world_parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	world_parent.add_child(cloud)
	cloud.global_position = at
	get_tree().create_timer(8.0).timeout.connect(func() -> void:
		if is_instance_valid(cloud):
			cloud.queue_free())


func _on_salt_line_deployed(at: Vector3, direction: Vector3) -> void:
	_show_salt.rpc(at, direction)


@rpc("authority", "call_remote", "reliable")
func _show_salt(at: Vector3, direction: Vector3) -> void:
	var stripe: MeshInstance3D = MeshInstance3D.new()
	stripe.name = "SaltLineVisual"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.18, 0.06, 4.0)
	stripe.mesh = box
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.92, 0.85)
	stripe.material_override = material
	var world_parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	world_parent.add_child(stripe)
	stripe.global_position = at + direction.normalized() * 2.0
	stripe.look_at(at + direction, Vector3.UP)
	get_tree().create_timer(30.0).timeout.connect(func() -> void:
		if is_instance_valid(stripe):
			stripe.queue_free())
