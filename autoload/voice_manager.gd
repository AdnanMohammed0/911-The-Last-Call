## Voice chat (ARCHITECTURE §6): microphone capture -> 16 kHz mono 20 ms frames -> VoiceCodec ->
## unreliable_ordered RPC on transfer channel 2 -> per-speaker jitter buffer -> AudioStreamGenerator.
## Routing:
##  * proximity: the speaker's Player/Head/VoiceEmitter (AudioStreamPlayer3D, VoiceProximity bus),
##    muffled when a wall is in between; 2D fallback while the speaker has no body (lobby).
##  * radio (hold `radio_ptt`): 2D on the VoiceRadio bus (band-pass + distortion) with squelch in/out,
##    skipped when the speaker is close enough to hear directly.
## Transmit: open mic with an adaptive gate (noise floor + margin, pre-roll, hangover) or push-to-talk
## (`voice_ptt`); the radio key always transmits. Automatic gain lifts quiet microphones.
## Settings (input device, mode, auto gain) persist in user://voice.cfg.
## Authority: every peer (sends its own voice, validates and plays everyone else's)
extends Node

enum Mode { VOICE_ACTIVITY, PUSH_TO_TALK }

const VOICE_CHANNEL: int = 2
const PROXIMITY_BUS: StringName = &"VoiceProximity"
const RADIO_BUS: StringName = &"VoiceRadio"
const RECORD_BUS: StringName = &"Record"

const FLAG_RADIO: int = 1
const FLAG_END: int = 2
## Frames to buffer before starting playback of a talk spurt (5 x 20 ms = 100 ms jitter buffer,
## enough for internet tunnels such as playit.gg).
const JITTER_FRAMES: int = 5
## Backlog above this is trimmed one frame per push to slowly catch up; hard cap drops the oldest.
const CATCH_UP_FRAMES: int = 10
const MAX_QUEUED_FRAMES: int = 20
const GENERATOR_CAPACITY_FRAMES: int = 8000  # 0.5 s at 16 kHz
const SETTINGS_FILE: String = "user://voice.cfg"
## Adaptive gate: open when the frame is this many dB above the tracked noise floor.
const VAD_MARGIN_DB: float = 9.0
const VAD_MIN_OPEN_DB: float = -75.0
## Frames kept before the gate opens so the start of words is not clipped (60 ms).
const PRE_ROLL_FRAMES: int = 3
## Automatic gain: bring speech up towards this RMS level, never boosting more than MAX_GAIN_DB.
const AGC_TARGET_DB: float = -20.0
const AGC_MAX_GAIN_DB: float = 36.0
const MAX_PACKET_BYTES: int = 512
const SPEAKING_TIMEOUT_SEC: float = 0.25
const RADIO_END_TIMEOUT_SEC: float = 0.3
## Listeners this close to a radio speaker hear them directly instead of through the radio.
const RADIO_DIRECT_HEAR_DISTANCE: float = 4.0
const OCCLUSION_INTERVAL_SEC: float = 0.1
const OCCLUDED_CUTOFF_HZ: float = 900.0
const OCCLUDED_VOLUME_DB: float = -8.0
const OPEN_CUTOFF_HZ: float = 5000.0

## peer_id, speaking, radio. Emitted for remote speakers and for the local player.
signal speaking_changed(peer_id: int, speaking: bool, radio: bool)
signal mode_changed(new_mode: Mode)

var mode: Mode = Mode.VOICE_ACTIVITY:
	set(value):
		mode = value
		mode_changed.emit(mode)
var vad_hangover_sec: float = 0.5
var microphone_enabled: bool = true
var auto_gain: bool = true
## Extra manual gain on top of automatic gain.
var manual_gain_db: float = 0.0
## Play our own voice back locally (debug / mic check).
var loopback: bool = false

var local_transmitting: bool = false
var local_radio: bool = false
## Post-gain level of the last captured frame (what others hear), and the raw microphone level.
var local_level_db: float = -80.0
var raw_level_db: float = -80.0
var noise_floor_db: float = -70.0
var current_gain_db: float = 0.0
var frames_sent: int = 0

