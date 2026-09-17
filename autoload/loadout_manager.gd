## Loadout Manager — manages armory budget, gear purchases, and loadout voting (GAMEPLAY_MECHANICS §6).
## Authority: HOST (budget and purchases validated on host, replicated via RPC).
class_name LoadoutManager
extends Node

signal budget_changed(new_budget: int)
signal gear_purchased(peer_id: int, gear_id: StringName, cost: int)
signal gear_sold(peer_id: int, gear_id: StringName, refund: int)
signal loadout_finalized(peer_id: int, loadout: Dictionary)
signal vote_opened(vote_id: int, topic: StringName, options: Array[StringName], timeout: float)
signal vote_cast(peer_id: int, vote_id: int, option: StringName)
signal vote_closed(vote_id: int, result: StringName, tally: Dictionary)
signal approach_selected(approach: StringName)

@export var loadout_vote_timeout: float = 90.0

## Shared station budget (from GameState)
var _station_budget: int = 10000

## Per-peer loadout selections: peer_id -> {gear_id -> quantity}
var _player_loadouts: Dictionary[int, Dictionary[StringName, int]] = {}

## Active vote state
var _active_vote_id: int = 0
var _vote_counter: int = 0
var _votes: Dictionary[int, Dictionary] = {}

## Gear catalog (loaded from resources)
var _gear_catalog: Dictionary[StringName, GearItem] = {}

func _ready() -> void:
	_load_gear_catalog()
	if GameState != null:
		_station_budget = GameState.station_budget
		GameState.budget_changed.connect(_on_game_state_budget_changed)


func _load_gear_catalog() -> void:
	# Load all .tres files from data/loadout/gear/
	var dir: DirAccess = DirAccess.open("res://data/loadout/gear/")
	if dir == null:
		push_error("LoadoutManager: gear directory not found")
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path: String = "res://data/loadout/gear/" + file_name
			var gear: GearItem = load(path) as GearItem
			if gear != null and gear.id != &"":
				_gear_catalog[gear.id] = gear
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# If no gear files found, create default catalog
	if _gear_catalog.is_empty():
		_create_default_catalog()


