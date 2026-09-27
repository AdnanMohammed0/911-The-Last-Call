## Station OS — the desktop of the main computer (and of every bought workstation).
## A small windowed desktop with a taskbar: Start menu, one button per open window, the station balance and
## the shift clock. Apps:
##   911 CAD      — the dispatch terminal (calls, records, trace, verdict)
##   StationMart  — buy furniture, computers, security, weapons, armor, vehicles and upgrades (Economy)
##   Bank         — balance, payday countdown, this period's calls and the payslip history
##   My Station   — security rating, morale, salary / mission multipliers, owned items
##   CCTV         — live camera feeds (only once the CCTV System is bought)
##   Inbox        — messages from County HQ (how pay works, paydays)
## Opened by DispatchComputer; Esc (or Start → Log off) closes it.
## Authority: LOCAL (UI) — purchases are requests the host validates in Economy.
class_name StationOS
extends Control

const GROUP: StringName = &"station_os"
const GREEN: Color = Color(0.45, 1.0, 0.6)
const AMBER: Color = Color(1.0, 0.72, 0.25)
const RED: Color = Color(1.0, 0.4, 0.35)
const DIM: Color = Color(0.6, 0.66, 0.7)
const TEXT: Color = Color(0.9, 0.93, 0.95)
const ACCENT: Color = Color(0.25, 0.55, 0.95)
const TASKBAR_HEIGHT: float = 46.0
const APPS: Array[Dictionary] = [
	{"id": &"cad", "name": "911 CAD", "color": Color(0.85, 0.2, 0.2)},
	{"id": &"shop", "name": "StationMart", "color": Color(0.2, 0.7, 0.35)},
	{"id": &"bank", "name": "Bank", "color": Color(0.9, 0.7, 0.2)},
	{"id": &"station", "name": "My Station", "color": Color(0.3, 0.55, 0.95)},
	{"id": &"cctv", "name": "CCTV", "color": Color(0.5, 0.5, 0.55)},
	{"id": &"inbox", "name": "Inbox", "color": Color(0.6, 0.4, 0.9)},
]
## [name, camera position, look-at point] (world space, Station 4).
const CCTV_CAMERAS: Array[Array] = [
	["CAM 1 · ENTRANCE", Vector3(26.6, 3.5, -35.3), Vector3(20.0, 0.8, -41.0)],
	["CAM 2 · LOBBY", Vector3(16.8, 3.9, -32.6), Vector3(26.0, 0.8, -25.5)],
	["CAM 3 · DISPATCH", Vector3(0.8, 3.9, -27.2), Vector3(9.0, 0.8, -19.5)],
	["CAM 4 · CORRIDOR", Vector3(19.2, 3.9, -23.6), Vector3(19.2, 0.8, -4.0)],
	["CAM 5 · ARMORY", Vector3(23.0, 3.9, -5.8), Vector3(34.0, 0.8, -1.0)],
	["CAM 6 · GARAGE", Vector3(39.2, 4.6, -1.0), Vector3(47.0, 0.8, -16.0)],
]

var _desktop: Control
var _windows_layer: Control
var _taskbar_buttons: HBoxContainer
var _start_menu: PanelContainer
var _money_label: Label
var _clock_label: Label
var _windows: Dictionary[StringName, PanelContainer] = {}
var _task_buttons: Dictionary[StringName, Button] = {}
var _closed_player_input: Player = null
var _in_cad: bool = false
var _drag_window: Control = null
var _drag_offset: Vector2 = Vector2.ZERO
var _z_counter: int = 1

# App widgets refreshed on Economy changes.
var _shop_category: String = "Computers"
var _shop_list: VBoxContainer
var _shop_balance: Label
var _shop_status: Label
var _shop_tabs: VBoxContainer
var _bank_balance: Label
var _bank_timer: Label
var _bank_period: RichTextLabel
var _bank_history: RichTextLabel
var _station_text: RichTextLabel
var _inbox_text: RichTextLabel
var _inbox: Array[String] = []


