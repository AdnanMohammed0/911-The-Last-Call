## Voice codec interface: 20 ms mono frames at 16 kHz in, compact packets out.
## Swap the implementation (e.g. an Opus GDExtension, or Steam voice in P1-09) without touching routing.
## Every encoded frame must be decodable on its own so lost packets only cost 20 ms of audio.
## Authority: LOCAL
class_name VoiceCodec
extends RefCounted

const SAMPLE_RATE: int = 16000
const FRAME_SAMPLES: int = 320          # 20 ms


func get_name() -> StringName:
	return &"none"


## `samples` has exactly FRAME_SAMPLES values in -1..1.
func encode(_samples: PackedFloat32Array) -> PackedByteArray:
	return PackedByteArray()


## Returns FRAME_SAMPLES values, or an empty array for a malformed packet.
func decode(_packet: PackedByteArray) -> PackedFloat32Array:
	return PackedFloat32Array()
