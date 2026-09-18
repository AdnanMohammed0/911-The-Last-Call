## Telemetry Manager (P5-03).
## Collects anonymous KPIs and sends them to backend (or logs locally).
## Only runs if user has opted in via TelemetrySettings.
## Authority: LOCAL
class_name TelemetryManager
extends Node

## Singleton
static var instance: TelemetryManager = null

## Settings resource
@export var settings: TelemetrySettings

## Current session data (in-memory only)
var session_data: Dictionary = {
	"session_id": "",
	"start_time": 0,
	"shift_number": 0,
	"phase": "",
	"calls_received": 0,
	"calls_classified": 0,
	"calls_correct": 0,
	"calls_missed": 0,
	"missions_started": 0,
	"missions_completed": 0,
	"missions_failed": 0,
	"players_joined": 0,
	"players_max": 1,
	"ending_reached": "",
	"public_trust_final": 0,
	"station_budget_final": 0,
	"cult_awareness_final": 0,
	"traits_gained": [],
	"traits_cured": [],
	"total_playtime_seconds": 0,
	"crashes_this_session": 0,
	"errors_logged": 0,
}

## Queue of events to send (batched)
var event_queue: Array[Dictionary] = []

## HTTP request for sending (if using REST endpoint)
var _http_request: HTTPRequest = null

## Batch send timer
var _batch_timer: Timer = null

## Backend endpoint (configure for production)
const TELEMETRY_ENDPOINT: String = "https://telemetry.911lastcall.example/v1/events"  # Replace with real endpoint
const BATCH_INTERVAL_SEC: float = 30.0
const MAX_BATCH_SIZE: int = 50
const MAX_QUEUE_SIZE: int = 500


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Load settings
	if settings == null:
		settings = TelemetrySettings.new()
	_load_settings()

	# Initialize session
	_init_session()

	# Set up HTTP request
	_http_request = HTTPRequest.new()
	_http_request.use_threads = true
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)

	# Batch timer
	_batch_timer = Timer.new()
	_batch_timer.wait_time = BATCH_INTERVAL_SEC
	_batch_timer.one_shot = false
	_batch_timer.timeout.connect(_flush_queue)
	add_child(_batch_timer)

	# Start batch timer if telemetry enabled
	if settings.telemetry_enabled:
		_batch_timer.start()

	# Listen for game events
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.call_received.connect(_on_call_received)
	EventBus.call_classified.connect(_on_call_classified)
	EventBus.vote_finished.connect(_on_vote_finished)

	# Listen for GameState changes
	GameState.day_number_changed.connect(_on_day_changed)
	GameState.phase_changed.connect(_on_game_state_phase_changed)

	print("[TelemetryManager] Initialized. Telemetry enabled: ", settings.telemetry_enabled)


func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var path: String = "user://telemetry.cfg"
	if config.load(path) == OK:
		settings.has_consented = config.get_value("consent", "has_consented", false)
		settings.telemetry_enabled = config.get_value("consent", "telemetry_enabled", false)
		settings.crash_reporting_enabled = config.get_value("consent", "crash_reporting_enabled", false)
		settings.consent_timestamp = config.get_value("consent", "consent_timestamp", "")
		settings.consent_version = config.get_value("consent", "consent_version", "")
		settings.deletion_requested = config.get_value("consent", "deletion_requested", false)


func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("consent", "has_consented", settings.has_consented)
	config.set_value("consent", "telemetry_enabled", settings.telemetry_enabled)
	config.set_value("consent", "crash_reporting_enabled", settings.crash_reporting_enabled)
	config.set_value("consent", "consent_timestamp", settings.consent_timestamp)
	config.set_value("consent", "consent_version", settings.consent_version)
	config.set_value("consent", "deletion_requested", settings.deletion_requested)
	config.save("user://telemetry.cfg")


func _init_session() -> void:
	session_data.session_id = _generate_session_id()
	settings.session_id = session_data.session_id
	session_data.start_time = Time.get_unix_time_from_system()
	session_data.shift_number = GameState.day_number
	session_data.phase = GameState.Phase.keys()[GameState.phase].to_lower()
	session_data.players_max = NetManager.roster.size()


func _generate_session_id() -> String:
	# Anonymous session ID: timestamp + random suffix (no personal data)
	var timestamp: String = Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "").replace("T", "").replace(".", "")
	var random_suffix: String = ""
	for i in range(8):
		random_suffix += str(randi() % 16).to_upper()
	return "%s_%s" % [timestamp, random_suffix]


# --- Public API ---

## Record a custom telemetry event (if opted in).
func record_event(event_type: StringName, payload: Dictionary = {}) -> void:
	if not settings.telemetry_enabled:
		return

	var event: Dictionary = {
		"event_type": event_type,
		"timestamp": Time.get_unix_time_from_system(),
		"session_id": session_data.session_id,
		"shift": GameState.day_number,
		"phase": GameState.Phase.keys()[GameState.phase].to_lower(),
		"payload": payload,
		"game_version": ProjectSettings.get_setting("application/config/version", "unknown"),
		"engine_version": Engine.get_version_info()["string"],
		"platform": OS.get_name(),
		"is_host": multiplayer.is_server() if multiplayer.multiplayer_peer != null else true,
		"peer_count": NetManager.roster.size(),
	}

	_enqueue_event(event)