func _ready() -> void:
	add_to_group(GROUP)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	_inbox.append("[b]County HQ — Welcome to Station 4[/b]\nThe station is paid every %d minutes of shift time. Every call you handle pays $%d, and every call you classify [color=#7dff9a]correctly[/color] pays $%d more. Wrong verdicts (-$%d) and missed calls (-$%d) are deducted. Mission payouts are added to the next payday.\nSpend the money in [b]StationMart[/b]: more computers, security, weapons for the armory, armor, vehicles for the garage and comfort items that raise morale (and pay)." % [
		roundi(Economy.PAY_PERIOD_SEC / 60.0), Economy.HANDLED_PAY, Economy.CORRECT_PAY, Economy.WRONG_PENALTY, Economy.MISSED_PENALTY])
	Economy.money_changed.connect(func(_m: int) -> void: _refresh_apps())
	Economy.inventory_changed.connect(_refresh_apps)
	Economy.period_changed.connect(_refresh_apps)
	Economy.purchase_result.connect(_on_purchase_result)
	Economy.payday.connect(_on_payday)


static func find(tree: SceneTree) -> StationOS:
	return tree.get_first_node_in_group(GROUP) as StationOS


# --- Open / close --------------------------------------------------------------------------------

func open() -> void:
	if visible:
		return
	visible = true
	add_to_group(DispatchTerminal.MODAL_GROUP)
	var player: Player = Player.find_by_peer(get_tree(), multiplayer.get_unique_id())
	if player != null:
		player.set_input_enabled(false)
		_closed_player_input = player
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_apps()


func close() -> void:
	if not visible:
		return
	visible = false
	_start_menu.visible = false
	remove_from_group(DispatchTerminal.MODAL_GROUP)
	_set_cctv_active(false)
	if _closed_player_input != null and is_instance_valid(_closed_player_input):
		_closed_player_input.set_input_enabled(true)
	_closed_player_input = null
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		if _start_menu.visible:
			_start_menu.visible = false
		else:
			close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	var minutes: int = CallDirector.shift_clock_minutes
	_clock_label.text = "%02d:%02d" % [minutes / 60, minutes % 60]
	if _bank_timer != null and _windows.has(&"bank") and _windows[&"bank"].visible:
		var left: int = ceili(maxf(Economy.pay_timer, 0.0))
		_bank_timer.text = "Next payday in %d:%02d" % [left / 60, left % 60]


# --- Apps / windows ------------------------------------------------------------------------------

func app_available(app_id: StringName) -> bool:
	if app_id == &"cctv":
		return Economy.owns(&"cctv")
	return true


func open_app(app_id: StringName) -> void:
	_start_menu.visible = false
	if not app_available(app_id):
		_push_inbox("[color=#ffb347]CCTV is not installed. Buy the CCTV System in StationMart.[/color]")
		open_app(&"inbox")
		return
	if app_id == &"cad":
		_launch_cad()
		return
	if not _windows.has(app_id):
		_windows[app_id] = _create_window(app_id)
	var window: PanelContainer = _windows[app_id]
	window.visible = true
	_raise(window)
	if app_id == &"cctv":
		_set_cctv_active(true)
	_refresh_apps()
	_refresh_taskbar()


func close_app(app_id: StringName) -> void:
	if not _windows.has(app_id):
		return
	if app_id == &"cctv":
		_set_cctv_active(false)
	_windows[app_id].queue_free()
	_windows.erase(app_id)
	_refresh_taskbar()


func _toggle_minimize(app_id: StringName) -> void:
	if not _windows.has(app_id):
		return
	var window: PanelContainer = _windows[app_id]
	window.visible = not window.visible
	if app_id == &"cctv":
		_set_cctv_active(window.visible)
	if window.visible:
		_raise(window)


