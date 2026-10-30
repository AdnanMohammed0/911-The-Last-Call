extends GutTest


func test_demo_uses_only_curated_calls_and_excludes_training_drill() -> void:
	assert_eq(DispatchSetup.calls_dir_for_build(true), DispatchSetup.DEMO_CALLS_DIR)
	assert_eq(DispatchSetup.calls_dir_for_build(false), CallValidator.CALLS_DIR)
	assert_false(DispatchSetup.test_call_enabled(true))
	assert_true(DispatchSetup.test_call_enabled(false))
	var paths: PackedStringArray = CallValidator._find_resources(DispatchSetup.calls_dir_for_build(true))
	assert_eq(paths.size(), 15)
	for path: String in paths:
		assert_true(path.begins_with(DispatchSetup.DEMO_CALLS_DIR + "/"))
		assert_ne(path, DispatchSetup.TRAINING_CALL)
		var call: CallData = load(path) as CallData
		assert_true(CallValidator.is_playable(call), path)