## Record a KPI metric (numeric value).
func record_metric(metric_name: StringName, value: float, tags: Dictionary = {}) -> void:
	if not settings.telemetry_enabled:
		return

	var event: Dictionary = {
		"event_type": &"metric",
		"metric_name": metric_name,
		"value": value,
		"tags": tags,
		"timestamp": Time.get_unix_time_from_system(),
		"session_id": session_data.session_id,
		"shift": GameState.day_number,
		"game_version": ProjectSettings.get_setting("application/config/version", "unknown"),
	}

	_enqueue_event(event)


## Record an error (non-crash) for debugging.
func record_error(error_type: String, message: String, context: Dictionary = {}) -> void:
	if not settings.telemetry_enabled and not settings.crash_reporting_enabled:
		return

	session_data.errors_logged += 1

	var event: Dictionary = {
		"event_type": &"error",
		"error_type": error_type,
		"message": message,
		"context": context,
		"timestamp": Time.get_unix_time_from_system(),
		"session_id": session_data.session_id,
		"game_version": ProjectSettings.get_setting("application/config/version", "unknown"),
	}

	_enqueue_event(event, priority: true)


## Called when a crash is caught (from CrashReporter).
func record_crash(crash_info: Dictionary) -> void:
	if not settings.crash_reporting_enabled:
		return

	session_data.crashes_this_session += 1

	var event: Dictionary = {
		"event_type": &"crash",
		"crash_info": crash_info,
		"timestamp": Time.get_unix_time_from_system(),
		"session_id": session_data.session_id,
		"shift": GameState.day_number,
		"phase": GameState.Phase.keys()[GameState.phase].to_lower(),
		"game_version": ProjectSettings.get_setting("application/config/version", "unknown"),
		"engine_version": Engine.get_version_info()["string"],
		"platform": OS.get_name(),
	}

	_enqueue_event(event, priority: true)
	_flush_queue()  # Send immediately for crashes


## Enable/disable telemetry at runtime (respects user consent).
func set_telemetry_enabled(enabled: bool) -> void:
	if not settings.has_consented:
		push_warning("TelemetryManager: Cannot enable telemetry without user consent")
		return

	settings.telemetry_enabled = enabled
	_save_settings()

	if enabled:
		_batch_timer.start()
	else:
		_batch_timer.stop()
		_flush_queue()  # Send any remaining events


## Enable/disable crash reporting.
func set_crash_reporting_enabled(enabled: bool) -> void:
	if not settings.has_consented:
		push_warning("TelemetryManager: Cannot enable crash reporting without user consent")
		return

	settings.crash_reporting_enabled = enabled
	_save_settings()


## Request data deletion (GDPR).
func request_data_deletion() -> void:
	settings.request_deletion()
	settings.telemetry_enabled = false
	settings.crash_reporting_enabled = false
	_save_settings()
	_clear_local_data()
	# In production: send deletion request to backend


func _clear_local_data() -> void:
	event_queue.clear()
	session_data = {
		"session_id": "",
		"start_time": 0,
		"shift_number": 0,
		"phase": "",
		"calls_received": 0,
		"calls_classified": 0,
		"calls_correct": 0,
		"calls_missed": 0,
		"missions_started": 0,
		"missions_completed": 0,
		"missions_failed": 0,
		"players_joined": 0,
		"players_max": 1,
		"ending_reached": "",
		"public_trust_final": 0,
		"station_budget_final": 0,
		"cult_awareness_final": 0,
		"traits_gained": [],
		"traits_cured": [],
		"total_playtime_seconds": 0,
		"crashes_this_session": 0,
		"errors_logged": 0,
	}
	_init_session()


# --- Event Queue Management ---

func _enqueue_event(event: Dictionary, priority: bool = false) -> void:
	if event_queue.size() >= MAX_QUEUE_SIZE:
		# Drop oldest non-priority event
		for i in range(event_queue.size()):
			if not event_queue[i].get("priority", false):
				event_queue.remove_at(i)
				break
		else:
			return  # Queue full of priority events, drop this one

	event.priority = priority
	event_queue.append(event)

	# Flush immediately for priority events
	if priority:
		_flush_queue()


func _flush_queue() -> void:
	if event_queue.is_empty():
		return
	if not settings.telemetry_enabled and not settings.crash_reporting_enabled:
		return

	# Separate priority and normal events
	var priority_events: Array[Dictionary] = []
	var normal_events: Array[Dictionary] = []

	for event in event_queue:
		if event.get("priority", false):
			priority_events.append(event)
		else:
			normal_events.append(event)

	# Send priority first
	if not priority_events.is_empty():
		_send_batch(priority_events)

	# Send normal in batches
	for i in range(0, normal_events.size(), MAX_BATCH_SIZE):
		var batch: Array[Dictionary] = normal_events.slice(i, i + MAX_BATCH_SIZE)
		_send_batch(batch)

	event_queue.clear()


