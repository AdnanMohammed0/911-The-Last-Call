## Voice Stress Analyzer (VSA) runtime for emergency calls (GAMEPLAY_MECHANICS §5.3).
## Live spectrum analysis on the Phone bus + authored StressProfile curves.
class_name VoiceStressAnalyzer
extends RefCounted

const PHONE_BUS_NAME: StringName = &"Phone"
const SPECTRUM_EFFECT_NAME: String = "SpectrumAnalyzer"

## Frequency band definitions in Hz
const BAND_MICRO_TREMOR_MIN: float = 8.0
const BAND_MICRO_TREMOR_MAX: float = 12.0
const BAND_EMF_MIN: float = 50.0
const BAND_EMF_MAX: float = 60.0
const BAND_VOICE_LOW: float = 300.0
const BAND_VOICE_HIGH: float = 3400.0
const BAND_TREBLE_HIGH: float = 8000.0

var active_profile: StressProfile = null
var current_playback_time: float = 0.0
var total_call_duration: float = 60.0
var background_isolate_active: bool = false

var _spectrum_instance: AudioEffectSpectrumAnalyzerInstance = null
var _has_spectrum: bool = false
var _cached_magnitude: float = 0.0


func _init(p_profile: StressProfile = null) -> void:
	if p_profile != null:
		set_profile(p_profile)
	_setup_spectrum_tap()


func set_profile(p_profile: StressProfile, p_total_duration: float = 60.0) -> void:
	active_profile = p_profile
	total_call_duration = maxf(1.0, p_total_duration)
	current_playback_time = 0.0


func update_playback_time(time_seconds: float) -> void:
	current_playback_time = maxf(0.0, time_seconds)


func toggle_background_isolate(enabled: bool) -> void:
	background_isolate_active = enabled


func _setup_spectrum_tap() -> void:
	var bus_idx: int = AudioServer.get_bus_index(PHONE_BUS_NAME)
	if bus_idx < 0:
		_has_spectrum = false
		return
	
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		var effect: AudioEffect = AudioServer.get_bus_effect(bus_idx, i)
		if effect is AudioEffectSpectrumAnalyzer:
			var inst: AudioEffectInstance = AudioServer.get_bus_effect_instance(bus_idx, i)
			if inst is AudioEffectSpectrumAnalyzerInstance:
				_spectrum_instance = inst as AudioEffectSpectrumAnalyzerInstance
				_has_spectrum = true
				return


## Returns live frequency magnitudes (0.0 to 1.0) for visualizers.
func get_live_spectrum_bands() -> Dictionary:
	var tremor_mag: float = 0.0
	var emf_mag: float = 0.0
	var voice_mag: float = 0.0
	var treble_mag: float = 0.0
	
	if _has_spectrum and _spectrum_instance != null:
		var tremor_v: Vector2 = _spectrum_instance.get_magnitude_for_frequency_range(BAND_MICRO_TREMOR_MIN, BAND_MICRO_TREMOR_MAX)
		var emf_v: Vector2 = _spectrum_instance.get_magnitude_for_frequency_range(BAND_EMF_MIN, BAND_EMF_MAX)
		var voice_v: Vector2 = _spectrum_instance.get_magnitude_for_frequency_range(BAND_VOICE_LOW, BAND_VOICE_HIGH)
		var treble_v: Vector2 = _spectrum_instance.get_magnitude_for_frequency_range(BAND_VOICE_HIGH, BAND_TREBLE_HIGH)
		
		tremor_mag = clampf((tremor_v.x + tremor_v.y) * 4.0, 0.0, 1.0)
		emf_mag = clampf((emf_v.x + emf_v.y) * 4.0, 0.0, 1.0)
		voice_mag = clampf((voice_v.x + voice_v.y) * 2.0, 0.0, 1.0)
		treble_mag = clampf((treble_v.x + treble_v.y) * 2.0, 0.0, 1.0)
	else:
		# Simulated baseline energy when audio bus is not rendering (e.g. headless tests)
		var read: Dictionary = get_stress_readout(current_playback_time)
		tremor_mag = float(read.get("tremor_level", 0.3))
		emf_mag = 0.8 if read.get("emf_detected", false) == true else 0.05
		voice_mag = 0.1 if background_isolate_active else 0.6
		treble_mag = 0.35
	
	if background_isolate_active:
		# Duck voice band, boost ambient / room noise
		voice_mag *= 0.15
		treble_mag *= 1.4
		emf_mag *= 1.5
	
	return {
		"micro_tremor": tremor_mag,
		"emf_hum": emf_mag,
		"voice_band": voice_mag,
		"treble": treble_mag,
		"background_isolate": background_isolate_active,
	}


