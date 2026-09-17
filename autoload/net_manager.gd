## Host/join over ENet, peer lifecycle, lobby roster (class selection, ready-up) and level-load handshake.
## Authority: HOST (the roster is owned by the host and pushed to clients).
extends Node

enum Transport { ENET, STEAM }
enum State { OFFLINE, HOSTING, CONNECTING, CONNECTED }

const DEFAULT_PORT: int = 24911
const MAX_PEERS: int = 4                       # including the host
const MAX_NAME_LENGTH: int = 24
## Bump when the network protocol changes; mismatched clients are rejected.
const PROTOCOL_VERSION: int = 2
const CONNECT_TIMEOUT_SEC: float = 10.0
const REGISTER_TIMEOUT_SEC: float = 5.0
const MAIN_MENU_SCENE: String = "res://scenes/boot/main_menu.tscn"
const MIN_PLAYERS_TO_START: int = 1

signal state_changed(new_state: State)
## Host: server is up. Client: host accepted our registration.
signal session_started()
## The session ended for us (left, kicked, host gone). `reason` is empty on a voluntary leave.
signal session_ended(reason: String)
signal connection_failed(reason: String)
signal peer_joined(peer_id: int, player_name: String)
signal peer_left(peer_id: int)
signal lobby_updated(roster: Dictionary)
## Every peer: `peer_id` finished loading `scene_path` and can receive spawns / sync for it.
signal level_loaded(peer_id: int, scene_path: String)
## Host: result of the UPnP port mapping. `public_address` is empty when unknown.
signal internet_hosting_changed(public_address: String, port_open: bool, message: String)

var transport: Transport = Transport.ENET
var state: State = State.OFFLINE
## peer_id -> { "name": String, "class_id": StringName, "ready": bool }
var roster: Dictionary[int, Dictionary] = {}
var local_player_name: String = ""

var _connect_timer: SceneTreeTimer = null
## peer_id -> scene path the peer reported as loaded (host-owned, mirrored to clients).
var _loaded_levels: Dictionary[int, String] = {}
var _limiter: RpcRateLimiter = RpcRateLimiter.new(8.0, 8.0)

## Internet hosting (UPnP). Public address as reported by the router.
var public_address: String = ""
var _upnp: UPNP = null
var _upnp_thread: Thread = null
var _upnp_port: int = 0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# --- Queries ----------------------------------------------------------------

func is_online() -> bool:
	return state == State.HOSTING or state == State.CONNECTED


func is_host() -> bool:
	return state == State.HOSTING


func get_local_peer_id() -> int:
	return multiplayer.get_unique_id()


func get_player_name(peer_id: int) -> String:
	var entry: Dictionary = roster.get(peer_id, {})
	var raw: Variant = entry.get("name", "Player %d" % peer_id)
	return str(raw)


func get_class_id(peer_id: int) -> StringName:
	var entry: Dictionary = roster.get(peer_id, {})
	var value: StringName = entry.get("class_id", &"")
	return value


func is_ready(peer_id: int) -> bool:
	var entry: Dictionary = roster.get(peer_id, {})
	var value: bool = entry.get("ready", false)
	return value


## True when a peer other than `except_peer` already picked `class_id`.
func is_class_taken(class_id: StringName, except_peer: int = 0) -> bool:
	for peer_id: int in roster:
		if peer_id != except_peer and get_class_id(peer_id) == class_id:
			return true
	return false


## Host: everyone has a class and is ready, and we are still in the lobby.
func can_start() -> bool:
	if not is_host() or not GameState.is_lobby() or roster.size() < MIN_PLAYERS_TO_START:
		return false
	for peer_id: int in roster:
		if not is_ready(peer_id) or get_class_id(peer_id) == &"":
			return false
	return true


func is_level_loaded(peer_id: int, scene_path: String) -> bool:
	return _loaded_levels.get(peer_id, "") == scene_path


# --- Host / join / leave ----------------------------------------------------