func _create_default_catalog() -> void:
	# Service Pistol (free, all classes)
	var pistol: GearItem = GearItem.new()
	pistol.id = &"service_pistol"
	pistol.display_name = "Service Pistol"
	pistol.cost = 0
	pistol.slot = GearItem.Slot.SIDEARM
	pistol.max_carry = 1
	_gear_catalog[pistol.id] = pistol
	
	# Pump Shotgun
	var shotgun: GearItem = GearItem.new()
	shotgun.id = &"pump_shotgun"
	shotgun.display_name = "Pump Shotgun"
	shotgun.cost = 400
	shotgun.slot = GearItem.Slot.PRIMARY
	shotgun.breacher_discount = true
	_gear_catalog[shotgun.id] = shotgun
	
	# Patrol Rifle
	var rifle: GearItem = GearItem.new()
	rifle.id = &"patrol_rifle"
	rifle.display_name = "Patrol Rifle"
	rifle.cost = 700
	rifle.slot = GearItem.Slot.PRIMARY
	_gear_catalog[rifle.id] = rifle
	
	# Ballistic Shield (Breacher only)
	var shield: GearItem = GearItem.new()
	shield.id = &"ballistic_shield"
	shield.display_name = "Ballistic Shield"
	shield.cost = 900
	shield.slot = GearItem.Slot.HEAVY
	shield.allowed_classes = PackedStringArray(&"breacher")
	_gear_catalog[shield.id] = shield
	
	# Battering Ram (Breacher only)
	var ram: GearItem = GearItem.new()
	ram.id = &"battering_ram"
	ram.display_name = "Battering Ram"
	ram.cost = 300
	ram.slot = GearItem.Slot.HEAVY
	ram.allowed_classes = PackedStringArray(&"breacher")
	_gear_catalog[ram.id] = ram
	
	# Recon Drone (Tech only)
	var drone: GearItem = GearItem.new()
	drone.id = &"recon_drone"
	drone.display_name = "Recon Drone"
	drone.cost = 600
	drone.slot = GearItem.Slot.GADGET
	drone.allowed_classes = PackedStringArray(&"tech")
	_gear_catalog[drone.id] = drone
	
	# Tear Gas
	var tear_gas: GearItem = GearItem.new()
	tear_gas.id = &"tear_gas"
	tear_gas.display_name = "Tear Gas ×2"
	tear_gas.cost = 250
	tear_gas.slot = GearItem.Slot.THROWABLE
	tear_gas.quantity_per_purchase = 2
	tear_gas.max_carry = 2
	_gear_catalog[tear_gas.id] = tear_gas
	
	# Trauma Kit
	var trauma: GearItem = GearItem.new()
	trauma.id = &"trauma_kit"
	trauma.display_name = "Trauma Kit"
	trauma.cost = 200
	trauma.slot = GearItem.Slot.CONSUMABLE
	trauma.max_carry = 1
	_gear_catalog[trauma.id] = trauma
	
	# Sedatives (Medic only)
	var sedatives: GearItem = GearItem.new()
	sedatives.id = &"sedatives"
	sedatives.display_name = "Sedatives ×3"
	sedatives.cost = 300
	sedatives.slot = GearItem.Slot.CONSUMABLE
	sedatives.allowed_classes = PackedStringArray(&"medic")
	sedatives.quantity_per_purchase = 3
	sedatives.max_carry = 3
	_gear_catalog[sedatives.id] = sedatives
	
	# EMF Reader (Medic primary, others 50% accuracy - handled in field)
	var emf: GearItem = GearItem.new()
	emf.id = &"emf_reader"
	emf.display_name = "EMF Reader"
	emf.cost = 150
	emf.slot = GearItem.Slot.GADGET
	emf.allowed_classes = PackedStringArray(&"medic")
	_gear_catalog[emf.id] = emf
	
	# Salt Canister
	var salt: GearItem = GearItem.new()
	salt.id = &"salt_canister"
	salt.display_name = "Salt Canister"
	salt.cost = 120
	salt.slot = GearItem.Slot.CONSUMABLE
	salt.quantity_per_purchase = 1
	salt.max_carry = 2
	_gear_catalog[salt.id] = salt
	
	# Spectral Tone Emitter
	var tone: GearItem = GearItem.new()
	tone.id = &"spectral_tone_emitter"
	tone.display_name = "Spectral Tone Emitter"
	tone.cost = 500
	tone.slot = GearItem.Slot.GADGET
	tone.max_carry = 1
	_gear_catalog[tone.id] = tone


## Gets the gear item by ID.
func get_gear(gear_id: StringName) -> GearItem:
	return _gear_catalog.get(gear_id, null)


## Gets all gear items for a specific class.
func get_gear_for_class(class_id: StringName) -> Array[GearItem]:
	var result: Array[GearItem] = []
	for gear in _gear_catalog.values():
		if gear.is_available_for_class(class_id):
			result.append(gear)
	return result


## Gets current station budget.
func get_budget() -> int:
	return _station_budget


## Sets station budget (host only).
func set_budget(amount: int) -> void:
	if not multiplayer.is_server():
		return
	_station_budget = max(0, amount)
	budget_changed.emit(_station_budget)
	_sync_budget.rpc(_station_budget)


@rpc("authority", "call_local", "reliable")
func _sync_budget(amount: int) -> void:
	_station_budget = amount
	budget_changed.emit(amount)


