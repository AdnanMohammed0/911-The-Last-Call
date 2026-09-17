## Interactive, networked door system supporting open/close, peek (15° crack), kick breach, and locking.
## Authority: HOST (server-authoritative state machine; clients send request_interact RPC).
class_name Door
extends Node3D

enum DoorState {
	CLOSED = 0,
	PEEK = 1,
	OPEN = 2,
	KICKED = 3,
}

enum DoorAction {
	TOGGLE_OPEN = 0,
	PEEK = 1,
	KICK = 2,
	UNLOCK = 3,
}

signal state_changed(new_state: DoorState, old_state: DoorState)
signal locked_interacted(peer_id: int)
signal door_kicked(by_peer: int, was_locked: bool)
signal door_unlocked(by_peer: int)

@export_group("Door Settings")
@export var is_locked: bool = false
@export var required_key_id: StringName = &""
@export var can_be_kicked: bool = true
@export var is_reinforced: bool = false
@export var max_interaction_distance: float = 3.2

@export_group("Angles & Motion")
@export var open_angle_deg: float = 90.0
@export var peek_angle_deg: float = 15.0
@export var swing_speed: float = 4.0
@export var kick_speed: float = 16.0
@export var stun_radius: float = 2.5

# Replicated properties (MultiplayerSynchronizer)
@export var current_state: DoorState = DoorState.CLOSED:
	set(value):
		var old := current_state
		current_state = value
		_update_target_angle()
		if old != value:
			state_changed.emit(value, old)

@export var swing_direction: float = 1.0: # 1.0 = forward/clockwise, -1.0 = backward
	set(value):
		swing_direction = value
		_update_target_angle()

@export var target_angle_deg: float = 0.0

var current_angle_deg: float = 0.0

@onready var hinge: Node3D = $Hinge
@onready var leaf_body: AnimatableBody3D = $Hinge/DoorLeaf
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var stun_area: Area3D = $StunArea3D
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer


func _ready() -> void:
	_setup_audio_samples()
	_update_target_angle()
	current_angle_deg = target_angle_deg
	if hinge:
		hinge.rotation_degrees.y = current_angle_deg


func _process(delta: float) -> void:
	if not hinge:
		return
	var speed := kick_speed if current_state == DoorState.KICKED else swing_speed
	var step := deg_to_rad(speed * 45.0 * delta)
	var current_rad := deg_to_rad(current_angle_deg)
	var target_rad := deg_to_rad(target_angle_deg)

	if not is_equal_approx(current_rad, target_rad):
		current_rad = move_toward(current_rad, target_rad, step)
		current_angle_deg = rad_to_deg(current_rad)
		hinge.rotation_degrees.y = current_angle_deg


# --- Interaction API --------------------------------------------------------

## Called by local player or AI to perform an action on the door.
func interact(action: DoorAction, player_global_pos: Vector3, peer_id: int = 1) -> void:
	if is_inside_tree() and multiplayer != null and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		# Client: send RPC request to host
		request_interact.rpc_id(1, action, player_global_pos)
		return

	# Server or Standalone mode: execute locally
	_execute_interaction(action, player_global_pos, peer_id)


@rpc("any_peer", "call_remote", "reliable")
func request_interact(action: int, player_global_pos: Vector3) -> void:
	# Host validation rule (ARCHITECTURE §4.3)
	if multiplayer != null and not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id() if multiplayer != null and multiplayer.has_multiplayer_peer() else 1
	var door_pos: Vector3 = global_position if is_inside_tree() else position
	if door_pos.distance_to(player_global_pos) > max_interaction_distance:
		return

	_execute_interaction(action as DoorAction, player_global_pos, sender_id)


func _execute_interaction(action: DoorAction, player_global_pos: Vector3, peer_id: int) -> void:
	match action:
		DoorAction.TOGGLE_OPEN:
			_handle_toggle_open(player_global_pos, peer_id)
		DoorAction.PEEK:
			_handle_peek(player_global_pos, peer_id)
		DoorAction.KICK:
			_handle_kick(player_global_pos, peer_id)
		DoorAction.UNLOCK:
			_handle_unlock(peer_id)


func _handle_toggle_open(player_global_pos: Vector3, peer_id: int) -> void:
	if current_state != DoorState.CLOSED:
		# If open or peeked, close it
		_set_state(DoorState.CLOSED)
		_play_sound(&"close")
		return

	if is_locked:
		locked_interacted.emit(peer_id)
		_play_sound(&"rattle_locked")
		return

	# Calculate swing direction away from player
	swing_direction = _calculate_swing_direction(player_global_pos)
	_set_state(DoorState.OPEN)
	_play_sound(&"open")


func _handle_peek(player_global_pos: Vector3, peer_id: int) -> void:
	if is_locked:
		locked_interacted.emit(peer_id)
		_play_sound(&"rattle_locked")
		return

	if current_state == DoorState.PEEK:
		# If already peeked, close it
		_set_state(DoorState.CLOSED)
		_play_sound(&"close")
	elif current_state == DoorState.CLOSED:
		swing_direction = _calculate_swing_direction(player_global_pos)
		_set_state(DoorState.PEEK)
		_play_sound(&"creak_peek")
	elif current_state == DoorState.OPEN:
		# Can pull back to peek
		_set_state(DoorState.PEEK)
		_play_sound(&"creak_peek")


