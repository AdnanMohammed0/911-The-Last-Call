## Host-authoritative emergency call director and shift supervisor (GAMEPLAY_MECHANICS §5.1–§5.7).
## Manages shift clock, call queuing, ring/answer/missed lifecycle, handset token ownership, and replicated dialogue.
## Authority: HOST (all state changes occur on host and are replicated via RPC to clients).
extends Node

enum CallState { IDLE, RINGING, CONNECTED, ASSESSMENT, COMPLETED, MISSED }

const DEFAULT_RING_TIMEOUT: float = 20.0
const DEFAULT_TIME_SCALE: float = 6.0 # 1 real min = 6 in-game min (1 in-game min = 10 real sec)
const PHONE_BUS_NAME: StringName = &"Phone"

# --- State ---
var shift_clock_minutes: int = 0
var shift_clock_accum_seconds: float = 0.0
var shift_running: bool = false
var time_scale: float = DEFAULT_TIME_SCALE

var current_state: CallState = CallState.IDLE
var active_call: CallData = null
var active_call_id: StringName = &""

var ring_timer: float = 0.0
var ring_timeout: float = DEFAULT_RING_TIMEOUT

var handset_owner_peer_id: int = 0

var registered_calls: Dictionary[StringName, CallData] = {}
var call_queue: Array[StringName] = []
var call_history: Dictionary[StringName, Dictionary] = {}

# --- Subsystems ---
var dialogue_runner: DialogueRunner = DialogueRunner.new()
var vsa: VoiceStressAnalyzer = VoiceStressAnalyzer.new()
var phone_audio_player: AudioStreamPlayer = null
## Host: open team verdict vote for the active call (P2-14), 0 when none.
var verdict_vote_id: int = 0


func _ready() -> void:
	phone_audio_player = AudioStreamPlayer.new()
	phone_audio_player.name = "PhoneAudioPlayer"
	phone_audio_player.bus = PHONE_BUS_NAME
	add_child(phone_audio_player)
	
	dialogue_runner.node_entered.connect(_on_dialogue_node_entered)
	dialogue_runner.choices_updated.connect(_on_dialogue_choices_updated)
	dialogue_runner.patience_changed.connect(_on_dialogue_patience_changed)
	dialogue_runner.evidence_revealed.connect(_on_dialogue_evidence_revealed)
	dialogue_runner.dialogue_finished.connect(_on_dialogue_runner_finished)
	
	if EventBus != null:
		EventBus.phase_changed.connect(_on_phase_changed)
	
	VoteManager.vote_closed.connect(_on_vote_closed)

	if NetManager != null:
		if NetManager.has_signal("peer_left"):
			NetManager.peer_left.connect(_on_player_left)
		if NetManager.has_signal("peer_dropped"):
			NetManager.peer_dropped.connect(_on_player_left)


func _process(delta: float) -> void:
	if not _is_server():
		return
	
	_process_shift_clock(delta)
	_process_call_lifecycle(delta)


func _is_server() -> bool:
	if multiplayer.multiplayer_peer == null:
		return true
	return multiplayer.is_server()


# ==============================================================================
# Shift Clock (GAMEPLAY_MECHANICS §5.5)
# ==============================================================================

func start_shift() -> void:
	shift_running = true
	shift_clock_accum_seconds = 0.0


func pause_shift() -> void:
	shift_running = false


func resume_shift() -> void:
	shift_running = true


func set_shift_time(minutes: int) -> void:
	shift_clock_minutes = clampi(minutes, 0, GameState.SHIFT_END_MINUTES if GameState != null else 360)
	shift_clock_accum_seconds = 0.0
	if _is_server():
		_sync_shift_clock.rpc(shift_clock_minutes)
		_check_scheduled_calls()
	else:
		EventBus.shift_clock_updated.emit(shift_clock_minutes)


func _process_shift_clock(delta: float) -> void:
	if not shift_running:
		return
	
	# Only tick clock during dispatch phase or when running
	if GameState != null and not GameState.is_phase(&"dispatch") and not GameState.is_lobby():
		return
	
	shift_clock_accum_seconds += delta * time_scale
	if shift_clock_accum_seconds >= 60.0:
		var minutes_to_add: int = int(shift_clock_accum_seconds / 60.0)
		shift_clock_accum_seconds = fmod(shift_clock_accum_seconds, 60.0)
		shift_clock_minutes += minutes_to_add
		
		if GameState != null:
			GameState.shift_clock_minutes = shift_clock_minutes
		
		_sync_shift_clock.rpc(shift_clock_minutes)
		_check_scheduled_calls()


