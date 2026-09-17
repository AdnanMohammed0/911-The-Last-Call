## Host/join over ENet, peer lifecycle, player registration and the lobby roster.
## Authority: HOST (the roster is owned by the host and pushed to clients).
extends Node

enum Transport { ENET, STEAM }
enum State { OFFLINE, HOSTING, CONNECTING, CONNECTED }

const DEFAULT_PORT: int = 24911
const MAX_PEERS: int = 4                       # including the host
const MAX_NAME_LENGTH: int = 24
## Bump when the network protocol changes; mismatched clients are rejected.
const PROTOCOL_VERSION: int = 1
const CONNECT_TIMEOUT_SEC: float = 10.0
const REGISTER_TIMEOUT_SEC: float = 5.0
const MAIN_MENU_SCENE: String = "res://scenes/boot/main_menu.tscn"

signal state_changed(new_state: State)
## Host: server is up. Client: host accepted our registration.
signal session_started()
## The session ended for us (left, kicked, host gone). `reason` is empty on a voluntary leave.
signal session_ended(reason: String)
signal connection_failed(reason: String)
signal peer_joined(peer_id: int, player_name: String)
signal peer_left(peer_id: int)
signal lobby_updated(roster: Dictionary)

var transport: Transport = Transport.ENET
var state: State = State.OFFLINE
## peer_id -> { "name": String, "class_id": StringName, "ready": bool }
var roster: Dictionary[int, Dictionary] = {}
var local_player_name: String = ""

var _connect_timer: SceneTreeTimer = null


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


# --- Host / join / leave ----------------------------------------------------

func host_game(player_name: String, port: int = DEFAULT_PORT) -> Error:
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
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if roster.has(sender):
		return
	if protocol_version != PROTOCOL_VERSION:
		_kick(sender, "Version mismatch (host %d, you %d)" % [PROTOCOL_VERSION, protocol_version])
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
	peer_left.emit(peer_id)
	_sync_roster.rpc(roster)


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
	_connect_timer = null
	_set_state(State.OFFLINE)


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)


func _new_entry(player_name: String) -> Dictionary:
	return {"name": player_name, "class_id": &"", "ready": false}
