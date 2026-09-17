## In-game pause menu (Esc): resume, leave to main menu, quit. The game keeps running (online co-op).
## Authority: LOCAL (only the owning player's HUD is visible)
class_name PauseMenu
extends Control

@export var player: Player

@onready var _resume_button: Button = %ResumeButton
@onready var _leave_button: Button = %LeaveButton
@onready var _quit_button: Button = %QuitButton
@onready var _session_label: Label = %SessionLabel


func _ready() -> void:
	_resume_button.pressed.connect(close)
	_leave_button.pressed.connect(_on_leave_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.is_multiplayer_authority():
		return
	if event.is_action_pressed(&"ui_cancel"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	player.set_input_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var leave_text: String = "Stop hosting (ends the game for everyone)" if NetManager.is_host() else "Leave to main menu"
	_leave_button.text = leave_text if NetManager.is_online() else "Back to main menu"
	_session_label.text = "Hosting · %d players" % NetManager.roster.size() if NetManager.is_host() \
		else ("Connected as %s" % NetManager.get_player_name(NetManager.get_local_peer_id()) if NetManager.is_online() else "Offline")
	_resume_button.grab_focus()


func close() -> void:
	visible = false
	player.set_input_enabled(true)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_leave_pressed() -> void:
	NetManager.leave_to_menu()


func _on_quit_pressed() -> void:
	NetManager.leave_game()
	get_tree().quit()
