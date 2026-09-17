## Noise System — centralized emission of NoiseEvents for AI hearing (GAMEPLAY_MECHANICS §7, ARCHITECTURE §6.4).
## Authority: HOST (emits noise_event on EventBus which AIPerception listens to).
class_name NoiseSystem
extends Node

## Standard noise radii (metres) per GAMEPLAY_MECHANICS §7.
const WALK_RADIUS: float = 4.0
const SPRINT_RADIUS: float = 10.0
const CROUCH_RADIUS: float = 1.5
const KICK_RADIUS: float = 25.0
const GUNSHOT_RADIUS: float = 60.0
const DOOR_OPEN_RADIUS: float = 8.0
const DOOR_CLOSE_RADIUS: float = 6.0
const DOOR_PEEK_RADIUS: float = 3.0
const GRENADE_RADIUS: float = 30.0
const EXPLOSION_RADIUS: float = 50.0
const GLASS_BREAK_RADIUS: float = 15.0
const FOOTSTEP_INTERVAL: float = 0.45

## Voice chat noise radii (ARCHITECTURE §6.4): whisper 2m .. shout 20m
const VOICE_MIN_RADIUS: float = 2.0
const VOICE_MAX_RADIUS: float = 20.0


func _ready() -> void:
	pass


## Emits a footstep noise event (host only).
## `multiplier` is the player's class noise multiplier (Breacher 1.6, etc.).
func emit_footstep(position: Vector3, is_sprinting: bool, is_crouching: bool, multiplier: float = 1.0, source_peer: int = 1) -> void:
	if not multiplayer.is_server():
		return
	var radius: float = WALK_RADIUS
	if is_sprinting:
		radius = SPRINT_RADIUS
	elif is_crouching:
		radius = CROUCH_RADIUS
	radius *= multiplier
	EventBus.noise_event.emit(position, radius, source_peer)


## Emits a door interaction noise event (host only).
func emit_door_noise(position: Vector3, action: Door.DoorAction, source_peer: int = 1) -> void:
	if not multiplayer.is_server():
		return
	var radius: float = DOOR_OPEN_RADIUS
	match action:
		Door.DoorAction.KICK:
			radius = KICK_RADIUS
		Door.DoorAction.TOGGLE_OPEN:
			radius = DOOR_OPEN_RADIUS
		Door.DoorAction.PEEK:
			radius = DOOR_PEEK_RADIUS
		_:
			radius = DOOR_CLOSE_RADIUS
	EventBus.noise_event.emit(position, radius, source_peer)


## Emits a gunshot noise event (host only).
func emit_gunshot(position: Vector3, radius: float = GUNSHOT_RADIUS, source_peer: int = 1) -> void:
	if not multiplayer.is_server():
		return
	EventBus.noise_event.emit(position, radius, source_peer)


## Emits a voice chat noise event (host only).
## `loudness` is 0..1 RMS gate from VoiceManager (ARCHITECTURE §6.4).
func emit_voice_noise(position: Vector3, loudness: float, source_peer: int = 1) -> void:
	if not multiplayer.is_server():
		return
	var radius: float = lerpf(VOICE_MIN_RADIUS, VOICE_MAX_RADIUS, clampf(loudness, 0.0, 1.0))
	EventBus.voice_noise.emit(source_peer, position, loudness)
	EventBus.noise_event.emit(position, radius, source_peer)


## Emits a grenade impact noise event (host only).
func emit_grenade(position: Vector3, source_peer: int = 1) -> void:
	if not multiplayer.is_server():
		return
	EventBus.noise_event.emit(position, GRENADE_RADIUS, source_peer)


## Emits an explosion noise event (host only).
func emit_explosion(position: Vector3, source_peer: int = 1) -> void:
	if not multiplayer.is_server():
		return
	EventBus.noise_event.emit(position, EXPLOSION_RADIUS, source_peer)


## Emits a glass break noise event (host only).
func emit_glass_break(position: Vector3, source_peer: int = 1) -> void:
	if not multiplayer.is_server():
		return
	EventBus.noise_event.emit(position, GLASS_BREAK_RADIUS, source_peer)


## Emits a generic noise event with custom radius (host only).
func emit_noise(position: Vector3, radius: float, source_peer: int = 1) -> void:
	if not multiplayer.is_server():
		return
	EventBus.noise_event.emit(position, radius, source_peer)


## Helper: calculates the time between footstep intervals based on movement speed.
func get_footstep_interval(is_sprinting: bool, is_crouching: bool) -> float:
	if is_crouching:
		return FOOTSTEP_INTERVAL * 1.5
	if is_sprinting:
		return FOOTSTEP_INTERVAL * 0.7
	return FOOTSTEP_INTERVAL