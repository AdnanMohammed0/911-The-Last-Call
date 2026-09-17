## Walk-through portal to another scene. Only reacts to the local player's own body; online, only the
## host's player can trigger it and it moves every peer together (NetManager.change_level), so players
## never end up split across different scenes.
## Authority: HOST (online) / LOCAL (offline)
class_name InteractableSceneDoor
extends Area3D

@export var target_scene: String = "res://scenes/dispatch/operations_room.tscn"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null or not player.is_multiplayer_authority():
		return
	if NetManager.is_online() and not NetManager.is_host():
		return
	NetManager.change_level(target_scene)
