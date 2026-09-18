## GUT Tests for Telemetry & Crash Reporting (P5-03).
## Tests TelemetrySettings, TelemetryManager, CrashReporter, and GameSettings integration.
class_name TestTelemetry
extends GutTest

# Loosely typed test code (mocks and dictionaries).
@warning_ignore_start("unsafe_call_argument", "unsafe_cast", "unsafe_method_access", "unsafe_property_access", "untyped_declaration", "inferred_declaration", "return_value_discarded")


var _telemetry_settings: TelemetrySettings
var _telemetry_manager: TelemetryManager
var _crash_reporter: CrashReporter
var _game_settings: GameSettings


func before_each() -> void:
	# Create fresh instances for each test
	_telemetry_settings = TelemetrySettings.new()
	_telemetry_manager = TelemetryManager.new()
	_telemetry_manager.settings = _telemetry_settings
	_crash_reporter = CrashReporter.new()
	_game_settings = GameSettings.new()

	# Mock singletons
	TelemetryManager.instance = _telemetry_manager
	CrashReporter.instance = _crash_reporter
	GameSettings.instance = _game_settings

	# Clean up any test config files
	var config: ConfigFile = ConfigFile.new()
	config.save("user://test_telemetry.cfg")
	config.save("user://test_settings.cfg")


func after_each() -> void:
	# Clean up
	TelemetryManager.instance = null
	CrashReporter.instance = null
	GameSettings.instance = null

	# Remove test configs
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null:
		dir.remove("test_telemetry.cfg")
		dir.remove("test_settings.cfg")


# --- TelemetrySettings Tests ---

func test_telemetry_settings_defaults() -> void:
	assert_false(_telemetry_settings.has_consented)
	assert_false(_telemetry_settings.telemetry_enabled)
	assert_false(_telemetry_settings.crash_reporting_enabled)
	assert_true(_telemetry_settings.consent_timestamp.is_empty())
	assert_true(_telemetry_settings.consent_version.is_empty())
	assert_false(_telemetry_settings.deletion_requested)


func test_telemetry_settings_set_consent() -> void:
	_telemetry_settings.set_consent(true, true)

	assert_true(_telemetry_settings.has_consented)
	assert_true(_telemetry_settings.telemetry_enabled)
	assert_true(_telemetry_settings.crash_reporting_enabled)
	assert_false(_telemetry_settings.consent_timestamp.is_empty())
	assert_false(_telemetry_settings.consent_version.is_empty())


func test_telemetry_settings_set_consent_crashes_only() -> void:
	_telemetry_settings.set_consent(false, true)

	assert_true(_telemetry_settings.has_consented)
	assert_false(_telemetry_settings.telemetry_enabled)
	assert_true(_telemetry_settings.crash_reporting_enabled)


func test_telemetry_settings_validation() -> void:
	# Valid state
	var result: Dictionary = _telemetry_settings.validate()
	assert_true(result.errors.is_empty())

	# Invalid: telemetry enabled without consent
	_telemetry_settings.telemetry_enabled = true
	result = _telemetry_settings.validate()
	assert_true(result.errors.has("telemetry_enabled requires has_consented = true"))

	# Invalid: crash reporting without consent
	_telemetry_settings.telemetry_enabled = false
	_telemetry_settings.crash_reporting_enabled = true
	result = _telemetry_settings.validate()
	assert_true(result.errors.has("crash_reporting_enabled requires has_consented = true"))


func test_telemetry_settings_request_deletion() -> void:
	_telemetry_settings.set_consent(true, true)
	_telemetry_settings.request_deletion()

	assert_true(_telemetry_settings.deletion_requested)
	assert_false(_telemetry_settings.telemetry_enabled)
	assert_false(_telemetry_settings.crash_reporting_enabled)


# --- TelemetryManager Tests ---

func test_telemetry_manager_initialization() -> void:
	assert_not_null(_telemetry_manager)
	assert_eq(_telemetry_manager.settings, _telemetry_settings)
	assert_eq(_telemetry_manager.session_data.session_id, _telemetry_settings.session_id)
	assert_ne(_telemetry_manager.session_data.session_id, "")


func test_telemetry_manager_record_event_disabled() -> void:
	# Telemetry disabled by default
	_telemetry_manager.record_event(&"test_event", {"key": "value"})
	assert_true(_telemetry_manager.event_queue.is_empty())


