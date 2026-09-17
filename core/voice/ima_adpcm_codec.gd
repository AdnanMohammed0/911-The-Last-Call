## IMA ADPCM voice codec (4 bits/sample): 320 samples -> 163 bytes (~65 kbps at 16 kHz).
## Pure GDScript, no native dependency. Each packet carries its own predictor + step index,
## so frames decode independently. Opus (~24 kbps) can replace it behind VoiceCodec later.
## Packet: [s16 predictor][u8 step index][160 bytes of nibbles]
## Authority: LOCAL
class_name ImaAdpcmCodec
extends VoiceCodec

const HEADER_BYTES: int = 3
const PACKET_BYTES: int = HEADER_BYTES + FRAME_SAMPLES / 2

const INDEX_TABLE: PackedInt32Array = [-1, -1, -1, -1, 2, 4, 6, 8]
const STEP_TABLE: PackedInt32Array = [
	7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
	50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
	337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
	2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
	15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767,
]

# Encoder state carries across frames for quality; the header snapshots it for the decoder.
var _predictor: int = 0
var _index: int = 0


func get_name() -> StringName:
	return &"ima-adpcm"


func encode(samples: PackedFloat32Array) -> PackedByteArray:
	var packet: PackedByteArray = PackedByteArray()
	packet.resize(PACKET_BYTES)
	packet.encode_s16(0, _predictor)
	packet[2] = _index
	var predictor: int = _predictor
	var index: int = _index
	var count: int = mini(samples.size(), FRAME_SAMPLES)
	for i: int in FRAME_SAMPLES:
		var sample: int = int(clampf(samples[i] if i < count else 0.0, -1.0, 1.0) * 32767.0)
		var step: int = STEP_TABLE[index]
		var diff: int = sample - predictor
		var nibble: int = 0
		if diff < 0:
			nibble = 8
			diff = -diff
		var delta: int = step >> 3
		if diff >= step:
			nibble |= 4
			diff -= step
			delta += step
		step >>= 1
		if diff >= step:
			nibble |= 2
			diff -= step
			delta += step
		step >>= 1
		if diff >= step:
			nibble |= 1
			delta += step
		predictor = clampi(predictor - delta if nibble & 8 else predictor + delta, -32768, 32767)
		index = clampi(index + INDEX_TABLE[nibble & 7], 0, 88)
		var byte_index: int = HEADER_BYTES + (i >> 1)
		packet[byte_index] = packet[byte_index] | (nibble << (4 if i & 1 else 0))
	_predictor = predictor
	_index = index
	return packet


func decode(packet: PackedByteArray) -> PackedFloat32Array:
	var samples: PackedFloat32Array = PackedFloat32Array()
	if packet.size() != PACKET_BYTES:
		return samples
	var index: int = packet[2]
	if index > 88:
		return samples
	samples.resize(FRAME_SAMPLES)
	var predictor: int = packet.decode_s16(0)
	for i: int in FRAME_SAMPLES:
		var nibble: int = (packet[HEADER_BYTES + (i >> 1)] >> (4 if i & 1 else 0)) & 0x0F
		var step: int = STEP_TABLE[index]
		var delta: int = step >> 3
		if nibble & 4:
			delta += step
		if nibble & 2:
			delta += step >> 1
		if nibble & 1:
			delta += step >> 2
		predictor = clampi(predictor - delta if nibble & 8 else predictor + delta, -32768, 32767)
		index = clampi(index + INDEX_TABLE[nibble & 7], 0, 88)
		samples[i] = predictor / 32768.0
	return samples
