## Station money: payroll and StationMart purchases.
##
## Every PAY_PERIOD_SEC (while officers are on shift) the station gets paid. The payslip is a base wage plus
## pay for every call handled this period; calls classified CORRECTLY pay a lot more, wrong verdicts and
## missed calls cost money. Mission payouts (MissionDirector.extract) are added to the next payslip.
## Upgrades bought on the main computer raise salary (%), morale (%), base pay, and mission bonuses.
## The whole team shares one wallet. The host keeps it (and saves it to user://station_economy.cfg);
## clients ask the host to buy and receive the replicated state.
## Authority: HOST (money, inventory, payroll) / LOCAL (UI signals, toast)
extends Node

const PATH: String = "user://station_economy.cfg"
const START_MONEY: int = 2500
const PAY_PERIOD_SEC: float = 240.0
const BASE_PAY: int = 200
const HANDLED_PAY: int = 50
const CORRECT_PAY: int = 150
const WRONG_PENALTY: int = 50
const MISSED_PENALTY: int = 75
## Mission report XP → dollars.
const MISSION_PAY_PER_XP: int = 3
const MAX_PAYSLIPS: int = 12

signal money_changed(money: int)
signal inventory_changed()
## Current-period tallies changed (calls handled, correct…).
signal period_changed()
signal payday(slip: Dictionary)
## Local: answer to our own purchase request.
signal purchase_result(ok: bool, item_id: StringName, message: String)

var money: int = START_MONEY
var inventory: Dictionary[StringName, int] = {}
## {"calls": int, "correct": int, "wrong": int, "missed": int, "mission": int}
var period: Dictionary = {}
var payslips: Array[Dictionary] = []
var pay_timer: float = PAY_PERIOD_SEC
var paydays: int = 0
## Tests turn saving and the automatic payday off.
var persist: bool = true
var auto_payday: bool = true

var _limiter: RpcRateLimiter = RpcRateLimiter.new(4.0, 4.0)
var _toast: Label
var _toast_time: float = 0.0
var _sync_timer: float = 0.0


func _ready() -> void:
	_reset_period()
	load_profile()
	EventBus.call_classified.connect(_on_call_classified)
	EventBus.call_missed.connect(_on_call_missed)
	NetManager.peer_joined.connect(func(peer_id: int, _name: String) -> void:
		if multiplayer.is_server():
			_sync_state.rpc_id(peer_id, _state()))
	NetManager.session_ended.connect(func(_reason: String) -> void: load_profile())
	_build_toast()


func _process(delta: float) -> void:
	if _toast != null and _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
		_toast.visible = _toast_time > 0.0
	if not auto_payday or not multiplayer.is_server() or not _on_shift():
		return
	pay_timer -= delta
	_sync_timer += delta
	if pay_timer <= 0.0:
		pay_now()
	elif _sync_timer >= 5.0 and NetManager.is_online():
		_sync_timer = 0.0
		_sync_timer_rpc.rpc(pay_timer)


# --- Queries (any peer) ----------------------------------------------------------------------------

func count_of(item_id: StringName) -> int:
	return inventory.get(item_id, 0)


func owns(item_id: StringName) -> bool:
	return count_of(item_id) > 0


## "" when the station may buy one more `item_id`, otherwise the reason.
func purchase_block_reason(item_id: StringName) -> String:
	var item: Dictionary = ShopCatalog.get_item(item_id)
	if item.is_empty():
		return "Unknown item"
	if count_of(item_id) >= ShopCatalog.max_of(item_id):
		return "Already owned" if ShopCatalog.max_of(item_id) == 1 else "Station is full"
	if money < ShopCatalog.price_of(item_id):
		return "Not enough money"
	return ""


func salary_multiplier() -> float:
	return 1.0 + ShopCatalog.total_effect(inventory, "salary") + ShopCatalog.total_effect(inventory, "morale")


func morale_bonus() -> float:
	return ShopCatalog.total_effect(inventory, "morale")


func security_rating() -> int:
	return int(ShopCatalog.total_effect(inventory, "security"))


## Multiplier on caller patience (CAD server upgrade).
func patience_multiplier() -> float:
	return 1.0 + ShopCatalog.total_effect(inventory, "patience")


func mission_multiplier() -> float:
	return 1.0 + ShopCatalog.total_effect(inventory, "mission")


## Weapons racked in the armory (bought or starter).
func unlocked_weapons() -> Array[StringName]:
	var result: Array[StringName] = []
	for item: Dictionary in ShopCatalog.ITEMS:
		var item_id: StringName = item["id"]
		if item.has("weapon") and owns(item_id):
			var weapon: StringName = item["weapon"]
			result.append(weapon)
	return result


