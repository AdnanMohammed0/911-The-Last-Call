## Connects map triggers to the anomaly and the burial interaction.
class_name LakeHouseEvents
extends Node

@export var anomaly: DrownedWoman
@export var basement_trigger: Area3D
@export var remains: RemainsInteraction


func _ready() -> void:
	if basement_trigger != null:
		basement_trigger.body_entered.connect(_on_basement_entered)
	if remains != null:
		remains.burial_completed.connect(_on_burial_completed)


func _on_basement_entered(body: Node3D) -> void:
	if multiplayer.is_server() and anomaly != null and body is Player:
		anomaly.notify_basement_entered()


func _on_burial_completed(_flag_id: StringName) -> void:
	if multiplayer.is_server() and anomaly != null:
		anomaly.on_bones_buried()
