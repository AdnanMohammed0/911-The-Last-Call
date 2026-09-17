## Press-to-toggle interactable (light switch, generator, radio…). Optionally drives a node's visibility.
## Authority: HOST (state flips on every peer through the confirmed interaction).
class_name InteractableToggle
extends Interactable

signal toggled(is_on: bool)

@export var is_on: bool = false
@export var on_prompt: String = "Turn off"
@export var off_prompt: String = "Turn on"
## Optional node whose visibility follows `is_on` (e.g. a light).
@export var target: Node3D


func _ready() -> void:
	super()
	_apply()


func get_prompt_text() -> String:
	return on_prompt if is_on else off_prompt


func _on_interacted(_peer_id: int) -> void:
	is_on = not is_on
	_apply()
	toggled.emit(is_on)


func _apply() -> void:
	if target != null:
		target.visible = is_on