## What the next payday pays right now (for the Bank app).
func estimate_payslip() -> Dictionary:
	return compute_payslip(period, inventory)


## Payslip for one pay period. Returns {"total": int, "lines": PackedStringArray, ...tallies}.
static func compute_payslip(tally: Dictionary, owned: Dictionary) -> Dictionary:
	var calls: int = tally.get("calls", 0)
	var correct: int = tally.get("correct", 0)
	var wrong: int = tally.get("wrong", 0)
	var missed: int = tally.get("missed", 0)
	var mission: int = tally.get("mission", 0)
	var base: int = BASE_PAY + int(ShopCatalog.total_effect(owned, "base"))
	var correct_pay: int = CORRECT_PAY + int(ShopCatalog.total_effect(owned, "correct"))
	var earned: int = base + calls * HANDLED_PAY + correct * correct_pay - wrong * WRONG_PENALTY - missed * MISSED_PENALTY
	earned = maxi(earned, 0)
	var mult: float = 1.0 + ShopCatalog.total_effect(owned, "salary") + ShopCatalog.total_effect(owned, "morale")
	var bonus: int = roundi(earned * (mult - 1.0))
	var total: int = earned + bonus + mission
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Base wage  $%d" % base)
	lines.append("Calls handled  %d × $%d = $%d" % [calls, HANDLED_PAY, calls * HANDLED_PAY])
	lines.append("Correct verdicts  %d × $%d = $%d" % [correct, correct_pay, correct * correct_pay])
	if wrong > 0:
		lines.append("Wrong verdicts  %d × -$%d = -$%d" % [wrong, WRONG_PENALTY, wrong * WRONG_PENALTY])
	if missed > 0:
		lines.append("Missed calls  %d × -$%d = -$%d" % [missed, MISSED_PENALTY, missed * MISSED_PENALTY])
	if bonus != 0:
		lines.append("Salary & morale bonus  +%d%% = $%d" % [roundi((mult - 1.0) * 100.0), bonus])
	if mission > 0:
		lines.append("Mission payouts  $%d" % mission)
	return {"total": total, "lines": lines, "calls": calls, "correct": correct, "wrong": wrong, "missed": missed, "mission": mission}


# --- Purchases -------------------------------------------------------------------------------------

## Any peer: buy one `item_id` for the station.
func request_purchase(item_id: StringName) -> void:
	if multiplayer.is_server():
		var reason: String = host_purchase(item_id)
		purchase_result.emit(reason == "", item_id, reason if reason != "" else "Purchased")
	else:
		_rpc_purchase.rpc_id(1, item_id)


## Host: validate and apply a purchase. Returns "" on success, otherwise the reason.
func host_purchase(item_id: StringName) -> String:
	if not multiplayer.is_server():
		return "Only the host can buy"
	var reason: String = purchase_block_reason(item_id)
	if reason != "":
		return reason
	money -= ShopCatalog.price_of(item_id)
	inventory[item_id] = count_of(item_id) + 1
	_changed()
	return ""


@rpc("any_peer", "call_remote", "reliable")
func _rpc_purchase(item_id: StringName) -> void:
	if not RpcGuard.is_host(self):
		return
	var sender: int = RpcGuard.sender_id(self)
	if not RpcGuard.is_registered(sender) or not _limiter.allow(sender):
		return
	var reason: String = host_purchase(item_id)
	_rpc_purchase_result.rpc_id(sender, reason == "", item_id, reason if reason != "" else "Purchased")


@rpc("authority", "call_remote", "reliable")
func _rpc_purchase_result(ok: bool, item_id: StringName, message: String) -> void:
	purchase_result.emit(ok, item_id, message)


# --- Payroll (host) --------------------------------------------------------------------------------

## Host: add money earned on a mission (scaled by vehicles / radio console) to the current period.
func add_mission_pay(xp: int) -> void:
	if not multiplayer.is_server() or xp <= 0:
		return
	period["mission"] = _tally("mission") + roundi(xp * MISSION_PAY_PER_XP * mission_multiplier())
	_changed()


