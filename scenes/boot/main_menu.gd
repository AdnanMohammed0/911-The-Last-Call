## Main menu + tactical lobby: host / join over ENet, role selection via ClassCards, ready up, host starts.
## Dev flags (after `--`): --host, --join[=<ip>], --name=<name>, --class=<id> (picks + readies), --start (host auto-starts when everyone is ready).
## Authority: LOCAL
extends Control

const FIELD_SCENE: String = "res://scenes/dispatch/operations_room.tscn"
const LEGACY_SANDBOX_SCENE: String = "res://scenes/shared/player/player_sandbox.tscn"
const DOOR_SANDBOX_SCENE: String = "res://scenes/shared/door/door_sandbox.tscn"
const STATION4_SCENE: String = "res://scenes/dispatch/operations_room.tscn"

var _auto_class: StringName = &""
var _auto_start: bool = false

# Views
@onready var _home_view: Control = %HomeView
@onready var _host_view: Control = %HostView
@onready var _join_view: Control = %JoinView
@onready var _lobby_view: Control = %LobbyView

# Home controls
@onready var _name_edit: LineEdit = %NameEdit
@onready var _host_nav_button: Button = %HostNavButton
@onready var _join_nav_button: Button = %JoinNavButton
@onready var _station4_button: Button = %Station4Button
@onready var _rejoin_button: Button = %RejoinButton
@onready var _settings_button: Button = %SettingsButton
@onready var _door_sandbox_button: Button = %DoorSandboxButton
@onready var _sandbox_button: Button = %SandboxButton
@onready var _status_label: Label = %StatusLabel

# Host controls
@onready var _host_button: Button = %HostButton
@onready var _back_from_host_btn: Button = %BackFromHostBtn

# Join controls
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _join_button: Button = %JoinButton
@onready var _back_from_join_btn: Button = %BackFromJoinBtn

# Lobby controls
@onready var _internet_row: HBoxContainer = %InternetRow
@onready var _internet_label: Label = %InternetLabel
@onready var _copy_address_button: Button = %CopyAddressButton
@onready var _roster_list: ItemList = %RosterList
@onready var _ready_button: CheckButton = %ReadyButton
@onready var _start_button: Button = %StartButton
@onready var _leave_button: Button = %LeaveButton

# Class Cards
@onready var _card_tech: ClassCard = %CardTech
@onready var _card_profiler: ClassCard = %CardProfiler
@onready var _card_breacher: ClassCard = %CardBreacher
@onready var _card_medic: ClassCard = %CardMedic

var _cards: Array[ClassCard] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cards = [_card_tech, _card_profiler, _card_breacher, _card_medic]

	# Navigation buttons
	_host_nav_button.pressed.connect(func() -> void: _show_view(_host_view))
	_join_nav_button.pressed.connect(func() -> void: _show_view(_join_view))
	_back_from_host_btn.pressed.connect(func() -> void: _show_view(_home_view))
	_back_from_join_btn.pressed.connect(func() -> void: _show_view(_home_view))

	# Action buttons
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)
	_sandbox_button.pressed.connect(_on_sandbox_pressed)
	_door_sandbox_button.pressed.connect(_on_door_sandbox_pressed)
	_station4_button.pressed.connect(_on_station4_pressed)
	_ready_button.toggled.connect(NetManager.set_ready)
	_start_button.pressed.connect(_on_start_pressed)
	_rejoin_button.pressed.connect(_on_rejoin_pressed)
	_settings_button.pressed.connect(func() -> void: SettingsMenu.open_over(self))
	_copy_address_button.pressed.connect(_on_copy_address_pressed)

	# Connect class cards
	for card: ClassCard in _cards:
		if card:
			card.class_selected.connect(_on_class_selected)

	# NetManager signals
	NetManager.state_changed.connect(_on_state_changed)
	NetManager.connection_failed.connect(_on_connection_failed)
	NetManager.session_started.connect(_on_session_started)
	NetManager.session_ended.connect(_on_session_ended)
	NetManager.lobby_updated.connect(_on_lobby_updated)
	NetManager.internet_hosting_changed.connect(_on_internet_hosting_changed)

	_address_edit.text = "127.0.0.1"
	_name_edit.text = "Player"

	_show_view(_home_view)
	_on_state_changed(NetManager.state)
	_on_lobby_updated(NetManager.roster)

	if not NetManager.last_session_end_reason.is_empty():
		_status_label.text = "Disconnected: %s" % NetManager.last_session_end_reason

	_apply_command_line.call_deferred()


func _show_view(view_to_show: Control) -> void:
	_home_view.visible = (view_to_show == _home_view)
	_host_view.visible = (view_to_show == _host_view)
	_join_view.visible = (view_to_show == _join_view)
	_lobby_view.visible = (view_to_show == _lobby_view)


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


func _on_leave_pressed() -> void:
	NetManager.leave_game()
	_show_view(_home_view)


func _on_rejoin_pressed() -> void:
	var err: Error = NetManager.rejoin_last_session()
	if err != OK:
		_status_label.text = "Cannot rejoin: %s" % error_string(err)


func _on_sandbox_pressed() -> void:
	get_tree().change_scene_to_file(LEGACY_SANDBOX_SCENE)


