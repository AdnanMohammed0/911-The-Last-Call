## Player-submitted bug report (P5-10).
## Builds one JSON document with the player's description plus anonymous diagnostics (build, hardware,
## session state, crash-dump count), copies a readable version to the clipboard and keeps a local copy
## under `user://bug_reports/` so a player can attach it even if the clipboard is lost.
##
## Deliberately excluded: player name, IP addresses, voice audio, call recordings and the settings file.
## Authority: LOCAL
class_name BugReport
extends RefCounted

const SCHEMA_VERSION: int = 1
const REPORT_DIR: String = "user://bug_reports/"
const MAX_REPORTS: int = 20
const CATEGORIES: Array[String] = ["Gameplay", "Crash", "Performance", "Audio", "Multiplayer", "Other"]


## Build a report dictionary. `include_diagnostics` is the player's privacy switch; when it is false
## only the description, category and build identity are kept.
static func build(description: String, category: String = "Gameplay", include_diagnostics: bool = true,
		extra: Dictionary = {}) -> Dictionary:
	var chosen: String = category if CATEGORIES.has(category) else "Other"
	var report: Dictionary = {
		"schema": SCHEMA_VERSION,
		"created_at": Time.get_datetime_string_from_system(true),
		"description": description.strip_edges(),
		"category": chosen,
		"build": BuildInfo.as_dict(),
		"extra": extra,
	}
	if include_diagnostics:
		report["diagnostics"] = collect_diagnostics()
	return report


## Anonymous system + session snapshot. Everything here is either constant hardware/engine metadata or
## a game-state counter; no identifiers that point back to a person.
static func collect_diagnostics() -> Dictionary:
	var version_info: Dictionary = Engine.get_version_info()
	return {
		"engine": str(version_info.get("string", "")),
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"processor": OS.get_processor_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus")),
		"display_server": DisplayServer.get_name(),
		"locale": TranslationServer.get_locale(),
		"is_host": NetManager.is_host(),
		"players": NetManager.roster.size(),
		"shift": MissionDirector.shift_number,
		"phase": str(GameState.phase_name(GameState.phase)),
		"public_trust": GameState.public_trust,
		"station_budget": GameState.station_budget,
		"cult_awareness": GameState.cult_awareness,
		"active_call": str(CallDirector.active_call_id),
		"crash_dumps": CrashReporter.get_crash_dumps().size(),
	}


## Human-readable block for Discord / GitHub. Kept in English so the whole team can triage it.
static func format_text(report: Dictionary) -> String:
	var build: Dictionary = report.get("build", {})
	var diagnostics: Dictionary = report.get("diagnostics", {})
	var lines: PackedStringArray = PackedStringArray()
	lines.append("911: The Last Call — bug report")
	lines.append("Build: %s (%s)" % [str(build.get("version", "unknown")), str(build.get("channel", "unknown"))])
	lines.append("Created: %s" % str(report.get("created_at", "unknown")))
	lines.append("Category: %s" % str(report.get("category", "Other")))
	lines.append("")
	lines.append("What happened:")
	lines.append(str(report.get("description", "")).strip_edges())
	if not diagnostics.is_empty():
		lines.append("")
		lines.append("Diagnostics:")
		lines.append("Platform: %s %s · %s" % [
			str(diagnostics.get("os", "")), str(diagnostics.get("os_version", "")),
			str(diagnostics.get("display_server", ""))])
		lines.append("GPU: %s (%s)" % [
			str(diagnostics.get("gpu", "")), str(diagnostics.get("gpu_vendor", ""))])
		lines.append("CPU: %s" % str(diagnostics.get("processor", "")))
		lines.append("Locale: %s · renderer: %s" % [
			str(diagnostics.get("locale", "")), str(diagnostics.get("renderer", ""))])
		lines.append("Session: %s · %d player(s) · shift %d · %s" % [
			"host" if _as_bool(diagnostics.get("is_host", false)) else "client",
			_as_int(diagnostics.get("players", 1)), _as_int(diagnostics.get("shift", 1)),
			str(diagnostics.get("phase", ""))])
		lines.append("Meters: trust %d · budget %d · cult %d · call %s" % [
			_as_int(diagnostics.get("public_trust", 0)), _as_int(diagnostics.get("station_budget", 0)),
			_as_int(diagnostics.get("cult_awareness", 0)), str(diagnostics.get("active_call", ""))])
		lines.append("Crash dumps on disk: %d" % _as_int(diagnostics.get("crash_dumps", 0)))
	return "\n".join(lines)


## Variant helpers that survive the project's unsafe-cast warnings-as-errors setting.
static func _as_int(value: Variant) -> int:
	return int(str(value))


static func _as_bool(value: Variant) -> bool:
	return str(value).to_lower() == "true"


## Write the report as JSON and return its path, or `""` when the disk write failed.
static func save(report: Dictionary) -> String:
	if not _ensure_dir():
		return ""
	_prune()
	var stamp: String = Time.get_datetime_string_from_system(true).replace(":", "-").replace(".", "-")
	var path: String = "%sbug_%s_%04d.json" % [REPORT_DIR, stamp, randi() % 10000]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	return path


static func _ensure_dir() -> bool:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return false
	if dir.dir_exists("bug_reports"):
		return true
	return dir.make_dir("bug_reports") == OK


static func _prune() -> void:
	var dir: DirAccess = DirAccess.open(REPORT_DIR)
	if dir == null:
		return
	var names: Array[String] = []
	for name: String in dir.get_files():
		if name.ends_with(".json"):
			names.append(name)
	if names.size() < MAX_REPORTS:
		return
	names.sort_custom(func(a: String, b: String) -> bool:
		return FileAccess.get_modified_time(REPORT_DIR + a) < FileAccess.get_modified_time(REPORT_DIR + b))
	while names.size() >= MAX_REPORTS:
		var oldest: String = names.pop_front()
		dir.remove(oldest)
