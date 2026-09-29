## Main menu + tactical lobby. A live 3D street backdrop sits behind a torn ink sidebar that holds the logo
## and brush-stroke menu (host / join / offline station / settings / quit); host and join open glass panels
## in the sidebar, the lobby takes the whole screen (roster, role cards, ready / start / leave).
## Dev flags (after `--`): --host, --join[=<ip>], --name=<name>, --class=<id> (picks + readies), --start
## (host auto-starts when everyone is ready).
## Authority: LOCAL
extends Control

const FIELD_SCENE: String = "res://scenes/dispatch/operations_room.tscn"
const LEGACY_SANDBOX_SCENE: String = "res://scenes/shared/player/player_sandbox.tscn"
const DOOR_SANDBOX_SCENE: String = "res://scenes/shared/door/door_sandbox.tscn"
const STATION4_SCENE: String = "res://scenes/dispatch/operations_room.tscn"
const TORN_EDGE: Shader = preload("res://ui/shaders/torn_edge.gdshader")
const GRUNGE: Shader = preload("res://ui/shaders/grunge_text.gdshader")
const CLASS_ORDER: Array[StringName] = [&"tech", &"profiler", &"breacher", &"medic"]
const VERSION_TEXT: String = "BUILD 0.9 · SHIFT 1 PREVIEW"

var _auto_class: StringName = &""
var _auto_start: bool = false

# Views
var _home_view: Control
var _host_view: Control
var _join_view: Control
var _lobby_view: Control
var _sidebar: Control
var _sidebar_ink: ColorRect
var _logo: Control
var _esc_hint: Control

# Home controls
var _name_edit: LineEdit
var _host_nav_button: BrushButton
var _join_nav_button: BrushButton
var _station4_button: BrushButton
var _rejoin_button: BrushButton
var _settings_button: BrushButton
var _quit_button: BrushButton
var _door_sandbox_button: KitButton
var _sandbox_button: KitButton
var _status_label: Label
var _status_dot: IconView

# Host / join controls
var _host_button: KitButton
var _back_from_host_btn: KitButton
var _address_edit: LineEdit
var _join_button: KitButton
var _back_from_join_btn: KitButton

# Lobby controls
var _lobby_title_state: PanelContainer
var _lobby_count: Label
var _internet_row: HBoxContainer
var _internet_label: Label
var _copy_address_button: KitButton
var _roster_list: VBoxContainer
var _ready_button: KitButton
var _start_button: KitButton
var _leave_button: KitButton
var _cards: Array[ClassCard] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()

	_host_nav_button.pressed.connect(func() -> void: _show_view(_host_view))
	_join_nav_button.pressed.connect(func() -> void: _show_view(_join_view))
	_back_from_host_btn.pressed.connect(func() -> void: _show_view(_home_view))
	_back_from_join_btn.pressed.connect(func() -> void: _show_view(_home_view))
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
	_quit_button.pressed.connect(func() -> void: get_tree().quit())
	_copy_address_button.pressed.connect(_on_copy_address_pressed)
	for card: ClassCard in _cards:
		card.class_selected.connect(_on_class_selected)

	NetManager.state_changed.connect(_on_state_changed)
	NetManager.connection_failed.connect(_on_connection_failed)
	NetManager.session_started.connect(_on_session_started)
	NetManager.session_ended.connect(_on_session_ended)
	NetManager.lobby_updated.connect(_on_lobby_updated)
	NetManager.internet_hosting_changed.connect(_on_internet_hosting_changed)

	_address_edit.text = "127.0.0.1"
	_name_edit.text = tr("Player")
	_show_view(_home_view)
	_on_state_changed(NetManager.state)
	_on_lobby_updated(NetManager.roster)
	if not NetManager.last_session_end_reason.is_empty():
		_set_status("Disconnected: %s" % NetManager.last_session_end_reason, GameTheme.DANGER)
	_apply_command_line.call_deferred()
	_intro.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and (_host_view.visible or _join_view.visible):
		_show_view(_home_view)
		get_viewport().set_input_as_handled()


