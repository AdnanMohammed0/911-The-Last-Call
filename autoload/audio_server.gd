## Audio Director (P4-13). Named AudioDirector so it does not shadow Godot's built-in AudioServer singleton.
## Centralized playback for foley, SFX, music stingers, and ambience.
## Uses the bus layout from audio/buses/audio_buses.cfg
extends Node

# Loosely typed telemetry / audio data (dictionaries from JSON and data resources).
@warning_ignore_start("unsafe_call_argument", "unsafe_cast", "unsafe_method_access", "unsafe_property_access", "untyped_declaration", "inferred_declaration", "return_value_discarded")

## Singleton instance
static var instance: Node = null

## Foley definitions resource
@export var foley_defs: Resource
## Music stingers resource
@export var music_stingers: Resource
## Ambience tracks resource
@export var ambience_tracks: Resource

## Current ambience track ID
var current_ambience_id: StringName = &""
## Ambience crossfade state
var _ambience_crossfading: bool = false
## Active ambience players per layer
var _ambience_players: Dictionary[StringName, Array] = {}
## Music stinger cooldowns
var _stinger_cooldowns: Dictionary[StringName, float] = {}
## Active music stinger players
var _stinger_players: Array[AudioStreamPlayer] = []
## Current ambient drone player
var _drone_player: AudioStreamPlayer = null
## Current drone ID
var _current_drone_id: StringName = &""


func _ready() -> void:
	instance = self
	_load_resources()
	_init_stinger_cooldowns()


func _load_resources() -> void:
	# Resources are assigned in editor or loaded here
	if foley_defs == null:
		foley_defs = load("res://audio/foley/foley_definitions.tres")
	if music_stingers == null:
		music_stingers = load("res://audio/music/music_stingers.tres")
	if ambience_tracks == null:
		ambience_tracks = load("res://audio/ambience/ambience_tracks.tres")


func _init_stinger_cooldowns() -> void:
	if music_stingers != null:
		for stinger: MusicStinger in _list(music_stingers, &"stingers"):
			_stinger_cooldowns[stinger.id] = 0.0


func _process(delta: float) -> void:
	_update_stinger_cooldowns(delta)
	_cleanup_finished_players()


func _update_stinger_cooldowns(delta: float) -> void:
	for id: StringName in _stinger_cooldowns:
		if _stinger_cooldowns[id] > 0.0:
			_stinger_cooldowns[id] -= delta


func _cleanup_finished_players() -> void:
	# Clean up finished stinger players
	for i in range(_stinger_players.size() - 1, -1, -1):
		var player: AudioStreamPlayer = _stinger_players[i]
		if player == null or not player.playing:
			_stinger_players.remove_at(i)
	# Clean up ambience players
	for track_id: StringName in _ambience_players:
		var players: Array[AudioStreamPlayer] = _ambience_players[track_id]
		for j in range(players.size() - 1, -1, -1):
			var p: AudioStreamPlayer = players[j]
			if p == null or not p.playing:
				players.remove_at(j)


# --- Foley Playback ---------------------------------------------------------

## Plays a foley sound at world position with class modifier.
## Returns the AudioStreamPlayer3D for potential further control.
func play_foley(foley_id: StringName, position: Vector3, class_id: StringName = &"", parent: Node = null) -> AudioStreamPlayer3D:
	if foley_defs == null:
		push_error("AudioDirector: foley_defs not loaded")
		return null

	var foley: FoleyDefinition = _find_foley(foley_id)
	if foley == null:
		push_error("AudioDirector: foley '%s' not found" % foley_id)
		return null

	var variation: String = foley.get_random_variation()
	if variation.is_empty():
		return null

	var pitch: float = foley.get_random_pitch()
	var volume_mult: float = foley.get_class_multiplier(class_id)
	var volume_db: float = foley.volume_db + linear_to_db(volume_mult)

	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = load(variation)
	player.bus = &"Foley"
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.global_position = position
	player.max_distance = foley.max_distance
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

	if parent != null:
		parent.add_child(player)
	else:
		get_tree().root.add_child(player)

	player.play()
	return player


## Plays a foley sound as 2D (for UI, local player only).
func play_foley_2d(foley_id: StringName, class_id: StringName = &"") -> AudioStreamPlayer:
	if foley_defs == null:
		return null

	var foley: FoleyDefinition = _find_foley(foley_id)
	if foley == null:
		return null

	var variation: String = foley.get_random_variation()
	if variation.is_empty():
		return null

	var pitch: float = foley.get_random_pitch()
	var volume_mult: float = foley.get_class_multiplier(class_id)
	var volume_db: float = foley.volume_db + linear_to_db(volume_mult)

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = load(variation)
	player.bus = &"Foley"
	player.volume_db = volume_db
	player.pitch_scale = pitch

	add_child(player)
	player.play()
	return player