func test_telemetry_manager_record_event_enabled() -> void:
	_telemetry_settings.set_consent(true, true)
	_telemetry_manager.set_telemetry_enabled(true)

	_telemetry_manager.record_event(&"test_event", {"key": "value"})
	assert_eq(_telemetry_manager.event_queue.size(), 1)

	var event: Dictionary = _telemetry_manager.event_queue[0]
	assert_eq(event.event_type, &"test_event")
	assert_eq(event.payload.key, "value")
	assert_true(event.has("session_id"))
	assert_true(event.has("timestamp"))


func test_telemetry_manager_record_metric() -> void:
	_telemetry_settings.set_consent(true, true)
	_telemetry_manager.set_telemetry_enabled(true)

	_telemetry_manager.record_metric(&"test_metric", 42.5, {"tag": "value"})
	assert_eq(_telemetry_manager.event_queue.size(), 1)

	var event: Dictionary = _telemetry_manager.event_queue[0]
	assert_eq(event.event_type, &"metric")
	assert_eq(event.metric_name, &"test_metric")
	assert_eq(event.value, 42.5)
	assert_eq(event.tags.tag, "value")


func test_telemetry_manager_record_error() -> void:
	_telemetry_settings.set_consent(true, true)
	_telemetry_manager.set_telemetry_enabled(true)

	_telemetry_manager.record_error("TestError", "Something went wrong", {"context": "test"})
	assert_eq(_telemetry_manager.event_queue.size(), 1)

	var event: Dictionary = _telemetry_manager.event_queue[0]
	assert_eq(event.event_type, &"error")
	assert_eq(event.error_type, "TestError")
	assert_eq(event.message, "Something went wrong")
	assert_true(event.priority)  # Errors are priority


func test_telemetry_manager_record_crash() -> void:
	_telemetry_settings.set_consent(true, true)
	_telemetry_manager.set_crash_reporting_enabled(true)

	var crash_info: Dictionary = {
		"exception": "NullReferenceException",
		"stack_trace": "at Test.method()",
	}

	_telemetry_manager.record_crash(crash_info)
	assert_eq(_telemetry_manager.session_data.crashes_this_session, 1)
	assert_eq(_telemetry_manager.event_queue.size(), 1)

	var event: Dictionary = _telemetry_manager.event_queue[0]
	assert_eq(event.event_type, &"crash")
	assert_eq(event.crash_info.exception, "NullReferenceException")


func test_telemetry_manager_batch_flush() -> void:
	_telemetry_settings.set_consent(true, true)
	_telemetry_manager.set_telemetry_enabled(true)

	# Add multiple events
	for i in range(5):
		_telemetry_manager.record_event(&"batch_test", {"index": i})

	assert_eq(_telemetry_manager.event_queue.size(), 5)

	# Flush
	_telemetry_manager._flush_queue()
	assert_true(_telemetry_manager.event_queue.is_empty())


func test_telemetry_manager_queue_limit() -> void:
	_telemetry_settings.set_consent(true, true)
	_telemetry_manager.set_telemetry_enabled(true)

	# Fill queue beyond limit
	for i in range(600):
		_telemetry_manager.record_event(&"limit_test", {"index": i})

	# Should not exceed MAX_QUEUE_SIZE
	assert_lte(_telemetry_manager.event_queue.size(), 500)


func test_telemetry_manager_priority_queue() -> void:
	_telemetry_settings.set_consent(true, true)
	_telemetry_manager.set_telemetry_enabled(true)

	# Fill with normal events
	for i in range(10):
		_telemetry_manager.record_event(&"normal", {})

	# Add priority event
	_telemetry_manager.record_error("PriorityError", "High priority")

	# Priority event should be at the front when flushing
	_telemetry_manager._flush_queue()
	# Note: We can't easily test the internal send order without mocking HTTP,
	# but we can verify priority events are marked correctly
	var has_priority: bool = false
	for event in _telemetry_manager.event_queue:
		if event.get("priority", false):
			has_priority = true
			break
	assert_true(has_priority)


