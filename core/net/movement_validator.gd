## Host-side sanity checks on client-authoritative movement (ARCHITECTURE §4.4):
## max speed x 1.2 over a sliding window, no flying, no teleports. On a violation the host rolls the
## player back (start of the window, or last valid position for teleports) and tells the owner.
## Co-op trade-off: other clients may briefly see the invalid position before the correction lands.
## Authority: HOST (validation) / OWNING PEER (applies corrections sent by the host)
class_name MovementValidator
extends Node

const SPEED_TOLERANCE: float = 1.2
## Speed is measured over this window so per-packet jitter averages out.
const WINDOW_SEC: float = 0.5
## Absorbs lag spikes / packet bunching (~0.8 s of stalled packets at sprint speed).
const SLACK_METERS: float = 1.5
## Above jump take-off speed (Player.jump_velocity 4.2).
const MAX_RISE_SPEED: float = 5.5
## A single update moving further than this is a teleport, whatever the timing.
const TELEPORT_DISTANCE: float = 5.0
const CORRECTION_ACCEPT_DISTANCE: float = 1.0
const CORRECTION_RESEND_SEC: float = 1.0
const HISTORY_KEEP_SEC: float = 2.0

signal violation(peer_id: int, reason: StringName, distance: float)

var violation_count: int = 0

var _history_positions: PackedVector3Array = PackedVector3Array()
var _history_msec: PackedInt64Array = PackedInt64Array()
var _correction_pending: bool = false
var _correction_sent_msec: int = 0

@onready var _player: Player = get_parent() as Player
@onready var _client_sync: MultiplayerSynchronizer = $"../ClientSync"


func _ready() -> void:
	_client_sync.synchronized.connect(_on_synchronized)
	_reset_history(_player.global_position)


## Host: call after a legitimate teleport (respawn, cutscene) so it is not flagged.
func reset_baseline(target_position: Vector3) -> void:
	_player.sync_position = target_position
	_player.global_position = target_position
	_reset_history(target_position)
	_correction_pending = false


func get_last_valid_position() -> Vector3:
	return _history_positions[_history_positions.size() - 1]


func _on_synchronized() -> void:
	if not multiplayer.is_server() or _player.is_multiplayer_authority():
		return
	var now: int = Time.get_ticks_msec()
	var reported: Vector3 = _player.sync_position
	var last_valid: Vector3 = get_last_valid_position()

	if _correction_pending:
		if reported.distance_to(last_valid) <= CORRECTION_ACCEPT_DISTANCE:
			_correction_pending = false
			_reset_history(reported)
		else:
			_player.sync_position = last_valid
			if now - _correction_sent_msec > int(CORRECTION_RESEND_SEC * 1000.0):
				_send_correction(now)
		return

	var reference_index: int = _reference_index(now)
	var reference: Vector3 = _history_positions[reference_index]
	var dt: float = maxf(float(now - _history_msec[reference_index]) / 1000.0, 1.0 / 60.0)
	var moved: Vector3 = reported - reference
	var horizontal: float = Vector2(moved.x, moved.z).length()
	var max_horizontal: float = _player.get_max_move_speed() * SPEED_TOLERANCE * dt + SLACK_METERS

	var reason: StringName = &""
	if reported.distance_to(last_valid) > TELEPORT_DISTANCE:
		reason = &"teleport"
	elif horizontal > max_horizontal:
		reason = &"speed"
	elif moved.y > MAX_RISE_SPEED * dt + SLACK_METERS:
		reason = &"fly"

	if reason == &"":
		_push_history(reported, now)
		return

	violation_count += 1
	violation.emit(_player.peer_id, reason, reported.distance_to(last_valid))
	RpcGuard.reject("movement", _player.peer_id, "%s (%.2f m over %.2f s)" % [reason, horizontal, dt])
	# Roll back to the start of the offending window, not just the previous sample, so repeated
	# small over-speed steps cannot add up.
	var rollback: Vector3 = reference if reason != &"teleport" else last_valid
	_reset_history(rollback)
	_player.sync_position = rollback
	_player.global_position = rollback
	_correction_pending = true
	_send_correction(now)


## The newest sample that is at least WINDOW_SEC old, or the oldest one we have.
func _reference_index(now: int) -> int:
	var window_msec: int = int(WINDOW_SEC * 1000.0)
	for i: int in range(_history_msec.size() - 1, -1, -1):
		if now - _history_msec[i] >= window_msec:
			return i
	return 0


func _push_history(point: Vector3, now: int) -> void:
	_history_positions.append(point)
	_history_msec.append(now)
	var keep_msec: int = int(HISTORY_KEEP_SEC * 1000.0)
	while _history_msec.size() > 2 and now - _history_msec[1] > keep_msec:
		_history_positions.remove_at(0)
		_history_msec.remove_at(0)


func _reset_history(point: Vector3) -> void:
	_history_positions = PackedVector3Array([point])
	_history_msec = PackedInt64Array([Time.get_ticks_msec()])


func _send_correction(now: int) -> void:
	_correction_sent_msec = now
	_apply_correction.rpc_id(_player.peer_id, get_last_valid_position())


## Owner: the host rejected our movement; snap back.
@rpc("any_peer", "call_remote", "reliable")
func _apply_correction(target_position: Vector3) -> void:
	if not RpcGuard.is_from_host(self) or not _player.is_multiplayer_authority():
		return
	_player.apply_server_correction(target_position)
