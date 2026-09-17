## Network debug overlay (F3): session state, per-peer RTT / jitter / packet loss, and bandwidth per channel.
## ENet only reports totals, so systems that own a channel report their bytes with `record()`
## (voice uses channel 2); "game" is the remainder (RPCs + synchronizers on channel 0).
## Start visible with `-- --netdebug`.
## Authority: LOCAL
extends CanvasLayer

const TOGGLE_KEY: Key = KEY_F3
const SAMPLE_SEC: float = 1.0
const RTT_HISTORY: int = 30

## channel name -> transfer channel number, for display.
const CHANNELS: Dictionary[StringName, int] = {
	&"voice": 2,
}

var _panel: PanelContainer
var _label: Label
var _elapsed: float = 0.0

## Last computed rates (bytes/s) — also used by tests.
var total_in_bps: float = 0.0
var total_out_bps: float = 0.0
var channel_in_bps: Dictionary[StringName, float] = {}
var channel_out_bps: Dictionary[StringName, float] = {}

var _channel_in_bytes: Dictionary[StringName, int] = {}
var _channel_out_bytes: Dictionary[StringName, int] = {}
## peer_id -> recent RTT samples (ms)
var _rtt_history: Dictionary[int, PackedInt32Array] = {}


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 160)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))
	_panel.add_child(_label)
	add_child(_panel)
	visible = "--netdebug" in OS.get_cmdline_user_args()
	NetManager.state_changed.connect(func(_s: NetManager.State) -> void: _reset_counters())


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == TOGGLE_KEY:
		visible = not visible
		get_viewport().set_input_as_handled()


## Report bytes sent/received on an app-level channel (e.g. VoiceManager on &"voice").
func record(channel: StringName, bytes: int, outgoing: bool) -> void:
	var bucket: Dictionary[StringName, int] = _channel_out_bytes if outgoing else _channel_in_bytes
	bucket[channel] = bucket.get(channel, 0) + bytes


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < SAMPLE_SEC:
		return
	_sample(_elapsed)
	_elapsed = 0.0
	if visible:
		_label.text = build_report()


func _sample(seconds: float) -> void:
	var host: ENetConnection = _connection()
	if host != null:
		total_in_bps = host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA) / seconds
		total_out_bps = host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA) / seconds
	else:
		total_in_bps = 0.0
		total_out_bps = 0.0
	for channel: StringName in CHANNELS:
		channel_in_bps[channel] = _channel_in_bytes.get(channel, 0) / seconds
		channel_out_bps[channel] = _channel_out_bytes.get(channel, 0) / seconds
	_channel_in_bytes.clear()
	_channel_out_bytes.clear()
	for peer_id: int in _peer_ids():
		var packet_peer: ENetPacketPeer = _packet_peer(peer_id)
		if packet_peer == null:
			continue
		var history: PackedInt32Array = _rtt_history.get(peer_id, PackedInt32Array())
		history.append(int(packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)))
		if history.size() > RTT_HISTORY:
			history.remove_at(0)
		_rtt_history[peer_id] = history


func build_report() -> String:
	var lines: PackedStringArray = PackedStringArray()
	var state_name: String = NetManager.State.keys()[NetManager.state]
	lines.append("NET  %s  peer %d  players %d  phase %s  %d fps" % [
		state_name, multiplayer.get_unique_id(), NetManager.roster.size(),
		GameState.phase_name(GameState.phase), Engine.get_frames_per_second()])
	if _connection() == null:
		lines.append("(offline)   F3 to hide")
		return "\n".join(lines)

	lines.append("")
	lines.append("PEER              RTT   avg/max   jitter   loss")
	for peer_id: int in _peer_ids():
		var packet_peer: ENetPacketPeer = _packet_peer(peer_id)
		if packet_peer == null:
			continue
		var rtt: int = int(packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
		var jitter: int = int(packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME_VARIANCE))
		var loss: float = packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / float(ENetPacketPeer.PACKET_LOSS_SCALE) * 100.0
		var history: PackedInt32Array = _rtt_history.get(peer_id, PackedInt32Array())
		var avg: int = 0
		var worst: int = 0
		for sample: int in history:
			avg += sample
			worst = maxi(worst, sample)
		avg = avg / maxi(history.size(), 1)
		var label: String = "%s (%d)" % [NetManager.get_player_name(peer_id).left(10), peer_id % 10000]
		lines.append("%-16s %4d ms  %3d/%-4d  ±%3d ms  %4.1f%%%s" % [label, rtt, avg, worst, jitter, loss, _violations_text(peer_id)])

	lines.append("")
	lines.append("CHANNEL             in kbps   out kbps")
	var voice_in: float = 0.0
	var voice_out: float = 0.0
	for channel: StringName in CHANNELS:
		var in_bps: float = channel_in_bps.get(channel, 0.0)
		var out_bps: float = channel_out_bps.get(channel, 0.0)
		voice_in += in_bps
		voice_out += out_bps
		lines.append("%-18s %8.1f   %8.1f" % ["%s (ch %d)" % [channel, CHANNELS[channel]], in_bps * 8.0 / 1000.0, out_bps * 8.0 / 1000.0])
	lines.append("%-18s %8.1f   %8.1f" % ["game (ch 0)", maxf(total_in_bps - voice_in, 0.0) * 8.0 / 1000.0, maxf(total_out_bps - voice_out, 0.0) * 8.0 / 1000.0])
	lines.append("%-18s %8.1f   %8.1f" % ["total (ENet)", total_in_bps * 8.0 / 1000.0, total_out_bps * 8.0 / 1000.0])
	lines.append("")
	lines.append("F3 to hide")
	return "\n".join(lines)


## Host: movement validation strikes for the peer's player, if any.
func _violations_text(peer_id: int) -> String:
	if not multiplayer.is_server():
		return ""
	var player: Player = Player.find_by_peer(get_tree(), peer_id)
	if player == null:
		return ""
	var validator: MovementValidator = player.get_node_or_null(^"MovementValidator") as MovementValidator
	return "  strikes %d" % validator.violation_count if validator != null and validator.violation_count > 0 else ""


func _connection() -> ENetConnection:
	var peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null or peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return null
	return peer.host


func _peer_ids() -> Array[int]:
	var ids: Array[int] = []
	if multiplayer.is_server():
		for id: int in multiplayer.get_peers():
			ids.append(id)
	elif _connection() != null:
		ids.append(1)  # clients only have a direct ENet link to the host
	ids.sort()
	return ids


func _packet_peer(peer_id: int) -> ENetPacketPeer:
	var peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null:
		return null
	return peer.get_peer(peer_id)


func _reset_counters() -> void:
	_rtt_history.clear()
	_channel_in_bytes.clear()
	_channel_out_bytes.clear()
	channel_in_bps.clear()
	channel_out_bps.clear()
	total_in_bps = 0.0
	total_out_bps = 0.0