func _send_batch(events: Array[Dictionary]) -> void:
	if events.is_empty():
		return

	# In headless/CI mode, just log
	if DisplayServer.get_name() == "headless" or OS.has_feature("editor"):
		print("[Telemetry] Would send %d events (headless/editor mode)" % events.size())
		for event in events:
			print("  - %s: %s" % [event.event_type, JSON.stringify(event)])
		return

	# Prepare request
	var payload: Dictionary = {
		"events": events,
		"client_info": {
			"game_version": ProjectSettings.get_setting("application/config/version", "unknown"),
			"engine_version": Engine.get_version_info()["string"],
			"platform": OS.get_name(),
		}
	}

	var json_string: String = JSON.stringify(payload)
	var headers: PackedStringArray = ["Content-Type: application/json"]

	# Add auth header if Steam is available (for Steam builds)
	if Engine.has_singleton("Steam"):
		# Steamworks integration would go here (P1-09)
		pass

	_http_request.request(TELEMETRY_ENDPOINT, headers, HTTPClient.METHOD_POST, json_string)


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("[Telemetry] Request failed: %d" % result)
		return
	if response_code < 200 or response_code >= 300:
		push_warning("[Telemetry] Server returned %d: %s" % [response_code, body.get_string_from_utf8()])
		return
	# Success - events sent


# --- Game Event Handlers ---

func _on_phase_changed(new_phase: StringName) -> void:
	session_data.phase = String(new_phase).to_lower()
	record_event(&"phase_changed", {"phase": String(new_phase)})


func _on_game_state_phase_changed(new_phase: int) -> void:
	# This is the integer phase from GameState
	var phase_name: String = GameState.Phase.keys()[new_phase].to_lower()
	session_data.phase = phase_name


func _on_call_received(call_id: StringName) -> void:
	session_data.calls_received += 1
	record_event(&"call_received", {"call_id": String(call_id)})


func _on_call_classified(call_id: StringName, verdict: StringName) -> void:
	session_data.calls_classified += 1
	# Note: correctness would need to be determined by CallDirector
	record_event(&"call_classified", {"call_id": String(call_id), "verdict": String(verdict)})


func _on_vote_finished(topic: StringName, result: Variant) -> void:
	record_event(&"vote_finished", {"topic": String(topic), "result": result})


func _on_day_changed(new_day: int) -> void:
	session_data.shift_number = new_day


# --- Session Lifecycle ---

## Call when shift ends (aftermath) to record shift summary.
func record_shift_summary() -> void:
	session_data.total_playtime_seconds = Time.get_unix_time_from_system() - session_data.start_time
	session_data.public_trust_final = GameState.public_trust
	session_data.station_budget_final = GameState.station_budget
	session_data.cult_awareness_final = GameState.cult_awareness

	record_event(&"shift_summary", session_data.duplicate())


## Call when ending is reached.
func record_ending(ending_id: StringName) -> void:
	session_data.ending_reached = String(ending_id)
	record_event(&"ending_reached", {"ending": String(ending_id), "shift_summary": session_data.duplicate()})


## Call when a trait is gained/lost.
func record_trait_change(trait_id: StringName, gained: bool) -> void:
	if gained:
		session_data.traits_gained.append(String(trait_id))
		record_event(&"trait_gained", {"trait": String(trait_id)})
	else:
		session_data.traits_cured.append(String(trait_id))
		record_event(&"trait_cured", {"trait": String(trait_id)})


## Call when mission starts/completes/fails.
func record_mission_start(mission_id: StringName) -> void:
	session_data.missions_started += 1
	record_event(&"mission_started", {"mission": String(mission_id)})


func record_mission_complete(mission_id: StringName, success: bool, details: Dictionary = {}) -> void:
	if success:
		session_data.missions_completed += 1
	else:
		session_data.missions_failed += 1
	record_event(&"mission_complete", {"mission": String(mission_id), "success": success, "details": details})


func record_player_joined() -> void:
	session_data.players_joined += 1
	session_data.players_max = max(session_data.players_max, NetManager.roster.size())


# --- Cleanup ---

func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_PREDELETE or what == Node.NOTIFICATION_WM_QUIT_REQUEST:
		_on_game_quit()


func _on_game_quit() -> void:
	# Final flush on quit
	if settings.telemetry_enabled or settings.crash_reporting_enabled:
		session_data.total_playtime_seconds = Time.get_unix_time_from_system() - session_data.start_time
		record_event(&"session_end", session_data.duplicate())
		_flush_queue()
		# Give HTTP request time to complete (blocking not possible in Godot, but we try)
		var start_time: int = Time.get_ticks_msec()
		while _http_request.get_http_client_status() == HTTPClient.STATUS_REQUESTING:
			if Time.get_ticks_msec() - start_time > 2000:  # Max 2 seconds
				break
			OS.delay_msec(10)