# --- Layout -------------------------------------------------------------------------------------

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var black: ColorRect = ColorRect.new()
	black.color = GameTheme.INK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	var backdrop: MenuBackdrop = MenuBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	add_child(_vignette())

	_sidebar = Control.new()
	_sidebar.name = "Sidebar"
	_sidebar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sidebar)
	_sidebar_ink = ColorRect.new()
	_sidebar_ink.anchor_right = 0.0
	_sidebar_ink.anchor_bottom = 1.0
	_sidebar_ink.offset_right = 1060
	_sidebar_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink: ShaderMaterial = ShaderMaterial.new()
	ink.shader = TORN_EDGE
	ink.set_shader_parameter(&"edge", 0.66)
	_sidebar_ink.material = ink
	_sidebar.add_child(_sidebar_ink)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	column.anchor_bottom = 1.0
	column.offset_left = 96
	column.offset_top = 78
	column.offset_right = 96 + 560
	column.offset_bottom = -54
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sidebar.add_child(column)
	_logo = _build_logo()
	column.add_child(_logo)
	column.add_child(UiKit.spacer(54))
	var views: Control = VBoxContainer.new()
	views.size_flags_vertical = Control.SIZE_EXPAND_FILL
	views.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(views)
	_home_view = _unique(_build_home(), "HomeView", views)
	_host_view = _unique(_build_host(), "HostView", views)
	_join_view = _unique(_build_join(), "JoinView", views)
	column.add_child(_build_footer())

	_lobby_view = _unique(_build_lobby(), "LobbyView", self)
	add_child(_build_profile_chip())
	for node: Node in [_host_nav_button, _join_nav_button, _station4_button, _rejoin_button, _settings_button,
			_sandbox_button, _door_sandbox_button, _status_label, _host_button, _back_from_host_btn, _address_edit,
			_join_button, _back_from_join_btn, _internet_row, _internet_label, _copy_address_button, _roster_list,
			_ready_button, _start_button, _leave_button, _name_edit]:
		_mark_unique(node)
	for card: ClassCard in _cards:
		_mark_unique(card)
	_esc_hint = _build_esc_hint()
	add_child(_esc_hint)


## Register `node` under `parent` as a scene-unique name (%Name) owned by the menu.
func _unique(node: Control, node_name: String, parent: Node) -> Control:
	node.name = node_name
	parent.add_child(node)
	node.owner = self
	node.unique_name_in_owner = true
	return node


