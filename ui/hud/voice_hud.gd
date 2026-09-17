## Voice indicators: local transmit state (MIC / RADIO + input level) and who is talking.
## Authority: LOCAL
class_name VoiceHud
extends Control

const MIC_COLOR: Color = Color(0.45, 0.95, 0.5)
const RADIO_COLOR: Color = Color(1.0, 0.7, 0.25)
const IDLE_COLOR: Color = Color(0.7, 0.7, 0.7, 0.6)

var _speaking: Dictionary[int, bool] = {}
var _radio: Dictionary[int, bool] = {}

@onready var _local_label: Label = %LocalLabel
@onready var _level_bar: ProgressBar = %LevelBar
@onready var _talkers_label: Label = %TalkersLabel


func _ready() -> void:
	VoiceManager.speaking_changed.connect(_on_speaking_changed)
	VoiceManager.mode_changed.connect(func(_m: VoiceManager.Mode) -> void: _refresh())
	_refresh()


func _process(_delta: float) -> void:
	_level_bar.value = clampf(inverse_lerp(-60.0, 0.0, VoiceManager.local_level_db), 0.0, 1.0)


func _on_speaking_changed(peer_id: int, speaking: bool, radio: bool) -> void:
	_speaking[peer_id] = speaking
	_radio[peer_id] = radio
	_refresh()


func _refresh() -> void:
	var me: int = multiplayer.get_unique_id()
	if VoiceManager.local_radio:
		_local_label.text = "● RADIO"
		_local_label.modulate = RADIO_COLOR
	elif VoiceManager.local_transmitting:
		_local_label.text = "● MIC"
		_local_label.modulate = MIC_COLOR
	else:
		var hint: String = "open mic" if VoiceManager.mode == VoiceManager.Mode.VOICE_ACTIVITY else "Caps Lock to talk"
		_local_label.text = "○ %s · B radio" % hint if VoiceManager.has_microphone() else "○ no microphone"
		_local_label.modulate = IDLE_COLOR
	var talkers: PackedStringArray = PackedStringArray()
	for peer_id: int in _speaking:
		if _speaking[peer_id] and peer_id != me:
			talkers.append("%s %s" % ["📻" if _radio.get(peer_id, false) else "🔊", NetManager.get_player_name(peer_id)])
	_talkers_label.text = "\n".join(talkers)
