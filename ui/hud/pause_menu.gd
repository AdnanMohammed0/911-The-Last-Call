## In-game pause menu (Esc): resume, leave to main menu, quit. The game keeps running (online co-op).
## Authority: LOCAL (only the owning player's HUD is visible)
class_name PauseMenu
extends Control

@export var player: Player

@onready var _resume_button: Button = %ResumeButton
@onready var _leave_button: Button = %LeaveButton
@onready var _quit_button: Button = %QuitButton
@onready var _session_label: Label = %SessionLabel
@onready var _voice_mode_button: Button = %VoiceModeButton
@onready var _mic_device_option: OptionButton = %MicDeviceOption
@onready var _mic_level_bar: ProgressBar = %MicLevelBar
@onready var _mic_status_label: Label = %MicStatusLabel
@onready var _auto_gain_check: CheckBox = %AutoGainCheck
@onready var _hear_myself_check: CheckBox = %HearMyselfCheck


func _ready() -> void:
	_resume_button.pressed.connect(close)
	_leave_button.pressed.connect(_on_leave_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_voice_mode_button.pressed.connect(_on_voice_mode_pressed)
	_mic_device_option.item_selected.connect(_on_mic_device_selected)
	_auto_gain_check.toggled.connect(VoiceManager.set_auto_gain)
	_hear_myself_check.toggled.connect(func(on: bool) -> void: VoiceManager.loopback = on)


func _process(_delta: float) -> void:
	if not visible:
		return
	_mic_level_bar.value = clampf(inverse_lerp(-60.0, 0.0, VoiceManager.local_level_db), 0.0, 1.0)
	var state: String = "sending" if VoiceManager.local_transmitting else "quiet"
	_mic_status_label.text = "Mic %.0f dB · noise %.0f dB · gain +%.0f dB · %s" % [
		VoiceManager.raw_level_db, VoiceManager.noise_floor_db, VoiceManager.current_gain_db, state]


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
	_voice_mode_button.text = "Voice: %s" % VoiceManager.get_mode_text()
	_mic_device_option.clear()
	var current: String = VoiceManager.get_input_device()
	for device: String in VoiceManager.get_input_devices():
		_mic_device_option.add_item(device)
		if device == current:
			_mic_device_option.select(_mic_device_option.item_count - 1)
	_auto_gain_check.set_pressed_no_signal(VoiceManager.auto_gain)
	_hear_myself_check.set_pressed_no_signal(VoiceManager.loopback)
	_resume_button.grab_focus()


func close() -> void:
	visible = false
	if VoiceManager.loopback:
		VoiceManager.loopback = false
		_hear_myself_check.set_pressed_no_signal(false)
	player.set_input_enabled(true)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_mic_device_selected(index: int) -> void:
	VoiceManager.set_input_device(_mic_device_option.get_item_text(index))


func _on_voice_mode_pressed() -> void:
	VoiceManager.toggle_mode()
	_voice_mode_button.text = "Voice: %s" % VoiceManager.get_mode_text()


func _on_leave_pressed() -> void:
	NetManager.leave_to_menu()


func _on_quit_pressed() -> void:
	NetManager.leave_game()
	get_tree().quit()