@rpc("authority", "call_local", "unreliable")
func _sync_shift_clock(minutes: int) -> void:
	shift_clock_minutes = minutes
	if GameState != null:
		GameState.shift_clock_minutes = minutes
	if EventBus != null:
		EventBus.shift_clock_updated.emit(minutes)


# ==============================================================================
# Call Registration & Queuing
# ==============================================================================

func register_call(call_data: CallData) -> void:
	if call_data == null or call_data.id == &"":
		return
	registered_calls[call_data.id] = call_data


func enqueue_call(call_id: StringName, delay_in_game_minutes: int = 0) -> void:
	if not _is_server():
		return
	if not registered_calls.has(call_id):
		push_warning("CallDirector: cannot enqueue unregistered call '%s'" % call_id)
		return
	
	var data: CallData = registered_calls[call_id]
	if delay_in_game_minutes > 0:
		data.earliest_minute = shift_clock_minutes + delay_in_game_minutes
	
	if not call_id in call_queue:
		call_queue.append(call_id)
	
	_check_scheduled_calls()


func _check_scheduled_calls() -> void:
	if current_state != CallState.IDLE:
		return
	
	for i in range(call_queue.size()):
		var cid: StringName = call_queue[i]
		var cdata: CallData = registered_calls.get(cid, null)
		if cdata != null and shift_clock_minutes >= cdata.earliest_minute:
			call_queue.remove_at(i)
			ring_call(cid)
			break


# ==============================================================================
# Call Lifecycle (GAMEPLAY_MECHANICS §5.1)
# ==============================================================================

func ring_call(call_id: StringName) -> void:
	if not _is_server():
		return
	if not registered_calls.has(call_id):
		return
	
	active_call = registered_calls[call_id]
	active_call_id = call_id
	current_state = CallState.RINGING
	ring_timer = active_call.ring_timeout_seconds if active_call.ring_timeout_seconds > 0.0 else DEFAULT_RING_TIMEOUT
	ring_timeout = ring_timer
	
	_sync_call_ring.rpc(call_id, ring_timeout)


@rpc("authority", "call_local", "reliable")
func _sync_call_ring(call_id: StringName, timeout_sec: float) -> void:
	active_call_id = call_id
	active_call = registered_calls.get(call_id, null)
	current_state = CallState.RINGING
	ring_timer = timeout_sec
	ring_timeout = timeout_sec
	
	if EventBus != null:
		EventBus.call_ring.emit(call_id, active_call)


func _process_call_lifecycle(delta: float) -> void:
	match current_state:
		CallState.RINGING:
			ring_timer -= delta
			if ring_timer <= 0.0:
				_on_call_missed()
		
		CallState.CONNECTED:
			dialogue_runner.tick(delta)
			if phone_audio_player != null and phone_audio_player.playing:
				vsa.update_playback_time(phone_audio_player.get_playback_position())


func _on_call_missed() -> void:
	var missed_id: StringName = active_call_id
	current_state = CallState.MISSED
	
	call_history[missed_id] = {
		"id": missed_id,
		"state": "missed",
		"minute": shift_clock_minutes,
		"verdict": &"missed",
	}
	
	_sync_call_missed.rpc(missed_id)
	
	active_call = null
	active_call_id = &""
	current_state = CallState.IDLE


@rpc("authority", "call_local", "reliable")
func _sync_call_missed(call_id: StringName) -> void:
	current_state = CallState.MISSED
	if EventBus != null:
		EventBus.call_missed.emit(call_id)
		EventBus.call_ended.emit(call_id, &"missed")


## Client requests to pick up and answer ringing call.
@rpc("any_peer", "call_remote", "reliable")
func request_answer_call(call_id: StringName) -> void:
	if not _is_server():
		return
	if current_state != CallState.RINGING or active_call_id != call_id or active_call == null:
		return
	
	var sender: int = multiplayer.get_remote_sender_id()
	# If no handset owner, assign to answering player
	if handset_owner_peer_id == 0 and sender > 0:
		handset_owner_peer_id = sender
		_sync_handset_owner.rpc(handset_owner_peer_id)
	
	_answer_call()


