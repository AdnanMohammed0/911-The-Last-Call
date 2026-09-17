## Salt Canister — deploys a salt line barrier that blocks anomaly movement (GAMEPLAY_MECHANICS §9).
## Single use, lasts 30 seconds. Authority: HOST (spawns barrier), OWNING PEER (input).
class_name SaltCanister
extends Node3D

signal salt_line_deployed(position: Vector3, direction: Vector3)
signal salt_line_expired()

@export var line_length: float = 4.0
@export var line_duration: float = 30.0
@export var barrier_height: float = 1.5
@export var barrier_thickness: float = 0.2
@export var deploy_range: float = 3.0
@export var cooldown: float = 1.0

var _owner: Player = null
var _last_deploy_msec: int = 0
var _active_line: Node = null


func _ready() -> void:
	_owner = get_parent() as Player


func _physics_process(delta: float) -> void:
	if _active_line != null and not is_instance_valid(_active_line):
		_active_line = null
		salt_line_expired.emit()


## Deploys a salt line in front of the player.
## Returns true if deployed successfully.
func deploy() -> bool:
	if not multiplayer.is_server():
		return false
	if _owner == null or not _owner.get_health().is_alive():
		return false
	
	var now: int = Time.get_ticks_msec()
	if now - _last_deploy_msec < cooldown * 1000:
		return false
	
	# Check if player has salt canister in loadout
	var loadout: Dictionary = LoadoutManager.get_player_loadout(_owner.peer_id)
	if not loadout.has(&"salt_canister") or loadout[&"salt_canister"] <= 0:
		return false
	
	# Consume one salt canister
	LoadoutManager.sell_gear(_owner.peer_id, &"salt_canister")
	
	var pos: Vector3 = global_position
	var dir: Vector3 = -global_basis.z
	var end_pos: Vector3 = pos + dir * line_length
	
	# Create the salt line barrier
	var line: Node = _create_salt_line(pos, end_pos)
	if line != null:
		_active_line = line
		_last_deploy_msec = now
		salt_line_deployed.emit(pos, dir)
		
		# Auto-remove after duration
		var timer: Timer = Timer.new()
		timer.wait_time = line_duration
		timer.one_shot = true
		timer.timeout.connect(func() -> void:
			if is_instance_valid(line):
				line.queue_free()
			salt_line_expired.emit()
		)
		add_child(timer)
		timer.start()
		
		return true
	
	return false


func _create_salt_line(start: Vector3, end: Vector3) -> Node:
	var line: Node3D = Node3D.new()
	line.name = "SaltLine"
	line.global_position = start
	line.look_at(end, Vector3.UP)
	add_child(line)
	
	# Visual: particle effect or mesh
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "SaltParticles"
	particles.emitting = true
	particles.amount = 50
	particles.lifetime = 1.0
	particles.one_shot = false
	particles.scale = Vector3(0.05, 0.05, 0.05)
	particles.local_coords = true
	particles.process_material = _make_particle_material()
	line.add_child(particles)
	
	# Collision barrier for anomalies
	var area: Area3D = Area3D.new()
	area.name = "SaltBarrier"
	area.monitorable = false
	area.monitoring = true
	area.collision_layer = 1
	area.collision_mask = 1 << 4  # anomaly layer
	area.add_to_group("salt_barriers")
	
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(end.distance_to(start), barrier_height, barrier_thickness)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)
	area.global_position = (start + end) * 0.5
	area.look_at(end, Vector3.UP)
	add_child(area)
	
	# Body entered: anomaly hits salt line
	area.body_entered.connect(_on_anomaly_hit_salt.bind(area))
	
	return line


func _make_particle_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = """
		shader_type particles;
		render_mode blend_add;
		
		uniform vec4 color : source_color = vec4(1.0, 0.95, 0.8, 0.8);
		uniform float size = 0.1;
		
		void vertex() {
			POINT_SIZE = size * (1.0 - LIFETIME);
			COLOR = color * (1.0 - LIFETIME);
			VELOCITY = vec3(0.0, 0.5, 0.0) + rand_from_seed(SEED) * 0.3;
		}
	"""
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	return mat


func _on_anomaly_hit_salt(barrier: Area3D, body: Node3D) -> void:
	if body.is_in_group("anomalies"):
		# Anomaly hit salt line - trigger retreat
		if body.has_method("on_reverse_tone_complete"):
			body.on_reverse_tone_complete()
		elif body.has_method("retreat"):
			body.retreat()
		# Visual feedback
		EventBus.noise_event.emit(barrier.global_position, 5.0, 0)