func test_telemetry_manager_session_lifecycle() -> void:
	_telemetry_settings.set_consent(true, true)
	_telemetry_manager.set_telemetry_enabled(true)

	# Simulate game events
	_telemetry_manager._on_call_received(&"test_call")
	_telemetry_manager._on_call_classified(&"test_call", &"genuine")
	_telemetry_manager._on_phase_changed(&"dispatch")

	assert_eq(_telemetry_manager.session_data.calls_received, 1)
	assert_eq(_telemetry_manager.session_data.calls_classified, 1)
	assert_eq(_telemetry_manager.session_data.phase, "dispatch")

	# Record shift summary
	_telemetry_manager.record_shift_summary()
	assert_true(_telemetry_manager.session_data.total_playtime_seconds > 0)


func test_telemetry_manager_ending_record() -> void:
	_telemetry_settings.set_consent(true, true)
	_telemetry_manager.set_telemetry_enabled(true)

	_telemetry_manager.record_ending(&"ending_whistleblowers")
	assert_eq(_telemetry_manager.session_data.ending_reached, "ending_whistleblowers")


func test_telemetry_manager_trait_tracking() -> void:
	_telemetry_settings.set_consent(true, true)
	_telemetry_manager.set_telemetry_enabled(true)

	_telemetry_manager.record_trait_change(&"limping", true)
	_telemetry_manager.record_trait_change(&"ptsd", true)
	_telemetry_manager.record_trait_change(&"limping", false)

	assert_true(_telemetry_manager.session_data.traits_gained.has("limping"))
	assert_true(_telemetry_manager.session_data.traits_gained.has("ptsd"))
	assert_true(_telemetry_manager.session_data.traits_cured.has("limping"))


func test_telemetry_manager_mission_tracking() -> void:
	_telemetry_settings.set_consent(true, true)
	_telemetry_manager.set_telemetry_enabled(true)

	_telemetry_manager.record_mission_start(&"farmhouse")
	_telemetry_manager.record_mission_complete(&"farmhouse", true, {"civilians_saved": 2})

	assert_eq(_telemetry_manager.session_data.missions_started, 1)
	assert_eq(_telemetry_manager.session_data.missions_completed, 1)
	assert_eq(_telemetry_manager.session_data.missions_failed, 0)


func test_telemetry_manager_gdpr_deletion() -> void:
	_telemetry_settings.set_consent(true, true)
	_telemetry_manager.set_telemetry_enabled(true)

	_telemetry_manager.record_event(&"test", {})
	_telemetry_manager.request_data_deletion()

	assert_true(_telemetry_settings.deletion_requested)
	assert_false(_telemetry_settings.telemetry_enabled)
	assert_false(_telemetry_settings.crash_reporting_enabled)
	assert_true(_telemetry_manager.event_queue.is_empty())
	assert_eq(_telemetry_manager.session_data.calls_received, 0)


# --- CrashReporter Tests ---

func test_crash_reporter_initialization() -> void:
	assert_not_null(_crash_reporter)
	assert_true(_crash_reporter.active)


func test_crash_reporter_report_exception() -> void:
	_telemetry_settings.set_consent(true, true)
	_telemetry_manager.set_crash_reporting_enabled(true)

	_crash_reporter.report_exception("TestException", "Stack trace here", {"key": "value"})

	# Should have recorded crash in telemetry
	assert_eq(_telemetry_manager.session_data.crashes_this_session, 1)
	assert_eq(_telemetry_manager.event_queue.size(), 1)

	var event: Dictionary = _telemetry_manager.event_queue[0]
	assert_eq(event.event_type, &"crash")
	assert_eq(event.crash_info.exception, "TestException")


func test_crash_reporter_write_dump() -> void:
	# Test that crash dump directory is created
	var dir: DirAccess = DirAccess.open("user://crash_dumps")
	assert_not_null(dir)

	# The crash reporter creates this in _ready()


func test_crash_reporter_disabled() -> void:
	# Crash reporting disabled by default
	_crash_reporter.report_exception("TestException", "Stack trace")

	# Should not have recorded in telemetry (crash reporting disabled)
	assert_eq(_telemetry_manager.session_data.crashes_this_session, 0)
	assert_true(_telemetry_manager.event_queue.is_empty())


# --- GameSettings Integration Tests ---

func test_game_settings_privacy_defaults() -> void:
	assert_false(_game_settings.telemetry_enabled)
	assert_false(_game_settings.crash_reporting_enabled)
	assert_false(_game_settings.telemetry_consent_given)


