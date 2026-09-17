## Host/join, peer lifecycle, lobby roster and transport selection.
## Authority: HOST (the roster is owned by the host and pushed to clients).
extends Node

enum Transport { ENET, STEAM }

const DEFAULT_PORT: int = 24911
const MAX_PEERS: int = 4
const MAX_NAME_LENGTH: int = 24
const MAIN_MENU_SCENE: String = "res://scenes/boot/main_menu.tscn"

signal lobby_updated(roster: Dictionary)
signal connection_failed(reason: String)

var transport: Transport = Transport.ENET
## peer_id -> { "name": String, "class_id": StringName, "ready": bool }
var roster: Dictionary[int, Dictionary] = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_online() -> bool:
	return multiplayer.multiplayer_peer != null \
		and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


func host_game(_player_name: String) -> Error:
	# TODO(P1-04): create ENet server on DEFAULT_PORT, register host in roster.
	return ERR_UNAVAILABLE


func join_game(_address: String, _player_name: String) -> Error:
	# TODO(P1-04): create ENet client and call _register_player on connect.
	return ERR_UNAVAILABLE


func leave_game() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	roster.clear()


func _on_peer_connected(_id: int) -> void:
	pass  # TODO(P1-04): wait for _register_player


func _on_peer_disconnected(_id: int) -> void:
	pass  # TODO(P1-04/P1-10): remove from roster and resync


func _on_connection_failed() -> void:
	connection_failed.emit("Connection failed")


func _on_server_disconnected() -> void:
	leave_game()
	if ResourceLoader.exists(MAIN_MENU_SCENE):
		get_tree().change_scene_to_file.call_deferred(MAIN_MENU_SCENE)
