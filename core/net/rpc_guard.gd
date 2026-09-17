## Shared validation helpers for RPC handlers (ARCHITECTURE §4.3).
## Typical host-side guard:
##   if not RpcGuard.is_host(self): return
##   var sender: int = RpcGuard.sender_id(self)
##   if not RpcGuard.is_registered(sender) or not _limiter.allow(sender, &"interact"): return
## Authority: any (pure functions; each helper documents who should call it)
class_name RpcGuard
extends RefCounted

## Distance slack for host range checks (lean, latency, capsule radius).
const RANGE_TOLERANCE: float = 1.5


## True on the host. Every client → host intent handler must start with this.
static func is_host(node: Node) -> bool:
	return node.multiplayer.is_server()


## Peer that sent the RPC being handled. Local calls (host calling its own handler) return our id.
static func sender_id(node: Node) -> int:
	var sender: int = node.multiplayer.get_remote_sender_id()
	return sender if sender != 0 else node.multiplayer.get_unique_id()


## True when the RPC being handled came from the host (or is a local call on the host).
## Use in `any_peer` RPCs that only the host may send to an owner-authority node.
static func is_from_host(node: Node) -> bool:
	return sender_id(node) == 1


## True when the RPC came from `peer_id` (e.g. the owner of a player node).
static func is_from_peer(node: Node, peer_id: int) -> bool:
	return sender_id(node) == peer_id


## Registered in the lobby roster (always true offline).
static func is_registered(peer_id: int) -> bool:
	return not NetManager.is_online() or NetManager.roster.has(peer_id)


## Host: the sender's player exists and its eyes are within `max_distance` (+ tolerance) of `point`.
static func is_player_in_range(tree: SceneTree, peer_id: int, point: Vector3, max_distance: float) -> bool:
	var player: Player = Player.find_by_peer(tree, peer_id)
	if player == null:
		return false
	return player.get_eye_position().distance_to(point) <= max_distance + RANGE_TOLERANCE


## Logs a rejected request once per call site; keep reasons short and stable for grepping.
static func reject(context: String, peer_id: int, reason: String) -> void:
	if OS.is_debug_build():
		print_verbose("[RpcGuard] %s rejected peer %d: %s" % [context, peer_id, reason])
