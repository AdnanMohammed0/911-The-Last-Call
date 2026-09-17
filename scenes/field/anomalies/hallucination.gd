## A short, local-only scare played on the victim's machine (never replicated, no collision).
## Sounds are generated procedurally so no audio assets are needed yet (Mohamed's audio content can
## replace them later).
## Authority: LOCAL (victim peer)
class_name Hallucination
extends Node3D

const GROUP: StringName = &"hallucinations"
const SAMPLE_RATE: int = 22050

var kind: StringName = &""
var lifetime: float = 3.0
var _age: float = 0.0
var _figure: MeshInstance3D = null


static func create(scare_kind: StringName, at: Vector3) -> Hallucination:
	var effect: Hallucination = Hallucination.new()
	effect.kind = scare_kind
	effect.name = "Hallucination_%s" % scare_kind
	effect.position = at
	return effect


func _ready() -> void:
	add_to_group(GROUP)
	top_level = true
	match kind:
		&"phantom_steps":
			lifetime = 3.2
			_play_3d(_make_footsteps(), -2.0)
		&"phantom_ring":
			lifetime = 4.0
			_play_3d(_make_phone_ring(), 0.0)
		&"radio_whisper":
			lifetime = 1.5
			var player: AudioStreamPlayer = AudioStreamPlayer.new()
			player.bus = VoiceManager.RADIO_BUS
			player.stream = SquelchSounds.make_squelch_in()
			add_child(player)
			player.play()
		&"shadow_figure":
			lifetime = 1.4
			_figure = MeshInstance3D.new()
			var mesh: CapsuleMesh = CapsuleMesh.new()
			mesh.radius = 0.3
			mesh.height = 1.9
			var material: StandardMaterial3D = StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = Color(0.0, 0.0, 0.0, 0.85)
			mesh.material = material
			_figure.mesh = mesh
			_figure.position = Vector3(0, 0.95, 0)
			add_child(_figure)


func _process(delta: float) -> void:
	_age += delta
	if kind == &"phantom_steps":
		# Steps come closer, then stop just behind the victim.
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null:
			global_position = global_position.move_toward(camera.global_position - Vector3(0, 1.5, 0), delta * 1.2)
	if _figure != null:
		var material: StandardMaterial3D = (_figure.mesh as CapsuleMesh).material as StandardMaterial3D
		material.albedo_color.a = clampf(0.85 * (1.0 - _age / lifetime), 0.0, 0.85)
	if _age >= lifetime:
		queue_free()


func _play_3d(stream: AudioStream, volume_db: float) -> void:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = &"SFX"
	add_child(player)
	player.play()


static func _make_footsteps() -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var seconds: float = 3.0
	var count: int = int(seconds * SAMPLE_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		var t: float = float(i) / SAMPLE_RATE
		var step_t: float = fmod(t, 0.55)
		var thump: float = sin(TAU * 70.0 * step_t) * exp(-step_t * 28.0) + rng.randf_range(-1.0, 1.0) * exp(-step_t * 60.0) * 0.4
		data.encode_s16(i * 2, int(clampf(thump * 0.7, -1.0, 1.0) * 32767.0))
	return _wav(data)


static func _make_phone_ring() -> AudioStreamWAV:
	var seconds: float = 3.5
	var count: int = int(seconds * SAMPLE_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		var t: float = float(i) / SAMPLE_RATE
		var on: bool = fmod(t, 3.0) < 2.0 and fmod(t, 0.1) < 0.05
		var value: float = (sin(TAU * 440.0 * t) + sin(TAU * 480.0 * t)) * 0.25 if on else 0.0
		data.encode_s16(i * 2, int(value * 32767.0))
	return _wav(data)


static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
