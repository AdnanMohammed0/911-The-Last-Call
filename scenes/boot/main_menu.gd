## Placeholder main menu: host / join over ENet and show the lobby roster (real lobby UI in P1-05).
## Supports `-- --host`, `-- --join=<ip>` and `-- --name=<name>` for quick multi-instance testing.
## Authority: LOCAL
extends Control

const SANDBOX_SCENE: String = "res://scenes/shared/player/player_sandbox.tscn"

@onready var _name_edit: LineEdit = %NameEdit
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _leave_button: Button = %LeaveButton
@onready var _sandbox_button: Button = %SandboxButton
@onready var _status_label: Label = %StatusLabel
@onready var _roster_list: ItemList = %RosterList


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_leave_button.pressed.connect(NetManager.leave_game)
	_sandbox_button.pressed.connect(_on_sandbox_pressed)
	NetManager.state_changed.connect(_on_state_changed)
	NetManager.connection_failed.connect(_on_connection_failed)
	NetManager.session_ended.connect(_on_session_ended)
	NetManager.lobby_updated.connect(_on_lobby_updated)
	_address_edit.text = "127.0.0.1"
	_name_edit.text = "Player"
	_on_state_changed(NetManager.state)
	_on_lobby_updated(NetManager.roster)
	_apply_command_line.call_deferred()


func _apply_command_line() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--name="):
			_name_edit.text = arg.trim_prefix("--name=")
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--host":
			_on_host_pressed()
		elif arg.begins_with("--join"):
			_address_edit.text = arg.trim_prefix("--join=") if "=" in arg else "127.0.0.1"
			_on_join_pressed()


func _on_host_pressed() -> void:
	NetManager.host_game(_name_edit.text)


func _on_join_pressed() -> void:
	NetManager.join_game(_address_edit.text, _name_edit.text)


func _on_sandbox_pressed() -> void:
	get_tree().change_scene_to_file(SANDBOX_SCENE)


func _on_state_changed(new_state: NetManager.State) -> void:
	var offline: bool = new_state == NetManager.State.OFFLINE
	_host_button.disabled = not offline
	_join_button.disabled = not offline
	_name_edit.editable = offline
	_address_edit.editable = offline
	_leave_button.disabled = offline
	match new_state:
		NetManager.State.OFFLINE:
			_status_label.text = "Offline"
		NetManager.State.HOSTING:
			_status_label.text = "Hosting on port %d" % NetManager.DEFAULT_PORT
		NetManager.State.CONNECTING:
			_status_label.text = "Connecting to %s…" % _address_edit.text
		NetManager.State.CONNECTED:
			_status_label.text = "Connected as peer %d" % NetManager.get_local_peer_id()


func _on_connection_failed(reason: String) -> void:
	_status_label.text = "Failed: %s" % reason


func _on_session_ended(reason: String) -> void:
	_on_lobby_updated(NetManager.roster)
	if not reason.is_empty():
		_status_label.text = "Disconnected: %s" % reason


func _on_lobby_updated(roster: Dictionary) -> void:
	_roster_list.clear()
	var ids: Array = roster.keys()
	ids.sort()
	for peer_id: int in ids:
		var tag: String = " (host)" if peer_id == 1 else ""
		var you: String = " — you" if NetManager.is_online() and peer_id == NetManager.get_local_peer_id() else ""
		_roster_list.add_item("%s%s%s" % [roster[peer_id]["name"], tag, you])
	if not roster.is_empty():
		_roster_list.add_item("%d / %d players" % [roster.size(), NetManager.MAX_PEERS])