## Purchases gear for a player (host only).
## Returns true if purchase successful.
func purchase_gear(peer_id: int, gear_id: StringName, class_id: StringName) -> bool:
	if not multiplayer.is_server():
		return false
	
	var gear: GearItem = _gear_catalog.get(gear_id, null)
	if gear == null:
		push_warning("LoadoutManager: gear '%s' not found" % gear_id)
		return false
	
	if not gear.is_available_for_class(class_id):
		push_warning("LoadoutManager: gear '%s' not available for class '%s'" % [gear_id, class_id])
		return false
	
	var effective_cost: int = gear.get_effective_cost(class_id)
	if _station_budget < effective_cost:
		push_warning("LoadoutManager: insufficient budget (%d < %d)" % [_station_budget, effective_cost])
		return false
	
	# Check carry limit
	var loadout: Dictionary = _player_loadouts.get(peer_id, {})
	var current_qty: int = loadout.get(gear_id, 0)
	if current_qty >= gear.max_carry:
		push_warning("LoadoutManager: player %d already at max carry for '%s'" % [peer_id, gear_id])
		return false
	
	# Process purchase
	_station_budget -= effective_cost
	loadout[gear_id] = current_qty + gear.quantity_per_purchase
	_player_loadouts[peer_id] = loadout
	
	budget_changed.emit(_station_budget)
	gear_purchased.emit(peer_id, gear_id, effective_cost)
	_sync_budget.rpc(_station_budget)
	
	return true


## Sells gear back for partial refund (host only).
func sell_gear(peer_id: int, gear_id: StringName) -> bool:
	if not multiplayer.is_server():
		return false
	
	var gear: GearItem = _gear_catalog.get(gear_id, null)
	if gear == null:
		return false
	
	var loadout: Dictionary = _player_loadouts.get(peer_id, {})
	var current_qty: int = loadout.get(gear_id, 0)
	if current_qty <= 0:
		return false
	
	# Refund 50% of effective cost
	var refund: int = (gear.get_effective_cost(NetManager.get_class_id(peer_id)) * gear.quantity_per_purchase) / 2
	
	_station_budget += refund
	loadout[gear_id] = current_qty - gear.quantity_per_purchase
	if loadout[gear_id] <= 0:
		loadout.erase(gear_id)
	_player_loadouts[peer_id] = loadout
	
	budget_changed.emit(_station_budget)
	gear_sold.emit(peer_id, gear_id, refund)
	_sync_budget.rpc(_station_budget)
	
	return true


## Gets a player's current loadout.
func get_player_loadout(peer_id: int) -> Dictionary:
	return _player_loadouts.get(peer_id, {}).duplicate()


