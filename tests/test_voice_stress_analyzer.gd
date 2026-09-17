extends GutTest

func _create_test_stress_profile() -> StressProfile:
	var profile: StressProfile = StressProfile.new()
	
	# Tremor curve: rising from 0.1 to 0.9
	var t_curve: Curve = Curve.new()
	t_curve.add_point(Vector2(0.0, 0.1))
	t_curve.add_point(Vector2(1.0, 0.9))
	profile.tremor_curve = t_curve
	
	# Pitch variance curve: flat 0.2
	var p_curve: Curve = Curve.new()
	p_curve.add_point(Vector2(0.0, 0.2))
	p_curve.add_point(Vector2(1.0, 0.2))
	profile.pitch_variance = p_curve
	
	profile.baseline_heart_rate = 75
	profile.loop_segments = [Vector2(10.0, 15.0), Vector2(30.0, 35.0)]
	profile.background_tags = [&"adult_breathing", &"water_drip"]
	profile.emf_frequency = 60.0
	
	return profile


func test_vsa_stress_readout_curves() -> void:
	var profile: StressProfile = _create_test_stress_profile()
	var vsa: VoiceStressAnalyzer = VoiceStressAnalyzer.new(profile)
	vsa.set_profile(profile, 100.0)
	
	# Readout at t = 0s (start)
	var read_start: Dictionary = vsa.get_stress_readout(0.0)
	assert_almost_eq(float(read_start["tremor_level"]), 0.1, 0.05)
	assert_almost_eq(float(read_start["pitch_variance"]), 0.2, 0.05)
	assert_eq(read_start["is_loop"] == true, false)
	assert_eq(read_start["emf_detected"] == true, true)
	
	# Readout at t = 100s (end)
	var read_end: Dictionary = vsa.get_stress_readout(100.0)
	assert_almost_eq(float(read_end["tremor_level"]), 0.9, 0.05)
	assert_true(int(read_end["estimated_bpm"]) > 100) # Higher BPM at high tremor


func test_vsa_loop_detection() -> void:
	var profile: StressProfile = _create_test_stress_profile()
	var vsa: VoiceStressAnalyzer = VoiceStressAnalyzer.new(profile)
	vsa.set_profile(profile, 100.0)
	
	assert_false(vsa.is_in_loop_segment(5.0))
	assert_true(vsa.is_in_loop_segment(12.5)) # Within [10, 15]
	assert_false(vsa.is_in_loop_segment(20.0))
	assert_true(vsa.is_in_loop_segment(32.0)) # Within [30, 35]


func test_vsa_background_isolate() -> void:
	var profile: StressProfile = _create_test_stress_profile()
	var vsa: VoiceStressAnalyzer = VoiceStressAnalyzer.new(profile)
	vsa.set_profile(profile, 100.0)
	
	assert_false(vsa.background_isolate_active)
	var normal_bands: Dictionary = vsa.get_live_spectrum_bands()
	
	vsa.toggle_background_isolate(true)
	assert_true(vsa.background_isolate_active)
	var isolated_bands: Dictionary = vsa.get_live_spectrum_bands()
	
	# Voice band should be suppressed in isolate mode
	assert_true(float(isolated_bands["voice_band"]) < float(normal_bands["voice_band"]))


func test_vsa_scrub_and_tag_mechanics() -> void:
	var profile: StressProfile = _create_test_stress_profile()
	var vsa: VoiceStressAnalyzer = VoiceStressAnalyzer.new(profile)
	vsa.set_profile(profile, 100.0)
	
	# Correct loop tag at t = 12s
	var res_loop_valid: Dictionary = vsa.tag_evidence(12.0, &"loop")
	assert_true(res_loop_valid["success"])
	assert_eq(res_loop_valid["evidence_key"], &"evidence_loop_detected")
	assert_true(float(res_loop_valid["patience_delta"]) > 0.0)
	
	# Incorrect loop tag at t = 50s
	var res_loop_invalid: Dictionary = vsa.tag_evidence(50.0, &"loop")
	assert_false(res_loop_invalid["success"])
	assert_true(float(res_loop_invalid["patience_delta"]) < 0.0)
	
	# Correct EMF tag
	var res_emf: Dictionary = vsa.tag_evidence(25.0, &"emf_hum")
	assert_true(res_emf["success"])
	assert_eq(res_emf["evidence_key"], &"evidence_emf_hum")
	
	# Correct custom background tag
	var res_bg: Dictionary = vsa.tag_evidence(25.0, &"adult_breathing")
	assert_true(res_bg["success"])
	assert_eq(res_bg["evidence_key"], &"evidence_adult_breathing")