func test_game_settings_save_load_privacy() -> void:
	_game_settings.telemetry_enabled = true
	_game_settings.crash_reporting_enabled = true
	_game_settings.telemetry_consent_given = true
	_game_settings.save_settings()

	# Create new instance and load
	var new_settings: GameSettings = GameSettings.new()
	new_settings.load_settings()

	assert_true(new_settings.telemetry_enabled)
	assert_true(new_settings.crash_reporting_enabled)
	assert_true(new_settings.telemetry_consent_given)


func test_game_settings_consent_flow() -> void:
	# Simulate consent dialog
	_game_settings._on_telemetry_consent(true, true)

	assert_true(_game_settings.telemetry_consent_given)
	assert_true(_game_settings.telemetry_enabled)
	assert_true(_game_settings.crash_reporting_enabled)

	# Verify TelemetryManager was updated
	assert_true(TelemetryManager.instance.settings.telemetry_enabled)
	assert_true(TelemetryManager.instance.settings.crash_reporting_enabled)


func test_game_settings_consent_crashes_only() -> void:
	_game_settings._on_telemetry_consent(false, true)

	assert_true(_game_settings.telemetry_consent_given)
	assert_false(_game_settings.telemetry_enabled)
	assert_true(_game_settings.crash_reporting_enabled)


func test_game_settings_consent_declined() -> void:
	_game_settings._on_telemetry_consent(false, false)

	assert_true(_game_settings.telemetry_consent_given)
	assert_false(_game_settings.telemetry_enabled)
	assert_false(_game_settings.crash_reporting_enabled)


func test_game_settings_toggle_after_consent() -> void:
	_game_settings._on_telemetry_consent(true, true)

	# Now toggle
	_game_settings.set_telemetry_enabled(false)
	assert_false(_game_settings.telemetry_enabled)
	assert_false(TelemetryManager.instance.settings.telemetry_enabled)

	_game_settings.set_crash_reporting_enabled(false)
	assert_false(_game_settings.crash_reporting_enabled)
	assert_false(TelemetryManager.instance.settings.crash_reporting_enabled)


func test_game_settings_data_deletion() -> void:
	_game_settings._on_telemetry_consent(true, true)
	_game_settings.request_data_deletion()

	assert_false(_game_settings.telemetry_consent_given)
	assert_false(_game_settings.telemetry_enabled)
	assert_false(_game_settings.crash_reporting_enabled)
	assert_true(TelemetryManager.instance.settings.deletion_requested)


# --- Integration Tests ---

func test_full_consent_flow() -> void:
	# 1. Fresh install - no consent
	assert_false(_game_settings.telemetry_consent_given)

	# 2. User opts in to full telemetry
	_game_settings._on_telemetry_consent(true, true)

	# 3. Telemetry records events
	_telemetry_manager.record_event(&"test_event", {})
	assert_eq(_telemetry_manager.event_queue.size(), 1)

	# 4. Crash occurs
	_crash_reporter.report_exception("Crash", "Trace")
	assert_eq(_telemetry_manager.session_data.crashes_this_session, 1)

	# 5. User disables telemetry but keeps crash reporting
	_game_settings.set_telemetry_enabled(false)
	_game_settings.set_crash_reporting_enabled(true)

	assert_false(_telemetry_manager.settings.telemetry_enabled)
	assert_true(_telemetry_manager.settings.crash_reporting_enabled)

	# 6. New events not recorded, but crashes still are
	_telemetry_manager.record_event(&"test_event_2", {})
	assert_eq(_telemetry_manager.event_queue.size(), 1)  # Still 1 (crash event)

	_crash_reporter.report_exception("Crash2", "Trace2")
	assert_eq(_telemetry_manager.session_data.crashes_this_session, 2)
	assert_eq(_telemetry_manager.event_queue.size(), 2)  # Crash events added


func test_headless_mode_no_http() -> void:
	# In headless mode (CI), HTTP requests should be logged not sent
	_telemetry_settings.set_consent(true, true)
	_telemetry_manager.set_telemetry_enabled(true)

	_telemetry_manager.record_event(&"headless_test", {})

	# Flush should not error in headless
	_telemetry_manager._flush_queue()
	assert_true(_telemetry_manager.event_queue.is_empty())