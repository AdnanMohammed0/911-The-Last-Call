## Player health (GAMEPLAY_MECHANICS §3.1): location damage, 25 % step regeneration, downed + bleed-out,
## revive and critical. All changes happen on the host and replicate through the player's HostSync.
## Weapons (P3-01), AI and hazards call `apply_damage` on the host.
## Authority: HOST
class_name HealthComponent
extends Node

enum State { ALIVE, DOWNED, CRITICAL }
enum HitZone { TORSO, HEAD, ARM, LEG }

const ZONE_MULTIPLIERS: Dictionary[HitZone, float] = {
	HitZone.TORSO: 1.0,
	HitZone.HEAD: 2.0,
	HitZone.ARM: 0.75,
	HitZone.LEG: 0.75,
}
const BLEED_OUT_SEC: float = 45.0
const REGEN_DELAY_SEC: float = 6.0
const REGEN_PER_SEC: float = 4.0
const REGEN_STEP: float = 0.25
## Revived players come back with this share of max health.
const REVIVE_HEALTH_RATIO: float = 0.4
## A single leg / arm hit this strong rolls a lingering trait (GAMEPLAY §3.4).
const TRAIT_HIT_THRESHOLD: float = 30.0
const MAX_ARMOR: float = 100.0
## Share of body-shot damage a vest absorbs while it has armor left (head shots bypass it).
const ARMOR_ABSORB: float = 0.65

signal health_changed(hp: float, max_hp: float)
signal state_changed(new_state: State)
signal damaged(amount: float, zone: HitZone, source_peer: int)

@export var max_hp: float = 100.0
## 0..1, from ClassData (Breacher 0.25).
@export var damage_resistance: float = 0.0

# --- Replicated (HostSync) ---
var hp: float = 100.0:
	set(value):
		hp = value
		health_changed.emit(hp, max_hp)
var state: State = State.ALIVE:
	set(value):
		if state == value:
			return
		state = value
		state_changed.emit(state)
var bleed_out_remaining: float = BLEED_OUT_SEC
## Peer currently reviving this player (0 = nobody); bleed-out is paused meanwhile.
var reviver_peer: int = 0
## Ballistic vest points (armory). Replicated (HostSync).
var armor: float = 0.0

var _since_damage: float = 0.0
var _regen_cap: float = 100.0

@onready var _player: Player = get_parent() as Player


func _ready() -> void:
	hp = max_hp
	_regen_cap = max_hp


func setup(new_max_hp: float, resistance: float) -> void:
	max_hp = new_max_hp
	damage_resistance = clampf(resistance, 0.0, 0.9)
	hp = max_hp
	_regen_cap = max_hp


func is_alive() -> bool:
	return state == State.ALIVE


func is_downed() -> bool:
	return state == State.DOWNED


## Maps a world-space hit point on the player to a zone (until per-bone hitboxes exist).
static func zone_for_hit(player: Player, world_point: Vector3) -> HitZone:
	var local: Vector3 = player.global_transform.affine_inverse() * world_point
	var height: float = player.get_eye_position().y - player.global_position.y + 0.15
	var ratio: float = clampf(local.y / maxf(height, 0.1), 0.0, 1.0)
	if ratio >= 0.86:
		return HitZone.HEAD
	if ratio < 0.47:
		return HitZone.LEG
	if absf(local.x) > 0.22:
		return HitZone.ARM
	return HitZone.TORSO


# --- Host API -----------------------------------------------------------------

## Host: deal damage. Returns the damage actually taken after zone multiplier and resistance.
func apply_damage(amount: float, zone: HitZone = HitZone.TORSO, source_peer: int = 0) -> float:
	if not multiplayer.is_server() or amount <= 0.0 or state == State.CRITICAL:
		return 0.0
	var taken: float = amount * ZONE_MULTIPLIERS[zone] * (1.0 - damage_resistance)
	if armor > 0.0 and zone != HitZone.HEAD and state == State.ALIVE:
		var absorbed: float = minf(taken * ARMOR_ABSORB, armor)
		armor -= absorbed
		taken -= absorbed
	if state == State.DOWNED:
		# Hits while downed shorten the bleed-out instead of killing outright.
		bleed_out_remaining = maxf(bleed_out_remaining - taken * 0.2, 0.0)
		return taken
	hp = maxf(hp - taken, 0.0)
	_since_damage = 0.0
	_regen_cap = minf(ceilf(hp / (max_hp * REGEN_STEP) - 0.0001) * max_hp * REGEN_STEP, max_hp)
	damaged.emit(taken, zone, source_peer)
	EventBus.player_damaged.emit(_player.peer_id, taken)
	if taken >= TRAIT_HIT_THRESHOLD:
		if zone == HitZone.LEG:
			EventBus.trait_applied.emit(_player.peer_id, &"limping")      # TODO(P4): TraitSystem applies effects
		elif zone == HitZone.ARM:
			EventBus.trait_applied.emit(_player.peer_id, &"fractured_hand")
	if hp <= 0.0:
		_go_down()
	return taken


## Host: equip / top up a ballistic vest.
func give_armor(amount: float) -> void:
	if multiplayer.is_server():
		armor = clampf(armor + amount, 0.0, MAX_ARMOR)


## Host: heal (sedatives, medkits). Does not revive a downed player.
func heal(amount: float) -> void:
	if not multiplayer.is_server() or state != State.ALIVE:
		return
	hp = minf(hp + amount, max_hp)
	_regen_cap = maxf(_regen_cap, hp)


## Host: finish a revive (called by ReviveInteractable).
func revive(by_peer: int) -> void:
	if not multiplayer.is_server() or state != State.DOWNED:
		return
	reviver_peer = 0
	hp = max_hp * REVIVE_HEALTH_RATIO
	_regen_cap = hp
	_since_damage = 0.0
	bleed_out_remaining = BLEED_OUT_SEC
	state = State.ALIVE
	EventBus.player_revived.emit(_player.peer_id, by_peer)


## Host: full reset (new mission / respawn).
func restore() -> void:
	if not multiplayer.is_server():
		return
	reviver_peer = 0
	bleed_out_remaining = BLEED_OUT_SEC
	hp = max_hp
	_regen_cap = max_hp
	state = State.ALIVE


func _go_down() -> void:
	hp = 0.0
	bleed_out_remaining = BLEED_OUT_SEC
	reviver_peer = 0
	state = State.DOWNED
	EventBus.player_downed.emit(_player.peer_id)


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	match state:
		State.ALIVE:
			_since_damage += delta
			if _since_damage >= REGEN_DELAY_SEC and hp < _regen_cap:
				hp = minf(hp + REGEN_PER_SEC * delta, _regen_cap)
		State.DOWNED:
			if reviver_peer == 0:
				bleed_out_remaining = maxf(bleed_out_remaining - delta, 0.0)
			if bleed_out_remaining <= 0.0:
				reviver_peer = 0
				state = State.CRITICAL
				EventBus.player_critical.emit(_player.peer_id)
				EventBus.trait_applied.emit(_player.peer_id, &"lingering_injury")  # §3.1: 100 % roll