## `open_internet_port` asks the router (UPnP) to forward the UDP port so friends outside the LAN
## can join by public IP. Result arrives through `internet_hosting_changed`.
func host_game(player_name: String, port: int = DEFAULT_PORT, open_internet_port: bool = true) -> Error:
	if state != State.OFFLINE:
		return ERR_ALREADY_IN_USE
	if transport != Transport.ENET:
		return ERR_UNAVAILABLE  # TODO(P1-09): SteamMultiplayerPeer
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_PEERS)  # one spare slot so a 5th client gets a "Lobby is full" reason
	if err != OK:
		connection_failed.emit("Could not host on port %d (%s)" % [port, error_string(err)])
		return err
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	local_player_name = sanitize_name(player_name, 1)
	roster.clear()
	roster[1] = _new_entry(local_player_name)
	_set_state(State.HOSTING)
	if open_internet_port:
		_start_upnp(port)
	session_started.emit()
	lobby_updated.emit(roster)
	return OK


func join_game(address: String, player_name: String, port: int = DEFAULT_PORT) -> Error:
	if state != State.OFFLINE:
		return ERR_ALREADY_IN_USE
	address = address.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		connection_failed.emit("Could not connect to %s:%d (%s)" % [address, port, error_string(err)])
		return err
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	local_player_name = player_name
	roster.clear()
	_set_state(State.CONNECTING)
	_connect_timer = get_tree().create_timer(CONNECT_TIMEOUT_SEC)
	_connect_timer.timeout.connect(_on_connect_timeout.bind(_connect_timer))
	return OK


## Voluntarily leave (or stop hosting). Does not change scene.
func leave_game() -> void:
	var was_online: bool = state != State.OFFLINE
	_close_peer()
	if was_online:
		session_ended.emit("")


# --- Lobby (any peer; the host validates) ----------------------------------

## Pick a class (&"" clears it). Refused by the host while ready or if another player has it.
func select_class(class_id: StringName) -> void:
	_send_to_host(&"_request_class", [class_id])


func set_ready(ready: bool) -> void:
	_send_to_host(&"_request_ready", [ready])


## Host: move every peer into the field level. Players spawn once each peer reports it loaded.
func start_game(scene_path: String) -> Error:
	if not can_start():
		return ERR_UNCONFIGURED
	if not ResourceLoader.exists(scene_path):
		return ERR_FILE_NOT_FOUND
	_loaded_levels.clear()
	GameState.change_phase.rpc(GameState.Phase.FIELD, scene_path)
	return OK


## Called by a level (PlayerSpawner) on every peer once its scene is in the tree.
func report_level_loaded(scene_path: String) -> void:
	_send_to_host(&"_report_level_loaded", [scene_path])


static func sanitize_name(raw: String, peer_id: int) -> String:
	var clean: String = ""
	for c: String in raw.strip_edges():
		if c.unicode_at(0) >= 32:
			clean += c
	clean = clean.strip_edges().left(MAX_NAME_LENGTH)
	return clean if not clean.is_empty() else "Player %d" % peer_id


# --- RPCs -------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _register_player(player_name: String, protocol_version: int) -> void:
	if not RpcGuard.is_host(self):
		return
	var sender: int = RpcGuard.sender_id(self)
	if roster.has(sender):
		return
	if protocol_version != PROTOCOL_VERSION:
		_kick(sender, "Version mismatch (host %d, you %d)" % [PROTOCOL_VERSION, protocol_version])
		return
	if not GameState.is_lobby():
		_kick(sender, "Game already in progress")  # TODO(P1-10): spectator slot
		return
	if roster.size() >= MAX_PEERS:
		_kick(sender, "Lobby is full")
		return
	# TODO(P1-10): late-join policy (spectator during FIELD phase, reserved slots).
	var clean_name: String = sanitize_name(player_name, sender)
	roster[sender] = _new_entry(clean_name)
	_accept_registration.rpc_id(sender)
	_sync_roster.rpc(roster)
	peer_joined.emit(sender, clean_name)