func _find_foley(id: StringName) -> FoleyDefinition:
	for def: FoleyDefinition in _list(foley_defs, &"definitions"):
		if def.id == id:
			return def
	return null


# --- SFX Playback -----------------------------------------------------------

## Plays a one-shot SFX at world position (gunshots, explosions, impacts).
func play_sfx(sfx_id: StringName, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0, max_dist: float = 60.0, parent: Node = null) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = load(sfx_id)
	player.bus = &"SFX"
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.global_position = position
	player.max_distance = max_dist
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

	if parent != null:
		parent.add_child(player)
	else:
		get_tree().root.add_child(player)

	player.play()
	return player


# --- Music Stinger System ---------------------------------------------------

## Requests a music stinger by ID. Handles priority, cooldown, and layering.
func request_stinger(stinger_id: StringName, force: bool = false) -> bool:
	if music_stingers == null:
		return false

	var stinger: MusicStinger = _find_stinger(stinger_id)
	if stinger == null:
		push_warning("AudioDirector: stinger '%s' not found" % stinger_id)
		return false

	# Check cooldown
	if not force and _stinger_cooldowns[stinger_id] > 0.0:
		return false

	# Check priority: stop lower-priority stingers if not layerable
	if not stinger.layerable:
		_stop_stingers_below_priority(stinger.priority)

	# Play
	_play_stinger(stinger)
	_stinger_cooldowns[stinger_id] = stinger.cooldown_sec
	return true


func _play_stinger(stinger: MusicStinger) -> void:
	var file: String = stinger.get_file_to_play()
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = load(file)
	player.bus = &"Music"
	player.volume_db = stinger.volume_db
	player.autoplay = false

	add_child(player)
	_stinger_players.append(player)

	# Fade in
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", -80.0, 0.0)  # Start silent
	tween.tween_property(player, "volume_db", stinger.volume_db, stinger.fade_in).set_trans(Tween.TRANS_LINEAR)

	player.play()

	# Schedule fade out and cleanup
	var fade_delay: float = stinger.fade_in + 0.5  # Brief hold
	if not stinger.loop:
		var fade_tween: Tween = create_tween()
		fade_tween.tween_callback(Callable(self, "_fade_out_stinger").bind(player, stinger.fade_out)).set_delay(fade_delay)
	else:
		# For looping stingers (drones), store reference
		if stinger.category == MusicStinger.Category.AMBIENT_DRONE:
			_drone_player = player
			_current_drone_id = stinger.id


func _fade_out_stinger(player: AudioStreamPlayer, fade_out: float) -> void:
	if not is_instance_valid(player):
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", -80.0, fade_out).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(Callable(player.queue_free).bind())


func _stop_stingers_below_priority(priority: int) -> void:
	for i in range(_stinger_players.size() - 1, -1, -1):
		var player: AudioStreamPlayer = _stinger_players[i]
		# Would need to track which stinger each player belongs to
		# For now, fade out all non-drone stingers
		if player != _drone_player:
			_fade_out_stinger(player, 1.0)
			_stinger_players.remove_at(i)


func _find_stinger(id: StringName) -> MusicStinger:
	for stinger: MusicStinger in _list(music_stingers, &"stingers"):
		if stinger.id == id:
			return stinger
	return null


## Sets the active ambient drone (crossfades from current).
func set_ambient_drone(drone_id: StringName, force: bool = false) -> void:
	if music_stingers == null:
		return

	var drone: MusicStinger = _find_stinger(drone_id)
	if drone == null or drone.category != MusicStinger.Category.AMBIENT_DRONE:
		push_warning("AudioDirector: '%s' is not an ambient drone" % drone_id)
		return

	if _current_drone_id == drone_id and not force:
		return

	# Crossfade
	if _drone_player != null and is_instance_valid(_drone_player):
		var old_player: AudioStreamPlayer = _drone_player
		var tween: Tween = create_tween()
		tween.tween_property(old_player, "volume_db", -80.0, drone.fade_out).set_trans(Tween.TRANS_LINEAR)
		tween.tween_callback(Callable(old_player.queue_free).bind())

	_play_stinger(drone)
	_current_drone_id = drone_id


## Stops the current ambient drone.
func stop_ambient_drone(fade_out: float = 5.0) -> void:
	if _drone_player != null and is_instance_valid(_drone_player):
		var tween: Tween = create_tween()
		tween.tween_property(_drone_player, "volume_db", -80.0, fade_out).set_trans(Tween.TRANS_LINEAR)
		tween.tween_callback(Callable(_drone_player.queue_free).bind())
		_drone_player = null
		_current_drone_id = &""


# --- Ambience System --------------------------------------------------------

