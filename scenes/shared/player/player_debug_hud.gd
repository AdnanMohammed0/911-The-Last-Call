## Debug readout for the player sandbox (stance, stamina, speed, lean).
## Authority: LOCAL
extends Label

const HELP_TEXT: String = "WASD move · Shift sprint · Ctrl crouch · Q/E lean · F interact · C peek · V kick · T flashlight · Caps talk · B radio · F3 net · Esc menu"

@export var player: Player


func _process(_delta: float) -> void:
	if player == null:
		player = Player.find_by_peer(get_tree(), multiplayer.get_unique_id())
		if player == null:
			return
	var interact_line := ("\n>>> %s <<<\n" % player.current_interaction_prompt) if player.current_interaction_prompt != "" else ""
	text = "%s (%s) | Stance: %s | Sprint: %s\nStamina: %.1f / %.1f\nSpeed: %.2f m/s | Lean: %+.2f%s\n\n%s" % [
		NetManager.get_player_name(player.peer_id), player.class_id,
		Player.Stance.keys()[player.stance], player.is_sprinting,
		player.stamina, player.get_max_stamina(),
		player.get_horizontal_speed(), player.lean_amount,
		interact_line,
		HELP_TEXT,
	]