func _answer_call() -> void:
	current_state = CallState.CONNECTED
	
	# Setup VSA profile
	if active_call.stress_profile != null:
		vsa.set_profile(active_call.stress_profile, active_call.patience_seconds)
	
	# Start dialogue runner
	if active_call.dialogue != null:
		dialogue_runner.start(active_call.dialogue, active_call.patience_seconds)
	
	_sync_call_connected.rpc(active_call_id, active_call.patience_seconds)
	
	# Start audio playback on Phone bus
	if active_call.caller_audio != null and phone_audio_player != null:
		phone_audio_player.stream = active_call.caller_audio
		phone_audio_player.play()


@rpc("authority", "call_local", "reliable")
func _sync_call_connected(call_id: StringName, patience: float) -> void:
	current_state = CallState.CONNECTED
	active_call_id = call_id
	active_call = registered_calls.get(call_id, null)
	
	if active_call != null and active_call.stress_profile != null:
		vsa.set_profile(active_call.stress_profile, patience)
	
	if EventBus != null:
		EventBus.call_connected.emit(call_id, active_call)
		EventBus.call_received.emit(call_id)


## Hangs up the call (manual or triggered).
@rpc("any_peer", "call_remote", "reliable")
func request_hangup_call() -> void:
	if not _is_server():
		return
	if current_state != CallState.CONNECTED:
		return
	
	var sender: int = multiplayer.get_remote_sender_id()
	if handset_owner_peer_id != 0 and sender != handset_owner_peer_id and sender != 1:
		return
	
	_hangup_call(&"manual_hangup")


func _hangup_call(reason: StringName) -> void:
	if phone_audio_player != null and phone_audio_player.playing:
		phone_audio_player.stop()
	
	# Leave CONNECTED before stopping the runner so its "finished" signal does not hang up again.
	current_state = CallState.ASSESSMENT
	dialogue_runner.stop(reason)
	_sync_call_assessment_started.rpc(active_call_id)
	# With several players the verdict is a team vote (60 s, unanimous ends early, Profiler breaks ties).
	if _is_server() and NetManager.roster.size() > 1:
		verdict_vote_id = VoteManager.open_verdict_vote(active_call_id)


func _on_vote_closed(vote: Dictionary, result: StringName) -> void:
	if not _is_server() or vote.get("id", 0) != verdict_vote_id:
		return
	verdict_vote_id = 0
	var context: Dictionary = vote.get("context", {})
	var call_id: StringName = context.get("call_id", &"")
	var decided_by: StringName = vote.get("decided_by", &"")
	if call_id == active_call_id and current_state == CallState.ASSESSMENT and decided_by != &"cancelled":
		submit_verdict(0, call_id, result)


@rpc("authority", "call_local", "reliable")
func _sync_call_assessment_started(call_id: StringName) -> void:
	current_state = CallState.ASSESSMENT
	if EventBus != null:
		EventBus.call_assessment_started.emit(call_id)


# ==============================================================================
# Assessment & Verdict (GAMEPLAY_MECHANICS §5.7)
# ==============================================================================

@rpc("any_peer", "call_remote", "reliable")
func request_classify_call(call_id: StringName, verdict: StringName) -> void:
	if not _is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	
	if current_state != CallState.ASSESSMENT and current_state != CallState.CONNECTED:
		return
	if active_call_id != call_id or active_call == null:
		return
	if not active_call.is_valid_verdict(verdict):
		return
	
	# Team assessment: the request becomes this player's ballot instead of an instant verdict.
	if verdict_vote_id != 0:
		VoteManager.cast_vote(verdict_vote_id, verdict)
		return
	submit_verdict(sender, call_id, verdict)


func submit_verdict(sender_peer_id: int, call_id: StringName, verdict: StringName) -> void:
	if not _is_server():
		return
	
	if phone_audio_player != null and phone_audio_player.playing:
		phone_audio_player.stop()
	
	current_state = CallState.COMPLETED
	
	var truth: CallData.Truth = active_call.truth if active_call != null else CallData.Truth.GENUINE
	call_history[call_id] = {
		"id": call_id,
		"state": "completed",
		"minute": shift_clock_minutes,
		"verdict": verdict,
		"truth": truth,
		"submitted_by": sender_peer_id,
	}
	
	_sync_call_classified.rpc(call_id, verdict)
	
	active_call = null
	active_call_id = &""
	current_state = CallState.IDLE


@rpc("authority", "call_local", "reliable")
func _sync_call_classified(call_id: StringName, verdict: StringName) -> void:
	current_state = CallState.COMPLETED
	if EventBus != null:
		EventBus.call_classified.emit(call_id, verdict)
		EventBus.call_ended.emit(call_id, verdict)