var _codec: VoiceCodec = ImaAdpcmCodec.new()
var _decoder: VoiceCodec = ImaAdpcmCodec.new()
var _capture: AudioEffectCapture = null
var _mic_player: AudioStreamPlayer = null
var _mix_rate: int = 48000
var _decimate_sum: float = 0.0
var _decimate_count: int = 0
var _decimate_phase: int = 0
var _frame: PackedFloat32Array = PackedFloat32Array()
var _hangover: float = 0.0
var _sequence: int = 0
var _was_radio: bool = false
var _last_local_frame_msec: int = 0
var _pre_roll: Array[PackedFloat32Array] = []
var _limiter: RpcRateLimiter = RpcRateLimiter.new(60.0, 20.0)
var _streams: Dictionary[int, SpeakerStream] = {}
var _occlusion_timer: float = 0.0
var _squelch_in: AudioStreamWAV = SquelchSounds.make_squelch_in()
var _squelch_out: AudioStreamWAV = SquelchSounds.make_squelch_out()


## Per remote speaker playback state.
class SpeakerStream:
	var peer_id: int = 0
	var queue: Array[PackedFloat32Array] = []
	var radio_queue: Array[PackedFloat32Array] = []
	var buffering: bool = true
	var radio_buffering: bool = true
	var fallback_player: AudioStreamPlayer = null
	var radio_player: AudioStreamPlayer = null
	var squelch_player: AudioStreamPlayer = null
	var speaking: bool = false
	var radio_active: bool = false
	var last_frame_msec: int = 0
	var last_radio_msec: int = 0
	var frames_received: int = 0
	var frames_played: int = 0
	var radio_frames_played: int = 0
	var last_samples: PackedFloat32Array = PackedFloat32Array()
	var radio_last_samples: PackedFloat32Array = PackedFloat32Array()
	var concealed_frames: int = 0
	var squelch_in_count: int = 0
	var squelch_out_count: int = 0


func _ready() -> void:
	_mix_rate = int(AudioServer.get_mix_rate())
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--ptt":
			mode = Mode.PUSH_TO_TALK
		elif arg == "--voice-loopback":
			loopback = true
	_load_settings()
	_setup_microphone()
	NetManager.peer_left.connect(_remove_stream)
	NetManager.session_ended.connect(func(_reason: String) -> void: _clear_streams())


# --- Public -----------------------------------------------------------------

func toggle_mode() -> void:
	mode = Mode.PUSH_TO_TALK if mode == Mode.VOICE_ACTIVITY else Mode.VOICE_ACTIVITY
	save_settings()


func get_input_devices() -> PackedStringArray:
	return AudioServer.get_input_device_list()


func get_input_device() -> String:
	return AudioServer.input_device


func set_input_device(device: String) -> void:
	if device in AudioServer.get_input_device_list():
		AudioServer.input_device = device
		noise_floor_db = -70.0
		current_gain_db = 0.0
		save_settings()


func set_auto_gain(enabled: bool) -> void:
	auto_gain = enabled
	if not enabled:
		current_gain_db = 0.0
	save_settings()


func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("voice", "input_device", AudioServer.input_device)
	config.set_value("voice", "mode", int(mode))
	config.set_value("voice", "auto_gain", auto_gain)
	config.set_value("voice", "manual_gain_db", manual_gain_db)
	config.save(SETTINGS_FILE)


func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_FILE) != OK:
		return
	var device: String = config.get_value("voice", "input_device", "Default")
	if device in AudioServer.get_input_device_list():
		AudioServer.input_device = device
	var saved_mode: int = config.get_value("voice", "mode", int(Mode.VOICE_ACTIVITY))
	mode = Mode.PUSH_TO_TALK if saved_mode == int(Mode.PUSH_TO_TALK) else Mode.VOICE_ACTIVITY
	auto_gain = config.get_value("voice", "auto_gain", true)
	manual_gain_db = config.get_value("voice", "manual_gain_db", 0.0)


func get_mode_text() -> String:
	return "Open mic (voice activity)" if mode == Mode.VOICE_ACTIVITY else "Push-to-talk (Caps Lock)"


func has_microphone() -> bool:
	return _capture != null


func is_speaking(peer_id: int) -> bool:
	if peer_id == multiplayer.get_unique_id():
		return local_transmitting
	var stream: SpeakerStream = _streams.get(peer_id, null)
	return stream != null and stream.speaking