@rpc("any_peer", "call_remote", "reliable")
func _request_class(class_id: StringName) -> void:
	if not RpcGuard.is_host(self):
		return
	var sender: int = RpcGuard.sender_id(self)
	if not _limiter.allow(sender, &"lobby"):
		return
	if not roster.has(sender) or not GameState.is_lobby() or is_ready(sender):
		return
	if class_id != &"" and (not ClassCatalog.has(class_id) or is_class_taken(class_id, sender)):
		_sync_roster.rpc(roster)  # re-sync so the requester's UI snaps back
		return
	roster[sender]["class_id"] = class_id
	_sync_roster.rpc(roster)


@rpc("any_peer", "call_remote", "reliable")
func _request_ready(ready: bool) -> void:
	if not RpcGuard.is_host(self):
		return
	var sender: int = RpcGuard.sender_id(self)
	if not _limiter.allow(sender, &"lobby"):
		return
	if not roster.has(sender) or not GameState.is_lobby():
		return
	if ready and get_class_id(sender) == &"":
		return
	roster[sender]["ready"] = ready
	_sync_roster.rpc(roster)


@rpc("any_peer", "call_remote", "reliable")
func _report_level_loaded(scene_path: String) -> void:
	if not RpcGuard.is_host(self):
		return
	var sender: int = RpcGuard.sender_id(self)
	if not RpcGuard.is_registered(sender) or not scene_path.begins_with("res://"):
		return
	_loaded_levels[sender] = scene_path
	if is_online():
		_sync_loaded_levels.rpc(_loaded_levels)
	level_loaded.emit(sender, scene_path)


@rpc("authority", "call_remote", "reliable")
func _sync_loaded_levels(levels: Dictionary) -> void:
	var previous: Dictionary[int, String] = _loaded_levels.duplicate()
	_loaded_levels.clear()
	for key: Variant in levels:
		var peer_id: int = key
		var path: String = levels[key]
		_loaded_levels[peer_id] = path
	for peer_id: int in _loaded_levels:
		if previous.get(peer_id, "") != _loaded_levels[peer_id]:
			level_loaded.emit(peer_id, _loaded_levels[peer_id])


@rpc("authority", "call_remote", "reliable")
func _accept_registration() -> void:
	if state != State.CONNECTING:
		return
	_connect_timer = null
	_set_state(State.CONNECTED)
	session_started.emit()


@rpc("authority", "call_remote", "reliable")
func _rejected(reason: String) -> void:
	_close_peer()
	connection_failed.emit(reason)


@rpc("authority", "call_local", "reliable")
func _sync_roster(new_roster: Dictionary) -> void:
	if multiplayer.is_server():
		lobby_updated.emit(roster)
		return
	var previous: Dictionary[int, Dictionary] = roster.duplicate()
	roster.clear()
	for key: Variant in new_roster:
		var pid: int = key
		var entry: Dictionary = new_roster[key]
		roster[pid] = entry
	for peer_id: int in roster:
		if not previous.has(peer_id) and peer_id != multiplayer.get_unique_id():
			peer_joined.emit(peer_id, get_player_name(peer_id))
	for peer_id: int in previous:
		if not roster.has(peer_id):
			peer_left.emit(peer_id)
	lobby_updated.emit(roster)


# --- Multiplayer callbacks --------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	# Drop peers that connect but never register (wrong game, stuck client).
	await get_tree().create_timer(REGISTER_TIMEOUT_SEC).timeout
	if state == State.HOSTING and not roster.has(peer_id) \
			and peer_id in multiplayer.get_peers():
		_kick(peer_id, "Registration timed out")


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server() or not roster.has(peer_id):
		return
	roster.erase(peer_id)
	_loaded_levels.erase(peer_id)
	_limiter.forget_peer(peer_id)
	peer_left.emit(peer_id)
	_sync_roster.rpc(roster)
	_sync_loaded_levels.rpc(_loaded_levels)


func _on_connected_to_server() -> void:
	_register_player.rpc_id(1, local_player_name, PROTOCOL_VERSION)


func _on_connection_failed() -> void:
	_close_peer()
	connection_failed.emit("Could not reach the host")


