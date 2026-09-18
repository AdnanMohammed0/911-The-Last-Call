## Authored stress profile for Voice Stress Analyzer (GAMEPLAY_MECHANICS §5.3).
## Gameplay truth is authored here for determinism and designability.
class_name StressProfile
extends Resource

## 0..1 micro-tremor intensity over normalized call time (0.0 to 1.0)
@export var tremor_curve: Curve
## 0..1 pitch variance over normalized call time
@export var pitch_variance: Curve
## [start_s, end_s] repeated/pre-recorded audio segments for loop detection
@export var loop_segments: Array[Vector2] = []
## Background tags e.g. &"adult_breathing", &"emf_hum", &"highway_silence", &"water_drip"
@export var background_tags: Array[StringName] = []
## Baseline heart rate in BPM (e.g. 80; AMBUSH callers stay abnormally steady despite screaming)
@export var baseline_heart_rate: int = 80
## EMF interference frequency in Hz (e.g. 50.0 or 60.0 for Dead Frequency paranormal calls, 0.0 if none)
@export var emf_frequency: float = 0.0

## Returns the tremor value at normalized time (0.0..1.0).
func get_tremor_at(t_normalized: float) -> float:
	if tremor_curve == null:
		return 0.0
	return tremor_curve.sample(t_normalized)

## Returns the pitch variance at normalized time (0.0..1.0).
func get_pitch_variance_at(t_normalized: float) -> float:
	if pitch_variance == null:
		return 0.0
	return pitch_variance.sample(t_normalized)

## Checks if the given time falls within a loop segment.
func is_in_loop(t_seconds: float) -> bool:
	for seg: Vector2 in loop_segments:
		if t_seconds >= seg.x and t_seconds <= seg.y:
			return true
	return false

## Validates the resource for authoring mistakes.
func validate() -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	var warnings: PackedStringArray = PackedStringArray()

	if tremor_curve == null:
		warnings.append("tremor_curve is empty")
	if pitch_variance == null:
		warnings.append("pitch_variance is empty")

	for i: int in range(loop_segments.size()):
		var seg: Vector2 = loop_segments[i]
		if seg.x < 0.0 or seg.y < 0.0 or seg.x >= seg.y:
			errors.append("loop_segments[%d] invalid: start=%.2f end=%.2f" % [i, seg.x, seg.y])

	if baseline_heart_rate <= 0:
		errors.append("baseline_heart_rate must be > 0")

	return {"errors": errors, "warnings": warnings}