func _vignette() -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + TIME) * 43758.5453); }
void fragment() {
	float v = smoothstep(0.35, 1.05, length((UV - vec2(0.62, 0.5)) * vec2(1.3, 1.0)));
	float grain = (hash(FRAGCOORD.xy) - 0.5) * 0.05;
	COLOR = vec4(vec3(grain), v * 0.75 + abs(grain));
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	return rect


func _build_logo() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", -18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var number: Label = UiKit.label("911", 168, GameTheme.ACCENT, &"black_italic")
	var grunge: ShaderMaterial = ShaderMaterial.new()
	grunge.shader = GRUNGE
	grunge.set_shader_parameter(&"erosion", 0.3)
	number.material = grunge
	number.add_theme_color_override(&"font_shadow_color", Color(0.9, 0.1, 0.08, 0.35))
	number.add_theme_constant_override(&"shadow_offset_x", 0)
	number.add_theme_constant_override(&"shadow_offset_y", 0)
	number.add_theme_constant_override(&"shadow_outline_size", 22)
	box.add_child(number)
	var title: Label = UiKit.caps("THE LAST CALL", 44, GameTheme.TEXT, &"black", 9)
	var title_grunge: ShaderMaterial = grunge.duplicate() as ShaderMaterial
	title_grunge.set_shader_parameter(&"erosion", 0.2)
	title_grunge.set_shader_parameter(&"scale", 0.09)
	title.material = title_grunge
	box.add_child(title)
	var tag_row: HBoxContainer = HBoxContainer.new()
	tag_row.add_theme_constant_override(&"separation", 12)
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(UiKit.margin(tag_row, 4, 30, 0, 0))
	var bar: ColorRect = ColorRect.new()
	bar.color = GameTheme.ACCENT
	bar.custom_minimum_size = Vector2(36, 3)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag_row.add_child(bar)
	tag_row.add_child(UiKit.caps("Every call could be your last", 14, GameTheme.TEXT_DIM, &"semibold", 3))
	return box


func _build_home() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rejoin_button = _brush(box, "Rejoin last shift", "RejoinButton")
	_host_nav_button = _brush(box, "Host a shift", "HostNavButton")
	_join_nav_button = _brush(box, "Join a shift", "JoinNavButton")
	_station4_button = _brush(box, "Station 4 · Offline", "Station4Button")
	_settings_button = _brush(box, "Settings", "SettingsButton")
	_quit_button = _brush(box, "Quit", "QuitButton")
	box.add_child(UiKit.spacer(26))
	var dev: HBoxContainer = HBoxContainer.new()
	dev.add_theme_constant_override(&"separation", 8)
	box.add_child(dev)
	var dev_label: Label = UiKit.caps("Dev", 11, GameTheme.TEXT_FAINT, &"bold", 2)
	dev_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dev.add_child(dev_label)
	_sandbox_button = KitButton.make("Player sandbox", &"user", KitButton.Variant.GHOST)
	_door_sandbox_button = KitButton.make("Door sandbox", &"door", KitButton.Variant.GHOST)
	for button: KitButton in [_sandbox_button, _door_sandbox_button]:
		button.add_theme_font_size_override(&"font_size", 13)
		button.icon_size = 15.0
		button.add_theme_color_override(&"font_color", GameTheme.TEXT_FAINT)
		dev.add_child(button)
	_sandbox_button.name = "SandboxButton"
	_door_sandbox_button.name = "DoorSandboxButton"
	return box


func _brush(parent: Container, text: String, node_name: String) -> BrushButton:
	var button: BrushButton = BrushButton.make(text, Callable(), 28)
	button.name = node_name
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(button)
	return button


func _build_host() -> Control:
	var panel: PanelContainer = UiKit.glass(Color(0.04, 0.045, 0.055), 14, 30, 26, 0.72)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.custom_minimum_size = Vector2(500, 0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	panel.add_child(box)
	box.add_child(UiKit.caps("Host a shift", 13, GameTheme.ACCENT))
	box.add_child(UiKit.label("Open your station", 34, GameTheme.TEXT, &"black_italic"))
	box.add_child(UiKit.paragraph("Up to three officers can join your dispatch floor. The router port is opened automatically (UPnP) so friends can join over the internet."))
	var facts: VBoxContainer = VBoxContainer.new()
	facts.add_theme_constant_override(&"separation", 8)
	facts.add_child(UiKit.icon_row(&"users", "4 players · roles are claimed in the lobby", 15, GameTheme.TEXT_DIM))
	facts.add_child(UiKit.icon_row(&"globe", "UDP port %d" % NetManager.DEFAULT_PORT, 15, GameTheme.TEXT_DIM))
	facts.add_child(UiKit.icon_row(&"shield", "Host validates every action (anti-cheat)", 15, GameTheme.TEXT_DIM))
	box.add_child(facts)
	box.add_child(UiKit.spacer(4))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	box.add_child(row)
	_host_button = KitButton.make("Host game", &"play", KitButton.Variant.PRIMARY)
	_host_button.name = "HostButton"
	_host_button.custom_minimum_size = Vector2(190, 48)
	row.add_child(_host_button)
	_back_from_host_btn = KitButton.make("Back", &"back", KitButton.Variant.GHOST)
	_back_from_host_btn.name = "BackFromHostBtn"
	_back_from_host_btn.custom_minimum_size = Vector2(0, 48)
	row.add_child(_back_from_host_btn)
	return panel


func _build_join() -> Control:
	var panel: PanelContainer = UiKit.glass(Color(0.04, 0.045, 0.055), 14, 30, 26, 0.72)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.custom_minimum_size = Vector2(500, 0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	panel.add_child(box)
	box.add_child(UiKit.caps("Join a shift", 13, GameTheme.ACCENT))
	box.add_child(UiKit.label("Report for duty", 34, GameTheme.TEXT, &"black_italic"))
	box.add_child(UiKit.paragraph("Enter the host's address. LAN: their local IP. Internet: the public IP the host copies from the lobby."))
	box.add_child(UiKit.caps("Host address", 11, GameTheme.TEXT_DIM))
	_address_edit = LineEdit.new()
	_address_edit.name = "AddressEdit"
	_address_edit.placeholder_text = "127.0.0.1  or  203.0.113.7:24911"
	_address_edit.custom_minimum_size = Vector2(0, 48)
	_address_edit.add_theme_font_size_override(&"font_size", 20)
	_address_edit.text_submitted.connect(func(_text: String) -> void: _on_join_pressed())
	box.add_child(_address_edit)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	box.add_child(row)
	_join_button = KitButton.make("Join game", &"forward", KitButton.Variant.PRIMARY)
	_join_button.name = "JoinButton"
	_join_button.custom_minimum_size = Vector2(190, 48)
	row.add_child(_join_button)
	_back_from_join_btn = KitButton.make("Back", &"back", KitButton.Variant.GHOST)
	_back_from_join_btn.name = "BackFromJoinBtn"
	_back_from_join_btn.custom_minimum_size = Vector2(0, 48)
	row.add_child(_back_from_join_btn)
	return panel


func _build_footer() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var status: HBoxContainer = HBoxContainer.new()
	status.add_theme_constant_override(&"separation", 8)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(status)
	_status_dot = IconView.make(&"wifi", 16, GameTheme.TEXT_DIM)
	_status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(_status_dot)
	_status_label = UiKit.label("Offline", 15, GameTheme.TEXT_DIM, &"medium")
	_status_label.name = "StatusLabel"
	status.add_child(_status_label)
	box.add_child(UiKit.caps(VERSION_TEXT, 11, GameTheme.TEXT_FAINT, &"semibold", 2))
	return box


func _build_profile_chip() -> Control:
	var chip: PanelContainer = UiKit.glass(Color(0.04, 0.045, 0.055), 30, 14, 8, 0.7)
	chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 32)
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	chip.add_child(row)
	var avatar: IconView = IconView.make(&"badge", 26, GameTheme.WARNING)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(avatar)
	var names: VBoxContainer = VBoxContainer.new()
	names.add_theme_constant_override(&"separation", -2)
	row.add_child(names)
	names.add_child(UiKit.caps("Callsign", 10, GameTheme.TEXT_DIM, &"bold", 2))
	_name_edit = LineEdit.new()
	_name_edit.name = "NameEdit"
	_name_edit.max_length = 20
	_name_edit.custom_minimum_size = Vector2(190, 0)
	_name_edit.flat = true
	_name_edit.add_theme_font_override(&"font", GameTheme.font(&"bold"))
	_name_edit.add_theme_font_size_override(&"font_size", 19)
	var flat: StyleBoxEmpty = StyleBoxEmpty.new()
	_name_edit.add_theme_stylebox_override(&"normal", flat)
	_name_edit.add_theme_stylebox_override(&"focus", UiKit.style(Color(1, 1, 1, 0.06), 4, 4, 0))
	names.add_child(_name_edit)
	var settings: KitButton = KitButton.make("", &"gear", KitButton.Variant.GHOST, func() -> void: SettingsMenu.open_over(self))
	settings.tooltip_text = tr("Settings")
	row.add_child(settings)
	return chip


func _build_esc_hint() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiKit.key_cap("Esc", 12))
	row.add_child(UiKit.caps("Back", 13, GameTheme.TEXT_DIM, &"bold", 2))
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 40)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	return row


