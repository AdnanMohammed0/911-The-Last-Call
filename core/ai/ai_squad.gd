## Squad coordination (GAMEPLAY_MECHANICS §8.3): shared callouts, flank tokens and morale.
## Members register themselves; morale events can target one member or the whole squad.
## Morale modifiers: ally killed −15, leader killed −30, Breacher shield wall visible −10,
## megaphone success −25, tear gas −20, outnumbering the visible players +10 (re-evaluated periodically).
## Authority: HOST
class_name AISquad
extends Node

const ALLY_KILLED: float = -15.0
const LEADER_KILLED: float = -30.0
const SHIELD_WALL: float = -10.0
const MEGAPHONE: float = -25.0
const TEAR_GAS: float = -20.0
const OUTNUMBERING: float = 10.0
const OUTNUMBER_CHECK_SEC: float = 3.0

signal member_surrendered(member: HostileAgent)

var members: Array[HostileAgent] = []

var _flank_holders: Array[HostileAgent] = []
var _outnumber_timer: float = 0.0
var _outnumber_bonus_applied: bool = false


func register(member: HostileAgent) -> void:
	if member in members:
		return
	members.append(member)
	member.perception.callout.connect(_on_callout.bind(member))
	member.died.connect(_on_member_died.bind(member))
	member.surrendered.connect(func() -> void: member_surrendered.emit(member))


func alive_members() -> Array[HostileAgent]:
	var alive: Array[HostileAgent] = []
	for member: HostileAgent in members:
		if is_instance_valid(member) and member.is_active():
			alive.append(member)
	return alive


## Half the squad (rounded down, at least one) may flank at the same time.
func request_flank_token(member: HostileAgent) -> bool:
	_flank_holders = _flank_holders.filter(func(m: HostileAgent) -> bool: return is_instance_valid(m) and m.is_active())
	if member in _flank_holders:
		return true
	var limit: int = maxi(1, alive_members().size() / 2)
	if _flank_holders.size() >= limit or alive_members().size() < 2:
		return false
	_flank_holders.append(member)
	return true


func release_flank_token(member: HostileAgent) -> void:
	_flank_holders.erase(member)


func has_free_flank_token(member: HostileAgent) -> bool:
	if member in _flank_holders:
		return true
	return alive_members().size() >= 2 and _flank_holders.size() < maxi(1, alive_members().size() / 2)


## Apply a morale change to every living member (megaphone, tear gas on the group, etc.).
func apply_morale_event(amount: float, reason: StringName) -> void:
	for member: HostileAgent in alive_members():
		member.change_morale(amount, reason)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_outnumber_timer += delta
	if _outnumber_timer < OUTNUMBER_CHECK_SEC:
		return
	_outnumber_timer = 0.0
	var alive: Array[HostileAgent] = alive_members()
	var seen_players: int = 0
	for member: HostileAgent in alive:
		seen_players = maxi(seen_players, member.perception.visible_player_count)
	var outnumbering: bool = seen_players > 0 and alive.size() > seen_players
	if outnumbering != _outnumber_bonus_applied:
		_outnumber_bonus_applied = outnumbering
		apply_morale_event(OUTNUMBERING if outnumbering else -OUTNUMBERING, &"outnumbering")


func _on_callout(target_peer: int, position: Vector3, caller: HostileAgent) -> void:
	for member: HostileAgent in alive_members():
		if member != caller:
			member.perception.receive_callout(target_peer, position)


func _on_member_died(member: HostileAgent) -> void:
	release_flank_token(member)
	var amount: float = LEADER_KILLED if member.archetype.reinforcements > 0 or member.archetype.id == &"ambush_leader" else ALLY_KILLED
	for other: HostileAgent in alive_members():
		if other != member:
			other.change_morale(amount, &"ally_killed")