func _launch_cad() -> void:
	var terminal: DispatchTerminal = DispatchTerminal.find(get_tree())
	if terminal == null:
		return
	_in_cad = true
	visible = false
	remove_from_group(DispatchTerminal.MODAL_GROUP)
	if not terminal.closed.is_connected(_on_cad_closed):
		terminal.closed.connect(_on_cad_closed)
	terminal.open()


func _on_cad_closed() -> void:
	if not _in_cad:
		return
	_in_cad = false
	# Back to the desktop; the terminal already gave control back to the player, take it again.
	_closed_player_input = null
	open()


func _raise(window: Control) -> void:
	_z_counter += 1
	window.move_to_front()


func _create_window(app_id: StringName) -> PanelContainer:
	var app: Dictionary = _app(app_id)
	var window: PanelContainer = PanelContainer.new()
	window.name = "Window_%s" % app_id
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12, 0.98)
	style.border_color = _color(app)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 12
	window.add_theme_stylebox_override("panel", style)
	var sizes: Dictionary = {&"shop": Vector2(1080, 700), &"bank": Vector2(720, 640), &"station": Vector2(640, 600),
		&"cctv": Vector2(1180, 560), &"inbox": Vector2(640, 520)}
	window.custom_minimum_size = sizes.get(app_id, Vector2(640, 480))
	var offset: float = 40.0 * (_windows.size() % 6)
	window.position = Vector2(180 + offset, 60 + offset)
	window.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_raise(window))
	_windows_layer.add_child(window)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	window.add_child(column)
	var bar: PanelContainer = PanelContainer.new()
	var bar_style: StyleBoxFlat = StyleBoxFlat.new()
	bar_style.bg_color = _color(app).darkened(0.45)
	bar_style.set_content_margin_all(6)
	bar_style.corner_radius_top_left = 6
	bar_style.corner_radius_top_right = 6
	bar.add_theme_stylebox_override("panel", bar_style)
	bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	bar.gui_input.connect(_on_title_input.bind(window))
	column.add_child(bar)
	var bar_row: HBoxContainer = HBoxContainer.new()
	bar.add_child(bar_row)
	var title: Label = _label(str(app.get("name", "App")), 18, TEXT, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_child(title)
	var minimize: Button = _button(" _ ", _toggle_minimize.bind(app_id))
	bar_row.add_child(minimize)
	var close_button: Button = _button(" X ", close_app.bind(app_id))
	bar_row.add_child(close_button)

	var body: MarginContainer = MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 14)
	column.add_child(body)
	match app_id:
		&"shop":
			body.add_child(_build_shop())
		&"bank":
			body.add_child(_build_bank())
		&"station":
			body.add_child(_build_station())
		&"cctv":
			body.add_child(_build_cctv())
		&"inbox":
			body.add_child(_build_inbox())
	return window


func _on_title_input(event: InputEvent, window: Control) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_drag_window = window
				_drag_offset = window.get_global_mouse_position() - window.position
				_raise(window)
			else:
				_drag_window = null
	elif event is InputEventMouseMotion and _drag_window == window:
		var limit: Vector2 = size - Vector2(120, TASKBAR_HEIGHT + 30)
		window.position = (window.get_global_mouse_position() - _drag_offset).clamp(Vector2(-window.size.x + 120, 0), limit)


func _app(app_id: StringName) -> Dictionary:
	for app: Dictionary in APPS:
		if app["id"] == app_id:
			return app
	return {}


# --- StationMart ---------------------------------------------------------------------------------

func _build_shop() -> Control:
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	var header: HBoxContainer = HBoxContainer.new()
	root.add_child(header)
	var title: Label = _label("STATIONMART · County Police Supply", 22, GREEN, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_shop_balance = _label("", 22, AMBER, false)
	header.add_child(_shop_balance)
	_shop_status = _label("Pick a category, then press Buy. Everything is delivered to the station right away.", 15, DIM)
	root.add_child(_shop_status)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	root.add_child(columns)
	_shop_tabs = VBoxContainer.new()
	_shop_tabs.custom_minimum_size = Vector2(190, 0)
	columns.add_child(_shop_tabs)
	for category: String in ShopCatalog.CATEGORIES:
		var tab: Button = _button(category, _select_category.bind(category))
		tab.toggle_mode = true
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.custom_minimum_size = Vector2(0, 42)
		_shop_tabs.add_child(tab)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	_shop_list = VBoxContainer.new()
	_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_shop_list)
	return root