# ==============================================================================
# Handset Token Ownership (P2-05, GAMEPLAY_MECHANICS §5.6)
# ==============================================================================

@rpc("any_peer", "call_remote", "reliable")
func request_take_handset() -> void:
	if not _is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	
	handset_owner_peer_id = sender
	_sync_handset_owner.rpc(handset_owner_peer_id)


@rpc("any_peer", "call_remote", "reliable")
func request_release_handset() -> void:
	if not _is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	
	if handset_owner_peer_id == sender:
		handset_owner_peer_id = 0
		_sync_handset_owner.rpc(0)


@rpc("any_peer", "call_remote", "reliable")
func request_pass_handset(to_peer_id: int) -> void:
	if not _is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	
	if handset_owner_peer_id == sender or handset_owner_peer_id == 0:
		handset_owner_peer_id = to_peer_id
		_sync_handset_owner.rpc(to_peer_id)


@rpc("authority", "call_local", "reliable")
func _sync_handset_owner(peer_id: int) -> void:
	handset_owner_peer_id = peer_id
	if EventBus != null:
		EventBus.handset_owner_changed.emit(peer_id)


func has_handset(peer_id: int) -> bool:
	if handset_owner_peer_id == 0:
		return true # Open to anyone when on desk
	return handset_owner_peer_id == peer_id


# ==============================================================================
# Replicated Dialogue State & Choice Selection (P2-05)
# ==============================================================================

@rpc("any_peer", "call_remote", "reliable")
func request_dialogue_choice(choice_index: int) -> void:
	if not _is_server():
		return
	if current_state != CallState.CONNECTED:
		return
	
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	
	# Handset ownership validation
	if handset_owner_peer_id != 0 and sender != handset_owner_peer_id:
		return
	
	# Determine player class for role-locked choices
	var player_class: StringName = &""
	if NetManager != null and NetManager.roster.has(sender):
		player_class = NetManager.roster[sender].get("class_id", &"")
	
	var res: Dictionary = dialogue_runner.select_choice(choice_index, player_class)
	if res.get("success", false) != true:
		push_warning("Dialogue choice %d rejected: %s" % [choice_index, res.get("reason", "")])


@rpc("any_peer", "call_remote", "reliable")
func request_ping_choice(choice_index: int) -> void:
	if not _is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	
	_sync_choice_ping.rpc(sender, choice_index)


@rpc("authority", "call_local", "reliable")
func _sync_choice_ping(sender_peer_id: int, choice_index: int) -> void:
	if EventBus != null:
		EventBus.dialogue_choice_pinged.emit(sender_peer_id, choice_index)


func _on_dialogue_node_entered(node: DialogueNode) -> void:
	if not _is_server():
		return
	
	var choices_data: Array[Dictionary] = dialogue_runner.get_available_choices_data()
	var audio_path: String = ""
	if node.audio != null and node.audio.resource_path != "":
		audio_path = node.audio.resource_path
	
	_sync_dialogue_node.rpc(
		node.id,
		node.speaker,
		node.line,
		audio_path,
		choices_data,
		dialogue_runner.patience_remaining,
		true
	)


func _on_dialogue_choices_updated(choices: Array[Dictionary]) -> void:
	if not _is_server():
		return
	if dialogue_runner.current_node == null:
		return
	
	_sync_dialogue_choices.rpc(choices)


func _on_dialogue_patience_changed(current: float, max_p: float) -> void:
	if not _is_server():
		return
	_sync_patience.rpc(current, max_p)


func _on_dialogue_evidence_revealed(evidence_key: StringName) -> void:
	if not _is_server():
		return
	_sync_evidence_unlocked.rpc(evidence_key)


func _on_dialogue_runner_finished(reason: StringName) -> void:
	if not _is_server():
		return
	
	_sync_dialogue_finished.rpc(reason)
	if current_state == CallState.CONNECTED:
		_hangup_call(reason)


@rpc("authority", "call_local", "reliable")
func _sync_dialogue_node(node_id: StringName, speaker: StringName, line: String, _audio_path: String, choices: Array, _patience: float, _is_active: bool) -> void:
	if EventBus != null:
		EventBus.dialogue_node_changed.emit(node_id, speaker, line, choices)


