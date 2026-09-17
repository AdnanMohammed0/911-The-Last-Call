## Hold-to-collect interactable (evidence, keys, ammo). Single use; removes a node when collected.
## Authority: HOST
class_name InteractablePickup
extends Interactable

signal collected(peer_id: int)

@export var item_id: StringName = &""
## Node removed on every peer once collected (usually the visual parent).
@export var remove_node: Node


func _init() -> void:
	prompt_text = "Collect"
	hold_duration = 1.5
	single_use = true


func _on_interact(_peer_id: int) -> void:
	pass  # TODO(P4-01): FlagSystem.record_event(&"item_collected", {item = item_id, peer = peer_id})


func _on_interacted(peer_id: int) -> void:
	collected.emit(peer_id)
	if remove_node != null:
		remove_node.queue_free()