func _on_door_sandbox_pressed() -> void:
	get_tree().change_scene_to_file(DOOR_SANDBOX_SCENE)


func _on_station4_pressed() -> void:
	get_tree().change_scene_to_file(STATION4_SCENE)


func _on_start_pressed() -> void:
	var err: Error = NetManager.start_game(FIELD_SCENE)
	if err != OK:
		_status_label.text = "Cannot start: %s" % error_string(err)


func _on_class_selected(class_id: StringName) -> void:
	NetManager.select_class(class_id)


func _on_session_started() -> void:
	if _auto_class != &"":
		NetManager.select_class(_auto_class)
		NetManager.set_ready(true)


func _on_state_changed(new_state: NetManager.State) -> void:
	var offline: bool = (new_state == NetManager.State.OFFLINE)
	_host_button.disabled = not offline
	_join_button.disabled = not offline
	_host_nav_button.disabled = not offline
	_join_nav_button.disabled = not offline
	_name_edit.editable = offline
	_address_edit.editable = offline
	_leave_button.disabled = offline
	_sandbox_button.disabled = not offline
	_door_sandbox_button.disabled = not offline
	_station4_button.disabled = not offline
	_rejoin_button.visible = offline and NetManager.has_rejoin_info()
	_internet_row.visible = (new_state == NetManager.State.HOSTING)

	if new_state != NetManager.State.HOSTING:
		_internet_label.text = "Checking router (UPnP)…"
		_copy_address_button.disabled = true
		_copy_address_button.text = "Copy IP"

	match new_state:
		NetManager.State.OFFLINE:
			_status_label.text = "Offline"
			_show_view(_home_view)
		NetManager.State.HOSTING:
			_status_label.text = "Hosting on port %d" % NetManager.DEFAULT_PORT
			_show_view(_lobby_view)
		NetManager.State.CONNECTING:
			_status_label.text = "Connecting to %s…" % _address_edit.text
		NetManager.State.CONNECTED:
			_status_label.text = "Connected as peer %d" % NetManager.get_local_peer_id()
			_show_view(_lobby_view)

	_refresh_lobby_controls()


func _on_internet_hosting_changed(public_address: String, port_open: bool, message: String) -> void:
	_internet_label.text = message
	_copy_address_button.disabled = public_address.is_empty() or not port_open


func _on_copy_address_pressed() -> void:
	DisplayServer.clipboard_set(NetManager.public_address)
	_copy_address_button.text = "Copied!"


func _on_connection_failed(reason: String) -> void:
	_status_label.text = "Failed: %s" % reason
	_show_view(_home_view)


func _on_session_ended(reason: String) -> void:
	_on_lobby_updated(NetManager.roster)
	if not reason.is_empty():
		_status_label.text = "Disconnected: %s" % reason
	_show_view(_home_view)


func _on_lobby_updated(roster: Dictionary) -> void:
	_roster_list.clear()
	var ids: Array = roster.keys()
	ids.sort()
	for peer_id: int in ids:
		var class_id: StringName = NetManager.get_class_id(peer_id)
		var class_name_text: String = ClassCatalog.get_data(class_id).display_name if ClassCatalog.has(class_id) else "No role selected"
		_roster_list.add_item("%s  %s%s%s — [%s]" % [
			"● READY" if NetManager.is_ready(peer_id) else "○ WAITING",
			roster[peer_id]["name"],
			" (HOST)" if peer_id == 1 else "",
			" (YOU)" if peer_id == NetManager.get_local_peer_id() else "",
			class_name_text.to_upper(),
		])

	if not roster.is_empty():
		_roster_list.add_item("— %d / %d ACTIVE DISPATCHERS —" % [roster.size(), NetManager.MAX_PEERS])

	_refresh_lobby_controls()
	if _auto_start and NetManager.can_start():
		_auto_start = false
		_on_start_pressed.call_deferred()


func _refresh_lobby_controls() -> void:
	var me: int = NetManager.get_local_peer_id()
	var online: bool = NetManager.is_online()
	var my_class: StringName = NetManager.get_class_id(me)
	var my_ready: bool = NetManager.is_ready(me)
	var roster: Dictionary = NetManager.roster

	# Update each class card
	for card: ClassCard in _cards:
		if not is_instance_valid(card):
			continue
		var is_my_selection: bool = (my_class == card.class_id and card.class_id != &"")
		var is_taken: bool = false
		var occupant_name: String = ""

		for peer_id: int in roster.keys():
			if peer_id != me and NetManager.get_class_id(peer_id) == card.class_id and card.class_id != &"":
				is_taken = true
				var p_info: Dictionary = roster[peer_id]
				occupant_name = str(p_info.get("name", "Peer %d" % peer_id))
				break

		card.set_card_state(is_my_selection, is_taken, occupant_name)
		if my_ready:
			# If user is already ready, lock card choice
			card.set_card_state(is_my_selection, not is_my_selection, occupant_name)

	_ready_button.disabled = not online or my_class == &""
	_ready_button.set_pressed_no_signal(my_ready)
	_start_button.visible = NetManager.is_host()
	_start_button.disabled = not NetManager.can_start()
