## Placeholder boot scene until the real main menu/lobby lands (P1-05).
## Authority: LOCAL
extends Control


func _ready() -> void:
	print("911: The Last Call — boot OK (phase: %s)" % GameState.phase_name(GameState.phase))