@rpc("authority", "call_local", "reliable")
func _sync_dialogue_choices(choices: Array) -> void:
	if EventBus != null and dialogue_runner.current_node != null:
		EventBus.dialogue_node_changed.emit(
			dialogue_runner.current_node_id,
			dialogue_runner.current_node.speaker,
			dialogue_runner.current_node.line,
			choices
		)


@rpc("authority", "call_local", "unreliable")
func _sync_patience(current: float, max_p: float) -> void:
	if EventBus != null:
		EventBus.caller_patience_updated.emit(current, max_p)


@rpc("authority", "call_local", "reliable")
func _sync_evidence_unlocked(evidence_key: StringName) -> void:
	if EventBus != null:
		EventBus.evidence_unlocked.emit(evidence_key)


@rpc("authority", "call_local", "reliable")
func _sync_dialogue_finished(_reason: StringName) -> void:
	pass


# ==============================================================================
# Voice Stress Analyzer RPCs (P2-08)
# ==============================================================================

@rpc("any_peer", "call_remote", "reliable")
func request_vsa_tag(playback_time: float, tag_type: StringName) -> void:
	if not _is_server():
		return
	if current_state != CallState.CONNECTED:
		return
	
	var res: Dictionary = vsa.tag_evidence(playback_time, tag_type)
	@warning_ignore("unsafe_cast")
	var delta_patience: float = (res.get("patience_delta", 0.0) as float)
	if delta_patience != 0.0:
		dialogue_runner.modify_patience(delta_patience)
	
	@warning_ignore("unsafe_call_argument")
	var ev_key: StringName = StringName(res.get("evidence_key", &""))
	if ev_key != &"":
		dialogue_runner.add_revealed_evidence(ev_key)
	
	var sender: int = multiplayer.get_remote_sender_id()
	_sync_vsa_tag_result.rpc_id(sender if sender > 0 else 1, res)


@rpc("authority", "call_local", "reliable")
func _sync_vsa_tag_result(_result: Dictionary) -> void:
	# Local client receives notification of tag result
	pass


func get_vsa() -> VoiceStressAnalyzer:
	return vsa


# ==============================================================================
# Snapshot & State Recovery
# ==============================================================================

func is_active(call_id: StringName) -> bool:
	return active_call_id == call_id and (current_state == CallState.RINGING or current_state == CallState.CONNECTED or current_state == CallState.ASSESSMENT)


func get_snapshot() -> Dictionary:
	return {
		"shift_clock_minutes": shift_clock_minutes,
		"current_state": int(current_state),
		"active_call_id": String(active_call_id),
		"ring_timer": ring_timer,
		"handset_owner_peer_id": handset_owner_peer_id,
		"patience_remaining": dialogue_runner.patience_remaining,
		"revealed_evidence": dialogue_runner.revealed_evidence,
	}


func apply_snapshot(data: Dictionary) -> void:
	@warning_ignore("unsafe_call_argument")
	shift_clock_minutes = int(data.get("shift_clock_minutes", 0))
	@warning_ignore("unsafe_call_argument")
	current_state = CallState.values()[clampi(int(data.get("current_state", 0)), 0, CallState.size() - 1)]
	@warning_ignore("unsafe_call_argument")
	active_call_id = StringName(data.get("active_call_id", ""))
	active_call = registered_calls.get(active_call_id, null)
	@warning_ignore("unsafe_cast")
	ring_timer = (data.get("ring_timer", 0.0) as float)
	@warning_ignore("unsafe_call_argument")
	handset_owner_peer_id = int(data.get("handset_owner_peer_id", 0))
	
	if EventBus != null:
		EventBus.shift_clock_updated.emit(shift_clock_minutes)
		EventBus.handset_owner_changed.emit(handset_owner_peer_id)


# ==============================================================================
# Callbacks
# ==============================================================================

func _on_phase_changed(new_phase: StringName) -> void:
	if new_phase == &"dispatch":
		start_shift()
	elif new_phase == &"field" or new_phase == &"loadout_vote":
		pause_shift()


func _on_player_left(peer_id: int) -> void:
	if not _is_server():
		return
	if handset_owner_peer_id == peer_id:
		handset_owner_peer_id = 0
		_sync_handset_owner.rpc(0)


func reset() -> void:
	shift_clock_minutes = 0
	shift_clock_accum_seconds = 0.0
	shift_running = false
	current_state = CallState.IDLE
	active_call = null
	active_call_id = &""
	handset_owner_peer_id = 0
	call_queue.clear()
	call_history.clear()
	if phone_audio_player != null and phone_audio_player.playing:
		phone_audio_player.stop()