## Host: pay the current period now and start a new one.
func pay_now() -> Dictionary:
	if not multiplayer.is_server():
		return {}
	var slip: Dictionary = compute_payslip(period, inventory)
	paydays += 1
	slip["number"] = paydays
	slip["shift_minute"] = CallDirector.shift_clock_minutes
	var earned: int = slip["total"]
	money += earned
	payslips.append(slip)
	while payslips.size() > MAX_PAYSLIPS:
		payslips.pop_front()
	_reset_period()
	pay_timer = PAY_PERIOD_SEC
	_changed()
	_rpc_payday.rpc(slip)
	return slip


@rpc("authority", "call_local", "reliable")
func _rpc_payday(slip: Dictionary) -> void:
	if not multiplayer.is_server():
		payslips.append(slip)
	var earned: int = slip.get("total", 0)
	show_toast("PAYDAY  +$%d" % earned)
	payday.emit(slip)


func _on_call_classified(call_id: StringName, verdict: StringName) -> void:
	if not multiplayer.is_server():
		return
	period["calls"] = _tally("calls") + 1
	var record: Dictionary = CallDirector.call_history.get(call_id, {})
	if record.has("truth"):
		var truth: CallData.Truth = record["truth"]
		if verdict == MissionDirector.verdict_for_truth(truth):
			period["correct"] = _tally("correct") + 1
		else:
			period["wrong"] = _tally("wrong") + 1
	_changed()


func _on_call_missed(_call_id: StringName) -> void:
	if not multiplayer.is_server():
		return
	period["missed"] = _tally("missed") + 1
	_changed()


func _tally(key: String) -> int:
	var value: int = period.get(key, 0)
	return value


func _reset_period() -> void:
	period = {"calls": 0, "correct": 0, "wrong": 0, "missed": 0, "mission": 0}


func _on_shift() -> bool:
	return get_tree() != null and not get_tree().get_nodes_in_group(Player.GROUP).is_empty()


# --- Replication -----------------------------------------------------------------------------------

func _changed() -> void:
	save_profile()
	if multiplayer.is_server() and NetManager.is_online():
		_sync_state.rpc(_state())
	_emit_all()


func _state() -> Dictionary:
	var inv: Dictionary = {}
	for id: StringName in inventory:
		inv[String(id)] = inventory[id]
	return {"money": money, "inventory": inv, "period": period, "timer": pay_timer, "paydays": paydays, "payslips": payslips}


func _apply_state(state: Dictionary) -> void:
	money = state.get("money", money)
	inventory.clear()
	var inv: Dictionary = state.get("inventory", {})
	for id: Variant in inv:
		var count: int = inv[id]
		inventory[StringName(str(id))] = count
	for starter: StringName in ShopCatalog.starter_items():
		if count_of(starter) == 0:
			inventory[starter] = 1
	var p: Dictionary = state.get("period", {})
	_reset_period()
	for key: Variant in p:
		period[key] = p[key]
	pay_timer = state.get("timer", PAY_PERIOD_SEC)
	paydays = state.get("paydays", 0)
	payslips.clear()
	var slips: Array = state.get("payslips", [])
	for slip: Variant in slips:
		var entry: Dictionary = slip
		payslips.append(entry)


@rpc("authority", "call_remote", "reliable")
func _sync_state(state: Dictionary) -> void:
	_apply_state(state)
	_emit_all()


@rpc("authority", "call_remote", "unreliable")
func _sync_timer_rpc(seconds: float) -> void:
	pay_timer = seconds


func _emit_all() -> void:
	money_changed.emit(money)
	inventory_changed.emit()
	period_changed.emit()


# --- Persistence -----------------------------------------------------------------------------------

func load_profile() -> void:
	var config: ConfigFile = ConfigFile.new()
	var state: Dictionary = {}
	if persist and config.load(PATH) == OK:
		state = config.get_value("economy", "state", {})
	if state.is_empty():
		state = {"money": START_MONEY}
	_apply_state(state)
	_emit_all()


func save_profile() -> void:
	if not persist or not multiplayer.is_server():
		return
	var config: ConfigFile = ConfigFile.new()
	config.set_value("economy", "state", _state())
	config.save(PATH)


## Tests / "new career": fresh wallet with only the starter gear.
func reset() -> void:
	paydays = 0
	payslips.clear()
	pay_timer = PAY_PERIOD_SEC
	_apply_state({"money": START_MONEY})
	save_profile()
	_emit_all()


# --- Toast -----------------------------------------------------------------------------------------

func show_toast(text: String, seconds: float = 5.0) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast_time = seconds
	_toast.visible = true


func _build_toast() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 90
	_toast.offset_left = -300
	_toast.offset_right = 300
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 34)
	_toast.add_theme_color_override("font_color", Color(0.45, 1.0, 0.6))
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_toast)