## Clears a player's loadout (refunds all).
func clear_player_loadout(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	
	var loadout: Dictionary = _player_loadouts.get(peer_id, {})
	var class_id: StringName = NetManager.get_class_id(peer_id)
	
	for gear_id, qty in loadout:
		var gear: GearItem = _gear_catalog.get(gear_id, null)
		if gear != null:
			var refund_per: int = (gear.get_effective_cost(class_id) * gear.quantity_per_purchase) / 2
			var total_refund: int = refund_per * (qty / gear.quantity_per_purchase)
			_station_budget += total_refund
	
	_player_loadouts.erase(peer_id)
	budget_changed.emit(_station_budget)
	_sync_budget.rpc(_station_budget)


## Finalizes a player's loadout for the mission.
func finalize_loadout(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	
	var loadout: Dictionary = _player_loadouts.get(peer_id, {})
	loadout_finalized.emit(peer_id, loadout.duplicate())


## Opens the approach vote (host only).
func open_approach_vote() -> int:
	if not multiplayer.is_server():
		return 0
	
	if _active_vote_id != 0:
		return _active_vote_id
	
	_vote_counter += 1
	_active_vote_id = _vote_counter
	
	var options: Array[StringName] = [&"code3", &"silent", &"on_foot", &"decoy"]
	var vote_data: Dictionary = {
		"id": _active_vote_id,
		"topic": &"approach",
		"options": options,
		"votes": {},
		"start_time": Time.get_ticks_msec() / 1000.0,
		"timeout": loadout_vote_timeout,
	}
	_votes[_active_vote_id] = vote_data
	
	vote_opened.emit(_active_vote_id, &"approach", options, loadout_vote_timeout)
	
	# Auto-close after timeout
	var timer: Timer = Timer.new()
	timer.wait_time = loadout_vote_timeout
	timer.one_shot = true
	timer.timeout.connect(func(): _close_vote(_active_vote_id))
	add_child(timer)
	timer.start()
	
	return _active_vote_id


## Casts a vote in the active approach vote.
func cast_vote(peer_id: int, option: StringName) -> bool:
	if not multiplayer.is_server():
		return false
	
	if _active_vote_id == 0:
		return false
	
	var vote_data: Dictionary = _votes.get(_active_vote_id, {})
	if not vote_data.has("options") or option not in vote_data.options:
		return false
	
	vote_data.votes[peer_id] = option
	vote_cast.emit(peer_id, _active_vote_id, option)
	
	# Check for unanimous verdict (all players voted same)
	var all_voted: bool = vote_data.votes.size() == NetManager.roster.size()
	var unanimous: bool = false
	if all_voted:
		var first_vote: StringName = vote_data.votes.values().front()
		unanimous = true
		for v in vote_data.votes.values():
			if v != first_vote:
				unanimous = false
				break
	
	if unanimous:
		_close_vote(_active_vote_id)
	
	return true


## Gets current vote tally.
func get_tally(vote_id: int) -> Dictionary:
	var vote_data: Dictionary = _votes.get(vote_id, {})
	var tally: Dictionary = {}
	if vote_data.has("votes"):
		for peer_id, option in vote_data.votes:
			tally[option] = tally.get(option, 0) + 1
	return tally


## Gets time left in vote.
func get_time_left(vote_id: int) -> float:
	var vote_data: Dictionary = _votes.get(vote_id, {})
	if not vote_data.has("start_time") or not vote_data.has("timeout"):
		return 0.0
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - vote_data.start_time
	return max(0.0, vote_data.timeout - elapsed)


func _close_vote(vote_id: int) -> void:
	if not _votes.has(vote_id):
		return
	
	var vote_data: Dictionary = _votes[vote_id]
	var tally: Dictionary = get_tally(vote_id)
	
	# Determine winner (majority, ties broken by Breacher)
	var result: StringName = _determine_vote_winner(tally)
	
	vote_closed.emit(vote_id, result, tally)
	_votes.erase(vote_id)
	
	if _active_vote_id == vote_id:
		_active_vote_id = 0
	
	if result != &"":
		approach_selected.emit(result)


func _determine_vote_winner(tally: Dictionary) -> StringName:
	if tally.is_empty():
		return &""
	
	# Find option with most votes
	var max_votes: int = -1
	var winners: Array[StringName] = []
	for option, count in tally:
		if count > max_votes:
			max_votes = count
			winners = [option]
		elif count == max_votes:
			winners.append(option)
	
	if winners.size() == 1:
		return winners[0]
	
	# Tie - Breacher decides
	var breacher_peer: int = _find_breacher_peer()
	if breacher_peer > 0 and _votes.has(_active_vote_id):
		var vote_data: Dictionary = _votes[_active_vote_id]
		if vote_data.has("votes") and vote_data.votes.has(breacher_peer):
			return vote_data.votes[breacher_peer]
	
	# No breacher or breacher didn't vote - pick first alphabetically
	winners.sort()
	return winners[0]


func _find_breacher_peer() -> int:
	if NetManager == null:
		return 0
	for peer_id, data in NetManager.roster:
		if data.get("class_id", &"") == &"breacher":
			return peer_id
	return 0


func _on_game_state_budget_changed(amount: int) -> void:
	_station_budget = amount


func reset() -> void:
	_station_budget = 10000
	_player_loadouts.clear()
	_votes.clear()
	_active_vote_id = 0
	_vote_counter = 0