func _build_lobby() -> Control:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.015, 0.018, 0.026)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var blur: ShaderMaterial = ShaderMaterial.new()
	blur.shader = UiKit.ACRYLIC
	blur.set_shader_parameter(&"blur_lod", 4.5)
	blur.set_shader_parameter(&"tint_amount", 0.55)
	shade.material = blur
	root.add_child(shade)
	var frame: MarginContainer = MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		frame.add_theme_constant_override("margin_" + side, 72)
	frame.add_theme_constant_override(&"margin_top", 110)
	frame.add_theme_constant_override(&"margin_bottom", 56)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 22)
	frame.add_child(layout)

	# Header.
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 16)
	layout.add_child(header)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.add_theme_constant_override(&"separation", -4)
	header.add_child(titles)
	titles.add_child(UiKit.caps("Pre-shift briefing", 13, GameTheme.ACCENT))
	titles.add_child(UiKit.label("SHIFT LOBBY", 52, GameTheme.TEXT, &"black_italic"))
	var badges: HBoxContainer = HBoxContainer.new()
	badges.add_theme_constant_override(&"separation", 8)
	badges.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(badges)
	_lobby_title_state = UiKit.pill("Hosting", GameTheme.SUCCESS)
	badges.add_child(_lobby_title_state)
	_lobby_count = UiKit.caps(tr("%d / %d OFFICERS") % [0, NetManager.MAX_PEERS], 13, GameTheme.TEXT_DIM, &"bold", 2)
	badges.add_child(_lobby_count)
	header.add_child(UiKit.expand(Control.new()))
	_internet_row = HBoxContainer.new()
	_internet_row.name = "InternetRow"
	_internet_row.add_theme_constant_override(&"separation", 10)
	_internet_row.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(_internet_row)
	_internet_row.add_child(IconView.make(&"globe", 20, GameTheme.SIREN_BLUE))
	_internet_label = UiKit.label("Checking router (UPnP)…", 15, GameTheme.TEXT_DIM)
	_internet_label.name = "InternetLabel"
	_internet_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_internet_row.add_child(_internet_label)
	_copy_address_button = KitButton.make("Copy IP", &"copy", KitButton.Variant.SUBTLE)
	_copy_address_button.name = "CopyAddressButton"
	_internet_row.add_child(_copy_address_button)

	# Body: roster on the left, role cards on the right.
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override(&"separation", 26)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	var roster_panel: PanelContainer = UiKit.glass(Color(0.035, 0.04, 0.05), 14, 18, 18, 0.75)
	roster_panel.custom_minimum_size = Vector2(390, 0)
	roster_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(roster_panel)
	var roster_box: VBoxContainer = VBoxContainer.new()
	roster_box.add_theme_constant_override(&"separation", 12)
	roster_panel.add_child(roster_box)
	roster_box.add_child(UiKit.caps("Officers on shift", 12, GameTheme.TEXT_DIM))
	_roster_list = VBoxContainer.new()
	_roster_list.name = "RosterList"
	_roster_list.add_theme_constant_override(&"separation", 8)
	roster_box.add_child(_roster_list)
	roster_box.add_child(UiKit.spacer(10))
	roster_box.add_child(UiKit.paragraph("Claim a role, then ready up. The host starts the shift when every officer is ready.", 13, GameTheme.TEXT_FAINT))

	var cards_box: VBoxContainer = VBoxContainer.new()
	cards_box.add_theme_constant_override(&"separation", 12)
	cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(cards_box)
	cards_box.add_child(UiKit.caps("Choose your role", 12, GameTheme.TEXT_DIM))
	var cards: HBoxContainer = HBoxContainer.new()
	cards.add_theme_constant_override(&"separation", 16)
	cards_box.add_child(cards)
	var card_scene: PackedScene = load("res://scenes/boot/class_card.tscn") as PackedScene
	for class_id: StringName in CLASS_ORDER:
		var card: ClassCard = card_scene.instantiate() as ClassCard
		card.class_id = class_id
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.name = "Card%s" % String(class_id).capitalize()
		cards.add_child(card)
		_cards.append(card)

	# Footer actions.
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 12)
	layout.add_child(footer)
	_leave_button = KitButton.make("Leave", &"logout", KitButton.Variant.DANGER)
	_leave_button.name = "LeaveButton"
	_leave_button.custom_minimum_size = Vector2(150, 52)
	footer.add_child(_leave_button)
	footer.add_child(UiKit.expand(Control.new()))
	_ready_button = KitButton.make("Ready up", &"check", KitButton.Variant.DEFAULT)
	_ready_button.name = "ReadyButton"
	_ready_button.toggle_mode = true
	_ready_button.custom_minimum_size = Vector2(210, 52)
	_ready_button.toggled.connect(func(on: bool) -> void:
		_ready_button.text = tr("Ready") if on else tr("Ready up")
		_ready_button.variant = KitButton.Variant.PRIMARY if on else KitButton.Variant.DEFAULT
		_ready_button.accent = GameTheme.SUCCESS if on else GameTheme.ACCENT
		_ready_button.apply_variant())
	footer.add_child(_ready_button)
	_start_button = KitButton.make("Start shift", &"play", KitButton.Variant.PRIMARY)
	_start_button.name = "StartButton"
	_start_button.custom_minimum_size = Vector2(230, 52)
	footer.add_child(_start_button)
	return root


