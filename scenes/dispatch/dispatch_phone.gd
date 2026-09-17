## The 911 phone on the dispatch desk. Rings (sound + blinking red light) while a call is RINGING on every
## peer; pressing F answers it (the answering player takes the handset) and opens the CAD terminal.
## Authority: HOST (answer goes through CallDirector.request_answer_call validation)
class_name DispatchPhone
extends Interactable

const BLINK_SECONDS: float = 0.35

@export var ring_light: Light3D
@export var status_label: Label3D

var _ring_player: AudioStreamPlayer3D
var _blink: float = 0.0


func _ready() -> void:
	super()
	prompt_text = "Answer 911 call"
	max_distance = 2.2
	cooldown = 0.3
	_ring_player = AudioStreamPlayer3D.new()
	var ring: AudioStreamWAV = Hallucination._make_phone_ring()
	ring.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ring.loop_end = ring.data.size() / 2
	_ring_player.stream = ring
	_ring_player.bus = &"SFX"
	_ring_player.unit_size = 4.0
	add_child(_ring_player)
	if ring_light != null:
		ring_light.visible = false
	EventBus.call_ring.connect(func(_id: StringName, _data: CallData) -> void: _set_ringing(true))
	EventBus.call_connected.connect(func(_id: StringName, _data: CallData) -> void: _set_ringing(false))
	EventBus.call_missed.connect(func(_id: StringName) -> void: _set_ringing(false))
	EventBus.call_ended.connect(func(_id: StringName, _reason: StringName) -> void: _set_ringing(false))


func get_prompt_text() -> String:
	match CallDirector.current_state:
		1:  # RINGING
			return "Answer 911 call"
		2:  # CONNECTED
			return "Open call screen"
	return "Phone (no incoming calls)"


func _process(delta: float) -> void:
	var ringing: bool = CallDirector.current_state == 1
	if ring_light != null:
		if ringing:
			_blink += delta
			ring_light.visible = fmod(_blink, BLINK_SECONDS * 2.0) < BLINK_SECONDS
		else:
			ring_light.visible = false
	if status_label != null:
		var minutes: int = CallDirector.shift_clock_minutes
		match CallDirector.current_state:
			1:
				status_label.text = "INCOMING 911 CALL\n%s" % (CallDirector.active_call.phone_number if CallDirector.active_call != null else "")
				status_label.modulate = Color(1, 0.35, 0.3) if fmod(_blink, 0.8) < 0.4 else Color(1, 0.8, 0.3)
			2:
				status_label.text = "CALL IN PROGRESS"
				status_label.modulate = Color(0.45, 1.0, 0.6)
			3:
				status_label.text = "ASSESSMENT"
				status_label.modulate = Color(1.0, 0.72, 0.25)
			_:
				status_label.text = "LINES CLEAR  %02d:%02d" % [minutes / 60, minutes % 60]
				status_label.modulate = Color(0.55, 0.75, 0.7)


## Host: answering the phone = CallDirector answer request from the interacting peer.
func _on_interact(_peer_id: int) -> void:
	if CallDirector.current_state == 1:
		CallDirector.request_answer_call(CallDirector.active_call_id)


func _on_interacted(peer_id: int) -> void:
	if peer_id != multiplayer.get_unique_id():
		return
	var terminal: DispatchTerminal = DispatchTerminal.find(get_tree())
	if terminal != null:
		terminal.open()


func _set_ringing(ringing: bool) -> void:
	if ringing and not _ring_player.playing:
		_ring_player.play()
	elif not ringing:
		_ring_player.stop()
