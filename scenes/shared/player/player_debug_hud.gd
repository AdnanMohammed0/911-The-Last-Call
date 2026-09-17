## Debug readout for the player sandbox (stance, stamina, speed, lean).
## Authority: LOCAL
extends Label

const HELP_TEXT: String = "WASD move · Shift sprint · Ctrl/C crouch · Q/E lean · Esc free mouse"

@export var player: Player


func _process(_delta: float) -> void:
	if player == null:
		return
	text = "Stance: %s | Sprint: %s\nStamina: %.1f / %.1f\nSpeed: %.2f m/s | Lean: %+.2f\n\n%s" % [
		Player.Stance.keys()[player.stance], player.is_sprinting,
		player.stamina, player.get_max_stamina(),
		player.get_horizontal_speed(), player.lean_amount, HELP_TEXT,
	]
