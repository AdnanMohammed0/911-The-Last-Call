## Crash Reporter (P5-03).
## Captures unhandled exceptions and crashes, sends to backend if opted in.
## Uses Godot's error handling hooks + Steam crash reporting (when available).
## Authority: LOCAL
class_name CrashReporter
extends Node

## Singleton
static var instance: CrashReporter = null

## Whether crash reporter is active
var active: bool = false

## Crash dump directory
const CRASH_DUMP_DIR: String = "user://crash_dumps/"

## Max crash dumps to keep
const MAX_CRASH_DUMPS: int = 10


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Ensure crash dump directory exists
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null and not dir.dir_exists("crash_dumps"):
		dir.make_dir("crash_dumps")

	# Initialize crash handling
	_setup_crash_handling()

	# Clean old crash dumps
	_clean_old_dumps()

	print("[CrashReporter] Initialized")


func _setup_crash_handling() -> void:
	# Godot 4.x doesn't have a built-in unhandled exception hook in GDScript
	# We use the Error handler and rely on the OS signal handler for native crashes

	# Hook into Godot's error reporting (for script errors)
	# Note: This only catches GDScript errors, not engine/native crashes
	# For native crashes, we'd need a GDExtension or Steam's crash handler

	# Set up a custom error handler
	# In Godot 4, we can use the `OS.set_error_handler` if available
	# For now, we rely on manual reporting via TelemetryManager.record_crash()

	active = true


func _clean_old_dumps() -> void:
	var dir: DirAccess = DirAccess.open(CRASH_DUMP_DIR)
	if dir == null:
		return

	var files: PackedStringArray = dir.get_files()
	files.sort_custom(Callable(self, "_compare_file_time").bind(dir))

	while files.size() > MAX_CRASH_DUMPS:
		var old_file: String = files.pop_back()
		dir.remove("%s%s" % [CRASH_DUMP_DIR, old_file])


func _compare_file_time(a: String, b: String, dir: DirAccess) -> int:
	var time_a: int = dir.get_file_modified_time("%s%s" % [CRASH_DUMP_DIR, a])
	var time_b: int = dir.get_file_modified_time("%s%s" % [CRASH_DUMP_DIR, b])
	return time_a - time_b  # Oldest first


# --- Public API ---

## Manually report an exception (call from catch blocks or error handlers).
func report_exception(exception: String, stack_trace: String = "", context: Dictionary = {}) -> void:
	var crash_info: Dictionary = _build_crash_info(exception, stack_trace, context, false)
	_handle_crash(crash_info)


## Manually report a native crash (call from GDExtension/Steam crash handler).
func report_native_crash(crash_type: String, crash_data: Dictionary) -> void:
	var crash_info: Dictionary = {
		"type": "native_crash",
		"crash_type": crash_type,
		"data": crash_data,
		"timestamp": Time.get_unix_time_from_system(),
		"session_id": TelemetryManager.instance?.settings?.session_id ?? "unknown",
		"game_version": ProjectSettings.get_setting("application/config/version", "unknown"),
		"engine_version": Engine.get_version_info()["string"],
		"platform": OS.get_name(),
		"is_host": multiplayer.is_server() if multiplayer.multiplayer_peer != null else true,
	}
	_handle_crash(crash_info)


func _build_crash_info(exception: String, stack_trace: String, context: Dictionary, is_native: bool) -> Dictionary:
	return {
		"type": "script_exception" if not is_native else "native_crash",
		"exception": exception,
		"stack_trace": stack_trace,
		"context": context,
		"timestamp": Time.get_unix_time_from_system(),
		"session_id": TelemetryManager.instance?.settings?.session_id ?? "unknown",
		"game_version": ProjectSettings.get_setting("application/config/version", "unknown"),
		"engine_version": Engine.get_version_info()["string"],
		"platform": OS.get_name(),
		"is_host": multiplayer.is_server() if multiplayer.multiplayer_peer != null else true,
		"shift": GameState.day_number,
		"phase": GameState.Phase.keys()[GameState.phase].to_lower(),
		"public_trust": GameState.public_trust,
		"station_budget": GameState.station_budget,
		"cult_awareness": GameState.cult_awareness,
		"peer_count": NetManager.roster.size(),
		"active_call": CallDirector.active_call_id if CallDirector != null else "",
	}


func _handle_crash(crash_info: Dictionary) -> void:
	# Write crash dump to disk
	_write_crash_dump(crash_info)

	# Send to telemetry if opted in
	if TelemetryManager.instance != null:
		TelemetryManager.instance.record_crash(crash_info)

	# If Steam is available, use Steam's crash reporting
	if Engine.has_singleton("Steam"):
		_Steam_report_crash(crash_info)

	print("[CrashReporter] Crash recorded: %s" % crash_info.exception)


func _write_crash_dump(crash_info: Dictionary) -> void:
	var filename: String = "crash_%s_%s.json" % [
		Time.get_datetime_string_from_system(true).replace(":", "-").replace(".", "-"),
		str(randi() % 10000).pad_zeros(4)
	]
	var path: String = "%s%s" % [CRASH_DUMP_DIR, filename]

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(crash_info, "\t"))
		file.close()
		print("[CrashReporter] Crash dump written to: %s" % path)
	else:
		push_error("[CrashReporter] Failed to write crash dump to: %s" % path)


func _Steam_report_crash(crash_info: Dictionary) -> void:
	# Steamworks crash reporting integration (when Steamworks GDExtension is available)
	# This is a placeholder for P1-09 integration
	# Steam.setCrashCallback() or similar would be used
	print("[CrashReporter] Steam crash reporting not yet integrated (requires P1-09)")


## Get list of recent crash dumps (for debug menu).
static func get_crash_dumps() -> Array[Dictionary]:
	var dir: DirAccess = DirAccess.open(CRASH_DUMP_DIR)
	if dir == null:
		return []

	var files: PackedStringArray = dir.get_files()
	files.sort_custom(Callable(CrashReporter, "_compare_file_time_static").bind(dir))

	var dumps: Array[Dictionary] = []
	for file_name in files:
		if file_name.ends_with(".json"):
			var file: FileAccess = FileAccess.open("%s%s" % [CRASH_DUMP_DIR, file_name], FileAccess.READ)
			if file != null:
				var content: String = file.get_as_text()
				file.close()
				var data: Dictionary = JSON.parse_string(content)
				if data:
					dumps.append(data)
	return dumps


static func _compare_file_time_static(a: String, b: String, dir: DirAccess) -> int:
	var time_a: int = dir.get_file_modified_time("%s%s" % [CRASH_DUMP_DIR, a])
	var time_b: int = dir.get_file_modified_time("%s%s" % [CRASH_DUMP_DIR, b])
	return time_a - time_b


## Clear all crash dumps.
static func clear_crash_dumps() -> void:
	var dir: DirAccess = DirAccess.open(CRASH_DUMP_DIR)
	if dir == null:
		return
	var files: PackedStringArray = dir.get_files()
	for file_name in files:
		if file_name.ends_with(".json"):
			dir.remove("%s%s" % [CRASH_DUMP_DIR, file_name])


## Check if there are unsent crash dumps (for startup reporting).
static func has_unsent_crashes() -> bool:
	var dir: DirAccess = DirAccess.open(CRASH_DUMP_DIR)
	if dir == null:
		return false
	var files: PackedStringArray = dir.get_files()
	for file_name in files:
		if file_name.ends_with(".json") and file_name.contains("unsent"):
			return true
	return false