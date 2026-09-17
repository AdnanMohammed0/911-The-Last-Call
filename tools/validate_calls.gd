## Command-line call validator (P2-01). Exit code = number of errors, so CI fails on broken calls.
##   godot --headless --path . -s res://tools/validate_calls.gd
## Authority: LOCAL (tool)
extends SceneTree


func _initialize() -> void:
	var results: Dictionary = CallValidator.validate_directory()
	var counts: Dictionary = {}
	print(CallValidator.format_report(results, counts))
	var errors: int = counts.get("errors", 0)
	quit(mini(errors, 125))