func _mark_unique(node: Node) -> void:
	if node.is_inside_tree():
		node.owner = self
		node.unique_name_in_owner = true


# --- Views --------------------------------------------------------------------------------------

func _show_view(view_to_show: Control) -> void:
	var lobby: bool = view_to_show == _lobby_view
	for view: Control in [_home_view, _host_view, _join_view, _lobby_view]:
		var was_visible: bool = view.visible
		view.visible = view == view_to_show
		if view.visible and not was_visible and is_inside_tree():
			if view == _home_view:
				UiKit.stagger(_home_view, 0.04)
			else:
				UiKit.reveal(view, 0.0, Vector2(0, 16) if lobby else Vector2(-20, 0))
	_sidebar.visible = not lobby
	if _esc_hint != null:
		_esc_hint.visible = view_to_show == _host_view or view_to_show == _join_view
	if view_to_show == _home_view and is_inside_tree():
		var first: Button = _rejoin_button if _rejoin_button.visible else _host_nav_button
		if first != null and DisplayServer.get_name() != "headless":
			first.grab_focus.call_deferred()
	elif view_to_show == _join_view and is_inside_tree():
		_address_edit.grab_focus.call_deferred()


func _intro() -> void:
	if not is_inside_tree():
		return
	UiKit.reveal(_logo, 0.1, Vector2(-30, 0), 0.6)
	if _home_view.visible:
		UiKit.stagger(_home_view, 0.06, 0.35)