## Transitions to a new ambience track (crossfades layers).
func transition_ambience(track_id: StringName, fade_time: float = 5.0) -> void:
	if ambience_tracks == null:
		return

	var track: AmbienceTrack = _find_ambience_track(track_id)
	if track == null:
		push_warning("AudioDirector: ambience track '%s' not found" % track_id)
		return

	if current_ambience_id == track_id:
		return

	_ambience_crossfading = true

	# Fade out current
	if current_ambience_id != &"":
		_fade_out_current_ambience(fade_time)

	# Fade in new
	_fade_in_ambience(track, fade_time)
	current_ambience_id = track_id

	_ambience_crossfading = false


func _fade_out_current_ambience(fade_time: float) -> void:
	var old_players: Array[AudioStreamPlayer] = _ambience_players.get(current_ambience_id, [])
	for player: AudioStreamPlayer in old_players:
		if is_instance_valid(player) and player.playing:
			var tween: Tween = create_tween()
			tween.tween_property(player, "volume_db", -80.0, fade_time).set_trans(Tween.TRANS_LINEAR)
			tween.tween_callback(Callable(player.queue_free).bind())
	_ambience_players.erase(current_ambience_id)


func _fade_in_ambience(track: AmbienceTrack, fade_time: float) -> void:
	var new_players: Array[AudioStreamPlayer] = []

	# Looping layers
	for layer: Dictionary in track.get_looping_layers():
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = load(layer["file"])
		player.bus = &"Ambience"
		player.volume_db = -80.0  # Start silent
		player.autoplay = true
		if layer.get("random_start", false):
			player.seek(randf_range(0.0, player.stream.get_length()))
		add_child(player)
		new_players.append(player)

		var tween: Tween = create_tween()
		tween.tween_property(player, "volume_db", layer["volume_db"], layer.get("fade_in", fade_time)).set_trans(Tween.TRANS_LINEAR)

	# Oneshot layers (handled by timer system)
	# For now, we'll use a simple timer approach
	for layer: Dictionary in track.get_oneshot_layers():
		if layer.get("probability", 1.0) >= 1.0 or randf() < layer.get("probability", 1.0):
			_schedule_oneshot_layer(layer, track.id)

	_ambience_players[track.id] = new_players


func _schedule_oneshot_layer(layer: Dictionary, track_id: StringName) -> void:
	var interval: float = randf_range(layer["interval_range"].x, layer["interval_range"].y)
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = interval
	timer.timeout.connect(Callable(self, "_play_oneshot_layer").bind(layer, track_id))
	add_child(timer)
	timer.start()


func _play_oneshot_layer(layer: Dictionary, track_id: StringName) -> void:
	# Only play if this track is still active
	if current_ambience_id != track_id:
		return

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = load(layer["file"])
	player.bus = &"Ambience"
	player.volume_db = layer["volume_db"]
	player.pitch_scale = 1.0 + randf_range(-layer.get("random_pitch", 0.0), layer.get("random_pitch", 0.0))
	player.autoplay = false
	add_child(player)

	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", -80.0, 0.0)
	tween.tween_property(player, "volume_db", layer["volume_db"], layer.get("fade_in", 1.0)).set_trans(Tween.TRANS_LINEAR)

	player.play()

	# Schedule fade out
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(player, "volume_db", -80.0, layer.get("fade_out", 2.0)).set_trans(Tween.TRANS_LINEAR).set_delay(player.stream.get_length())
	fade_tween.tween_callback(Callable(player.queue_free).bind())

	# Reschedule if this track is still active
	var interval: float = randf_range(layer["interval_range"].x, layer["interval_range"].y)
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = interval
	timer.timeout.connect(Callable(self, "_play_oneshot_layer").bind(layer, track_id))
	add_child(timer)
	timer.start()


func _find_ambience_track(id: StringName) -> AmbienceTrack:
	for track: AmbienceTrack in _list(ambience_tracks, &"tracks"):
		if track.id == id:
			return track
	return null


# --- Utility ----------------------------------------------------------------

## Sets bus volume (for settings menu).
static func set_bus_volume(bus_name: StringName, volume_db: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, volume_db)


## Gets bus volume.
static func get_bus_volume(bus_name: StringName) -> float:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return AudioServer.get_bus_volume_db(idx)
	return 0.0


## Mutes/unmutes a bus.
static func set_bus_mute(bus_name: StringName, mute: bool) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, mute)


## Applies VHS post-process bus (P4-11).
static func set_vhs_enabled(enabled: bool) -> void:
	var idx: int = AudioServer.get_bus_index(&"VHS")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, not enabled)

## Array property of an untyped data resource (empty when the resource is missing).
static func _list(resource: Resource, property: StringName) -> Array:
	if resource == null:
		return []
	var value: Variant = resource.get(property)
	return value if value is Array else []
