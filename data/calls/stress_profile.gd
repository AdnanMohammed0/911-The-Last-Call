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