func _set_status(text: String, colour: Color = GameTheme.TEXT_DIM) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override(&"font_color", colour)
	_status_dot.color = colour


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


# --- Actions ------------------------------------------------------------------------------------

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
		_set_status("Cannot rejoin: %s" % error_string(err), GameTheme.DANGER)


func _on_sandbox_pressed() -> void:
	get_tree().change_scene_to_file(LEGACY_SANDBOX_SCENE)


func _on_door_sandbox_pressed() -> void:
	get_tree().change_scene_to_file(DOOR_SANDBOX_SCENE)


func _on_station4_pressed() -> void:
	get_tree().change_scene_to_file(STATION4_SCENE)


func _on_start_pressed() -> void:
	var err: Error = NetManager.start_game(FIELD_SCENE)
	if err != OK:
		_set_status("Cannot start: %s" % error_string(err), GameTheme.DANGER)


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
		_internet_label.text = tr("Checking router (UPnP)…")
		_copy_address_button.disabled = true
		_copy_address_button.text = tr("Copy IP")
	match new_state:
		NetManager.State.OFFLINE:
			_set_status("Offline")
			_show_view(_home_view)
		NetManager.State.HOSTING:
			_set_status("Hosting on port %d" % NetManager.DEFAULT_PORT, GameTheme.SUCCESS)
			_set_state_pill("Hosting", GameTheme.SUCCESS)
			_show_view(_lobby_view)
		NetManager.State.CONNECTING:
			_set_status("Connecting to %s…" % _address_edit.text, GameTheme.WARNING)
		NetManager.State.CONNECTED:
			_set_status("Connected as peer %d" % NetManager.get_local_peer_id(), GameTheme.SUCCESS)
			_set_state_pill("Connected", GameTheme.SIREN_BLUE)
			_show_view(_lobby_view)
	_refresh_lobby_controls()


func _set_state_pill(text: String, colour: Color) -> void:
	var parent: Node = _lobby_title_state.get_parent()
	var index: int = _lobby_title_state.get_index()
	_lobby_title_state.queue_free()
	_lobby_title_state = UiKit.pill(text, colour)
	parent.add_child(_lobby_title_state)
	parent.move_child(_lobby_title_state, index)


func _on_internet_hosting_changed(public_address: String, port_open: bool, message: String) -> void:
	_internet_label.text = message
	_copy_address_button.disabled = public_address.is_empty() or not port_open


func _on_copy_address_pressed() -> void:
	DisplayServer.clipboard_set(NetManager.public_address)
	_copy_address_button.text = tr("Copied!")


func _on_connection_failed(reason: String) -> void:
	_set_status("Failed: %s" % reason, GameTheme.DANGER)
	_show_view(_home_view)


func _on_session_ended(reason: String) -> void:
	_on_lobby_updated(NetManager.roster)
	if not reason.is_empty():
		_set_status("Disconnected: %s" % reason, GameTheme.DANGER)
	_show_view(_home_view)


