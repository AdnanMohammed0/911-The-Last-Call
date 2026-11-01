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


func test_old_radio_is_not_replayed_or_mixed_with_new_speech() -> void:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(VoiceCodec.FRAME_SAMPLES)
	var packet: PackedByteArray = ImaAdpcmCodec.new().encode(samples)
	for i: int in VoiceManager.JITTER_FRAMES:
		VoiceManager._remember_radio(2, packet)
	VoiceManager._recent_radio_last_msec[2] = Time.get_ticks_msec() - VoiceManager.DEAD_FREQUENCY_MAX_AGE_MS - 1
	assert_false(VoiceManager.inject_dead_frequency(1, 2))
	VoiceManager._remember_radio(2, packet)
	assert_eq(VoiceManager._recent_radio[2].size(), 1)
	assert_false(VoiceManager.inject_dead_frequency(1, 2))


func test_speaker_departure_cancels_pending_imitation() -> void:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(VoiceCodec.FRAME_SAMPLES)
	var packet: PackedByteArray = ImaAdpcmCodec.new().encode(samples)
	for i: int in VoiceManager.JITTER_FRAMES:
		VoiceManager._remember_radio(2, packet)
	assert_true(VoiceManager.inject_dead_frequency(1, 2))
	VoiceManager._remove_stream(2)
	assert_false(VoiceManager._recent_radio.has(2))
	assert_false(VoiceManager._dead_frequency_outbox.has(1))


func test_replay_keeps_20ms_cadence_when_host_frames_are_slow() -> void:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(VoiceCodec.FRAME_SAMPLES)
	var packet: PackedByteArray = ImaAdpcmCodec.new().encode(samples)
	for _i: int in 10:
		VoiceManager._remember_radio(2, packet)
	assert_true(VoiceManager.inject_dead_frequency(1, 2))
	var start_msec: int = VoiceManager._dead_frequency_outbox[1]["next_msec"]
	VoiceManager._pump_dead_frequency(start_msec + 79)
	var index: int = VoiceManager._dead_frequency_outbox[1]["index"]
	assert_eq(index, 4, "four frames are due within 80 ms")
	VoiceManager._pump_dead_frequency(start_msec + 1000)
	index = VoiceManager._dead_frequency_outbox[1]["index"]
	assert_eq(index, 8, "a long stall is capped to four packets per update")
	VoiceManager._pump_dead_frequency(start_msec + 1000)
	assert_false(VoiceManager._dead_frequency_outbox.has(1), "the remaining frames finish without stretching the clip")


func test_dead_frequency_rpc_reaches_only_the_victim() -> void:
	var server_root: Node = Node.new()
	server_root.name = "FrequencyServer"
	add_child_autofree(server_root)
	var client_root: Node = Node.new()
	client_root.name = "FrequencyClient"
	add_child_autofree(client_root)
	var bystander_root: Node = Node.new()
	bystander_root.name = "FrequencyBystander"
	add_child_autofree(bystander_root)
	var server_api: SceneMultiplayer = SceneMultiplayer.new()
	var client_api: SceneMultiplayer = SceneMultiplayer.new()
	var bystander_api: SceneMultiplayer = SceneMultiplayer.new()
	get_tree().set_multiplayer(server_api, server_root.get_path())
	get_tree().set_multiplayer(client_api, client_root.get_path())
	get_tree().set_multiplayer(bystander_api, bystander_root.get_path())
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(49395, 3), OK)
	server_api.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", 49395), OK)
	client_api.multiplayer_peer = client_peer
	var bystander_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(bystander_peer.create_client("127.0.0.1", 49395), OK)
	bystander_api.multiplayer_peer = bystander_peer
	for _i: int in 120:
		if server_api.get_peers().size() == 2 and client_api.get_unique_id() > 1 and bystander_api.get_unique_id() > 1:
			break
		await get_tree().process_frame
	var victim_id: int = client_api.get_unique_id()
	assert_gt(victim_id, 1)
	assert_ne(victim_id, bystander_api.get_unique_id())
	var host_voice: VoiceService = VoiceService.new()
	host_voice.name = "Voice"
	server_root.add_child(host_voice)
	host_voice.set_process(false)
	var victim_voice: VoiceService = VoiceService.new()
	victim_voice.name = "Voice"
	client_root.add_child(victim_voice)
	victim_voice.set_process(false)
	var bystander_voice: VoiceService = VoiceService.new()
	bystander_voice.name = "Voice"
	bystander_root.add_child(bystander_voice)
	bystander_voice.set_process(false)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(VoiceCodec.FRAME_SAMPLES)
	for i: int in samples.size():
		samples[i] = sin(float(i) * 0.1) * 0.25
	var packet: PackedByteArray = ImaAdpcmCodec.new().encode(samples)
	for _i: int in VoiceManager.JITTER_FRAMES:
		host_voice._remember_radio(1, packet)
	assert_true(host_voice.inject_dead_frequency(victim_id, 1))
	host_voice._pump_dead_frequency(Time.get_ticks_msec())
	for _i: int in 120:
		if victim_voice._streams.has(-1):
			break
		await get_tree().process_frame
	assert_true(victim_voice._streams.has(-1), "the victim receives the fake radio frame")
	assert_false(host_voice._streams.has(-1), "the host does not hear the victim's hallucination")
	assert_false(bystander_voice._streams.has(-1), "the other client does not hear it")
	if victim_voice._streams.has(-1):
		assert_eq(victim_voice._streams[-1].radio_queue.size(), 1)
	var next_msec: int = host_voice._dead_frequency_outbox[victim_id]["next_msec"]
	host_voice._pump_dead_frequency(next_msec + 59)
	for _i: int in 120:
		if victim_voice._streams[-1].radio_queue.size() >= 4:
			break
		await get_tree().process_frame
	assert_eq(victim_voice._streams[-1].radio_queue.size(), 4, "late host updates still deliver every due frame to the victim")
	assert_false(bystander_voice._streams.has(-1))
	client_peer.close()
	bystander_peer.close()
	server_peer.close()
