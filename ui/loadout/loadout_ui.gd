## Loadout UI — armory screen for gear selection and approach voting.
## Opens in loadout phase. Authority: LOCAL (UI), host validates purchases.
class_name LoadoutUI
extends Control

const GROUP: StringName = &"loadout_ui"
const MODAL_GROUP: StringName = &"modal_ui"

signal loadout_confirmed()

var _is_open: bool = false
var _closed_player_input: Player = null

var _budget_label: Label = null
var _gear_list: VBoxContainer = null
var _my_loadout: VBoxContainer = null
var _total_cost_label: Label = null
var _vote_box: VBoxContainer = null
var _vote_timer_label: Label = null
var _vote_tally_label: Label = null
var _confirm_button: Button = null
var _vote_buttons: Dictionary[StringName, Button] = {}

var _my_class: StringName = &""
var _pending_purchases: Dictionary[StringName, int] = {}  # gear_id -> quantity to buy


func _ready() -> void:
	add_to_group(GROUP)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	
	LoadoutManager.budget_changed.connect(_on_budget_changed)
	LoadoutManager.gear_purchased.connect(_on_gear_purchased)
	LoadoutManager.gear_sold.connect(_on_gear_sold)
	LoadoutManager.vote_opened.connect(_on_vote_opened)
	LoadoutManager.vote_cast.connect(_on_vote_cast)
	LoadoutManager.vote_closed.connect(_on_vote_closed)
	LoadoutManager.approach_selected.connect(_on_approach_selected)
	
	_refresh_budget()
	_refresh_gear_list()
	_refresh_my_loadout()


func open() -> void:
	if _is_open:
		return
	
	_is_open = true
	visible = true
	add_to_group(MODAL_GROUP)
	
	var player: Player = Player.find_by_peer(get_tree(), multiplayer.get_unique_id())
	if player != null:
		player.set_input_enabled(false)
		_closed_player_input = player
	
	_my_class = NetManager.get_class_id(multiplayer.get_unique_id())
	_pending_purchases.clear()
	
	_refresh_budget()
	_refresh_gear_list()
	_refresh_my_loadout()
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not _is_open:
		return
	
	_is_open = false
	visible = false
	remove_from_group(MODAL_GROUP)
	
	if _closed_player_input != null and is_instance_valid(_closed_player_input):
		_closed_player_input.set_input_enabled(true)
	_closed_player_input = null
	
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# --- Event Handlers -------------------------------------------------------------

func _on_budget_changed(new_budget: int) -> void:
	_refresh_budget()


