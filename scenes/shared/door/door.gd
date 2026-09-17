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

enum SoundType {
	OPEN = 0,
	CLOSE = 1,
	PEEK = 2,
	KICK = 3,
	LOCKED = 4,
	UNLOCK = 5,
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
@export var swing_speed: float = 5.0
@export var kick_speed: float = 18.0
@export var stun_radius: float = 2.5
## If true, the door opens to one fixed side only (realistic architectural stop).
@export var one_way_swing: bool = true
## Direction when one_way_swing is true: 1.0 (inwards / clockwise) or -1.0 (outwards).
@export var fixed_swing_direction: float = 1.0

@export_group("Audio (Optional)")
@export var sound_open: AudioStream
@export var sound_close: AudioStream
@export var sound_peek: AudioStream
@export var sound_kick: AudioStream
@export var sound_locked: AudioStream
@export var sound_unlock: AudioStream

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
	_update_target_angle()
	current_angle_deg = target_angle_deg
	if hinge:
		hinge.rotation_degrees.y = current_angle_deg


func _process(delta: float) -> void:
	if not hinge:
		return
	if is_equal_approx(current_angle_deg, target_angle_deg):
		current_angle_deg = target_angle_deg
		hinge.rotation_degrees.y = current_angle_deg
		return

	var smooth_rate: float = kick_speed if current_state == DoorState.KICKED else swing_speed
	var weight: float = 1.0 - exp(-smooth_rate * delta)
	current_angle_deg = lerpf(current_angle_deg, target_angle_deg, weight)

	if absf(current_angle_deg - target_angle_deg) < 0.05:
		current_angle_deg = target_angle_deg

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
		_broadcast_sound(SoundType.CLOSE)
		return

	if is_locked:
		locked_interacted.emit(peer_id)
		_broadcast_sound(SoundType.LOCKED)
		return

	# Calculate swing direction away from player
	swing_direction = _calculate_swing_direction(player_global_pos)
	_set_state(DoorState.OPEN)
	_broadcast_sound(SoundType.OPEN)


func _handle_peek(player_global_pos: Vector3, peer_id: int) -> void:
	if is_locked:
		locked_interacted.emit(peer_id)
		_broadcast_sound(SoundType.LOCKED)
		return

	if current_state == DoorState.PEEK:
		# If already peeked, close it
		_set_state(DoorState.CLOSED)
		_broadcast_sound(SoundType.CLOSE)
	elif current_state == DoorState.CLOSED:
		swing_direction = _calculate_swing_direction(player_global_pos)
		_set_state(DoorState.PEEK)
		_broadcast_sound(SoundType.PEEK)
	elif current_state == DoorState.OPEN:
		# Can pull back to peek
		_set_state(DoorState.PEEK)
		_broadcast_sound(SoundType.PEEK)


func _handle_kick(player_global_pos: Vector3, peer_id: int) -> void:
	if not can_be_kicked or is_reinforced:
		_broadcast_sound(SoundType.LOCKED)
		return

	var was_locked := is_locked
	is_locked = false # Kick breaks the latch
	swing_direction = _calculate_swing_direction(player_global_pos)
	_set_state(DoorState.KICKED)
	_broadcast_sound(SoundType.KICK)
	_trigger_kick_stun(peer_id)
	door_kicked.emit(peer_id, was_locked)


func _handle_unlock(peer_id: int) -> void:
	if is_locked:
		is_locked = false
		door_unlocked.emit(peer_id)
		_broadcast_sound(SoundType.UNLOCK)


# --- Utilities & Motion -----------------------------------------------------

## Calculates swing direction (+1 or -1). If one_way_swing is true, always returns fixed_swing_direction.
func _calculate_swing_direction(player_global_pos: Vector3) -> float:
	if one_way_swing:
		return fixed_swing_direction
	# Dynamic two-way swing: away from player's approach vector
	var door_pos: Vector3 = global_position if is_inside_tree() else position
	var door_basis: Basis = global_transform.basis if is_inside_tree() else transform.basis
	var to_player := (player_global_pos - door_pos).normalized()
	var forward := -door_basis.z
	var dot := forward.dot(to_player)
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


# --- Audio Playback ---------------------------------------------------------

func _broadcast_sound(type: SoundType) -> void:
	if is_inside_tree() and multiplayer != null and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_play_door_sound_rpc.rpc(type as int)
	else:
		_play_door_sound_rpc(type as int)


@rpc("authority", "call_local", "reliable")
func _play_door_sound_rpc(type_val: int) -> void:
	var stream: AudioStream = null
	match type_val as SoundType:
		SoundType.OPEN:
			stream = sound_open
		SoundType.CLOSE:
			stream = sound_close
		SoundType.PEEK:
			stream = sound_peek if sound_peek != null else sound_open
		SoundType.KICK:
			stream = sound_kick if sound_kick != null else sound_open
		SoundType.LOCKED:
			stream = sound_locked
		SoundType.UNLOCK:
			stream = sound_unlock
	_play_sound(stream)


func _play_sound(stream: AudioStream) -> void:
	if not audio_player or stream == null:
		return
	audio_player.stream = stream
	audio_player.play()
