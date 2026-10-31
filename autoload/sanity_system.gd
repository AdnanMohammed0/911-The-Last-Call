## Host-owned sanity rules and local Panic audio. Spatial drain only occurs inside explicit dark zones.
extends Node

enum Band { STEADY, UNEASY, PANICKED, BROKEN }

const DARK_DRAIN: float = 0.5
const LIGHT_RESTORE: float = 0.3
const AMBIENT_STEP: float = 0.25
const PANIC_BUS: StringName = &"Panic"

var _ambient_clock: float = 0.0
var _local_band: Band = Band.STEADY
var _hallucination_clock: float = 24.0
var _audio_ratio: float = 1.0


func _ready() -> void:
	EventBus.player_downed.connect(_on_player_downed)
	EventBus.player_critical.connect(_on_player_critical)
	MissionDirector.state_changed.connect(_on_mission_state_changed)
	NetManager.session_ended.connect(_on_session_ended)


static func ratio(player: Player) -> float:
	return clampf(player.sanity / maxf(player.max_sanity, 1.0), 0.0, 1.0)


static func band_for(value: float, maximum: float) -> Band:
	var percent: float = clampf(value / maxf(maximum, 1.0), 0.0, 1.0)
	if percent < 0.15:
		return Band.BROKEN
	if percent < 0.40:
		return Band.PANICKED
	if percent < 0.70:
		return Band.UNEASY
	return Band.STEADY


func get_band(peer_id: int) -> Band:
	var player: Player = Player.find_by_peer(get_tree(), peer_id)
	return band_for(player.sanity, player.max_sanity) if player != null else Band.STEADY


func get_sanity(peer_id: int) -> float:
	var player: Player = Player.find_by_peer(get_tree(), peer_id)
	return player.sanity if player != null else 0.0


func damage(peer_id: int, amount: float, source: StringName) -> void:
	var player: Player = Player.find_by_peer(get_tree(), peer_id)
	if player != null:
		player.apply_sanity_damage(amount, source)


func restore(peer_id: int, amount: float) -> void:
	var player: Player = Player.find_by_peer(get_tree(), peer_id)
	if player != null:
		player.restore_sanity(amount)


func _process(delta: float) -> void:
	_update_local_effects(delta)
	if not multiplayer.is_server():
		return
	_ambient_clock += delta
	if _ambient_clock < AMBIENT_STEP:
		return
	var elapsed: float = _ambient_clock
	_ambient_clock = 0.0
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var player: Player = node as Player
		if player == null or player.connection_lost or player.get_health() == null or not player.get_health().is_alive():
			continue
		match _zone_at(player.global_position + Vector3.UP):
			-1:
				if not player.flashlight_on:
					player.apply_sanity_damage(DARK_DRAIN * elapsed, &"darkness")
			1:
				player.restore_sanity(LIGHT_RESTORE * elapsed)


## -1: explicit dark area, 1: lit area, 0: neutral. No broad unlit-world drain.
func _zone_at(point: Vector3) -> int:
	var lit: bool = false
	for node: Node in get_tree().get_nodes_in_group(&"light_zones"):
		var area: Area3D = node as Area3D
		if area == null or not AIPerception._area_contains(area, point):
			continue
		if area.is_in_group(&"darkness_zones") or area.name.to_lower().begins_with("dark"):
			return -1
		lit = true
	return 1 if lit else 0


func _update_local_effects(delta: float) -> void:
	var player: Player = Player.find_by_peer(get_tree(), NetManager.get_local_peer_id())
	var target: float = ratio(player) if player != null else 1.0
	_audio_ratio = move_toward(_audio_ratio, target, delta * 0.7)
	var bus: int = AudioServer.get_bus_index(PANIC_BUS)
	if bus >= 0 and AudioServer.get_bus_effect_count(bus) >= 2:
		var lowpass: AudioEffectLowPassFilter = AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
		var reverb: AudioEffectReverb = AudioServer.get_bus_effect(bus, 1) as AudioEffectReverb
		if lowpass != null:
			lowpass.cutoff_hz = lerpf(800.0, 20000.0, _audio_ratio)
		if reverb != null:
			reverb.wet = lerpf(0.22, 0.0, _audio_ratio)
	var new_band: Band = band_for(player.sanity, player.max_sanity) if player != null else Band.STEADY
	if new_band != _local_band:
		_local_band = new_band
		EventBus.sanity_band_changed.emit(NetManager.get_local_peer_id(), new_band)
	if player == null or new_band < Band.PANICKED:
		return
	_hallucination_clock -= delta
	if _hallucination_clock <= 0.0:
		_hallucination_clock = randf_range(20.0, 35.0)
		EventBus.hallucination.emit(&"phantom_steps" if new_band == Band.PANICKED else &"phantom_ring", player.global_position)


func _on_player_downed(peer_id: int) -> void:
	_damage_teammates(peer_id, 10.0, &"teammate_downed")


func _on_player_critical(peer_id: int) -> void:
	_damage_teammates(peer_id, 15.0, &"witnessed_death")


func _damage_teammates(except_peer: int, amount: float, source: StringName) -> void:
	if not multiplayer.is_server():
		return
	var source_player: Player = Player.find_by_peer(get_tree(), except_peer)
	if source_player == null:
		return
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var player: Player = node as Player
		if player != null and player.peer_id != except_peer and player.global_position.distance_to(source_player.global_position) <= 18.0:
			player.apply_sanity_damage(amount, source)


func _on_mission_state_changed(new_state: MissionDirector.State) -> void:
	if not multiplayer.is_server() or new_state != MissionDirector.State.SECURED:
		return
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var player: Player = node as Player
		if player != null:
			player.restore_sanity(10.0)


func _on_session_ended(_reason: String) -> void:
	_ambient_clock = 0.0
	_hallucination_clock = 24.0