## Counters for the debug overlay and tests.
func get_stream_stats(peer_id: int) -> Dictionary:
	var stream: SpeakerStream = _streams.get(peer_id, null)
	if stream == null:
		return {}
	return {
		"frames_received": stream.frames_received,
		"frames_played": stream.frames_played,
		"radio_frames_played": stream.radio_frames_played,
		"squelch_in": stream.squelch_in_count,
		"squelch_out": stream.squelch_out_count,
		"concealed": stream.concealed_frames,
		"speaking": stream.speaking,
		"radio_active": stream.radio_active,
	}


## Feed captured audio (stereo, at the engine mix rate). Called with the microphone capture buffer;
## tests call it directly to inject audio.
func feed_capture(buffer: PackedVector2Array) -> void:
	for frame: Vector2 in buffer:
		# Integrate-and-dump decimation to 16 kHz doubles as a cheap anti-alias filter.
		_decimate_sum += (frame.x + frame.y) * 0.5
		_decimate_count += 1
		_decimate_phase += VoiceCodec.SAMPLE_RATE
		if _decimate_phase >= _mix_rate:
			_decimate_phase -= _mix_rate
			_frame.append(_decimate_sum / _decimate_count)
			_decimate_sum = 0.0
			_decimate_count = 0
			if _frame.size() == VoiceCodec.FRAME_SAMPLES:
				_on_local_frame(_frame)
				_frame = PackedFloat32Array()


