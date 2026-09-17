## Crosshair + "[F] Prompt" label + hold progress bar for the local player's PlayerInteractor.
## Authority: LOCAL
class_name InteractionPrompt
extends Control

@export var interactor: PlayerInteractor

@onready var _label: Label = %PromptLabel
@onready var _progress: ProgressBar = %HoldProgress


func _ready() -> void:
	_label.visible = false
	_progress.visible = false
	if interactor != null:
		interactor.focus_changed.connect(_on_focus_changed)
		interactor.hold_progress_changed.connect(_on_hold_progress_changed)


func _on_focus_changed(target: Interactable) -> void:
	_label.visible = target != null
	if target == null:
		return
	var verb: String = "Hold" if target.is_hold() else "Press"
	_label.text = "%s  %s  ·  %s" % [verb, _interact_key_name(), target.get_prompt_text()]


func _on_hold_progress_changed(progress: float) -> void:
	_progress.visible = progress >= 0.0
	_progress.value = maxf(progress, 0.0)


func _interact_key_name() -> String:
	return GameSettings.binding_text(&"interact").to_upper()
