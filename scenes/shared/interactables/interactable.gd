## Base class for anything a player can use: press (hold_duration = 0) or hold-to-interact.
## Give it a CollisionShape3D child; the PlayerInteractor raycast finds it on the interactable layer.
## Subclasses override `_can_interact` / `_on_interact` (host logic) and `_on_interacted` (all peers).
## Authority: HOST (clients send intents; the host validates and broadcasts the result).
class_name Interactable
extends Area3D

const LAYER: int = 1 << 3                  # physics layer 4 "interactable"
const HOLD_TOLERANCE_SEC: float = 0.25     # latency slack when validating hold time
const HOLD_STALE_SEC: float = 2.0          # a hold with no completion is released after this

## Emitted on every peer once the host confirmed the interaction.
signal interacted(peer_id: int)
## Emitted on every peer when a hold starts (peer_id > 0) or is released (peer_id = 0).
signal holder_changed(peer_id: int)

@export var prompt_text: String = "Interact"
## 0 = press to interact. Otherwise seconds the interact key must be held.
@export_range(0.0, 10.0, 0.1, "suffix:s") var hold_duration: float = 0.0
@export var max_distance: float = 2.5
@export var enabled: bool = true
@export var single_use: bool = false
@export_range(0.0, 5.0, 0.05, "suffix:s") var cooldown: float = 0.25

## Peer currently holding this interactable (0 = nobody).
var holder_peer: int = 0

var _hold_started_msec: int = 0
var _last_use_msec: int = -1_000_000
var _limiter: RpcRateLimiter = RpcRateLimiter.new(10.0, 6.0)


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false


# --- Queries (any peer) -----------------------------------------------------

func get_prompt_text() -> String:
	return prompt_text


func is_hold() -> bool:
	return hold_duration > 0.0


## Seconds `peer_id` must hold (subclasses vary it, e.g. Medic revives faster).
func get_hold_duration_for(_peer_id: int) -> float:
	return hold_duration


func is_available_to(peer_id: int) -> bool:
	return enabled and (holder_peer == 0 or holder_peer == peer_id or _is_hold_stale())


# --- Client API -------------------------------------------------------------

func request_interact() -> void:
	_send_to_host(&"_rpc_interact")


func request_hold_start() -> void:
	_send_to_host(&"_rpc_hold_start")


func request_hold_cancel() -> void:
	_send_to_host(&"_rpc_hold_cancel")


# --- Virtuals ---------------------------------------------------------------

## Host only. Extra gameplay checks (locked, wrong class, phase…).
func _can_interact(_peer_id: int) -> bool:
	return true


## Host only. Authoritative gameplay effects (FlagSystem, spawning, damage…).
func _on_interact(_peer_id: int) -> void:
	pass


## Every peer. Deterministic state + cosmetics that follow a confirmed interaction.
func _on_interacted(_peer_id: int) -> void:
	pass


# --- Networking -------------------------------------------------------------

func _send_to_host(method: StringName) -> void:
	if multiplayer.is_server():
		call(method)
	else:
		rpc_id(1, method)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hold_start() -> void:
	if not RpcGuard.is_host(self):
		return
	var sender: int = RpcGuard.sender_id(self)
	if not _limiter.allow(sender):
		return
	if not is_hold() or not _validate(sender):
		return
	_hold_started_msec = Time.get_ticks_msec()
	_set_holder.rpc(sender)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hold_cancel() -> void:
	if not RpcGuard.is_host(self):
		return
	if holder_peer != 0 and holder_peer == RpcGuard.sender_id(self):
		_set_holder.rpc(0)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_interact() -> void:
	if not RpcGuard.is_host(self):
		return
	var sender: int = RpcGuard.sender_id(self)
	if not _limiter.allow(sender):
		return
	if not _validate(sender):
		return
	var now: int = Time.get_ticks_msec()
	if is_hold():
		if holder_peer != sender:
			return
		if now - _hold_started_msec < int((get_hold_duration_for(sender) - HOLD_TOLERANCE_SEC) * 1000.0):
			return
	if now - _last_use_msec < int(cooldown * 1000.0):
		return
	if not _can_interact(sender):
		return
	_last_use_msec = now
	_on_interact(sender)
	_confirm_interact.rpc(sender)


@rpc("authority", "call_local", "reliable")
func _set_holder(peer_id: int) -> void:
	holder_peer = peer_id
	holder_changed.emit(peer_id)


@rpc("authority", "call_local", "reliable")
func _confirm_interact(peer_id: int) -> void:
	if holder_peer != 0:
		holder_peer = 0
		holder_changed.emit(0)
	if single_use:
		enabled = false
	_on_interacted(peer_id)
	interacted.emit(peer_id)
	EventBus.interacted.emit(self, peer_id)


func _validate(sender: int) -> bool:
	if not is_available_to(sender):
		return false
	return RpcGuard.is_registered(sender) \
		and RpcGuard.is_player_in_range(get_tree(), sender, global_position, max_distance)


func _is_hold_stale() -> bool:
	return holder_peer != 0 \
		and Time.get_ticks_msec() - _hold_started_msec > int((hold_duration + HOLD_STALE_SEC) * 1000.0)
