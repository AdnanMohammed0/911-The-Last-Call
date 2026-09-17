## Procedural firearm sounds (no audio assets yet): a sharp noise crack with a low body and a room tail.
## Streams are generated once per weapon kind and cached.
## Authority: LOCAL
class_name WeaponAudio
extends RefCounted

const SAMPLE_RATE: int = 22050

static var _cache: Dictionary[String, AudioStreamWAV] = {}


## `heaviness` 0 = pistol crack, 1 = shotgun boom.
static func gunshot(key: String, heaviness: float) -> AudioStreamWAV:
	if _cache.has(key):
		return _cache[key]
	var seconds: float = lerpf(0.45, 0.9, heaviness)
	var count: int = int(seconds * SAMPLE_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(key)
	var low: float = 0.0
	var body_freq: float = lerpf(140.0, 70.0, heaviness)
	for i: int in count:
		var t: float = float(i) / SAMPLE_RATE
		var noise: float = rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, lerpf(0.35, 0.18, heaviness))
		var crack: float = noise * exp(-t * lerpf(60.0, 35.0, heaviness))
		var body: float = sin(TAU * body_freq * t * (1.0 - t)) * exp(-t * lerpf(22.0, 12.0, heaviness))
		var tail: float = low * exp(-t * lerpf(9.0, 5.0, heaviness)) * 0.55
		var sample: float = clampf(crack * 0.9 + body * 0.8 + tail, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 30000.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	_cache[key] = stream
	return stream


## Short mechanical clicks for reload / dry fire.
static func click(key: String, pitch: float) -> AudioStreamWAV:
	if _cache.has(key):
		return _cache[key]
	var count: int = int(0.06 * SAMPLE_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(key)
	for i: int in count:
		var t: float = float(i) / SAMPLE_RATE
		var sample: float = (rng.randf_range(-0.6, 0.6) + sin(TAU * pitch * t) * 0.5) * exp(-t * 90.0)
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 26000.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	_cache[key] = stream
	return stream