func _on_gear_purchased(peer_id: int, gear_id: StringName, cost: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		_refresh_my_loadout()
		_refresh_gear_list()
	_refresh_budget()


func _on_gear_sold(peer_id: int, gear_id: StringName, refund: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		_refresh_my_loadout()
		_refresh_gear_list()
	_refresh_budget()


func _on_vote_opened(vote_id: int, topic: StringName, options: Array[StringName], timeout: float) -> void:
	if topic != &"approach":
		return
	
	_vote_box.visible = true
	_vote_timer_label.text = "VOTE TIME: %.0fs" % timeout
	_vote_tally_label.text = "Waiting for votes..."
	
	for opt in options:
		if _vote_buttons.has(opt):
			_vote_buttons[opt].disabled = false
	
	# Start vote timer update
	_start_vote_timer(vote_id)


func _on_vote_cast(peer_id: int, vote_id: int, option: StringName) -> void:
	var tally: Dictionary = LoadoutManager.get_tally(vote_id)
	_update_vote_tally(tally)
	
	# Disable this player's vote buttons
	for btn in _vote_buttons.values():
		btn.disabled = true


func _on_vote_closed(vote_id: int, result: StringName, tally: Dictionary) -> void:
	_update_vote_tally(tally)
	_vote_timer_label.text = "VOTE CLOSED"
	
	if result != &"":
		_vote_tally_label.text += "\n[color=#7dff9a]SELECTED: %s[/color]" % String(result).to_upper()
	
	for btn in _vote_buttons.values():
		btn.disabled = true


func _on_approach_selected(approach: StringName) -> void:
	_append_log("Approach selected: %s" % String(approach).to_upper())


# --- Vote Timer ----------------------------------------------------------------

var _vote_timer: Timer = null

func _start_vote_timer(vote_id: int) -> void:
	if _vote_timer != null:
		_vote_timer.stop()
		_vote_timer.queue_free()
	
	_vote_timer = Timer.new()
	_vote_timer.wait_time = 1.0
	_vote_timer.one_shot = false
	_vote_timer.timeout.connect(func() -> void: _update_vote_timer(vote_id))
	add_child(_vote_timer)
	_vote_timer.start()


func _update_vote_timer(vote_id: int) -> void:
	var time_left: float = LoadoutManager.get_time_left(vote_id)
	_vote_timer_label.text = "VOTE TIME: %.0fs" % time_left
	
	if time_left <= 0.0:
		_vote_timer.stop()
		_vote_timer.queue_free()
		_vote_timer = null


func _update_vote_tally(tally: Dictionary) -> void:
	var parts: PackedStringArray = PackedStringArray()
	for option: StringName in tally.keys():
		var count: int = tally[option]
		var option_name: String = String(option).to_upper()
		parts.append("%s %d" % [option_name, count])
	_vote_tally_label.text = "TALLY: %s" % ", ".join(parts) if not parts.is_empty() else "No votes yet"


# --- Actions -------------------------------------------------------------------

func _buy_gear(gear_id: StringName) -> void:
	var gear: GearItem = LoadoutManager.get_gear(gear_id)
	if gear == null:
		return
	
	var effective_cost: int = gear.get_effective_cost(_my_class)
	var current_budget: int = LoadoutManager.get_budget()
	
	if current_budget >= effective_cost:
		if multiplayer.is_server():
			LoadoutManager.purchase_gear(multiplayer.get_unique_id(), gear_id, _my_class)
		else:
			LoadoutManager.rpc_id(1, &"purchase_gear", multiplayer.get_unique_id(), gear_id, _my_class)


func _sell_gear(gear_id: StringName) -> void:
	if multiplayer.is_server():
		LoadoutManager.sell_gear(multiplayer.get_unique_id(), gear_id)
	else:
		LoadoutManager.rpc_id(1, &"sell_gear", multiplayer.get_unique_id(), gear_id)


func _vote_approach(option: StringName) -> void:
	if multiplayer.is_server():
		LoadoutManager.cast_vote(multiplayer.get_unique_id(), option)
	else:
		LoadoutManager.rpc_id(1, &"cast_vote", multiplayer.get_unique_id(), option)


func _confirm_loadout() -> void:
	LoadoutManager.finalize_loadout(multiplayer.get_unique_id())
	loadout_confirmed.emit()
	close()


func _append_log(text: String) -> void:
	# Could add to a log display if needed
	pass


# --- View Refresh ---------------------------------------------------------------

func _refresh_budget() -> void:
	if _budget_label != null:
		_budget_label.text = "STATION BUDGET: $%d" % LoadoutManager.get_budget()
		var color: Color = Color(0.4, 1.0, 0.6) if LoadoutManager.get_budget() >= 3000 else Color(1.0, 0.5, 0.3)
		_budget_label.add_theme_color_override("font_color", color)


func _refresh_gear_list() -> void:
	if _gear_list == null:
		return
	
	for child in _gear_list.get_children():
		child.queue_free()
	
	var gear_for_class: Array[GearItem] = LoadoutManager.get_gear_for_class(_my_class)
	
	# Group by slot
	var slots_order: Array[GearItem.Slot] = [
		GearItem.Slot.SIDEARM,
		GearItem.Slot.PRIMARY,
		GearItem.Slot.HEAVY,
		GearItem.Slot.GADGET,
		GearItem.Slot.THROWABLE,
		GearItem.Slot.CONSUMABLE
	]
	
	var slot_names: Dictionary = {
		GearItem.Slot.SIDEARM: "SIDEARM",
		GearItem.Slot.PRIMARY: "PRIMARY WEAPON",
		GearItem.Slot.HEAVY: "HEAVY GEAR",
		GearItem.Slot.GADGET: "GADGETS",
		GearItem.Slot.THROWABLE: "THROWABLES",
		GearItem.Slot.CONSUMABLE: "CONSUMABLES"
	}
	
	for slot in slots_order:
		var slot_gear: Array[GearItem] = []
		for gear in gear_for_class:
			if gear.slot == slot:
				slot_gear.append(gear)
		
		if slot_gear.is_empty():
			continue
		
		var header: Label = _label(slot_names[slot], 16, Color(0.7, 0.9, 1.0))
		_gear_list.add_child(header)
		
		for gear in slot_gear:
			var item_box: HBoxContainer = HBoxContainer.new()
			item_box.add_theme_constant_override("separation", 10)
			_gear_list.add_child(item_box)
			
			var info_box: VBoxContainer = VBoxContainer.new()
			info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_box.add_child(info_box)
			
			var name_label: Label = _label("%s  [$%d]" % [gear.display_name, gear.get_effective_cost(_my_class)], 16, Color(0.9, 0.95, 1.0))
			info_box.add_child(name_label)
			
			if not gear.description.is_empty():
				var desc: Label = _label(gear.description, 12, Color(0.6, 0.7, 0.8))
				info_box.add_child(desc)
			
			var qty_label: Label = _label("Carry: %d/%d" % [get_current_qty(gear.id), gear.max_carry], 12, Color(0.6, 0.7, 0.8))
			info_box.add_child(qty_label)
			
			# Buy/Sell buttons
			var btn_box: VBoxContainer = VBoxContainer.new()
			btn_box.add_theme_constant_override("separation", 5)
			item_box.add_child(btn_box)
			
			var can_buy: bool = get_current_qty(gear.id) < gear.max_carry and LoadoutManager.get_budget() >= gear.get_effective_cost(_my_class)
			var buy_btn: Button = _button("Buy", func() -> void: _buy_gear(gear.id))
			buy_btn.disabled = not can_buy
			btn_box.add_child(buy_btn)
			
			var can_sell: bool = get_current_qty(gear.id) > 0
			var sell_btn: Button = _button("Sell", func() -> void: _sell_gear(gear.id))
			sell_btn.disabled = not can_sell
			sell_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
			btn_box.add_child(sell_btn)
		
		_gear_list.add_child(HSeparator.new())


func _refresh_my_loadout() -> void:
	if _my_loadout == null:
		return
	
	for child in _my_loadout.get_children():
		child.queue_free()
	
	var loadout: Dictionary = LoadoutManager.get_player_loadout(multiplayer.get_unique_id())
	
	if loadout.is_empty():
		var empty: Label = _label("(no gear selected)", 14, Color(0.5, 0.5, 0.6))
		_my_loadout.add_child(empty)
	else:
		var total_cost: int = 0
		for gear_id: StringName in loadout.keys():
			var qty: int = loadout[gear_id]
			var gear: GearItem = LoadoutManager.get_gear(gear_id)
			if gear != null:
				var cost_per: int = gear.get_effective_cost(_my_class)
				var item_cost: int = cost_per * (qty / gear.quantity_per_purchase)
				total_cost += item_cost
				
				var item_box: HBoxContainer = HBoxContainer.new()
				item_box.add_theme_constant_override("separation", 10)
				_my_loadout.add_child(item_box)
				
				var qty_per: int = gear.quantity_per_purchase
				var num_purchases: int = qty / qty_per
				
				var name: Label = _label("%s ×%d  [$%d]" % [gear.display_name, qty, item_cost], 14, Color(0.85, 0.9, 0.88))
				name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				item_box.add_child(name)
				
				var sell_btn: Button = _button("Sell", func() -> void: _sell_gear(gear_id))
				sell_btn.custom_minimum_size = Vector2(60, 28)
				item_box.add_child(sell_btn)
		
		if _total_cost_label != null:
			_total_cost_label.text = "LOADOUT TOTAL: $%d" % total_cost


func get_current_qty(gear_id: StringName) -> int:
	var loadout: Dictionary = LoadoutManager.get_player_loadout(multiplayer.get_unique_id())
	return loadout.get(gear_id, 0)


# --- Layout --------------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	
	var frame: PanelContainer = PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 60
	frame.offset_top = 50
	frame.offset_right = -60
	frame.offset_bottom = -50
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.05, 0.97)
	style.border_color = Color(0.2, 0.55, 0.4)
	style.set_border_width_all(2)
	style.set_content_margin_all(20)
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)
	
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 15)
	frame.add_child(root)
	
	# Header
	var header: HBoxContainer = HBoxContainer.new()
	root.add_child(header)
	var title: Label = _label("STATION 4 ARMORY — TACTICAL LOADOUT & REQUISITION", 24, Color(0.4, 1.0, 0.6), false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_budget_label = _label("STATION BUDGET: $10000", 24, Color(1.0, 0.8, 0.2), false)
	header.add_child(_budget_label)
	var close_btn: Button = _button("  Close [Esc]  ", close)
	header.add_child(close_btn)
	
	# Main content area
	var content: HBoxContainer = HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 20)
	root.add_child(content)
	
	# Left: Gear Catalog
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(450, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	content.add_child(left)
	
	left.add_child(_label("AVAILABLE GEAR [%s]" % String(_my_class).capitalize(), 18, Color(0.7, 0.9, 1.0)))
	
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	
	_gear_list = VBoxContainer.new()
	_gear_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_gear_list)
	
	# Center: My Loadout
	var center: VBoxContainer = VBoxContainer.new()
	center.custom_minimum_size = Vector2(350, 0)
	center.add_theme_constant_override("separation", 10)
	content.add_child(center)
	
	center.add_child(_label("MY LOADOUT", 18, Color(0.4, 1.0, 0.6)))
	
	var loadout_scroll: ScrollContainer = ScrollContainer.new()
	loadout_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loadout_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.add_child(loadout_scroll)
	
	_my_loadout = VBoxContainer.new()
	_my_loadout.add_theme_constant_override("separation", 8)
	loadout_scroll.add_child(_my_loadout)
	
	_total_cost_label = _label("LOADOUT TOTAL: $0", 16, Color(1.0, 0.8, 0.2), false)
	center.add_child(_total_cost_label)
	
	# Right: Approach Vote
	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	right.add_theme_constant_override("separation", 10)
	content.add_child(right)
	
	_vote_box = VBoxContainer.new()
	_vote_box.visible = false
	right.add_child(_vote_box)
	
	_vote_box.add_child(_label("APPROACH VOTE", 18, Color(1.0, 0.7, 0.2)))
	
	_vote_timer_label = _label("VOTE TIME: --", 16, Color(1.0, 0.8, 0.2), false)
	_vote_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vote_box.add_child(_vote_timer_label)
	
	_vote_tally_label = _label("Waiting for vote to open...", 14, Color(0.7, 0.8, 0.9), false)
	_vote_tally_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vote_box.add_child(_vote_tally_label)
	
	HSeparator.new().add_to_parent(_vote_box)
	
	var vote_options: Array[StringName] = [&"code3", &"silent", &"on_foot", &"decoy"]
	var vote_descriptions: Dictionary = {
		&"code3": "CODE 3 — Lights & Sirens (fastest, alerts enemies)",
		&"silent": "SILENT — +3 min, surprise approach",
		&"on_foot": "ON FOOT — +8 min, flank spawn",
		&"decoy": "DECOY — Requires 3+ players or Tech drone, cruiser at risk"
	}
	
	for opt in vote_options:
		var btn: Button = _button(vote_descriptions[opt], func() -> void: _vote_approach(opt))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = true
		_vote_buttons[opt] = btn
		_vote_box.add_child(btn)
	
	HSeparator.new().add_to_parent(right)
	
	_confirm_button = _button("CONFIRM LOADOUT", _confirm_loadout)
	_confirm_button.custom_minimum_size = Vector2(0, 48)
	var confirm_style: StyleBoxFlat = StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.1, 0.3, 0.15)
	confirm_style.border_color = Color(0.4, 1.0, 0.5)
	confirm_style.set_border_width_all(2)
	_confirm_button.add_theme_stylebox_override("normal", confirm_style)
	right.add_child(_confirm_button)
	
	var hint: Label = _label("Budget < $3000: heavy gear locked. Budget < $1000: only basic gear.", 12, Color(0.6, 0.7, 0.8), false)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(hint)


func _label(text: String, size: int, colour: Color, wrap: bool = true) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(80, 32)
	button.pressed.connect(callback)
	return button