func _select_category(category: String) -> void:
	_shop_category = category
	_refresh_shop()


func _refresh_shop() -> void:
	if _shop_list == null or not is_instance_valid(_shop_list):
		return
	_shop_balance.text = "Balance  $%s" % _money(Economy.money)
	for tab: Node in _shop_tabs.get_children():
		var button: Button = tab as Button
		button.button_pressed = button.text == _shop_category
	for child: Node in _shop_list.get_children():
		child.queue_free()
	for item: Dictionary in ShopCatalog.items_in(_shop_category):
		_shop_list.add_child(_shop_card(item))


func _shop_card(item: Dictionary) -> Control:
	var item_id: StringName = item["id"]
	var card: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.14, 0.18)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var owned: int = Economy.count_of(item_id)
	var max_count: int = item.get("max", 1)
	var name_text: String = str(item["name"])
	if max_count > 1:
		name_text += "   (%d/%d)" % [owned, max_count]
	text.add_child(_label(name_text, 19, TEXT))
	text.add_child(_label(str(item.get("desc", "")), 14, DIM))
	var weapon_id: StringName = item.get("weapon", &"")
	if weapon_id != &"":
		var data: WeaponData = WeaponCatalog.get_data(weapon_id)
		if data != null:
			var classes: String = "all classes" if data.allowed_classes.is_empty() else ", ".join(PackedStringArray(data.allowed_classes))
			text.add_child(_label("DMG %d%s · MAG %d · %s · rank %s" % [roundi(data.damage), "×%d" % data.pellets if data.pellets > 1 else "",
				data.magazine_size, classes, Career.rank_name(Career.required_rank(weapon_id))], 13, ACCENT.lightened(0.3)))
	var side: VBoxContainer = VBoxContainer.new()
	side.custom_minimum_size = Vector2(150, 0)
	row.add_child(side)
	var price: int = item.get("price", 0)
	side.add_child(_label("FREE" if price == 0 else "$%s" % _money(price), 20, AMBER))
	var reason: String = Economy.purchase_block_reason(item_id)
	var buy: Button = _button("Buy", Economy.request_purchase.bind(item_id))
	if item.get("starter", false):
		buy.text = "Standard issue"
		buy.disabled = true
	elif reason == "Already owned" or reason == "Station is full":
		buy.text = "Owned" if reason == "Already owned" else "Max owned"
		buy.disabled = true
	elif reason != "":
		buy.text = reason
		buy.disabled = true
	side.add_child(buy)
	return card


func _on_purchase_result(ok: bool, item_id: StringName, message: String) -> void:
	var item: Dictionary = ShopCatalog.get_item(item_id)
	if _shop_status != null and is_instance_valid(_shop_status):
		_shop_status.text = ("✔ %s delivered to the station." % item.get("name", item_id)) if ok else ("✖ %s: %s" % [item.get("name", item_id), message])
		_shop_status.add_theme_color_override("font_color", GREEN if ok else RED)
	if ok:
		_push_inbox("[color=#7dff9a]Delivery:[/color] %s installed at the station." % item.get("name", item_id))


# --- Bank ----------------------------------------------------------------------------------------

func _build_bank() -> Control:
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.add_child(_label("BLACKVALE COUNTY CREDIT UNION · Station 4 account", 18, DIM))
	_bank_balance = _label("", 40, GREEN)
	root.add_child(_bank_balance)
	_bank_timer = _label("", 18, AMBER)
	root.add_child(_bank_timer)
	root.add_child(HSeparator.new())
	root.add_child(_label("THIS PAY PERIOD", 15, DIM))
	_bank_period = _rich(170)
	root.add_child(_bank_period)
	root.add_child(_label("PAYSLIPS", 15, DIM))
	_bank_history = _rich(0)
	_bank_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_bank_history)
	return root


func _refresh_bank() -> void:
	if _bank_balance == null or not is_instance_valid(_bank_balance):
		return
	_bank_balance.text = "$%s" % _money(Economy.money)
	var slip: Dictionary = Economy.estimate_payslip()
	_bank_period.clear()
	_bank_period.append_text("Calls handled [b]%d[/b] · correct [color=#7dff9a]%d[/color] · wrong [color=#ff6b5e]%d[/color] · missed [color=#ff6b5e]%d[/color]\n" % [
		slip["calls"], slip["correct"], slip["wrong"], slip["missed"]])
	var lines: PackedStringArray = slip["lines"]
	for line: String in lines:
		_bank_period.append_text("  %s\n" % line)
	_bank_period.append_text("[color=#ffb347]Estimated payday: $%s[/color]" % _money(_int(slip["total"])))
	_bank_history.clear()
	if Economy.payslips.is_empty():
		_bank_history.append_text("[color=#8a9]No paydays yet this career.[/color]")
	for i: int in range(Economy.payslips.size() - 1, -1, -1):
		var past: Dictionary = Economy.payslips[i]
		var minute: int = past.get("shift_minute", 0)
		_bank_history.append_text("[b]Payday #%d[/b]  (shift %02d:%02d)  [color=#7dff9a]+$%s[/color]  ·  %d calls, %d correct\n" % [
			past.get("number", i + 1), minute / 60, minute % 60, _money(_int(past.get("total", 0))), past.get("calls", 0), past.get("correct", 0)])


# --- My Station ----------------------------------------------------------------------------------

func _build_station() -> Control:
	_station_text = _rich(0)
	_station_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return _station_text


func _refresh_station() -> void:
	if _station_text == null or not is_instance_valid(_station_text):
		return
	_station_text.clear()
	_station_text.append_text("[font_size=22][color=#7dff9a]STATION 4 · STATUS[/color][/font_size]\n\n")
	_station_text.append_text("Security rating   [b]%d[/b]\n" % Economy.security_rating())
	_station_text.append_text("Staff morale      [b]+%d%%[/b]\n" % roundi(Economy.morale_bonus() * 100.0))
	_station_text.append_text("Salary multiplier [b]×%.2f[/b]\n" % Economy.salary_multiplier())
	_station_text.append_text("Mission payouts   [b]×%.2f[/b]\n" % Economy.mission_multiplier())
	_station_text.append_text("Caller patience   [b]×%.2f[/b]\n\n" % Economy.patience_multiplier())
	_station_text.append_text("[color=#ffb347]OWNED[/color]\n")
	for category: String in ShopCatalog.CATEGORIES:
		var names: PackedStringArray = PackedStringArray()
		for item: Dictionary in ShopCatalog.items_in(category):
			var count: int = Economy.count_of(StringName(str(item["id"])))
			if count > 0:
				names.append(str(item["name"]) + (" ×%d" % count if count > 1 else ""))
		if not names.is_empty():
			_station_text.append_text("[b]%s:[/b] %s\n" % [category, ", ".join(names)])


# --- CCTV ----------------------------------------------------------------------------------------

func _build_cctv() -> Control:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for feed: Array in CCTV_CAMERAS:
		var cell: VBoxContainer = VBoxContainer.new()
		grid.add_child(cell)
		var container: SubViewportContainer = SubViewportContainer.new()
		container.stretch = true
		container.custom_minimum_size = Vector2(368, 207)
		cell.add_child(container)
		var viewport: SubViewport = SubViewport.new()
		viewport.size = Vector2i(368, 207)
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		container.add_child(viewport)
		var camera: Camera3D = Camera3D.new()
		camera.fov = 80.0
		camera.current = true
		viewport.add_child(camera)
		var at: Vector3 = feed[1]
		var target: Vector3 = feed[2]
		camera.position = at
		camera.basis = Basis.looking_at(target - at, Vector3.UP)
		var feed_name: String = feed[0]
		cell.add_child(_label("● REC  " + feed_name, 13, RED))
	return grid


func _set_cctv_active(active: bool) -> void:
	if not _windows.has(&"cctv"):
		return
	for viewport: Node in _windows[&"cctv"].find_children("*", "SubViewport", true, false):
		(viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED


# --- Inbox ---------------------------------------------------------------------------------------

func _build_inbox() -> Control:
	_inbox_text = _rich(0)
	_inbox_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return _inbox_text


func _push_inbox(bbcode: String) -> void:
	_inbox.append(bbcode)
	while _inbox.size() > 40:
		_inbox.remove_at(1)
	_refresh_inbox()


func _refresh_inbox() -> void:
	if _inbox_text == null or not is_instance_valid(_inbox_text):
		return
	_inbox_text.clear()
	for i: int in range(_inbox.size() - 1, -1, -1):
		_inbox_text.append_text(_inbox[i] + "\n\n")


func _on_payday(slip: Dictionary) -> void:
	var lines: PackedStringArray = slip.get("lines", PackedStringArray())
	_push_inbox("[b]Payday #%d — [color=#7dff9a]+$%s[/color][/b]\n%s" % [slip.get("number", 0), _money(_int(slip.get("total", 0))), "\n".join(lines)])


# --- Refresh -------------------------------------------------------------------------------------

func _refresh_apps() -> void:
	if _money_label != null:
		_money_label.text = "$%s" % _money(Economy.money)
	_refresh_shop()
	_refresh_bank()
	_refresh_station()
	_refresh_inbox()
	_refresh_desktop_icons()


func _refresh_taskbar() -> void:
	for child: Node in _taskbar_buttons.get_children():
		child.queue_free()
	_task_buttons.clear()
	for app_id: StringName in _windows:
		var app: Dictionary = _app(app_id)
		var button: Button = _button("  %s  " % app.get("name", app_id), _toggle_minimize.bind(app_id))
		_taskbar_buttons.add_child(button)
		_task_buttons[app_id] = button


func _refresh_desktop_icons() -> void:
	for icon: Node in _desktop.get_children():
		if icon.has_meta(&"app"):
			var app_id: StringName = icon.get_meta(&"app")
			(icon as Control).modulate.a = 1.0 if app_available(app_id) else 0.35


# --- Layout --------------------------------------------------------------------------------------

func _build() -> void:
	var wallpaper: ColorRect = ColorRect.new()
	wallpaper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wallpaper.color = Color(0.04, 0.09, 0.16)
	add_child(wallpaper)
	var brand: Label = _label("BLACKVALE COUNTY SHERIFF · STATION 4\nStation OS 4.11", 30, Color(0.3, 0.45, 0.65, 0.5))
	brand.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.offset_left = -400
	brand.offset_right = 400
	brand.offset_top = -60
	brand.offset_bottom = 60
	add_child(brand)

	_desktop = Control.new()
	_desktop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desktop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_desktop)
	for i: int in APPS.size():
		var app: Dictionary = APPS[i]
		var icon: Button = Button.new()
		icon.flat = true
		icon.custom_minimum_size = Vector2(104, 96)
		icon.position = Vector2(24, 24 + i * 108)
		icon.set_meta(&"app", app["id"])
		var app_id: StringName = app["id"]
		icon.pressed.connect(open_app.bind(app_id))
		var box: VBoxContainer = VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		icon.add_child(box)
		var tile: ColorRect = ColorRect.new()
		tile.color = _color(app)
		tile.custom_minimum_size = Vector2(52, 52)
		tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tile)
		var letter: Label = _label(str(app["name"]).substr(0, 1), 28, Color.WHITE)
		letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tile.add_child(letter)
		var caption: Label = _label(str(app["name"]), 15, TEXT)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(caption)
		_desktop.add_child(icon)

	_windows_layer = Control.new()
	_windows_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_windows_layer.offset_bottom = -TASKBAR_HEIGHT
	_windows_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_windows_layer)

	# Taskbar
	var taskbar: PanelContainer = PanelContainer.new()
	taskbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	taskbar.offset_top = -TASKBAR_HEIGHT
	taskbar.offset_bottom = 0
	var bar_style: StyleBoxFlat = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.03, 0.04, 0.06, 0.97)
	bar_style.border_color = Color(0.2, 0.3, 0.45)
	bar_style.border_width_top = 1
	bar_style.set_content_margin_all(5)
	taskbar.add_theme_stylebox_override("panel", bar_style)
	add_child(taskbar)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	taskbar.add_child(row)
	var start: Button = _button("  ◆ START  ", func() -> void: _start_menu.visible = not _start_menu.visible)
	start.add_theme_color_override("font_color", GREEN)
	row.add_child(start)
	row.add_child(VSeparator.new())
	for app: Dictionary in APPS:
		var app_id: StringName = app["id"]
		if app_id == &"cad" or app_id == &"shop" or app_id == &"bank":
			var pin: Button = _button(str(app["name"]), open_app.bind(app_id))
			pin.add_theme_color_override("font_color", _color(app).lightened(0.3))
			row.add_child(pin)
	row.add_child(VSeparator.new())
	_taskbar_buttons = HBoxContainer.new()
	_taskbar_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_taskbar_buttons)
	_money_label = _label("$0", 20, GREEN, false)
	row.add_child(_money_label)
	row.add_child(VSeparator.new())
	_clock_label = _label("00:00", 20, AMBER, false)
	row.add_child(_clock_label)
	var close_button: Button = _button("  Log off [Esc]  ", close)
	row.add_child(close_button)

	# Start menu
	_start_menu = PanelContainer.new()
	_start_menu.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_start_menu.visible = false
	var menu_style: StyleBoxFlat = StyleBoxFlat.new()
	menu_style.bg_color = Color(0.06, 0.08, 0.11, 0.98)
	menu_style.border_color = ACCENT
	menu_style.set_border_width_all(1)
	menu_style.set_content_margin_all(10)
	_start_menu.add_theme_stylebox_override("panel", menu_style)
	add_child(_start_menu)
	var menu: VBoxContainer = VBoxContainer.new()
	menu.custom_minimum_size = Vector2(260, 0)
	_start_menu.add_child(menu)
	menu.add_child(_label("STATION OS", 16, DIM))
	for app: Dictionary in APPS:
		var app_id: StringName = app["id"]
		var entry: Button = _button(str(app["name"]), open_app.bind(app_id))
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		menu.add_child(entry)
	menu.add_child(HSeparator.new())
	menu.add_child(_button("Log off", close))
	_start_menu.resized.connect(func() -> void:
		_start_menu.position = Vector2(4, size.y - TASKBAR_HEIGHT - _start_menu.size.y - 4))


func _label(text: String, font_size: int, colour: Color, wrap: bool = true) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _rich(min_height: float) -> RichTextLabel:
	var rich: RichTextLabel = RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.custom_minimum_size = Vector2(0, min_height)
	rich.add_theme_font_size_override("normal_font_size", 16)
	rich.add_theme_font_size_override("bold_font_size", 16)
	return rich


func _button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 34)
	button.pressed.connect(callback)
	return button


static func _int(value: Variant) -> int:
	var number: int = value
	return number


static func _color(app: Dictionary) -> Color:
	var colour: Color = app.get("color", ACCENT)
	return colour


static func _money(amount: int) -> String:
	var digits: String = str(absi(amount))
	var out: String = ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + out