func _on_connect_timeout(timer: SceneTreeTimer) -> void:
	if state == State.CONNECTING and timer == _connect_timer:
		_close_peer()
		connection_failed.emit("Connection timed out")


func _on_server_disconnected() -> void:
	_close_peer()
	session_ended.emit("Host closed the session")
	# TODO(P1-10): campaign-safe return + reconnect slot.
	if ResourceLoader.exists(MAIN_MENU_SCENE):
		get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)


# --- Internals --------------------------------------------------------------

func _kick(peer_id: int, reason: String) -> void:
	_rejected.rpc_id(peer_id, reason)
	# Give the reliable packet a moment to leave before dropping the peer.
	await get_tree().create_timer(0.2).timeout
	var peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer != null and peer_id in multiplayer.get_peers():
		peer.disconnect_peer(peer_id)


func _close_peer() -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	roster.clear()
	_loaded_levels.clear()
	_connect_timer = null
	_stop_upnp()
	GameState.reset()
	_set_state(State.OFFLINE)


func _send_to_host(method: StringName, args: Array = []) -> void:
	if multiplayer.is_server():
		callv(method, args)
	else:
		callv(&"rpc_id", [1, method] + args)


# --- Internet hosting (UPnP) -------------------------------------------------

func _start_upnp(port: int) -> void:
	if _upnp_thread != null:
		return
	_upnp_port = port
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_worker.bind(port))


func _upnp_worker(port: int) -> void:
	var upnp: UPNP = UPNP.new()
	var discover_err: int = upnp.discover(2000, 2, "InternetGatewayDevice")
	if discover_err != UPNP.UPNP_RESULT_SUCCESS or upnp.get_gateway() == null \
			or not upnp.get_gateway().is_valid_gateway():
		_on_upnp_finished.call_deferred(null, "", false,
			"No UPnP router found. Forward UDP %d manually or use a VPN (Tailscale / ZeroTier / Radmin)." % port)
		return
	var map_err: int = upnp.add_port_mapping(port, port, "911 The Last Call", "UDP", 0)
	var external: String = upnp.query_external_address()
	if map_err != UPNP.UPNP_RESULT_SUCCESS:
		_on_upnp_finished.call_deferred(upnp, external, false,
			"Router refused UPnP mapping (error %d). Forward UDP %d manually or use a VPN." % [map_err, port])
		return
	var message: String = "Friends join with %s (UDP %d open)." % [external, port]
	if is_unreachable_address(external):
		message = "Router IP %s is behind the ISP NAT (CGNAT): internet players cannot reach it. Use a VPN (Tailscale / ZeroTier / Radmin) or Steam (P1-09)." % external
	_on_upnp_finished.call_deferred(upnp, external, true, message)


func _on_upnp_finished(upnp: UPNP, external: String, mapped: bool, message: String) -> void:
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if state != State.HOSTING:
		if upnp != null and mapped:
			upnp.delete_port_mapping(_upnp_port, "UDP")
		return
	_upnp = upnp if mapped else null
	public_address = external
	internet_hosting_changed.emit(external, mapped and not is_unreachable_address(external), message)


func _stop_upnp() -> void:
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if _upnp != null:
		_upnp.delete_port_mapping(_upnp_port, "UDP")
		_upnp = null
	public_address = ""


## Private (RFC 1918) and carrier-grade NAT (100.64.0.0/10) addresses cannot be reached from the internet.
static func is_unreachable_address(address: String) -> bool:
	var parts: PackedStringArray = address.split(".")
	if parts.size() != 4:
		return false
	var a: int = parts[0].to_int()
	var b: int = parts[1].to_int()
	return a == 10 or (a == 100 and b >= 64 and b <= 127) or (a == 172 and b >= 16 and b <= 31) \
		or (a == 192 and b == 168)


func _exit_tree() -> void:
	_stop_upnp()


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)


func _new_entry(player_name: String) -> Dictionary:
	return {"name": player_name, "class_id": &"", "ready": false}