## True when a wall (world layer) blocks the straight line between two points.
static func is_path_occluded(world: World3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
	return not world.direct_space_state.intersect_ray(query).is_empty()


# --- Capture & send ---------------------------------------------------------

func _setup_microphone() -> void:
	if DisplayServer.get_name() == "headless" or not ProjectSettings.get_setting("audio/driver/enable_input", false):
		return
	var bus: int = AudioServer.get_bus_index(RECORD_BUS)
	if bus < 0 or AudioServer.get_bus_effect_count(bus) == 0:
		push_warning("VoiceManager: '%s' bus with AudioEffectCapture is missing; voice capture disabled." % RECORD_BUS)
		return
	_capture = AudioServer.get_bus_effect(bus, 0) as AudioEffectCapture
	_mic_player = AudioStreamPlayer.new()
	_mic_player.name = "Microphone"
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = RECORD_BUS
	add_child(_mic_player)
	_mic_player.play()


func _on_local_frame(raw: PackedFloat32Array) -> void:
	_last_local_frame_msec = Time.get_ticks_msec()
	raw_level_db = _rms_db(raw)
	_track_noise_floor(raw_level_db)
	var gate_open: bool = raw_level_db >= maxf(noise_floor_db + VAD_MARGIN_DB, VAD_MIN_OPEN_DB)

	# Automatic gain: adapt only while someone is speaking so background noise is not pumped up.
	if auto_gain and gate_open:
		var wanted: float = clampf(AGC_TARGET_DB - raw_level_db, 0.0, AGC_MAX_GAIN_DB)
		var rate: float = 0.25 if wanted < current_gain_db else 0.05
		current_gain_db = lerpf(current_gain_db, wanted, rate)
	var samples: PackedFloat32Array = _apply_gain(raw, db_to_linear(current_gain_db + manual_gain_db))
	local_level_db = _rms_db(samples)

	var radio_held: bool = Input.is_action_pressed(&"radio_ptt")
	var voice_active: bool
	if mode == Mode.VOICE_ACTIVITY:
		if gate_open:
			_hangover = vad_hangover_sec
		else:
			_hangover -= float(VoiceCodec.FRAME_SAMPLES) / VoiceCodec.SAMPLE_RATE
		voice_active = _hangover > 0.0
	else:
		voice_active = Input.is_action_pressed(&"voice_ptt")

	var transmit: bool = microphone_enabled and (voice_active or radio_held)
	var radio: bool = transmit and radio_held
	var starting: bool = transmit and not local_transmitting
	if transmit != local_transmitting or radio != local_radio:
		local_transmitting = transmit
		local_radio = radio
		speaking_changed.emit(multiplayer.get_unique_id(), transmit, radio)

	if transmit:
		var flags: int = FLAG_RADIO if radio else 0
		if starting and mode == Mode.VOICE_ACTIVITY:
			for early: PackedFloat32Array in _pre_roll:
				_send(flags, 0, _codec.encode(early))
		_pre_roll.clear()
		var loudness: int = clampi(int(db_to_linear(local_level_db) * 4.0 * 255.0), 0, 255)
		_send(flags, loudness, _codec.encode(samples))
		if multiplayer.is_server():
			_emit_noise(multiplayer.get_unique_id(), loudness)
	else:
		_pre_roll.append(samples)
		if _pre_roll.size() > PRE_ROLL_FRAMES:
			_pre_roll.pop_front()
		if _was_radio:
			_send(FLAG_END, 0, PackedByteArray())
	_was_radio = radio


static func _rms_db(samples: PackedFloat32Array) -> float:
	var sum: float = 0.0
	for sample: float in samples:
		sum += sample * sample
	return linear_to_db(maxf(sqrt(sum / maxf(samples.size(), 1.0)), 0.00001))


## Falls quickly to quiet frames, rises slowly (so speech does not drag the floor up).
func _track_noise_floor(level_db: float) -> void:
	if level_db < noise_floor_db:
		noise_floor_db = lerpf(noise_floor_db, level_db, 0.3)
	else:
		noise_floor_db = minf(noise_floor_db + 0.02, level_db)


## Gain with a soft limiter so boosted peaks do not clip harshly.
static func _apply_gain(samples: PackedFloat32Array, gain: float) -> PackedFloat32Array:
	if is_equal_approx(gain, 1.0):
		return samples
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(samples.size())
	for i: int in samples.size():
		var value: float = samples[i] * gain
		out[i] = value if absf(value) < 0.8 else signf(value) * (0.8 + 0.2 * tanh((absf(value) - 0.8) / 0.2))
	return out


func _send(flags: int, loudness: int, packet: PackedByteArray) -> void:
	if loopback:
		_receive(multiplayer.get_unique_id(), flags, loudness, packet)
	if not NetManager.is_online():
		return
	_voice_frame.rpc(_sequence, flags, loudness, packet)
	_sequence = (_sequence + 1) & 0xFFFF
	frames_sent += 1
	var copies: int = maxi(multiplayer.get_peers().size(), 1) if multiplayer.is_server() else 1
	NetDebug.record(&"voice", (packet.size() + 12) * copies, true)


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _voice_frame(_seq: int, flags: int, loudness: int, packet: PackedByteArray) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0 or not RpcGuard.is_registered(sender):
		return
	if packet.size() > MAX_PACKET_BYTES or not _limiter.allow(sender):
		return
	NetDebug.record(&"voice", packet.size() + 12, false)
	_receive(sender, flags, loudness, packet)


# --- Receive & play ---------------------------------------------------------

func _receive(peer_id: int, flags: int, loudness: int, packet: PackedByteArray) -> void:
	var stream: SpeakerStream = _get_stream(peer_id)
	var now: int = Time.get_ticks_msec()
	if flags & FLAG_END:
		if stream.radio_active:
			_play_squelch(stream, false)
		return
	var samples: PackedFloat32Array = _decoder.decode(packet)
	if samples.is_empty():
		return
	stream.frames_received += 1
	stream.last_frame_msec = now
	var radio: bool = flags & FLAG_RADIO != 0
	if not stream.speaking:
		stream.speaking = true
		speaking_changed.emit(peer_id, true, radio)

	var speaker: Player = Player.find_by_peer(get_tree(), peer_id)
	if multiplayer.is_server() and peer_id != multiplayer.get_unique_id():
		_emit_noise(peer_id, loudness)

	# Proximity: you hear someone talking (even into their radio) if you are near their body.
	if speaker != null or not radio:
		_enqueue(stream.queue, samples)

	if radio and _can_receive_radio(peer_id):
		if not stream.radio_active:
			_play_squelch(stream, true)
		stream.last_radio_msec = now
		if not _is_within_direct_hearing(speaker):
			_enqueue(stream.radio_queue, samples)


func _process(delta: float) -> void:
	if _capture != null:
		var available: int = _capture.get_frames_available()
		if available > 0:
			feed_capture(_capture.get_buffer(available))
	var now: int = Time.get_ticks_msec()
	# The microphone stopped delivering frames (device lost, muted): stop transmitting.
	if local_transmitting and now - _last_local_frame_msec > int(SPEAKING_TIMEOUT_SEC * 1000.0):
		if _was_radio:
			_send(FLAG_END, 0, PackedByteArray())
		_was_radio = false
		_hangover = 0.0
		local_transmitting = false
		local_radio = false
		speaking_changed.emit(multiplayer.get_unique_id(), false, false)
	for stream: SpeakerStream in _streams.values():
		_pump(stream, now)
	_occlusion_timer += delta
	if _occlusion_timer >= OCCLUSION_INTERVAL_SEC:
		_occlusion_timer = 0.0
		_update_occlusion()


func _pump(stream: SpeakerStream, now: int) -> void:
	var speaker: Player = Player.find_by_peer(get_tree(), stream.peer_id)
	var proximity_player: Node = speaker.get_voice_emitter() if speaker != null else _get_fallback_player(stream)
	var pushed: int = _drain(stream, false, proximity_player)
	stream.frames_played += maxi(pushed, 0)
	var radio_pushed: int = _drain(stream, true, stream.radio_player)
	stream.radio_frames_played += maxi(radio_pushed, 0)

	if stream.radio_active and now - stream.last_radio_msec > int(RADIO_END_TIMEOUT_SEC * 1000.0):
		_play_squelch(stream, false)
	if stream.speaking and now - stream.last_frame_msec > int(SPEAKING_TIMEOUT_SEC * 1000.0):
		stream.speaking = false
		speaking_changed.emit(stream.peer_id, false, false)


## Pushes queued frames into the player's generator; returns frames pushed.
## Waits for JITTER_FRAMES before a talk spurt starts, trims backlog to keep latency low, and on an
## underrun repeats the last frame once at half volume (packet-loss concealment) before re-buffering.
func _drain(stream: SpeakerStream, radio: bool, player: Node) -> int:
	var queue: Array[PackedFloat32Array] = stream.radio_queue if radio else stream.queue
	var buffering: bool = stream.radio_buffering if radio else stream.buffering
	if buffering and queue.size() < JITTER_FRAMES:
		return 0
	var playback: AudioStreamGeneratorPlayback = _ensure_playback(player)
	if playback == null:
		return 0
	var pushed: int = 0
	while playback.get_frames_available() >= VoiceCodec.FRAME_SAMPLES:
		var samples: PackedFloat32Array
		if not queue.is_empty():
			if queue.size() > CATCH_UP_FRAMES:
				queue.pop_front()
			samples = queue.pop_front()
			if radio:
				stream.radio_last_samples = samples
			else:
				stream.last_samples = samples
		else:
			var buffered: int = GENERATOR_CAPACITY_FRAMES - playback.get_frames_available()
			var last: PackedFloat32Array = stream.radio_last_samples if radio else stream.last_samples
			if buffered >= VoiceCodec.FRAME_SAMPLES or last.is_empty():
				break
			samples = _apply_gain(last, 0.5)
			stream.concealed_frames += 1
			if radio:
				stream.radio_last_samples = PackedFloat32Array()
			else:
				stream.last_samples = PackedFloat32Array()
		var stereo: PackedVector2Array = PackedVector2Array()
		stereo.resize(samples.size())
		for i: int in samples.size():
			stereo[i] = Vector2(samples[i], samples[i])
		playback.push_buffer(stereo)
		pushed += 1
	var now_buffering: bool = queue.is_empty()
	if radio:
		stream.radio_buffering = now_buffering
	else:
		stream.buffering = now_buffering
	return pushed


func _ensure_playback(player: Node) -> AudioStreamGeneratorPlayback:
	var player_3d: AudioStreamPlayer3D = player as AudioStreamPlayer3D
	var player_2d: AudioStreamPlayer = player as AudioStreamPlayer
	if player_3d != null:
		if not player_3d.playing:
			player_3d.play()
		return player_3d.get_stream_playback() as AudioStreamGeneratorPlayback
	if player_2d != null:
		if not player_2d.playing:
			player_2d.play()
		return player_2d.get_stream_playback() as AudioStreamGeneratorPlayback
	return null


func _enqueue(queue: Array[PackedFloat32Array], samples: PackedFloat32Array) -> void:
	queue.append(samples)
	while queue.size() > MAX_QUEUED_FRAMES:
		queue.pop_front()


func _play_squelch(stream: SpeakerStream, key_up: bool) -> void:
	stream.radio_active = key_up
	stream.squelch_player.stream = _squelch_in if key_up else _squelch_out
	stream.squelch_player.play()
	if key_up:
		stream.squelch_in_count += 1
	else:
		stream.squelch_out_count += 1
		stream.radio_queue.clear()
		stream.radio_buffering = true


## TODO(P3-13/P3-14): radio zones, anomaly jamming and Dead Frequency injection.
func _can_receive_radio(_speaker_peer_id: int) -> bool:
	return true


func _is_within_direct_hearing(speaker: Player) -> bool:
	var listener: Player = Player.find_by_peer(get_tree(), multiplayer.get_unique_id())
	if speaker == null or listener == null or speaker == listener:
		return false
	return listener.global_position.distance_to(speaker.global_position) <= RADIO_DIRECT_HEAR_DISTANCE


## Walls between the local camera and a speaker muffle their proximity voice.
func _update_occlusion() -> void:
	var listener: Player = Player.find_by_peer(get_tree(), multiplayer.get_unique_id())
	if listener == null:
		return
	var ear: Vector3 = listener.get_eye_position()
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var speaker: Player = node as Player
		if speaker == null or speaker == listener:
			continue
		var emitter: AudioStreamPlayer3D = speaker.get_voice_emitter()
		var exclude: Array[RID] = [listener.get_rid(), speaker.get_rid()]
		var occluded: bool = is_path_occluded(listener.get_world_3d(), ear, speaker.get_eye_position(), exclude)
		emitter.attenuation_filter_cutoff_hz = OCCLUDED_CUTOFF_HZ if occluded else OPEN_CUTOFF_HZ
		emitter.volume_db = OCCLUDED_VOLUME_DB if occluded else 0.0


## Host: voice is a noise source for AI hearing (ARCHITECTURE §6.4). Loudness 0..1.
func _emit_noise(peer_id: int, loudness: int) -> void:
	var speaker: Player = Player.find_by_peer(get_tree(), peer_id)
	if speaker != null:
		EventBus.voice_noise.emit(peer_id, speaker.global_position, loudness / 255.0)


# --- Streams ------------------------------------------------------------------

func _get_stream(peer_id: int) -> SpeakerStream:
	if _streams.has(peer_id):
		return _streams[peer_id]
	var stream: SpeakerStream = SpeakerStream.new()
	stream.peer_id = peer_id
	stream.radio_player = _make_player("Radio_%d" % peer_id, RADIO_BUS, _make_generator())
	stream.squelch_player = _make_player("Squelch_%d" % peer_id, RADIO_BUS, null)
	_streams[peer_id] = stream
	return stream


func _get_fallback_player(stream: SpeakerStream) -> AudioStreamPlayer:
	if stream.fallback_player == null:
		stream.fallback_player = _make_player("Lobby_%d" % stream.peer_id, PROXIMITY_BUS, _make_generator())
	return stream.fallback_player


func _make_player(node_name: String, bus: StringName, stream: AudioStream) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = node_name
	player.bus = bus
	player.stream = stream
	add_child(player)
	return player


static func _make_generator() -> AudioStreamGenerator:
	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = VoiceCodec.SAMPLE_RATE
	generator.buffer_length = 0.5
	return generator


func _remove_stream(peer_id: int) -> void:
	var stream: SpeakerStream = _streams.get(peer_id, null)
	if stream == null:
		return
	for player: AudioStreamPlayer in [stream.fallback_player, stream.radio_player, stream.squelch_player]:
		if player != null:
			player.queue_free()
	_streams.erase(peer_id)
	_limiter.forget_peer(peer_id)


func _clear_streams() -> void:
	for peer_id: int in _streams.keys():
		_remove_stream(peer_id)
	local_transmitting = false
	local_radio = false
	_was_radio = false
