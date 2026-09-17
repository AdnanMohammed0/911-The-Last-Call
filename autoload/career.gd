## Player progression: XP, police ranks and what each rank unlocks, plus lifetime stats. Each player keeps
## their own profile in user://career.cfg; the host awards XP to peers by RPC and keeps everyone's rank so
## it can validate rank-locked armory gear.
## Authority: LOCAL (profile) / HOST (awards, rank registry)
extends Node

const PATH: String = "user://career.cfg"
## [XP needed, rank name]
const RANKS: Array[Array] = [
	[0, "Rookie"], [250, "Officer"], [700, "Senior Officer"], [1400, "Corporal"],
	[2400, "Sergeant"], [3800, "Lieutenant"], [6000, "Captain"],
]
## Minimum rank index to draw each weapon from the armory (field pickups are never locked).
const WEAPON_RANKS: Dictionary[StringName, int] = {&"pistol": 0, &"shotgun": 1, &"smg": 2, &"rifle": 3}
const ARMOR_RANK: int = 1

signal xp_gained(amount: int, reason: String)
signal xp_changed(xp: int, rank: int)
signal promoted(rank: int, rank_name: String, unlocks: PackedStringArray)

var xp: int = 0
var stats: Dictionary[String, int] = {}
## Host registry of every connected player's rank (broadcast to all peers for UI prompts).
var peer_ranks: Dictionary[int, int] = {}
## Tests turn saving off.
var persist: bool = true


func _ready() -> void:
	load_profile()
	NetManager.session_started.connect(report_rank)
	NetManager.peer_joined.connect(func(_id: int, _name: String) -> void:
		if multiplayer.is_server():
			_sync_ranks.rpc(peer_ranks))


# --- Ranks ------------------------------------------------------------------------------------

static func rank_for_xp(amount: int) -> int:
	var index: int = 0
	for i: int in RANKS.size():
		var needed: int = RANKS[i][0]
		if amount >= needed:
			index = i
	return index


static func rank_name(index: int) -> String:
	var clamped: int = clampi(index, 0, RANKS.size() - 1)
	var rank_title: String = RANKS[clamped][1]
	return rank_title


func rank() -> int:
	return rank_for_xp(xp)


## XP where the current rank started and where the next begins (next = -1 at max rank).
func rank_bounds() -> Vector2i:
	var index: int = rank()
	var start: int = RANKS[index][0]
	var next: int = RANKS[index + 1][0] if index + 1 < RANKS.size() else -1
	return Vector2i(start, next)


## Rank of any player (the local profile for ourselves, the host registry for others).
func rank_of(peer_id: int) -> int:
	if peer_id == multiplayer.get_unique_id():
		return rank()
	return peer_ranks.get(peer_id, 0)


static func required_rank(weapon_id: StringName) -> int:
	return WEAPON_RANKS.get(weapon_id, 0)


## Names of the gear first available at `index`.
static func unlocks_at(index: int) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for weapon_id: StringName in WEAPON_RANKS:
		if WEAPON_RANKS[weapon_id] == index:
			var data: WeaponData = WeaponCatalog.get_data(weapon_id)
			if data != null:
				names.append(data.display_name)
	if ARMOR_RANK == index:
		names.append("Ballistic vest")
	return names


# --- Awards ------------------------------------------------------------------------------------

## Host: give `amount` XP (negative allowed) to `peer_id`. `stat` also increments a lifetime counter.
func award(peer_id: int, amount: int, reason: String, stat: String = "") -> void:
	if not multiplayer.is_server():
		return
	if peer_id == multiplayer.get_unique_id():
		_apply(amount, reason, stat)
	else:
		_rpc_award.rpc_id(peer_id, amount, reason, stat)


## Host: award every player currently in the level (or just us when nobody is spawned yet).
func award_team(amount: int, reason: String, stat: String = "") -> void:
	if not multiplayer.is_server():
		return
	var paid: int = 0
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var player: Player = node as Player
		if player != null and not player.connection_lost:
			award(player.peer_id, amount, reason, stat)
			paid += 1
	if paid == 0:
		award(multiplayer.get_unique_id(), amount, reason, stat)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_award(amount: int, reason: String, stat: String) -> void:
	if RpcGuard.is_from_host(self):
		_apply(amount, reason, stat)


func _apply(amount: int, reason: String, stat: String) -> void:
	var before: int = rank()
	xp = maxi(xp + amount, 0)
	if stat != "":
		stats[stat] = stats.get(stat, 0) + 1
	save_profile()
	if amount != 0:
		xp_gained.emit(amount, reason)
	xp_changed.emit(xp, rank())
	var after: int = rank()
	if after > before:
		var unlocked: PackedStringArray = PackedStringArray()
		for index: int in range(before + 1, after + 1):
			unlocked.append_array(unlocks_at(index))
		promoted.emit(after, rank_name(after), unlocked)
	if after != before:
		report_rank()


## Tell the host our rank (host records its own directly).
func report_rank() -> void:
	if multiplayer.is_server():
		peer_ranks[multiplayer.get_unique_id()] = rank()
		if NetManager.is_online():
			_sync_ranks.rpc(peer_ranks)
	else:
		_rpc_report_rank.rpc_id(1, rank())


@rpc("any_peer", "call_remote", "reliable")
func _rpc_report_rank(index: int) -> void:
	if not RpcGuard.is_host(self):
		return
	peer_ranks[RpcGuard.sender_id(self)] = clampi(index, 0, RANKS.size() - 1)
	_sync_ranks.rpc(peer_ranks)


@rpc("authority", "call_remote", "reliable")
func _sync_ranks(ranks: Dictionary) -> void:
	peer_ranks.clear()
	for peer: Variant in ranks:
		var id: int = peer
		var index: int = ranks[peer]
		peer_ranks[id] = index


# --- Persistence -------------------------------------------------------------------------------

func load_profile() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(PATH) != OK:
		return
	xp = config.get_value("career", "xp", 0)
	if config.has_section("stats"):
		for key: String in config.get_section_keys("stats"):
			stats[key] = config.get_value("stats", key, 0)


func save_profile() -> void:
	if not persist:
		return
	var config: ConfigFile = ConfigFile.new()
	config.set_value("career", "xp", xp)
	for key: String in stats:
		config.set_value("stats", key, stats[key])
	config.save(PATH)


## Tests / "reset career" option.
func reset(keep_file: bool = true) -> void:
	xp = 0
	stats.clear()
	peer_ranks.clear()
	if not keep_file:
		save_profile()
	xp_changed.emit(xp, rank())
