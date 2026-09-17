class_name InteractableSceneDoor
extends Area3D

@export var target_scene: String = "res://scenes/dispatch/operations_room.tscn"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player or body.is_in_group(&"players") or body.name.begins_with("Player"):
		get_tree().change_scene_to_file.call_deferred(target_scene)
