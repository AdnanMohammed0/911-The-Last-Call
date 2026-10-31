extends GutTest


func after_each() -> void:
	VoiceManager._clear_streams()


func test_radio_history_is_bounded_and_ignores_invalid_packets() -> void:
	VoiceManager._remember_radio(2, PackedByteArray([1, 2]))
	assert_false(VoiceManager._recent_radio.has(2))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(VoiceCodec.FRAME_SAMPLES)
	var packet: PackedByteArray = ImaAdpcmCodec.new().encode(samples)
	for i: int in VoiceManager.DEAD_FREQUENCY_FRAMES + 6:
		VoiceManager._remember_radio(2, packet)
	var frames: Array = VoiceManager._recent_radio[2]
	assert_eq(frames.size(), VoiceManager.DEAD_FREQUENCY_FRAMES)


func test_host_injects_only_to_selected_victim_with_cooldown() -> void:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(VoiceCodec.FRAME_SAMPLES)
	for i: int in samples.size():
		samples[i] = sin(float(i) * 0.1) * 0.25
	var packet: PackedByteArray = ImaAdpcmCodec.new().encode(samples)
	for i: int in 8:
		VoiceManager._remember_radio(2, packet)
	assert_false(VoiceManager.inject_dead_frequency(2, 2))
	assert_true(VoiceManager.inject_dead_frequency(1, 2))
	assert_false(VoiceManager.inject_dead_frequency(1, 2))
	assert_true(VoiceManager._dead_frequency_outbox.has(1))
	assert_false(VoiceManager._dead_frequency_outbox.has(3))
	VoiceManager._pump_dead_frequency(Time.get_ticks_msec())
	assert_true(VoiceManager._streams.has(-2))
