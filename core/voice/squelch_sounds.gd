## Procedural radio squelch SFX (no asset files): a key-up click + static burst, and a longer
## decaying "kssh" tail for key-down. Played on the VoiceRadio bus so the radio filter colours them.
## Authority: LOCAL
class_name SquelchSounds
extends RefCounted

const SAMPLE_RATE: int = 16000


static func make_squelch_in() -> AudioStreamWAV:
	return _build(0.12, 0.02, 0.35, 11)


static func make_squelch_out() -> AudioStreamWAV:
	return _build(0.22, 0.0, 0.45, 23)


## `click_sec` of a sharp square click, then band-limited noise decaying over `length_sec`.
static func _build(length_sec: float, click_sec: float, volume: float, seed_value: int) -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var count: int = int(length_sec * SAMPLE_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	var smoothed: float = 0.0
	for i: int in count:
		var t: float = float(i) / SAMPLE_RATE
		var envelope: float = pow(1.0 - float(i) / count, 2.0)
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), 0.55)
		var value: float = smoothed * envelope * volume
		if t < click_sec:
			value += (0.6 if int(t * 1800.0) % 2 == 0 else -0.6) * (1.0 - t / click_sec)
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