func _on_lobby_updated(roster: Dictionary) -> void:
	for child: Node in _roster_list.get_children():
		child.queue_free()
	var ids: Array = roster.keys()
	ids.sort()
	for peer_id: int in ids:
		var info: Dictionary = roster[peer_id]
		_roster_list.add_child(_roster_row(peer_id, str(info.get("name", "Peer %d" % peer_id))))
	for i: int in range(roster.size(), NetManager.MAX_PEERS):
		_roster_list.add_child(_empty_slot())
	_lobby_count.text = tr("%d / %d OFFICERS") % [roster.size(), NetManager.MAX_PEERS]
	_refresh_lobby_controls()
	if _auto_start and NetManager.can_start():
		_auto_start = false
		_on_start_pressed.call_deferred()


func _roster_row(peer_id: int, player_name: String) -> Control:
	var class_id: StringName = NetManager.get_class_id(peer_id)
	var data: ClassData = ClassCatalog.get_data(class_id) if ClassCatalog.has(class_id) else null
	var colour: Color = data.color if data != null else Color(0.4, 0.42, 0.46)
	var ready: bool = NetManager.is_ready(peer_id)
	var row: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.style(Color(1, 1, 1, 0.04), 10, 12, 10, Color(colour, 0.35), 0)
	box.border_width_left = 4
	box.border_color = colour
	row.add_theme_stylebox_override(&"panel", box)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 12)
	row.add_child(line)
	var avatar: PanelContainer = PanelContainer.new()
	avatar.add_theme_stylebox_override(&"panel", UiKit.style(Color(colour, 0.25), 20, 0, 0, colour, 1))
	avatar.custom_minimum_size = Vector2(40, 40)
	var initial: Label = UiKit.label(player_name.substr(0, 1).to_upper(), 18, Color.WHITE, &"black")
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(initial)
	line.add_child(avatar)
	var names: VBoxContainer = VBoxContainer.new()
	names.add_theme_constant_override(&"separation", -1)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(names)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 6)
	names.add_child(top)
	top.add_child(UiKit.label(player_name, 17, GameTheme.TEXT, &"bold"))
	if peer_id == 1:
		top.add_child(UiKit.pill("Host", GameTheme.WARNING, false, 9))
	if peer_id == NetManager.get_local_peer_id():
		top.add_child(UiKit.pill("You", GameTheme.SIREN_BLUE, false, 9))
	names.add_child(UiKit.caps(data.display_name if data != null else "No role selected", 11, colour.lightened(0.2) if data != null else GameTheme.TEXT_FAINT, &"semibold", 1))
	var status: Control = UiKit.pill("Ready", GameTheme.SUCCESS, true, 10) if ready else UiKit.pill("Waiting", GameTheme.TEXT_DIM, false, 10)
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(status)
	return row


func _empty_slot() -> Control:
	var row: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = UiKit.style(Color(1, 1, 1, 0.0), 10, 12, 10, Color(1, 1, 1, 0.08), 1)
	row.add_theme_stylebox_override(&"panel", box)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 12)
	row.add_child(line)
	var icon: IconView = IconView.make(&"user", 22, GameTheme.TEXT_FAINT)
	icon.custom_minimum_size = Vector2(40, 40)
	line.add_child(icon)
	var text: Label = UiKit.caps("Open slot", 12, GameTheme.TEXT_FAINT, &"bold", 2)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(text)
	return row


func _refresh_lobby_controls() -> void:
	var me: int = NetManager.get_local_peer_id()
	var online: bool = NetManager.is_online()
	var my_class: StringName = NetManager.get_class_id(me)
	var my_ready: bool = NetManager.is_ready(me)
	var roster: Dictionary = NetManager.roster
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
			card.set_card_state(is_my_selection, not is_my_selection, occupant_name)
	_ready_button.disabled = not online or my_class == &""
	if _ready_button.button_pressed != my_ready:
		_ready_button.set_pressed_no_signal(my_ready)
		_ready_button.text = tr("Ready") if my_ready else tr("Ready up")
		_ready_button.variant = KitButton.Variant.PRIMARY if my_ready else KitButton.Variant.DEFAULT
		_ready_button.accent = GameTheme.SUCCESS if my_ready else GameTheme.ACCENT
		_ready_button.apply_variant()
	_start_button.visible = NetManager.is_host()
	_start_button.disabled = not NetManager.can_start()