func _handle_kick(player_global_pos: Vector3, peer_id: int) -> void:
	if not can_be_kicked:
		_play_sound(&"kick_fail")
		return

	if is_reinforced:
		# Reinforced doors need battering ram (GAMEPLAY_MECHANICS §2)
		_play_sound(&"kick_fail")
		return

	var was_locked := is_locked
	is_locked = false # Kick breaks the latch
	swing_direction = _calculate_swing_direction(player_global_pos)
	_set_state(DoorState.KICKED)
	_play_sound(&"kick_slam")
	_trigger_kick_stun(peer_id)
	door_kicked.emit(peer_id, was_locked)


func _handle_unlock(peer_id: int) -> void:
	if is_locked:
		is_locked = false
		door_unlocked.emit(peer_id)
		_play_sound(&"unlock")


# --- Utilities & Motion -----------------------------------------------------

## Calculates swing direction (+1 or -1) so the door swings away from the interacting player.
func _calculate_swing_direction(player_global_pos: Vector3) -> float:
	# Local z points backwards in Godot. -basis.z points towards front of the door.
	var door_pos: Vector3 = global_position if is_inside_tree() else position
	var door_basis: Basis = global_transform.basis if is_inside_tree() else transform.basis
	var to_player := (player_global_pos - door_pos).normalized()
	var forward := -door_basis.z
	var dot := forward.dot(to_player)
	# If player is in front (dot > 0), swing into back (+1.0)
	# If player is in back (dot <= 0), swing towards front (-1.0)
	return 1.0 if dot >= 0.0 else -1.0


func _update_target_angle() -> void:
	match current_state:
		DoorState.CLOSED:
			target_angle_deg = 0.0
		DoorState.PEEK:
			target_angle_deg = swing_direction * peek_angle_deg
		DoorState.OPEN, DoorState.KICKED:
			target_angle_deg = swing_direction * open_angle_deg


func _set_state(new_state: DoorState) -> void:
	current_state = new_state


func _trigger_kick_stun(peer_id: int) -> void:
	if not stun_area:
		return
	# Query overlapping bodies in stun area
	var bodies := stun_area.get_overlapping_bodies()
	for body in bodies:
		if body == self or body == leaf_body:
			continue
		# If an enemy or entity has a stun or take_damage method, call it
		if body.has_method(&"apply_stun"):
			body.call(&"apply_stun", 1.5, peer_id)
		elif body.has_method(&"stun"):
			body.call(&"stun", 1.5)


func get_prompt_text() -> String:
	if is_locked:
		return "[F] Locked   [V] Kick"
	match current_state:
		DoorState.CLOSED:
			return "[F] Open   [C] Peek   [V] Kick"
		DoorState.PEEK:
			return "[F] Close   [C] Push Open   [V] Kick"
		DoorState.OPEN, DoorState.KICKED:
			return "[F] Close"
	return ""


# --- Procedural Audio -------------------------------------------------------

var _audio_streams: Dictionary = {}

func _setup_audio_samples() -> void:
	_audio_streams[&"open"] = _generate_tone_wav(180.0, 0.25, 0.4, 0.0)
	_audio_streams[&"close"] = _generate_tone_wav(120.0, 0.2, 0.6, 0.0)
	_audio_streams[&"creak_peek"] = _generate_tone_wav(320.0, 0.35, 0.2, 0.5)
	_audio_streams[&"kick_slam"] = _generate_tone_wav(80.0, 0.45, 1.0, 0.8)
	_audio_streams[&"kick_fail"] = _generate_tone_wav(95.0, 0.25, 0.7, 0.3)
	_audio_streams[&"rattle_locked"] = _generate_tone_wav(400.0, 0.15, 0.5, 0.2)
	_audio_streams[&"unlock"] = _generate_tone_wav(520.0, 0.12, 0.5, 0.0)


func _play_sound(sound_name: StringName) -> void:
	if not audio_player or not _audio_streams.has(sound_name):
		return
	audio_player.stream = _audio_streams[sound_name]
	audio_player.play()


func _generate_tone_wav(base_freq: float, duration: float, volume: float, noise_mix: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var total_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(total_samples)

	for i in range(total_samples):
		var t := float(i) / float(sample_rate)
		var envelope := 1.0 - (float(i) / float(total_samples))
		var tone := sin(2.0 * PI * base_freq * t)
		var noise := (randf() * 2.0 - 1.0) * noise_mix
		var sample_val := clampf((tone * (1.0 - noise_mix) + noise) * volume * envelope, -1.0, 1.0)
		# 8-bit unsigned PCM: 0..255, center 128
		data[i] = int(clampf(sample_val * 127.0 + 128.0, 0.0, 255.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav
