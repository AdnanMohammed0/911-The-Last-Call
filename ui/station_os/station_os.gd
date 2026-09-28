## Station OS — the desktop of the main computer (and of every bought workstation), styled after Windows 11:
## animated "Bloom" wallpaper, desktop icons, a centred acrylic taskbar (Start, search, pinned apps with
## running indicators, tray with Wi-Fi / volume / battery, balance and the shift clock), a centred Start
## menu (search, pinned grid, recommended, profile + power), rounded Mica windows with open / close
## animations, drag, maximize (button or double-click) and toast notifications.
## Apps:
##   911 CAD      — the dispatch terminal (calls, records, trace, verdict)
##   StationMart  — store: furniture, computers, security, weapons, armor, vehicles, upgrades (Economy)
##   Bank         — balance, payday countdown, this period's calls and the payslip history
##   My Station   — security rating, morale, salary / mission multipliers, owned items
##   CCTV         — live camera feeds (only once the CCTV System is bought)
##   Inbox        — messages from County HQ (how pay works, paydays, deliveries)
## Opened by DispatchComputer; Esc (or Start → Power → Log off) closes it.
## Authority: LOCAL (UI) — purchases are requests the host validates in Economy.
class_name StationOS
extends Control

signal closed()

const GROUP: StringName = &"station_os"
const WALLPAPER: Shader = preload("res://ui/shaders/win11_wallpaper.gdshader")
const SCREEN_FX: Shader = preload("res://ui/shaders/screen_fx.gdshader")
const GREEN: Color = Color(0.42, 0.9, 0.55)
const AMBER: Color = Color(1.0, 0.74, 0.3)
const RED: Color = Color(1.0, 0.4, 0.36)
const DIM: Color = Color(0.72, 0.75, 0.8)
const FAINT: Color = Color(0.55, 0.58, 0.63)
const TEXT: Color = Color(0.96, 0.97, 0.98)
const WIN_BLUE: Color = Color(0.3, 0.6, 1.0)
const TASKBAR_HEIGHT: float = 52.0
const WINDOW_RADIUS: int = 10
const APPS: Array[Dictionary] = [
	{"id": &"cad", "name": "911 CAD", "icon": &"siren", "color": Color(0.95, 0.3, 0.28)},
	{"id": &"shop", "name": "StationMart", "icon": &"cart", "color": Color(0.3, 0.82, 0.5)},
	{"id": &"bank", "name": "Bank", "icon": &"bank", "color": Color(1.0, 0.76, 0.3)},
	{"id": &"station", "name": "My Station", "icon": &"shield", "color": Color(0.36, 0.62, 1.0)},
	{"id": &"cctv", "name": "CCTV", "icon": &"camera", "color": Color(0.75, 0.78, 0.84)},
	{"id": &"inbox", "name": "Inbox", "icon": &"mail", "color": Color(0.65, 0.5, 1.0)},
]
const CATEGORY_ICONS: Dictionary[String, StringName] = {
	"Computers": &"monitor", "Security": &"shield", "Weapons": &"gun", "Armor": &"badge", "Medical": &"medkit",
	"Break Room": &"coffee", "Vehicles": &"car", "Upgrades": &"trophy",
}
## [name, camera position, look-at point] (world space, Station 4).
const CCTV_CAMERAS: Array[Array] = [
	["CAM 1 · ENTRANCE", Vector3(26.6, 3.5, -35.3), Vector3(20.0, 0.8, -41.0)],
	["CAM 2 · LOBBY", Vector3(16.8, 3.9, -32.6), Vector3(26.0, 0.8, -25.5)],
	["CAM 3 · DISPATCH", Vector3(0.8, 3.9, -27.2), Vector3(9.0, 0.8, -19.5)],
	["CAM 4 · CORRIDOR", Vector3(19.2, 3.9, -23.6), Vector3(19.2, 0.8, -4.0)],
	["CAM 5 · ARMORY", Vector3(23.0, 3.9, -5.8), Vector3(34.0, 0.8, -1.0)],
	["CAM 6 · GARAGE", Vector3(39.2, 4.6, -1.0), Vector3(47.0, 0.8, -16.0)],
]
const WINDOW_SIZES: Dictionary[StringName, Vector2] = {
	&"shop": Vector2(1180, 760), &"bank": Vector2(820, 680), &"station": Vector2(820, 640),
	&"cctv": Vector2(1220, 640), &"inbox": Vector2(860, 620),
}

var _desktop: Control
var _windows_layer: Control
var _toasts: VBoxContainer
var _taskbar_apps: HBoxContainer
var _start_menu: PanelContainer
var _start_search: LineEdit
var _start_grid: GridContainer
var _start_recent: VBoxContainer
var _money_label: Label
var _clock_label: Label
var _date_label: Label
var _windows: Dictionary[StringName, PanelContainer] = {}
var _maximized: Dictionary[StringName, Rect2] = {}
var _task_buttons: Dictionary[StringName, TaskbarButton] = {}
var _is_open: bool = false
var _closed_player_input: Player = null
var _in_cad: bool = false
var _drag_window: Control = null
var _drag_offset: Vector2 = Vector2.ZERO
var _last_title_click: int = 0

# App widgets refreshed on Economy changes.
var _shop_category: String = "Computers"
var _shop_grid: GridContainer
var _shop_balance: Label
var _shop_status: Label
var _shop_tabs: VBoxContainer
var _shop_search: String = ""
var _bank_balance: Label
var _bank_timer: Label
var _bank_ring: PaydayRing
var _bank_period: VBoxContainer
var _bank_history: VBoxContainer
var _station_tiles: GridContainer
var _station_owned: VBoxContainer
var _inbox_list: VBoxContainer
var _inbox: Array[String] = []


func _ready() -> void:
	add_to_group(GROUP)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	theme = GameSettings.ui_theme
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
	_is_open = true
	visible = true
	add_to_group(DispatchTerminal.MODAL_GROUP)
	var player: Player = Player.find_by_peer(get_tree(), multiplayer.get_unique_id())
	if player != null:
		player.set_input_enabled(false)
		_closed_player_input = player
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_apps()
	if is_inside_tree() and DisplayServer.get_name() != "headless":
		modulate.a = 0.0
		scale = Vector2(1.02, 1.02)
		pivot_offset = size * 0.5
		var tween: Tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "modulate:a", 1.0, 0.25)
		tween.tween_property(self, "scale", Vector2.ONE, 0.3)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_start_menu.visible = false
	remove_from_group(DispatchTerminal.MODAL_GROUP)
	_set_cctv_active(false)
	if _closed_player_input != null and is_instance_valid(_closed_player_input):
		_closed_player_input.set_input_enabled(true)
	_closed_player_input = null
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func is_open() -> bool:
	return _is_open


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		if _start_menu.visible:
			_toggle_start(false)
		else:
			close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_META:
		_toggle_start(not _start_menu.visible)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	var minutes: int = CallDirector.shift_clock_minutes
	_clock_label.text = "%02d:%02d" % [minutes / 60, minutes % 60]
	if _bank_timer != null and is_instance_valid(_bank_timer) and _windows.has(&"bank") and _windows[&"bank"].visible:
		var left: int = ceili(maxf(Economy.pay_timer, 0.0))
		_bank_timer.text = "%d:%02d" % [left / 60, left % 60]
		_bank_ring.ratio = 1.0 - clampf(Economy.pay_timer / maxf(Economy.PAY_PERIOD_SEC, 1.0), 0.0, 1.0)
		_bank_ring.queue_redraw()


# --- Apps / windows ------------------------------------------------------------------------------

func app_available(app_id: StringName) -> bool:
	if app_id == &"cctv":
		return Economy.owns(&"cctv")
	return true


func open_app(app_id: StringName) -> void:
	_toggle_start(false)
	if not app_available(app_id):
		_toast(&"camera", "CCTV not installed", "Buy the CCTV System in StationMart to unlock live feeds.", AMBER)
		_push_inbox("[color=#ffb347]CCTV is not installed. Buy the CCTV System in StationMart.[/color]")
		open_app(&"shop")
		return
	if app_id == &"cad":
		_launch_cad()
		return
	var fresh: bool = not _windows.has(app_id)
	if fresh:
		_windows[app_id] = _create_window(app_id)
	var window: PanelContainer = _windows[app_id]
	window.visible = true
	_raise(window)
	if app_id == &"cctv":
		_set_cctv_active(true)
	_refresh_apps()
	_refresh_taskbar()
	if fresh:
		_animate_open(window)


func close_app(app_id: StringName) -> void:
	if not _windows.has(app_id):
		return
	if app_id == &"cctv":
		_set_cctv_active(false)
	var window: PanelContainer = _windows[app_id]
	_windows.erase(app_id)
	_maximized.erase(app_id)
	_refresh_taskbar()
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		window.queue_free()
		return
	window.pivot_offset = window.size * 0.5
	var tween: Tween = window.create_tween().set_parallel().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(window, "modulate:a", 0.0, 0.14)
	tween.tween_property(window, "scale", Vector2(0.94, 0.94), 0.14)
	tween.chain().tween_callback(window.queue_free)


func _toggle_minimize(app_id: StringName) -> void:
	if not _windows.has(app_id):
		return
	var window: PanelContainer = _windows[app_id]
	# Clicking the taskbar button of a background window brings it forward instead of minimizing.
	if window.visible and window.get_index() != _windows_layer.get_child_count() - 1:
		_raise(window)
		return
	window.visible = not window.visible
	if app_id == &"cctv":
		_set_cctv_active(window.visible)
	if window.visible:
		_raise(window)
		_animate_open(window)
	_refresh_taskbar()


func _toggle_maximize(app_id: StringName) -> void:
	if not _windows.has(app_id):
		return
	var window: PanelContainer = _windows[app_id]
	if _maximized.has(app_id):
		var rect: Rect2 = _maximized[app_id]
		_maximized.erase(app_id)
		window.position = rect.position
		window.size = rect.size
		window.custom_minimum_size = rect.size
	else:
		_maximized[app_id] = Rect2(window.position, window.size)
		window.position = Vector2(6, 6)
		window.custom_minimum_size = _windows_layer.size - Vector2(12, 12)
		window.size = window.custom_minimum_size


func _animate_open(window: Control) -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	window.pivot_offset = window.custom_minimum_size * 0.5
	window.modulate.a = 0.0
	window.scale = Vector2(0.94, 0.94)
	var tween: Tween = window.create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(window, "modulate:a", 1.0, 0.18)
	tween.tween_property(window, "scale", Vector2.ONE, 0.26)


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
	window.move_to_front()
	_refresh_taskbar()


func _create_window(app_id: StringName) -> PanelContainer:
	var app: Dictionary = _app(app_id)
	var window: PanelContainer = PanelContainer.new()
	window.name = "Window_%s" % app_id
	UiKit.apply_glass(window, Color(0.1, 0.11, 0.13), WINDOW_RADIUS, 0, 0, 0.9, 4.0, Color(1, 1, 1, 0.12))
	var size_hint: Vector2 = WINDOW_SIZES.get(app_id, Vector2(720, 520))
	var available: Vector2 = size - Vector2(40, TASKBAR_HEIGHT + 40) if size.x > 0.0 else size_hint
	window.custom_minimum_size = size_hint.min(available.max(Vector2(480, 360)))
	var offset: float = 36.0 * (_windows.size() % 5)
	var free_space: Vector2 = (size - Vector2(0, TASKBAR_HEIGHT) - window.custom_minimum_size) * 0.5
	window.position = free_space.max(Vector2(20, 20)) + Vector2(offset, offset) - Vector2(60, 40)
	window.position = window.position.max(Vector2(12, 12))
	window.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_raise(window))
	_windows_layer.add_child(window)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	window.add_child(column)
	# Title bar (Mica) with app icon, title and caption buttons.
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override(&"panel", UiKit.style(Color(0, 0, 0, 0), 0, 14, 0))
	bar.custom_minimum_size = Vector2(0, 44)
	bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	bar.gui_input.connect(_on_title_input.bind(window, app_id))
	column.add_child(bar)
	var bar_row: HBoxContainer = HBoxContainer.new()
	bar_row.add_theme_constant_override(&"separation", 10)
	bar.add_child(bar_row)
	var icon: IconView = IconView.make(_icon_of(app), 16, _color(app))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(icon)
	var title: Label = _label(str(app.get("name", "App")), 14, TEXT, &"regular")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(title)
	for caption: Array in [[&"minimize", _toggle_minimize.bind(app_id), false], [&"maximize", _toggle_maximize.bind(app_id), false],
			[&"close", close_app.bind(app_id), true]]:
		var icon_name: StringName = caption[0]
		var callback: Callable = caption[1]
		var danger: bool = caption[2]
		bar_row.add_child(_caption_button(icon_name, callback, danger))

	var body: MarginContainer = MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"margin_left", 20)
	body.add_theme_constant_override(&"margin_right", 20)
	body.add_theme_constant_override(&"margin_top", 6)
	body.add_theme_constant_override(&"margin_bottom", 18)
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


func _caption_button(icon_name: StringName, callback: Callable, danger: bool) -> Button:
	var button: KitButton = KitButton.make("", icon_name, KitButton.Variant.GHOST, callback)
	button.icon_size = 14.0
	button.custom_minimum_size = Vector2(46, 32)
	button.focus_mode = Control.FOCUS_NONE
	if danger:
		button.mouse_entered.connect(func() -> void:
			button.add_theme_stylebox_override(&"hover", UiKit.style(Color(0.9, 0.17, 0.14), 6, 0, 0)))
	return button


func _on_title_input(event: InputEvent, window: Control, app_id: StringName) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				var now: int = Time.get_ticks_msec()
				if button.double_click or now - _last_title_click < 300:
					_toggle_maximize(app_id)
					_drag_window = null
					return
				_last_title_click = now
				_drag_window = window
				_drag_offset = window.get_global_mouse_position() - window.position
				_raise(window)
			else:
				_drag_window = null
	elif event is InputEventMouseMotion and _drag_window == window:
		if _maximized.has(app_id):
			_toggle_maximize(app_id)
			_drag_offset = Vector2(window.size.x * 0.5, 20)
		var limit: Vector2 = _windows_layer.size - Vector2(120, 40)
		window.position = (window.get_global_mouse_position() - _drag_offset).clamp(Vector2(-window.size.x + 120, 0), limit)


func _app(app_id: StringName) -> Dictionary:
	for app: Dictionary in APPS:
		if app["id"] == app_id:
			return app
	return {}


# --- StationMart ---------------------------------------------------------------------------------

func _build_shop() -> Control:
	var root: HBoxContainer = HBoxContainer.new()
	root.add_theme_constant_override(&"separation", 18)
	# Navigation rail.
	_shop_tabs = VBoxContainer.new()
	_shop_tabs.custom_minimum_size = Vector2(200, 0)
	_shop_tabs.add_theme_constant_override(&"separation", 4)
	root.add_child(_shop_tabs)
	var search: LineEdit = LineEdit.new()
	search.placeholder_text = "Search StationMart"
	search.custom_minimum_size = Vector2(0, 38)
	search.add_theme_font_size_override(&"font_size", 15)
	search.text_changed.connect(func(text: String) -> void:
		_shop_search = text.strip_edges().to_lower()
		_refresh_shop())
	_shop_tabs.add_child(search)
	_shop_tabs.add_child(UiKit.spacer(6))
	for category: String in ShopCatalog.CATEGORIES:
		var tab: KitButton = KitButton.make(category, _cat_icon(category), KitButton.Variant.GHOST, _select_category.bind(category))
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.custom_minimum_size = Vector2(0, 40)
		tab.set_meta(&"category", category)
		tab.add_theme_font_size_override(&"font_size", 15)
		tab.add_theme_font_override(&"font", GameTheme.font(&"medium"))
		_shop_tabs.add_child(tab)

	var main: VBoxContainer = VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override(&"separation", 12)
	root.add_child(main)
	# Hero banner.
	var hero: PanelContainer = PanelContainer.new()
	var hero_style: StyleBoxFlat = UiKit.style(Color(0.14, 0.32, 0.22), 12, 22, 16)
	hero_style.bg_color = Color(0.1, 0.3, 0.2)
	hero_style.border_color = Color(0.4, 0.95, 0.6, 0.25)
	hero_style.set_border_width_all(1)
	hero.add_theme_stylebox_override(&"panel", hero_style)
	main.add_child(hero)
	var hero_row: HBoxContainer = HBoxContainer.new()
	hero_row.add_theme_constant_override(&"separation", 16)
	hero.add_child(hero_row)
	hero_row.add_child(IconView.make(&"cart", 40, GREEN))
	var hero_text: VBoxContainer = VBoxContainer.new()
	hero_text.add_theme_constant_override(&"separation", -2)
	hero_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_row.add_child(hero_text)
	hero_text.add_child(_label("StationMart", 26, TEXT, &"bold"))
	hero_text.add_child(_label("County Police Supply · delivered to the station instantly", 14, Color(0.8, 0.95, 0.85), &"regular"))
	var balance_box: VBoxContainer = VBoxContainer.new()
	balance_box.add_theme_constant_override(&"separation", -4)
	hero_row.add_child(balance_box)
	var caption: Label = UiKit.caps("Station balance", 10, Color(0.8, 0.95, 0.85), &"bold", 2)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balance_box.add_child(caption)
	_shop_balance = _label("$0", 30, TEXT, &"black")
	_shop_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balance_box.add_child(_shop_balance)
	_shop_status = _label("Pick a category, then buy. Everything appears in the station right away.", 14, DIM, &"regular")
	main.add_child(_shop_status)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	_shop_grid = GridContainer.new()
	_shop_grid.columns = 3
	_shop_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_grid.add_theme_constant_override(&"h_separation", 12)
	_shop_grid.add_theme_constant_override(&"v_separation", 12)
	scroll.add_child(_shop_grid)
	return root


func _select_category(category: String) -> void:
	_shop_category = category
	_refresh_shop()


func _refresh_shop() -> void:
	if _shop_grid == null or not is_instance_valid(_shop_grid):
		return
	_shop_balance.text = "$%s" % _money(Economy.money)
	for tab: Node in _shop_tabs.get_children():
		var button: KitButton = tab as KitButton
		if button == null:
			continue
		var active: bool = str(button.get_meta(&"category", "")) == _shop_category and _shop_search.is_empty()
		button.variant = KitButton.Variant.SUBTLE if active else KitButton.Variant.GHOST
		button.icon_tint = GREEN if active else Color(0, 0, 0, 0)
		button.apply_variant()
	for child: Node in _shop_grid.get_children():
		child.queue_free()
	var items: Array[Dictionary] = []
	if _shop_search.is_empty():
		items = ShopCatalog.items_in(_shop_category)
	else:
		for item: Dictionary in ShopCatalog.ITEMS:
			var haystack: String = (str(item.get("name", "")) + " " + str(item.get("desc", "")) + " " + str(item.get("category", ""))).to_lower()
			if _shop_search in haystack:
				items.append(item)
	for item: Dictionary in items:
		_shop_grid.add_child(_shop_card(item))


func _shop_card(item: Dictionary) -> Control:
	var item_id: StringName = item["id"]
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override(&"panel", UiKit.style(Color(1, 1, 1, 0.05), 10, 0, 0, Color(1, 1, 1, 0.07), 1))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 330)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	card.add_child(column)
	# Product photo on a soft gradient stage.
	var stage: PanelContainer = PanelContainer.new()
	var stage_style: StyleBoxFlat = UiKit.style(Color(0.16, 0.18, 0.22), 0, 0, 0)
	stage_style.corner_radius_top_left = 9
	stage_style.corner_radius_top_right = 9
	stage.add_theme_stylebox_override(&"panel", stage_style)
	stage.custom_minimum_size = Vector2(0, 150)
	column.add_child(stage)
	var category: String = str(item.get("category", ""))
	var placeholder: IconView = IconView.make(_cat_icon(category), 54, Color(1, 1, 1, 0.25))
	placeholder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	placeholder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stage.add_child(placeholder)
	var photo: TextureRect = TextureRect.new()
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(UiKit.margin(photo, 12, 10, 12, 10))
	var texture: Texture2D = _product_photo(item, func(tex: Texture2D) -> void:
		if is_instance_valid(photo):
			photo.texture = tex
			placeholder.visible = false)
	if texture != null:
		photo.texture = texture
		placeholder.visible = false
	var owned: int = Economy.count_of(item_id)
	var max_count: int = item.get("max", 1)
	if owned > 0:
		var badge: PanelContainer = UiKit.pill("Owned %d/%d" % [owned, max_count] if max_count > 1 else "Owned", GREEN, true, 10)
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		badge.position = Vector2(10, 10)
		stage.add_child(badge)
		badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var info: VBoxContainer = VBoxContainer.new()
	info.add_theme_constant_override(&"separation", 4)
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(UiKit.margin(info, 14, 12, 14, 14))
	(info.get_parent() as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(UiKit.caps(category, 10, FAINT, &"bold", 2))
	info.add_child(_label(str(item["name"]), 17, TEXT, &"semibold"))
	var desc: Label = _label(str(item.get("desc", "")), 13, DIM, &"regular")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(0, 34)
	info.add_child(desc)
	var weapon_id: StringName = item.get("weapon", &"")
	if weapon_id != &"":
		var data: WeaponData = WeaponCatalog.get_data(weapon_id)
		if data != null:
			var classes: String = "All classes" if data.allowed_classes.is_empty() else ", ".join(PackedStringArray(data.allowed_classes)).capitalize()
			info.add_child(_label("DMG %d%s · MAG %d · %s · %s" % [roundi(data.damage), "×%d" % data.pellets if data.pellets > 1 else "",
				data.magazine_size, classes, Career.rank_name(Career.required_rank(weapon_id))], 12, WIN_BLUE.lightened(0.3), &"medium"))
	info.add_child(UiKit.expand(Control.new(), false, true))
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 8)
	info.add_child(footer)
	var price: int = item.get("price", 0)
	var price_label: Label = _label("Free" if price == 0 else "$%s" % _money(price), 20, TEXT, &"bold")
	price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(price_label)
	var reason: String = Economy.purchase_block_reason(item_id)
	var buy: KitButton = KitButton.make("Buy", &"cart", KitButton.Variant.PRIMARY, Economy.request_purchase.bind(item_id))
	buy.accent = WIN_BLUE
	buy.icon_size = 15.0
	buy.custom_minimum_size = Vector2(110, 36)
	if item.get("starter", false):
		buy.text = "Standard issue"
		buy.icon_name = &"check"
		buy.disabled = true
	elif reason == "Already owned" or reason == "Station is full":
		buy.text = "Owned" if reason == "Already owned" else "Max owned"
		buy.icon_name = &"check"
		buy.disabled = true
	elif reason != "":
		buy.text = reason
		buy.icon_name = &"lock"
		buy.disabled = true
	footer.add_child(buy)
	return card


## Rendered photo of the item as it looks in the station (weapons: the gun; everything else: the build).
func _product_photo(item: Dictionary, on_ready: Callable) -> Texture2D:
	if not is_inside_tree():
		return null
	var item_id: StringName = item["id"]
	var weapon_id: StringName = item.get("weapon", &"")
	if weapon_id != &"":
		var data: WeaponData = WeaponCatalog.get_data(weapon_id)
		if data != null:
			return IconStudio.weapon(get_tree(), data.get_model_id(), on_ready)
	var view: Vector3 = Vector3(0.9, 0.55, 1.0)
	if item_id in [&"cruiser", &"swat_van", &"ambulance"]:
		view = Vector3(1.0, 0.45, 0.7)
	return IconStudio.request(get_tree(), StringName("shop_%s" % item_id), func() -> Node3D:
		return StationFurniture.preview(item_id), on_ready, view)


func _on_purchase_result(ok: bool, item_id: StringName, message: String) -> void:
	var item: Dictionary = ShopCatalog.get_item(item_id)
	var item_name: String = str(item.get("name", item_id))
	if _shop_status != null and is_instance_valid(_shop_status):
		_shop_status.text = ("%s delivered to the station." % item_name) if ok else ("%s: %s" % [item_name, message])
		_shop_status.add_theme_color_override(&"font_color", GREEN if ok else RED)
	if ok:
		_push_inbox("[color=#7dff9a]Delivery:[/color] %s installed at the station." % item_name)
		_toast(&"box", "Order delivered", "%s is now installed at the station." % item_name, GREEN)
	else:
		_toast(&"alert", "Order declined", "%s — %s" % [item_name, message], RED)


# --- Bank ----------------------------------------------------------------------------------------

func _build_bank() -> Control:
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 14)
	# Balance card.
	var card: PanelContainer = PanelContainer.new()
	var card_style: StyleBoxFlat = UiKit.style(Color(0.22, 0.17, 0.06), 14, 26, 22, Color(1.0, 0.8, 0.35, 0.3), 1)
	card.add_theme_stylebox_override(&"panel", card_style)
	root.add_child(card)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 22)
	card.add_child(row)
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override(&"separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(UiKit.caps("Blackvale County Credit Union", 11, Color(1, 0.88, 0.6), &"bold", 2))
	left.add_child(_label("Station 4 operating account", 14, Color(1, 0.92, 0.75), &"regular"))
	_bank_balance = _label("$0", 52, TEXT, &"black")
	left.add_child(_bank_balance)
	_bank_ring = PaydayRing.new()
	_bank_ring.custom_minimum_size = Vector2(118, 118)
	row.add_child(_bank_ring)
	_bank_timer = _label("0:00", 20, TEXT, &"bold")
	_bank_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bank_timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bank_timer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bank_timer.offset_bottom = -12
	_bank_ring.add_child(_bank_timer)
	var ring_caption: Label = UiKit.caps("Payday", 9, Color(1, 0.88, 0.6), &"bold", 2)
	ring_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ring_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	ring_caption.position.y -= 38
	_bank_ring.add_child(ring_caption)

	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)
	var period_panel: PanelContainer = PanelContainer.new()
	period_panel.add_theme_stylebox_override(&"panel", UiKit.style(Color(1, 1, 1, 0.04), 10, 16, 14))
	period_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(period_panel)
	var period_box: VBoxContainer = VBoxContainer.new()
	period_box.add_theme_constant_override(&"separation", 8)
	period_panel.add_child(period_box)
	period_box.add_child(UiKit.caps("This pay period", 11, FAINT, &"bold", 2))
	_bank_period = VBoxContainer.new()
	_bank_period.add_theme_constant_override(&"separation", 6)
	period_box.add_child(_bank_period)
	var history_panel: PanelContainer = PanelContainer.new()
	history_panel.add_theme_stylebox_override(&"panel", UiKit.style(Color(1, 1, 1, 0.04), 10, 16, 14))
	history_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(history_panel)
	var history_box: VBoxContainer = VBoxContainer.new()
	history_box.add_theme_constant_override(&"separation", 8)
	history_panel.add_child(history_box)
	history_box.add_child(UiKit.caps("Payslips", 11, FAINT, &"bold", 2))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	history_box.add_child(scroll)
	_bank_history = VBoxContainer.new()
	_bank_history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bank_history.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_bank_history)
	return root


func _refresh_bank() -> void:
	if _bank_balance == null or not is_instance_valid(_bank_balance):
		return
	_bank_balance.text = "$%s" % _money(Economy.money)
	var slip: Dictionary = Economy.estimate_payslip()
	for child: Node in _bank_period.get_children():
		child.queue_free()
	var stats: HBoxContainer = HBoxContainer.new()
	stats.add_theme_constant_override(&"separation", 8)
	_bank_period.add_child(stats)
	for stat: Array in [["Handled", slip["calls"], TEXT], ["Correct", slip["correct"], GREEN], ["Wrong", slip["wrong"], RED], ["Missed", slip["missed"], RED]]:
		var tile: PanelContainer = PanelContainer.new()
		tile.add_theme_stylebox_override(&"panel", UiKit.style(Color(1, 1, 1, 0.04), 8, 10, 8))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override(&"separation", -2)
		tile.add_child(box)
		var stat_colour: Color = stat[2]
		box.add_child(_label(str(stat[1]), 24, stat_colour, &"bold"))
		box.add_child(UiKit.caps(str(stat[0]), 9, FAINT, &"bold", 1))
		stats.add_child(tile)
	var lines: PackedStringArray = slip["lines"]
	for line: String in lines:
		_bank_period.add_child(_label(line, 14, DIM, &"regular"))
	_bank_period.add_child(UiKit.separator())
	var total: HBoxContainer = HBoxContainer.new()
	_bank_period.add_child(total)
	var total_label: Label = _label("Estimated payday", 15, DIM, &"medium")
	total_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total.add_child(total_label)
	total.add_child(_label("$%s" % _money(_int(slip["total"])), 20, AMBER, &"bold"))
	for child: Node in _bank_history.get_children():
		child.queue_free()
	if Economy.payslips.is_empty():
		_bank_history.add_child(_label("No paydays yet this career.", 14, FAINT, &"regular"))
	for i: int in range(Economy.payslips.size() - 1, -1, -1):
		var past: Dictionary = Economy.payslips[i]
		var minute: int = past.get("shift_minute", 0)
		var entry: HBoxContainer = HBoxContainer.new()
		entry.add_theme_constant_override(&"separation", 10)
		entry.add_child(IconView.make(&"file", 18, FAINT))
		var texts: VBoxContainer = VBoxContainer.new()
		texts.add_theme_constant_override(&"separation", -2)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_child(texts)
		texts.add_child(_label("Payday #%d" % past.get("number", i + 1), 15, TEXT, &"semibold"))
		texts.add_child(_label("Shift %02d:%02d · %d calls, %d correct" % [minute / 60, minute % 60, past.get("calls", 0), past.get("correct", 0)], 12, FAINT, &"regular"))
		entry.add_child(_label("+$%s" % _money(_int(past.get("total", 0))), 16, GREEN, &"bold"))
		_bank_history.add_child(entry)


# --- My Station ----------------------------------------------------------------------------------

func _build_station() -> Control:
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 14)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 14)
	root.add_child(head)
	head.add_child(IconView.make(&"badge", 44, WIN_BLUE))
	var titles: VBoxContainer = VBoxContainer.new()
	titles.add_theme_constant_override(&"separation", -2)
	head.add_child(titles)
	titles.add_child(_label("Station 4", 26, TEXT, &"bold"))
	titles.add_child(_label("Blackvale County Sheriff · status overview", 14, DIM, &"regular"))
	_station_tiles = GridContainer.new()
	_station_tiles.columns = 3
	_station_tiles.add_theme_constant_override(&"h_separation", 10)
	_station_tiles.add_theme_constant_override(&"v_separation", 10)
	root.add_child(_station_tiles)
	root.add_child(UiKit.caps("Owned equipment", 11, FAINT, &"bold", 2))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_station_owned = VBoxContainer.new()
	_station_owned.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_station_owned.add_theme_constant_override(&"separation", 10)
	scroll.add_child(_station_owned)
	return root


func _refresh_station() -> void:
	if _station_tiles == null or not is_instance_valid(_station_tiles):
		return
	for child: Node in _station_tiles.get_children():
		child.queue_free()
	var tiles: Array[Array] = [
		[&"shield", "Security rating", str(Economy.security_rating()), WIN_BLUE],
		[&"users", "Staff morale", "+%d%%" % roundi(Economy.morale_bonus() * 100.0), GREEN],
		[&"bank", "Salary multiplier", "×%.2f" % Economy.salary_multiplier(), AMBER],
		[&"siren", "Mission payouts", "×%.2f" % Economy.mission_multiplier(), RED],
		[&"phone", "Caller patience", "×%.2f" % Economy.patience_multiplier(), Color(0.65, 0.5, 1.0)],
		[&"cart", "Balance", "$%s" % _money(Economy.money), TEXT],
	]
	for tile_spec: Array in tiles:
		var tile: PanelContainer = PanelContainer.new()
		tile.add_theme_stylebox_override(&"panel", UiKit.style(Color(1, 1, 1, 0.05), 10, 16, 14))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 12)
		tile.add_child(row)
		var tint: Color = tile_spec[3]
		var icon_name: StringName = tile_spec[0]
		row.add_child(IconView.make(icon_name, 26, tint))
		var texts: VBoxContainer = VBoxContainer.new()
		texts.add_theme_constant_override(&"separation", -2)
		row.add_child(texts)
		texts.add_child(_label(str(tile_spec[2]), 22, TEXT, &"bold"))
		texts.add_child(UiKit.caps(str(tile_spec[1]), 9, FAINT, &"bold", 1))
		_station_tiles.add_child(tile)
	for child: Node in _station_owned.get_children():
		child.queue_free()
	for category: String in ShopCatalog.CATEGORIES:
		var chips: HFlowContainer = HFlowContainer.new()
		chips.add_theme_constant_override(&"h_separation", 6)
		chips.add_theme_constant_override(&"v_separation", 6)
		for item: Dictionary in ShopCatalog.items_in(category):
			var count: int = Economy.count_of(StringName(str(item["id"])))
			if count > 0:
				chips.add_child(UiKit.pill(str(item["name"]) + (" ×%d" % count if count > 1 else ""), DIM, false, 10))
		if chips.get_child_count() == 0:
			chips.queue_free()
			continue
		var section: VBoxContainer = VBoxContainer.new()
		section.add_theme_constant_override(&"separation", 6)
		section.add_child(UiKit.icon_row(_cat_icon(category), category, 14, TEXT, DIM))
		section.add_child(chips)
		_station_owned.add_child(section)


# --- CCTV ----------------------------------------------------------------------------------------

func _build_cctv() -> Control:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	for feed: Array in CCTV_CAMERAS:
		var cell: PanelContainer = PanelContainer.new()
		cell.add_theme_stylebox_override(&"panel", UiKit.style(Color(0, 0, 0, 1), 8, 0, 0))
		grid.add_child(cell)
		var container: SubViewportContainer = SubViewportContainer.new()
		container.stretch = true
		container.custom_minimum_size = Vector2(376, 212)
		var fx: ShaderMaterial = ShaderMaterial.new()
		fx.shader = SCREEN_FX
		fx.set_shader_parameter(&"monochrome", true)
		fx.set_shader_parameter(&"scanlines", 0.22)
		container.material = fx
		cell.add_child(container)
		var viewport: SubViewport = SubViewport.new()
		viewport.size = Vector2i(376, 212)
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
		var overlay: VBoxContainer = VBoxContainer.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(UiKit.margin(overlay, 10, 8, 10, 8))
		var top: HBoxContainer = HBoxContainer.new()
		top.add_theme_constant_override(&"separation", 6)
		overlay.add_child(top)
		var dot: ColorRect = ColorRect.new()
		dot.color = RED
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(dot)
		top.add_child(UiKit.caps("Rec", 10, RED, &"bold", 2))
		var feed_name: String = feed[0]
		overlay.add_child(UiKit.expand(Control.new(), false, true))
		overlay.add_child(UiKit.caps(feed_name, 11, Color(0.85, 1, 0.9), &"bold", 2))
	return grid


func _set_cctv_active(active: bool) -> void:
	if not _windows.has(&"cctv"):
		return
	for viewport: Node in _windows[&"cctv"].find_children("*", "SubViewport", true, false):
		(viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED


# --- Inbox ---------------------------------------------------------------------------------------

func _build_inbox() -> Control:
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 10)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 10)
	root.add_child(head)
	head.add_child(IconView.make(&"mail", 26, Color(0.65, 0.5, 1.0)))
	head.add_child(_label("Inbox", 24, TEXT, &"bold"))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_inbox_list = VBoxContainer.new()
	_inbox_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inbox_list.add_theme_constant_override(&"separation", 8)
	scroll.add_child(_inbox_list)
	return root


func _push_inbox(bbcode: String) -> void:
	_inbox.append(bbcode)
	while _inbox.size() > 40:
		_inbox.remove_at(1)
	_refresh_inbox()


func _refresh_inbox() -> void:
	if _inbox_list == null or not is_instance_valid(_inbox_list):
		return
	for child: Node in _inbox_list.get_children():
		child.queue_free()
	for i: int in range(_inbox.size() - 1, -1, -1):
		var message: PanelContainer = PanelContainer.new()
		message.add_theme_stylebox_override(&"panel", UiKit.style(Color(1, 1, 1, 0.045), 10, 16, 12))
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 12)
		message.add_child(row)
		var avatar: IconView = IconView.make(&"badge" if i == 0 else &"mail", 22, WIN_BLUE if i == 0 else FAINT)
		avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(avatar)
		var text: RichTextLabel = UiKit.rich(15)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.append_text(_inbox[i])
		row.add_child(text)
		_inbox_list.add_child(message)
	_refresh_start_recent()


func _on_payday(slip: Dictionary) -> void:
	var lines: PackedStringArray = slip.get("lines", PackedStringArray())
	var total: String = _money(_int(slip.get("total", 0)))
	_push_inbox("[b]Payday #%d — [color=#7dff9a]+$%s[/color][/b]\n%s" % [slip.get("number", 0), total, "\n".join(lines)])
	_toast(&"bank", "Payday #%d" % slip.get("number", 0), "+$%s was paid into the station account." % total, AMBER)


# --- Notifications -------------------------------------------------------------------------------

func _toast(icon_name: StringName, title: String, body: String, tint: Color) -> void:
	if _toasts == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var toast: PanelContainer = UiKit.glass(Color(0.12, 0.13, 0.15), 10, 16, 14, 0.88, 3.5, Color(1, 1, 1, 0.12))
	toast.custom_minimum_size = Vector2(360, 0)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	toast.add_child(row)
	var icon: IconView = IconView.make(icon_name, 24, tint)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.add_theme_constant_override(&"separation", 2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	texts.add_child(UiKit.caps("Station OS", 9, FAINT, &"bold", 2))
	texts.add_child(_label(title, 15, TEXT, &"semibold"))
	var body_label: Label = _label(body, 13, DIM, &"regular")
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(280, 0)
	texts.add_child(body_label)
	_toasts.add_child(toast)
	toast.modulate.a = 0.0
	var tween: Tween = toast.create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.2)
	tween.tween_interval(4.5)
	tween.tween_property(toast, "modulate:a", 0.0, 0.35)
	tween.tween_callback(toast.queue_free)
	while _toasts.get_child_count() > 4:
		_toasts.get_child(0).queue_free()
		_toasts.remove_child(_toasts.get_child(0))


# --- Refresh -------------------------------------------------------------------------------------

func _refresh_apps() -> void:
	if _money_label != null:
		_money_label.text = "$%s" % _money(Economy.money)
	_refresh_shop()
	_refresh_bank()
	_refresh_station()
	_refresh_inbox()
	_refresh_desktop_icons()
	_refresh_taskbar()
	_refresh_start_recent()


func _refresh_taskbar() -> void:
	if _taskbar_apps == null:
		return
	var top: Node = _windows_layer.get_child(_windows_layer.get_child_count() - 1) if _windows_layer.get_child_count() > 0 else null
	for app_id: StringName in _task_buttons:
		var button: TaskbarButton = _task_buttons[app_id]
		var running: bool = _windows.has(app_id)
		button.running = running
		button.focused = running and _windows[app_id].visible and _windows[app_id] == top
		button.available = app_available(app_id)
		button.queue_redraw()


func _refresh_desktop_icons() -> void:
	for icon: Node in _desktop.get_children():
		if icon.has_meta(&"app"):
			var app_id: StringName = icon.get_meta(&"app")
			(icon as Control).modulate.a = 1.0 if app_available(app_id) else 0.4


func _refresh_start_recent() -> void:
	if _start_recent == null:
		return
	for child: Node in _start_recent.get_children():
		child.queue_free()
	var shown: int = 0
	for i: int in range(_inbox.size() - 1, -1, -1):
		if shown >= 3:
			break
		var plain: String = _inbox[i]
		var regex: RegEx = RegEx.create_from_string("\\[[^\\]]*\\]")
		plain = regex.sub(plain, "", true).split("\n")[0]
		var entry: KitButton = KitButton.make(plain.substr(0, 70), &"mail", KitButton.Variant.GHOST, open_app.bind(&"inbox"))
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.clip_text = true
		entry.add_theme_font_size_override(&"font_size", 13)
		entry.add_theme_font_override(&"font", GameTheme.font(&"regular"))
		entry.custom_minimum_size = Vector2(0, 40)
		_start_recent.add_child(entry)
		shown += 1


# --- Layout --------------------------------------------------------------------------------------

func _build() -> void:
	var wallpaper: ColorRect = ColorRect.new()
	wallpaper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper: ShaderMaterial = ShaderMaterial.new()
	paper.shader = WALLPAPER
	wallpaper.material = paper
	wallpaper.resized.connect(func() -> void:
		paper.set_shader_parameter(&"aspect", wallpaper.size.x / maxf(wallpaper.size.y, 1.0)))
	wallpaper.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_toggle_start(false))
	wallpaper.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(wallpaper)
	var watermark: VBoxContainer = VBoxContainer.new()
	watermark.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	watermark.offset_bottom -= TASKBAR_HEIGHT
	watermark.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	watermark.grow_vertical = Control.GROW_DIRECTION_BEGIN
	watermark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(watermark)
	for line: String in ["Station OS 11 · Blackvale County Sheriff", "Build 4.11.2026 · licensed to Station 4"]:
		var text: Label = _label(line, 12, Color(1, 1, 1, 0.45), &"regular")
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		watermark.add_child(text)

	_desktop = Control.new()
	_desktop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desktop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_desktop)
	for i: int in APPS.size():
		var app: Dictionary = APPS[i]
		var app_id: StringName = app["id"]
		var icon: DesktopIcon = DesktopIcon.new()
		icon.icon_name = app["icon"]
		icon.tint = _color(app)
		icon.caption = str(app["name"])
		icon.position = Vector2(14, 14 + i * 104)
		icon.set_meta(&"app", app_id)
		icon.pressed.connect(open_app.bind(app_id))
		_desktop.add_child(icon)

	_windows_layer = Control.new()
	_windows_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_windows_layer.offset_bottom = -TASKBAR_HEIGHT
	_windows_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_windows_layer)

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 14)
	_toasts.offset_bottom = -TASKBAR_HEIGHT - 14
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.add_theme_constant_override(&"separation", 8)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	_build_taskbar()
	_build_start_menu()


func _build_taskbar() -> void:
	var taskbar: PanelContainer = PanelContainer.new()
	taskbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	taskbar.offset_top = -TASKBAR_HEIGHT
	UiKit.apply_glass(taskbar, Color(0.13, 0.14, 0.17), 0, 12, 0, 0.82, 4.0, Color(0, 0, 0, 0))
	var bar_style: StyleBoxFlat = taskbar.get_theme_stylebox(&"panel") as StyleBoxFlat
	bar_style.border_color = Color(1, 1, 1, 0.1)
	bar_style.border_width_top = 1
	bar_style.shadow_size = 0
	add_child(taskbar)
	var layout: Control = Control.new()
	layout.custom_minimum_size = Vector2(0, TASKBAR_HEIGHT)
	taskbar.add_child(layout)
	# Centred group: Start, search, pinned apps.
	_taskbar_apps = HBoxContainer.new()
	_taskbar_apps.add_theme_constant_override(&"separation", 4)
	_taskbar_apps.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_taskbar_apps.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_taskbar_apps.grow_vertical = Control.GROW_DIRECTION_BOTH
	layout.add_child(_taskbar_apps)
	var start: TaskbarButton = TaskbarButton.new()
	start.icon_name = &"start"
	start.tint = WIN_BLUE
	start.tooltip_text = "Start"
	start.pressed.connect(func() -> void: _toggle_start(not _start_menu.visible))
	_taskbar_apps.add_child(start)
	var search: TaskbarButton = TaskbarButton.new()
	search.icon_name = &"search"
	search.tint = TEXT
	search.tooltip_text = "Search"
	search.pressed.connect(func() -> void:
		_toggle_start(true)
		_start_search.grab_focus())
	_taskbar_apps.add_child(search)
	for app: Dictionary in APPS:
		var app_id: StringName = app["id"]
		var pin: TaskbarButton = TaskbarButton.new()
		pin.icon_name = app["icon"]
		pin.tint = _color(app)
		pin.tooltip_text = str(app["name"])
		pin.pressed.connect(func() -> void:
			if _windows.has(app_id):
				_toggle_minimize(app_id)
			else:
				open_app(app_id))
		_taskbar_apps.add_child(pin)
		_task_buttons[app_id] = pin
	# System tray on the right.
	var tray: HBoxContainer = HBoxContainer.new()
	tray.add_theme_constant_override(&"separation", 14)
	tray.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	tray.offset_left = -440
	tray.offset_right = -8
	tray.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(tray)
	_money_label = _label("$0", 14, GREEN, &"semibold")
	_money_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tray.add_child(_money_label)
	var tray_icons: HBoxContainer = HBoxContainer.new()
	tray_icons.add_theme_constant_override(&"separation", 10)
	tray.add_child(tray_icons)
	for tray_icon: StringName in [&"wifi", &"volume", &"battery"]:
		var view: IconView = IconView.make(tray_icon, 16, TEXT)
		view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tray_icons.add_child(view)
	var clock: VBoxContainer = VBoxContainer.new()
	clock.add_theme_constant_override(&"separation", -4)
	clock.alignment = BoxContainer.ALIGNMENT_CENTER
	tray.add_child(clock)
	_clock_label = _label("00:00", 13, TEXT, &"medium")
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock.add_child(_clock_label)
	_date_label = _label("Shift %d" % MissionDirector.shift_number, 12, DIM, &"regular")
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock.add_child(_date_label)
	var bell: KitButton = KitButton.make("", &"bell", KitButton.Variant.GHOST, open_app.bind(&"inbox"))
	bell.icon_size = 15.0
	bell.custom_minimum_size = Vector2(36, 36)
	bell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bell.focus_mode = Control.FOCUS_NONE
	tray.add_child(bell)
	# Left: weather-style widget with the station status.
	var widget: HBoxContainer = HBoxContainer.new()
	widget.add_theme_constant_override(&"separation", 8)
	widget.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	widget.offset_left = 10
	widget.offset_right = 320
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(widget)
	var moon: IconView = IconView.make(&"moon", 20, AMBER)
	moon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	widget.add_child(moon)
	var weather: VBoxContainer = VBoxContainer.new()
	weather.add_theme_constant_override(&"separation", -4)
	weather.alignment = BoxContainer.ALIGNMENT_CENTER
	widget.add_child(weather)
	weather.add_child(_label("11°C  Rain", 13, TEXT, &"medium"))
	weather.add_child(_label("Night shift · Blackvale", 11, DIM, &"regular"))


func _build_start_menu() -> void:
	_start_menu = UiKit.glass(Color(0.12, 0.13, 0.16), 12, 0, 0, 0.9, 4.5, Color(1, 1, 1, 0.12))
	_start_menu.visible = false
	_start_menu.custom_minimum_size = Vector2(640, 0)
	add_child(_start_menu)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	_start_menu.add_child(column)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 14)
	column.add_child(UiKit.margin(body, 30, 26, 30, 22))
	_start_search = LineEdit.new()
	_start_search.placeholder_text = "Search for apps and settings"
	_start_search.custom_minimum_size = Vector2(0, 40)
	_start_search.add_theme_stylebox_override(&"normal", UiKit.style(Color(0, 0, 0, 0.3), 20, 18, 8, Color(1, 1, 1, 0.1), 1))
	_start_search.add_theme_stylebox_override(&"focus", UiKit.style(Color(0, 0, 0, 0.35), 20, 18, 8, WIN_BLUE, 2))
	_start_search.text_changed.connect(_filter_start)
	_start_search.text_submitted.connect(func(_text: String) -> void:
		for tile: Node in _start_grid.get_children():
			if (tile as Control).visible:
				var target_app: StringName = tile.get_meta(&"app")
				open_app(target_app)
				return)
	body.add_child(_start_search)
	var pinned_head: HBoxContainer = HBoxContainer.new()
	body.add_child(pinned_head)
	var pinned_label: Label = _label("Pinned", 15, TEXT, &"semibold")
	pinned_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pinned_head.add_child(pinned_label)
	_start_grid = GridContainer.new()
	_start_grid.columns = 6
	_start_grid.add_theme_constant_override(&"h_separation", 6)
	_start_grid.add_theme_constant_override(&"v_separation", 6)
	body.add_child(_start_grid)
	for app: Dictionary in APPS:
		var app_id: StringName = app["id"]
		var tile: KitButton = KitButton.make(str(app["name"]), _icon_of(app), KitButton.Variant.TILE, open_app.bind(app_id))
		tile.icon_size = 30.0
		tile.icon_tint = _color(app)
		tile.custom_minimum_size = Vector2(92, 92)
		tile.add_theme_font_size_override(&"font_size", 12)
		tile.add_theme_font_override(&"font", GameTheme.font(&"regular"))
		tile.set_meta(&"app", app_id)
		_start_grid.add_child(tile)
	body.add_child(UiKit.spacer(4))
	body.add_child(_label("Recommended", 15, TEXT, &"semibold"))
	_start_recent = VBoxContainer.new()
	_start_recent.add_theme_constant_override(&"separation", 2)
	body.add_child(_start_recent)
	# Footer: profile + power.
	var footer: PanelContainer = PanelContainer.new()
	var footer_style: StyleBoxFlat = UiKit.style(Color(0, 0, 0, 0.22), 0, 30, 12)
	footer_style.corner_radius_bottom_left = 12
	footer_style.corner_radius_bottom_right = 12
	footer_style.border_color = Color(1, 1, 1, 0.08)
	footer_style.border_width_top = 1
	footer.add_theme_stylebox_override(&"panel", footer_style)
	column.add_child(footer)
	var footer_row: HBoxContainer = HBoxContainer.new()
	footer_row.add_theme_constant_override(&"separation", 12)
	footer.add_child(footer_row)
	var avatar: PanelContainer = PanelContainer.new()
	avatar.add_theme_stylebox_override(&"panel", UiKit.style(Color(WIN_BLUE, 0.3), 18, 0, 0, WIN_BLUE, 1))
	avatar.custom_minimum_size = Vector2(36, 36)
	var avatar_icon: IconView = IconView.make(&"user", 18, TEXT)
	avatar_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	avatar_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar.add_child(avatar_icon)
	footer_row.add_child(avatar)
	var who: String = NetManager.get_player_name(multiplayer.get_unique_id()) if multiplayer != null else "Dispatcher"
	var name_label: Label = _label("Dispatcher %s" % who, 14, TEXT, &"medium")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer_row.add_child(name_label)
	var power: KitButton = KitButton.make("Log off", &"power", KitButton.Variant.GHOST, close)
	power.icon_size = 16.0
	power.focus_mode = Control.FOCUS_NONE
	footer_row.add_child(power)
	_start_menu.resized.connect(_place_start_menu)
	resized.connect(_place_start_menu)
	_refresh_start_recent()


func _place_start_menu() -> void:
	_start_menu.position = Vector2((size.x - _start_menu.size.x) * 0.5, size.y - TASKBAR_HEIGHT - _start_menu.size.y - 12)


func _toggle_start(show: bool) -> void:
	if _start_menu.visible == show:
		return
	_start_menu.visible = show
	if not show:
		return
	_start_search.text = ""
	_filter_start("")
	_place_start_menu()
	if is_inside_tree() and DisplayServer.get_name() != "headless":
		var target: float = _start_menu.position.y
		_start_menu.position.y = target + 40
		_start_menu.modulate.a = 0.0
		var tween: Tween = _start_menu.create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(_start_menu, "position:y", target, 0.22)
		tween.tween_property(_start_menu, "modulate:a", 1.0, 0.18)


func _filter_start(query: String) -> void:
	var needle: String = query.strip_edges().to_lower()
	for tile: Node in _start_grid.get_children():
		var button: KitButton = tile as KitButton
		button.visible = needle.is_empty() or needle in button.text.to_lower()


func _label(text: String, font_size: int, colour: Color, weight: StringName = &"medium") -> Label:
	return UiKit.label(text, font_size, colour, weight)


static func _icon_of(app: Dictionary) -> StringName:
	var icon_name: StringName = app.get("icon", &"grid")
	return icon_name


static func _cat_icon(category: String) -> StringName:
	var icon_name: StringName = CATEGORY_ICONS.get(category, &"box")
	return icon_name


static func _int(value: Variant) -> int:
	var number: int = value
	return number


static func _color(app: Dictionary) -> Color:
	var colour: Color = app.get("color", WIN_BLUE)
	return colour


static func _money(amount: int) -> String:
	return UiKit.money(amount)


## Taskbar icon button: rounded hover plate, running dot, wider accent pill for the focused window.
class TaskbarButton:
	extends Button

	var icon_name: StringName = &"grid"
	var tint: Color = Color.WHITE
	var running: bool = false
	var focused: bool = false
	var available: bool = true

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(44, 44)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for state: StringName in [&"normal", &"pressed", &"focus", &"disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		add_theme_stylebox_override(&"hover", UiKit.style(Color(1, 1, 1, 0.08), 6, 0, 0))
		add_theme_stylebox_override(&"hover_pressed", UiKit.style(Color(1, 1, 1, 0.05), 6, 0, 0))

	func _draw() -> void:
		if focused:
			draw_style_box(UiKit.style(Color(1, 1, 1, 0.07), 6, 0, 0), Rect2(Vector2.ZERO, size))
		var icon_size: float = 22.0
		var rect: Rect2 = Rect2((size - Vector2(icon_size, icon_size)) * 0.5 - Vector2(0, 2), Vector2(icon_size, icon_size))
		var colour: Color = tint if available else Color(tint, 0.35)
		if icon_name == &"start":
			# Four-pane logo.
			var pane: float = 9.5
			for i: int in 4:
				var origin: Vector2 = rect.position + Vector2(1 + (i % 2) * (pane + 1.5), 1 + (i / 2) * (pane + 1.5))
				draw_rect(Rect2(origin, Vector2(pane, pane)), colour)
		else:
			IconView.paint(self, icon_name, rect, colour, 1.9)
		if running:
			var width: float = 16.0 if focused else 6.0
			var pill: Rect2 = Rect2(Vector2((size.x - width) * 0.5, size.y - 5.0), Vector2(width, 3.0))
			draw_style_box(UiKit.style(StationOS.WIN_BLUE if focused else Color(1, 1, 1, 0.6), 2, 0, 0), pill)


## Desktop shortcut: coloured glyph on a soft plate with a caption, highlighted on hover.
class DesktopIcon:
	extends Button

	var icon_name: StringName = &"grid"
	var tint: Color = Color.WHITE
	var caption: String = ""

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(96, 96)
		size = custom_minimum_size
		for state: StringName in [&"normal", &"pressed", &"focus", &"disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		add_theme_stylebox_override(&"hover", UiKit.style(Color(1, 1, 1, 0.1), 6, 0, 0, Color(1, 1, 1, 0.15), 1))
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		var plate: Rect2 = Rect2(Vector2((size.x - 48.0) * 0.5, 10.0), Vector2(48, 48))
		draw_style_box(UiKit.style(tint.darkened(0.55), 10, 0, 0, Color(tint, 0.6), 1), plate)
		IconView.paint(self, icon_name, plate.grow(-10.0), tint.lightened(0.25), 2.0)
		var font: Font = GameTheme.font(&"regular")
		var text_size: Vector2 = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
		var at: Vector2 = Vector2((size.x - text_size.x) * 0.5, 78.0)
		draw_string(font, at + Vector2(1, 1), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.6))
		draw_string(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


## Countdown ring to the next payday.
class PaydayRing:
	extends Control

	var ratio: float = 0.0

	func _draw() -> void:
		var centre: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - 6.0
		draw_arc(centre, radius, 0.0, TAU, 64, Color(1, 1, 1, 0.12), 7.0, true)
		draw_arc(centre, radius, -PI * 0.5, -PI * 0.5 + TAU * clampf(ratio, 0.0, 1.0), 64, StationOS.AMBER, 7.0, true)
