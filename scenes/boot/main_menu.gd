## Placeholder main menu + lobby: host / join over ENet, pick a class, ready up, host starts.
## Dev flags (after `--`): --host, --join[=<ip>], --name=<name>, --class=<id> (picks + readies), --start (host auto-starts when everyone is ready).
## Authority: LOCAL
extends Control

const FIELD_SCENE: String = "res://scenes/shared/player/player_sandbox.tscn"
const DOOR_SANDBOX_SCENE: String = "res://scenes/shared/door/door_sandbox.tscn"

var _auto_class: StringName = &""
var _auto_start: bool = false

@onready var _name_edit: LineEdit = %NameEdit
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _leave_button: Button = %LeaveButton
@onready var _sandbox_button: Button = %SandboxButton
@onready var _door_sandbox_button: Button = %DoorSandboxButton
@onready var _status_label: Label = %StatusLabel
@onready var _roster_list: ItemList = %RosterList
@onready var _class_option: OptionButton = %ClassOption
@onready var _ready_button: CheckButton = %ReadyButton
@onready var _start_button: Button = %StartButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_class_option.add_item("— Pick a class —")
	_class_option.set_item_metadata(0, &"")
	for class_id: StringName in ClassCatalog.ids():
		_class_option.add_item(ClassCatalog.get_data(class_id).display_name)
		_class_option.set_item_metadata(_class_option.item_count - 1, class_id)

	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_leave_button.pressed.connect(NetManager.leave_game)
	_sandbox_button.pressed.connect(_on_sandbox_pressed)
	_door_sandbox_button.pressed.connect(_on_door_sandbox_pressed)
	_class_option.item_selected.connect(_on_class_selected)
	_ready_button.toggled.connect(NetManager.set_ready)
	_start_button.pressed.connect(_on_start_pressed)
	NetManager.state_changed.connect(_on_state_changed)
	NetManager.connection_failed.connect(_on_connection_failed)
	NetManager.session_started.connect(_on_session_started)
	NetManager.session_ended.connect(_on_session_ended)
	NetManager.lobby_updated.connect(_on_lobby_updated)
	_address_edit.text = "127.0.0.1"
	_name_edit.text = "Player"
	_on_state_changed(NetManager.state)
	_on_lobby_updated(NetManager.roster)
	_apply_command_line.call_deferred()


func _apply_command_line() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--name="):
			_name_edit.text = arg.trim_prefix("--name=")
		elif arg.begins_with("--class="):
			_auto_class = StringName(arg.trim_prefix("--class="))
		elif arg == "--start":
			_auto_start = true
	for arg: String in args:
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
	get_tree().change_scene_to_file(FIELD_SCENE)


func _on_start_pressed() -> void:
	var err: Error = NetManager.start_game(FIELD_SCENE)
	if err != OK:
		_status_label.text = "Cannot start: %s" % error_string(err)


func _on_class_selected(index: int) -> void:
	var class_id: StringName = _class_option.get_item_metadata(index)
	NetManager.select_class(class_id)


func _on_session_started() -> void:
	if _auto_class != &"":
		NetManager.select_class(_auto_class)
		NetManager.set_ready(true)


func _on_door_sandbox_pressed() -> void:
	get_tree().change_scene_to_file(DOOR_SANDBOX_SCENE)


func _on_state_changed(new_state: NetManager.State) -> void:
	var offline: bool = new_state == NetManager.State.OFFLINE
	_host_button.disabled = not offline
	_join_button.disabled = not offline
	_name_edit.editable = offline
	_address_edit.editable = offline
	_leave_button.disabled = offline
	_sandbox_button.disabled = not offline
	_door_sandbox_button.disabled = not offline
	match new_state:
		NetManager.State.OFFLINE:
			_status_label.text = "Offline"
		NetManager.State.HOSTING:
			_status_label.text = "Hosting on port %d" % NetManager.DEFAULT_PORT
		NetManager.State.CONNECTING:
			_status_label.text = "Connecting to %s…" % _address_edit.text
		NetManager.State.CONNECTED:
			_status_label.text = "Connected as peer %d" % NetManager.get_local_peer_id()
	_refresh_lobby_controls()


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
		var class_id: StringName = NetManager.get_class_id(peer_id)
		var class_name_text: String = ClassCatalog.get_data(class_id).display_name if ClassCatalog.has(class_id) else "no class"
		_roster_list.add_item("%s %s%s%s — %s" % [
			"[READY]" if NetManager.is_ready(peer_id) else "[ . . ]",
			roster[peer_id]["name"],
			" (host)" if peer_id == 1 else "",
			" (you)" if peer_id == NetManager.get_local_peer_id() else "",
			class_name_text,
		])
	if not roster.is_empty():
		_roster_list.add_item("%d / %d players" % [roster.size(), NetManager.MAX_PEERS])
	_refresh_lobby_controls()
	if _auto_start and NetManager.can_start():
		_auto_start = false
		_on_start_pressed.call_deferred()


func _refresh_lobby_controls() -> void:
	var me: int = NetManager.get_local_peer_id()
	var online: bool = NetManager.is_online()
	var my_class: StringName = NetManager.get_class_id(me)
	var my_ready: bool = NetManager.is_ready(me)

	for i: int in _class_option.item_count:
		var class_id: StringName = _class_option.get_item_metadata(i)
		_class_option.set_item_disabled(i, class_id != &"" and NetManager.is_class_taken(class_id, me))
		if class_id == my_class:
			_class_option.select(i)
	_class_option.disabled = not online or my_ready
	_ready_button.disabled = not online or my_class == &""
	_ready_button.set_pressed_no_signal(my_ready)
	_start_button.visible = NetManager.is_host()
	_start_button.disabled = not NetManager.can_start()
