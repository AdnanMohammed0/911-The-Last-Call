## Host-side position history for hit targets (ARCHITECTURE §4.4: "host re-casts the ray using the peer's
## last synced transform, ±150 ms lag compensation buffer"). Every physics frame the host records the feet
## position of each node in GROUP; `position_at` interpolates where a target was at a past time.
## Authority: HOST
extends Node

const GROUP: StringName = &"lag_compensated"
const HISTORY_MSEC: int = 1000
## Clients render remote targets roughly this far in the past (sync interval + smoothing).
const INTERPOLATION_DELAY_MSEC: int = 100
const MAX_REWIND_MSEC: int = 300

## Debug / A-B testing switch: false resolves every shot against current positions.
var enabled: bool = true

## instance id -> Array of [msec: int, position: Vector3]
var _history: Dictionary[int, Array] = {}


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	var now: int = Time.get_ticks_msec()
	var alive: Dictionary[int, bool] = {}
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var target: Node3D = node as Node3D
		if target == null:
			continue
		var id: int = target.get_instance_id()
		alive[id] = true
		var samples: Array = _history.get(id, [])
		samples.append([now, target.global_position])
		while samples.size() > 2:
			var oldest: Array = samples[1]
			var oldest_msec: int = oldest[0]
			if now - oldest_msec <= HISTORY_MSEC:
				break
			samples.pop_front()
		_history[id] = samples
	for id: int in _history.keys():
		if not alive.has(id):
			_history.erase(id)


## How far back to rewind for a shot from `peer_id` (half the round trip + client interpolation).
func rewind_msec_for(peer_id: int) -> int:
	if peer_id == multiplayer.get_unique_id():
		return 0
	var rtt: int = 0
	var peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer != null:
		var packet_peer: ENetPacketPeer = peer.get_peer(peer_id)
		if packet_peer != null:
			var round_trip: float = packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
			rtt = int(round_trip)
	return clampi(rtt / 2 + INTERPOLATION_DELAY_MSEC, 0, MAX_REWIND_MSEC)


## Where `target` was `rewind_msec` ago (its current position when there is no history).
func position_at(target: Node3D, rewind_msec: int) -> Vector3:
	var samples: Array = _history.get(target.get_instance_id(), [])
	if samples.is_empty() or rewind_msec <= 0 or not enabled:
		return target.global_position
	var when: int = Time.get_ticks_msec() - rewind_msec
	for i: int in range(samples.size() - 1, -1, -1):
		var sample: Array = samples[i]
		var sample_msec: int = sample[0]
		if sample_msec <= when:
			var position: Vector3 = sample[1]
			if i + 1 < samples.size():
				var next: Array = samples[i + 1]
				var next_msec: int = next[0]
				var next_position: Vector3 = next[1]
				var t: float = float(when - sample_msec) / maxf(float(next_msec - sample_msec), 1.0)
				return position.lerp(next_position, clampf(t, 0.0, 1.0))
			return position
	var first: Array = samples[0]
	var first_position: Vector3 = first[1]
	return first_position