## Evaluates stress, pitch, BPM, loop detection, and tags for a given playback second.
func get_stress_readout(time_seconds: float = -1.0) -> Dictionary:
	var t: float = current_playback_time if time_seconds < 0.0 else time_seconds
	var norm_t: float = clampf(t / total_call_duration, 0.0, 1.0)
	
	var tremor_val: float = 0.0
	var pitch_val: float = 0.0
	var base_bpm: int = 80
	var in_loop: bool = false
	var has_emf: bool = false
	var tags: Array[StringName] = []
	
	if active_profile != null:
		if active_profile.tremor_curve != null:
			tremor_val = clampf(active_profile.tremor_curve.sample_baked(norm_t), 0.0, 1.0)
		if active_profile.pitch_variance != null:
			pitch_val = clampf(active_profile.pitch_variance.sample_baked(norm_t), 0.0, 1.0)
		
		base_bpm = active_profile.baseline_heart_rate
		has_emf = active_profile.emf_frequency > 0.0
		tags = active_profile.background_tags.duplicate()
		
		for seg in active_profile.loop_segments:
			if t >= seg.x and t <= seg.y:
				in_loop = true
				break
	
	# Calculated dynamic BPM estimate
	var dynamic_bpm: int = int(round(base_bpm + (tremor_val * 35.0) + (pitch_val * 15.0)))
	
	return {
		"time": t,
		"normalized_progress": norm_t,
		"tremor_level": tremor_val,
		"pitch_variance": pitch_val,
		"estimated_bpm": dynamic_bpm,
		"is_loop": in_loop,
		"emf_detected": has_emf,
		"background_tags": tags,
		"background_isolated": background_isolate_active,
	}


## Checks if a timestamp lies within an authored loop segment.
func is_in_loop_segment(time_seconds: float) -> bool:
	if active_profile == null:
		return false
	for seg in active_profile.loop_segments:
		if time_seconds >= seg.x and time_seconds <= seg.y:
			return true
	return false


## Profiler scrub-and-tag action (GAMEPLAY_MECHANICS §5.3).
## Returns outcome dict with success, patience delta, and evidence unlocked.
func tag_evidence(time_seconds: float, tag_type: StringName) -> Dictionary:
	if active_profile == null:
		return {
			"success": false,
			"tag": tag_type,
			"patience_delta": -10.0,
			"reason": "No active audio profile to analyze",
			"evidence_key": &"",
		}
	
	var readout: Dictionary = get_stress_readout(time_seconds)
	var is_correct: bool = false
	var evidence_key: StringName = &""
	var reason: String = ""
	
	match tag_type:
		&"loop":
			if readout.get("is_loop", false) == true:
				is_correct = true
				evidence_key = &"evidence_loop_detected"
				reason = "Identified pre-recorded audio loop"
			else:
				reason = "No repeated audio loop at this timestamp"
		
		&"tremor_flat":
			var tremor: float = float(readout.get("tremor_level", 0.0))
			if tremor <= 0.25:
				is_correct = true
				evidence_key = &"evidence_flat_tremor"
				reason = "Identified abnormally flat micro-tremor (feigned panic / deception)"
			else:
				reason = "Tremor is not flat (genuine stress detected)"
		
		&"tremor_high":
			var tremor: float = float(readout.get("tremor_level", 0.0))
			if tremor >= 0.6:
				is_correct = true
				evidence_key = &"evidence_high_stress"
				reason = "Confirmed acute physiological panic (high tremor)"
			else:
				reason = "Tremor level is insufficient for high stress tag"
		
		&"emf_hum", &"emf":
			if readout.get("emf_detected", false) == true:
				is_correct = true
				evidence_key = &"evidence_emf_hum"
				reason = "Identified sub-bass EMF frequency signature (Dead Frequency)"
			else:
				reason = "No electromagnetic anomaly detected on line"
		
		&"background_isolate", &"isolate":
			if not active_profile.background_tags.is_empty():
				is_correct = true
				var first_tag: StringName = active_profile.background_tags[0]
				evidence_key = StringName("evidence_bg_" + String(first_tag))
				reason = "Background audio isolated: %s" % first_tag
			else:
				reason = "No distinct background audio cues present"
		
		_:
			# Specific custom background tag check
			var bg_tags: Array[StringName] = active_profile.background_tags
			if tag_type in bg_tags:
				is_correct = true
				evidence_key = StringName("evidence_" + String(tag_type))
				reason = "Isolated audio tag: %s" % tag_type
			else:
				reason = "Audio tag not present in recording"
	
	if is_correct:
		return {
			"success": true,
			"tag": tag_type,
			"patience_delta": 10.0, # Calm caller slightly on insightful read
			"reason": reason,
			"evidence_key": evidence_key,
		}
	else:
		return {
			"success": false,
			"tag": tag_type,
			"patience_delta": -20.0, # Penalty for false accusation / bad tag
			"reason": reason,
			"evidence_key": &"",
		}
