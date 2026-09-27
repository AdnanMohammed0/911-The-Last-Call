## Everything the station can buy from StationMart (the shop app on the main computer), grouped by category.
## Each entry is plain data so the shop UI, Economy (money / effects) and StationFurniture (what appears in
## the building) all read the same table.
##   id / name / desc / price / category
##   max      — how many the station can own (extra workstations stack, most items are one-off)
##   starter  — owned from day one (never sold)
##   weapon   — WeaponCatalog id this purchase racks in the armory
##   armor    — armor points the locker hands out
##   effects  — {salary: +% pay, base: +$ base pay, security: +rating, morale: +% pay, patience: +% caller
##               patience, mission: +% mission bonus}
## Authority: LOCAL (static data shared by every peer)
class_name ShopCatalog
extends RefCounted

const CATEGORIES: Array[String] = ["Computers", "Security", "Weapons", "Armor", "Medical", "Break Room", "Vehicles", "Upgrades"]

const ITEMS: Array[Dictionary] = [
	# --- Computers --------------------------------------------------------------------------------
	{"id": &"workstation", "name": "Dispatch Workstation", "category": "Computers", "price": 1500, "max": 3,
		"desc": "Extra desk with a full Station OS computer so more officers can work calls at the same time. +5% salary each.",
		"effects": {"salary": 0.05}},
	{"id": &"cad_server", "name": "CAD Server Upgrade", "category": "Computers", "price": 2200, "max": 1,
		"desc": "Faster call routing and caller-ID lookups. Callers stay on the line 15% longer.",
		"effects": {"patience": 0.15}},
	{"id": &"printer", "name": "Report Printer", "category": "Computers", "price": 400, "max": 1,
		"desc": "Prints incident reports for the county. Paperwork done right: +3% salary.",
		"effects": {"salary": 0.03}},
	{"id": &"radio_console", "name": "Radio Console", "category": "Computers", "price": 1800, "max": 1,
		"desc": "Direct line to field units. +10% bonus on every mission payout.",
		"effects": {"mission": 0.10}},
	# --- Security ---------------------------------------------------------------------------------
	{"id": &"cctv", "name": "CCTV System", "category": "Security", "price": 3000, "max": 1,
		"desc": "Cameras on the entrance, lobby, garage and armory. Unlocks the CCTV app with live feeds.",
		"effects": {"security": 2}},
	{"id": &"alarm", "name": "Intrusion Alarm", "category": "Security", "price": 1200, "max": 1,
		"desc": "Siren beacons on every exit of the station.", "effects": {"security": 1}},
	{"id": &"floodlights", "name": "Perimeter Floodlights", "category": "Security", "price": 900, "max": 1,
		"desc": "Bright floodlights over the parking lot and the entrance.", "effects": {"security": 1}},
	{"id": &"barricades", "name": "Steel Barricades", "category": "Security", "price": 700, "max": 1,
		"desc": "Anti-ram barriers in front of the main entrance.", "effects": {"security": 1}},
	{"id": &"metal_detector", "name": "Lobby Metal Detector", "category": "Security", "price": 1100, "max": 1,
		"desc": "Walk-through detector at the lobby entrance.", "effects": {"security": 1}},
	{"id": &"sandbags", "name": "Sandbag Positions", "category": "Security", "price": 500, "max": 1,
		"desc": "Defensive sandbag walls by the garage and the entrance.", "effects": {"security": 1}},
	{"id": &"safe_room", "name": "Reinforced Safe Room", "category": "Security", "price": 4500, "max": 1,
		"desc": "Armored cage in the operations room with an emergency med kit inside.",
		"effects": {"security": 3}},
	# --- Weapons (armory racks) -------------------------------------------------------------------
	{"id": &"rack_pistol", "name": "Service Pistol Rack", "category": "Weapons", "price": 0, "max": 1, "starter": true,
		"weapon": &"pistol", "desc": "Standard issue sidearm for every officer."},
	{"id": &"rack_revolver", "name": ".357 Revolver Rack", "category": "Weapons", "price": 900, "max": 1,
		"weapon": &"revolver", "desc": "Six heavy rounds. Slow, loud, and it ends arguments."},
	{"id": &"rack_shotgun", "name": "Pump Shotgun Rack", "category": "Weapons", "price": 1200, "max": 1,
		"weapon": &"shotgun", "desc": "Breacher's best friend at close range."},
	{"id": &"rack_smg", "name": "SMG Rack", "category": "Weapons", "price": 1600, "max": 1,
		"weapon": &"smg", "desc": "Compact automatic for the Tech Operator."},
	{"id": &"rack_pdw", "name": "PDW Rack", "category": "Weapons", "price": 1800, "max": 1,
		"weapon": &"pdw", "desc": "Personal defense weapon every class can carry."},
	{"id": &"rack_rifle", "name": "Patrol Rifle Rack", "category": "Weapons", "price": 2500, "max": 1,
		"weapon": &"rifle", "desc": "Accurate automatic rifle for long corridors."},
	{"id": &"rack_dmr", "name": "Marksman Rifle Rack", "category": "Weapons", "price": 3200, "max": 1,
		"weapon": &"dmr", "desc": "Semi-auto precision rifle. Hard hits at long range."},
	{"id": &"rack_auto_shotgun", "name": "Auto Shotgun Rack", "category": "Weapons", "price": 3600, "max": 1,
		"weapon": &"auto_shotgun", "desc": "Magazine-fed shotgun that clears rooms fast."},
	{"id": &"ammo_crate", "name": "Ammo Crate", "category": "Weapons", "price": 0, "max": 1, "starter": true,
		"desc": "Refill every magazine you carry."},
	{"id": &"ammo_bench", "name": "Reloading Bench", "category": "Weapons", "price": 600, "max": 1,
		"desc": "Second ammo station in the garage, right by the deploy door."},
	# --- Armor ------------------------------------------------------------------------------------
	{"id": &"kevlar_vest", "name": "Kevlar Vest Locker", "category": "Armor", "price": 0, "max": 1, "starter": true,
		"armor": 50, "desc": "Soft armor: 50 armor points."},
	{"id": &"plate_carrier", "name": "Plate Carrier Locker", "category": "Armor", "price": 1500, "max": 1,
		"armor": 100, "desc": "Rifle plates front and back: full 100 armor."},
	{"id": &"riot_gear", "name": "Riot Gear Locker", "category": "Armor", "price": 2400, "max": 1,
		"armor": 100, "desc": "Helmet, shoulder guards and plates. Full armor and +2% salary (hazard pay).",
		"effects": {"salary": 0.02}},
	# --- Medical ----------------------------------------------------------------------------------
	{"id": &"first_aid", "name": "First Aid Station", "category": "Medical", "price": 800, "max": 1,
		"desc": "Wall cabinet that patches you back to full health."},
	{"id": &"trauma_cabinet", "name": "Trauma Kit Cabinet", "category": "Medical", "price": 1000, "max": 1,
		"desc": "Grab trauma kits so any class can revive a downed partner (max 2 carried)."},
	{"id": &"infirmary_bed", "name": "Infirmary Beds", "category": "Medical", "price": 1400, "max": 1,
		"desc": "Two beds in the staff room. Rest to heal fully. +3% morale.", "effects": {"morale": 0.03}},
	# --- Break room -------------------------------------------------------------------------------
	{"id": &"coffee_machine", "name": "Coffee Machine", "category": "Break Room", "price": 300, "max": 1,
		"desc": "Hot coffee: +15 health. Night shifts run on it. +3% morale.", "effects": {"morale": 0.03}},
	{"id": &"vending_machine", "name": "Vending Machine", "category": "Break Room", "price": 450, "max": 1,
		"desc": "Snacks: +10 health. +2% morale.", "effects": {"morale": 0.02}},
	{"id": &"water_cooler", "name": "Water Cooler", "category": "Break Room", "price": 150, "max": 1,
		"desc": "Stay hydrated. +1% morale.", "effects": {"morale": 0.01}},
	{"id": &"sofa", "name": "Break Room Sofa", "category": "Break Room", "price": 600, "max": 1,
		"desc": "Somewhere to sit between calls. +2% morale.", "effects": {"morale": 0.02}},
	{"id": &"tv", "name": "Wall TV", "category": "Break Room", "price": 800, "max": 1,
		"desc": "Local news on loop. +2% morale.", "effects": {"morale": 0.02}},
	{"id": &"arcade", "name": "Arcade Cabinet", "category": "Break Room", "price": 1200, "max": 1,
		"desc": "Retro shooter in the corner. +3% morale.", "effects": {"morale": 0.03}},
	{"id": &"pool_table", "name": "Pool Table", "category": "Break Room", "price": 1500, "max": 1,
		"desc": "For the long quiet hours. +3% morale.", "effects": {"morale": 0.03}},
	{"id": &"plants", "name": "Office Plants", "category": "Break Room", "price": 200, "max": 1,
		"desc": "A bit of green around the station. +1% morale.", "effects": {"morale": 0.01}},
	# --- Vehicles ---------------------------------------------------------------------------------
	{"id": &"cruiser", "name": "Patrol Cruiser", "category": "Vehicles", "price": 4000, "max": 2,
		"desc": "Another cruiser in the garage. +10% mission payout each.", "effects": {"mission": 0.10}},
	{"id": &"swat_van", "name": "SWAT Van", "category": "Vehicles", "price": 7500, "max": 1,
		"desc": "Armored tactical van. +25% mission payout.", "effects": {"mission": 0.25}},
	{"id": &"ambulance", "name": "Ambulance", "category": "Vehicles", "price": 5500, "max": 1,
		"desc": "Paramedics on standby in the garage. +15% mission payout.", "effects": {"mission": 0.15}},
	# --- Upgrades ---------------------------------------------------------------------------------
	{"id": &"training", "name": "Dispatcher Training", "category": "Upgrades", "price": 2000, "max": 1,
		"desc": "County certification course. +10% salary.", "effects": {"salary": 0.10}},
	{"id": &"union_deal", "name": "Union Pay Deal", "category": "Upgrades", "price": 5000, "max": 1,
		"desc": "Negotiated raise: +$100 base pay every payday.", "effects": {"base": 100}},
	{"id": &"overtime", "name": "Overtime Budget", "category": "Upgrades", "price": 3500, "max": 1,
		"desc": "Each correctly classified call pays $40 more.", "effects": {"correct": 40}},
]


static func get_item(item_id: StringName) -> Dictionary:
	for item: Dictionary in ITEMS:
		if item["id"] == item_id:
			return item
	return {}


static func has_item(item_id: StringName) -> bool:
	return not get_item(item_id).is_empty()


static func items_in(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in ITEMS:
		if item["category"] == category:
			result.append(item)
	return result


static func starter_items() -> Array[StringName]:
	var result: Array[StringName] = []
	for item: Dictionary in ITEMS:
		if item.get("starter", false):
			var id: StringName = item["id"]
			result.append(id)
	return result


static func price_of(item_id: StringName) -> int:
	return get_item(item_id).get("price", 0)


static func max_of(item_id: StringName) -> int:
	return get_item(item_id).get("max", 1)


## Sum of one effect key over an inventory {item_id: count}.
static func total_effect(inventory: Dictionary, key: String) -> float:
	var total: float = 0.0
	for id: Variant in inventory:
		var count: int = inventory[id]
		var effects: Dictionary = get_item(StringName(str(id))).get("effects", {})
		var value: float = effects.get(key, 0.0)
		total += value * count
	return total
