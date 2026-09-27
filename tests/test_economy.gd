extends GutTest
## Economy: payroll (correct verdicts pay more), StationMart purchases and the shop catalog.


func before_each() -> void:
	Economy.persist = false
	Economy.auto_payday = false
	Economy.reset()
	CallDirector.call_history.clear()


func after_all() -> void:
	Economy.reset()
	Economy.auto_payday = true


func test_catalog_is_consistent() -> void:
	var ids: Dictionary = {}
	for item: Dictionary in ShopCatalog.ITEMS:
		var id: StringName = item["id"]
		assert_false(ids.has(id), "duplicate id %s" % id)
		ids[id] = true
		assert_true(str(item["category"]) in ShopCatalog.CATEGORIES, "%s has a known category" % id)
		assert_gte(_n(item.get("price", -1)), 0, "%s has a price" % id)
		if item.has("weapon"):
			var weapon: StringName = item["weapon"]
			assert_true(WeaponCatalog.has(weapon), "%s racks a real weapon" % id)
			assert_true(StationFurniture.RACK_X.has(id), "%s has a rack slot" % id)
	for category: String in ShopCatalog.CATEGORIES:
		assert_gt(ShopCatalog.items_in(category).size(), 0, "%s is not empty" % category)


func test_starter_gear_is_owned() -> void:
	assert_eq(Economy.money, Economy.START_MONEY)
	for id: StringName in ShopCatalog.starter_items():
		assert_true(Economy.owns(id), "%s is standard issue" % id)
	assert_true(&"pistol" in Economy.unlocked_weapons())
	assert_false(&"rifle" in Economy.unlocked_weapons())


func test_purchase_spends_money_and_respects_limits() -> void:
	Economy.money = 2000
	assert_eq(Economy.host_purchase(&"rack_shotgun"), "")
	assert_eq(Economy.money, 2000 - ShopCatalog.price_of(&"rack_shotgun"))
	assert_true(&"shotgun" in Economy.unlocked_weapons())
	assert_eq(Economy.host_purchase(&"rack_shotgun"), "Already owned")
	assert_eq(Economy.host_purchase(&"swat_van"), "Not enough money")
	assert_eq(Economy.host_purchase(&"no_such_item"), "Unknown item")
	Economy.money = 100000
	for i: int in ShopCatalog.max_of(&"workstation"):
		assert_eq(Economy.host_purchase(&"workstation"), "")
	assert_eq(Economy.host_purchase(&"workstation"), "Station is full")
	assert_eq(Economy.count_of(&"workstation"), 3)


func test_correct_verdicts_pay_more() -> void:
	var owned: Dictionary = {}
	var correct: Dictionary = Economy.compute_payslip({"calls": 3, "correct": 3}, owned)
	var wrong: Dictionary = Economy.compute_payslip({"calls": 3, "wrong": 3}, owned)
	var idle: Dictionary = Economy.compute_payslip({}, owned)
	assert_eq(_n(idle["total"]), Economy.BASE_PAY)
	assert_eq(_n(correct["total"]), Economy.BASE_PAY + 3 * Economy.HANDLED_PAY + 3 * Economy.CORRECT_PAY)
	assert_gt(_n(correct["total"]), _n(wrong["total"]))
	var missed: Dictionary = Economy.compute_payslip({"missed": 10}, owned)
	assert_eq(_n(missed["total"]), 0, "pay never goes negative")


func test_upgrades_raise_the_payslip() -> void:
	var tally: Dictionary = {"calls": 2, "correct": 2}
	var plain: int = _n(Economy.compute_payslip(tally, {})["total"])
	var trained: int = _n(Economy.compute_payslip(tally, {&"training": 1, &"coffee_machine": 1})["total"])
	var union_pay: int = _n(Economy.compute_payslip(tally, {&"union_deal": 1})["total"])
	var overtime: int = _n(Economy.compute_payslip(tally, {&"overtime": 1})["total"])
	assert_eq(trained, plain + roundi(plain * 0.13))
	assert_eq(union_pay, plain + 100)
	assert_eq(overtime, plain + 80)


func test_classified_calls_are_counted_and_paid() -> void:
	CallDirector.call_history[&"call_a"] = {"truth": CallData.Truth.PRANK}
	CallDirector.call_history[&"call_b"] = {"truth": CallData.Truth.GENUINE}
	EventBus.call_classified.emit(&"call_a", &"prank")
	EventBus.call_classified.emit(&"call_b", &"prank")
	EventBus.call_missed.emit(&"call_c")
	assert_eq(_n(Economy.period["calls"]), 2)
	assert_eq(_n(Economy.period["correct"]), 1)
	assert_eq(_n(Economy.period["wrong"]), 1)
	assert_eq(_n(Economy.period["missed"]), 1)
	var before: int = Economy.money
	var slip: Dictionary = Economy.pay_now()
	var expected: int = Economy.BASE_PAY + 2 * Economy.HANDLED_PAY + Economy.CORRECT_PAY - Economy.WRONG_PENALTY - Economy.MISSED_PENALTY
	assert_eq(_n(slip["total"]), expected)
	assert_eq(Economy.money, before + expected)
	assert_eq(_n(Economy.period["calls"]), 0, "a new pay period starts")
	assert_eq(Economy.payslips.size(), 1)


func test_mission_pay_scales_with_vehicles() -> void:
	Economy.add_mission_pay(100)
	var plain: int = _n(Economy.period["mission"])
	assert_eq(plain, 100 * Economy.MISSION_PAY_PER_XP)
	Economy.inventory[&"swat_van"] = 1
	Economy.add_mission_pay(100)
	assert_eq(_n((Economy.period["mission"])) - plain, roundi(100 * Economy.MISSION_PAY_PER_XP * 1.25))


func test_station_os_builds_apps() -> void:
	var desktop: StationOS = StationOS.new()
	add_child_autofree(desktop)
	desktop.open()
	desktop.open_app(&"shop")
	desktop.open_app(&"bank")
	desktop.open_app(&"station")
	desktop.open_app(&"inbox")
	assert_false(desktop.app_available(&"cctv"), "CCTV needs the CCTV System")
	Economy.money = 10000
	Economy.request_purchase(&"cctv")
	assert_true(desktop.app_available(&"cctv"))
	desktop.open_app(&"cctv")
	desktop.close()
	assert_false(desktop.is_open())


func _n(value: Variant) -> int:
	var number: int = value
	return number
