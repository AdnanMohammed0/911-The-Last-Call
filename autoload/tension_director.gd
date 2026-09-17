## Horror pacing (GAMEPLAY_MECHANICS §9.3). The host tracks `tension` (0..1) from recent player damage,
## sanity, hostile combat, anomaly hunts and how recently a scare happened, then:
##  * tension < LOW for LOW_SECONDS  -> schedule a scare for one player (lowest sanity first)
##  * tension > HIGH                 -> suppress new manifestations (anomalies ask `can_manifest`) and scares
##                                      until tension falls back under RECOVERED (recovery beat)
## Scares are per-peer hallucinations sent only to the victim (rpc_id), so players see different things.
## Authority: HOST (tension, scheduling) / victim peer (playing the hallucination)
extends Node

const LOW: float = 0.3
const HIGH: float = 0.8
const RECOVERED: float = 0.6
const LOW_SECONDS: float = 90.0
const DAMAGE_WINDOW_SEC: float = 20.0
const DAMAGE_FOR_MAX: float = 150.0
const SCARE_AFTERGLOW_SEC: float = 30.0
const SMOOTHING: float = 0.35
const KINDS: Array[StringName] = [&"radio_whisper", &"phantom_steps", &"phantom_ring", &"shadow_figure"]

signal tension_changed(value: float)
signal scare_scheduled(peer_id: int, kind: StringName)

var tension: float = 0.0
var suppressed: bool = false
var enabled: bool = true

var _low_time: float = 0.0
var _since_scare: float = INF
var _last_kind: StringName = &""
var _damage_log: Array[Vector2] = []   # (time, amount)
var _clock: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	EventBus.player_damaged.connect(_on_player_damaged)
	NetManager.session_ended.connect(func(_reason: String) -> void: reset())


func _process(delta: float) -> void:
	if not enabled or not multiplayer.is_server() or get_tree().get_nodes_in_group(Player.GROUP).is_empty():
		return
	update(delta)


func reset() -> void:
	tension = 0.0
	suppressed = false
	_low_time = 0.0
	_since_scare = INF
	_damage_log.clear()


## Anomalies call this before manifesting.
func can_manifest() -> bool:
	return not suppressed


## Host: advance the director by `delta` seconds (tests step it directly).
func update(delta: float) -> void:
	_clock += delta
	_since_scare += delta
	var target: float = compute_target_tension()
	tension = lerpf(tension, target, clampf(SMOOTHING * delta * 4.0, 0.0, 1.0))
	tension_changed.emit(tension)

	if tension > HIGH:
		suppressed = true
	elif suppressed and tension < RECOVERED:
		suppressed = false

	if tension < LOW and not suppressed:
		_low_time += delta
		if _low_time >= LOW_SECONDS:
			_low_time = 0.0
			schedule_scare()
	else:
		_low_time = 0.0


## Instant tension from the current situation (before smoothing).
func compute_target_tension() -> float:
	var damage: float = 0.0
	_damage_log = _damage_log.filter(func(entry: Vector2) -> bool: return _clock - entry.x <= DAMAGE_WINDOW_SEC)
	for entry: Vector2 in _damage_log:
		damage += entry.y
	var damage_term: float = clampf(damage / DAMAGE_FOR_MAX, 0.0, 1.0)

	var sanity_total: float = 0.0
	var players: int = 0
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var player: Player = node as Player
		if player != null:
			sanity_total += player.sanity
			players += 1
	var sanity_term: float = 1.0 - (sanity_total / players) / 100.0 if players > 0 else 0.0

	var combat_term: float = 0.0
	for node: Node in get_tree().get_nodes_in_group(HostileAgent.GROUP):
		var hostile: HostileAgent = node as HostileAgent
		if hostile != null and hostile.is_active() and hostile.perception.level == AIPerception.Level.COMBAT:
			combat_term = 0.7
			break
	for node: Node in get_tree().get_nodes_in_group(Anomaly.GROUP):
		var anomaly: Anomaly = node as Anomaly
		if anomaly != null and anomaly.state_name in [&"hunt", &"attack"]:
			combat_term = maxf(combat_term, 0.95)
		elif anomaly != null and anomaly.state_name == &"manifest":
			combat_term = maxf(combat_term, 0.6)

	var scare_term: float = clampf(1.0 - _since_scare / SCARE_AFTERGLOW_SEC, 0.0, 1.0) * 0.5
	return clampf(maxf(maxf(damage_term, combat_term), scare_term) * 0.75 + sanity_term * 0.35, 0.0, 1.0)


## Host: pick a victim and a scare, and send it to that player only. Returns the victim peer (0 = none).
func schedule_scare(kind: StringName = &"") -> int:
	if not multiplayer.is_server() or suppressed:
		return 0
	var victim: Player = _pick_victim()
	if victim == null:
		return 0
	if kind == &"":
		var options: Array[StringName] = KINDS.filter(func(k: StringName) -> bool: return k != _last_kind)
		kind = options[_rng.randi() % options.size()]
	_last_kind = kind
	_since_scare = 0.0
	var at: Vector3 = _scare_position(victim)
	scare_scheduled.emit(victim.peer_id, kind)
	if victim.peer_id == multiplayer.get_unique_id() or not NetManager.is_online():
		_play_hallucination(kind, at)
	else:
		_play_hallucination.rpc_id(victim.peer_id, kind, at)
	return victim.peer_id


func _pick_victim() -> Player:
	var candidates: Array[Player] = []
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var player: Player = node as Player
		if player != null and player.get_health().is_alive():
			candidates.append(player)
	if candidates.is_empty():
		return null
	# Weighted towards low sanity: weight = 1 + (100 - sanity) / 20.
	var total: float = 0.0
	for player: Player in candidates:
		total += 1.0 + (100.0 - player.sanity) / 20.0
	var roll: float = _rng.randf() * total
	for player: Player in candidates:
		roll -= 1.0 + (100.0 - player.sanity) / 20.0
		if roll <= 0.0:
			return player
	return candidates[candidates.size() - 1]


## Just behind and to the side of the victim, where they are not looking.
func _scare_position(victim: Player) -> Vector3:
	var back: Vector3 = victim.get_camera().global_basis.z
	back.y = 0.0
	var side: Vector3 = back.cross(Vector3.UP) * _rng.randf_range(-2.0, 2.0)
	return victim.global_position + back.normalized() * _rng.randf_range(4.0, 7.0) + side


func _on_player_damaged(_peer_id: int, amount: float) -> void:
	_damage_log.append(Vector2(_clock, amount))


# --- Victim side ---------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _play_hallucination(kind: StringName, at: Vector3) -> void:
	EventBus.hallucination.emit(kind, at)
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	parent.add_child(Hallucination.create(kind, at))
