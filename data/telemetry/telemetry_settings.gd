## Telemetry Settings Resource (P5-03).
## User preferences for crash reporting and telemetry opt-in.
## Authority: LOCAL (saved to user://telemetry.cfg)
class_name TelemetrySettings
extends Resource

## Whether user has explicitly made a choice (opt-in or opt-out)
@export var has_consented: bool = false

## Whether user opted IN to anonymous telemetry (KPIs)
@export var telemetry_enabled: bool = false

## Whether user opted IN to crash reporting (includes stack traces, system info)
@export var crash_reporting_enabled: bool = false

## Timestamp of when consent was given/changed (ISO 8601)
@export var consent_timestamp: String = ""

## Unique anonymous session ID (generated per game session, not persisted)
@export var session_id: String = ""

## Game version when consent was given (for migration tracking)
@export var consent_version: String = ""

## GDPR: User can request data deletion
@export var deletion_requested: bool = false


func validate() -> Dictionary:
	var errors: PackedStringArray = []
	var warnings: PackedStringArray = []

	if has_consented and consent_timestamp.is_empty():
		warnings.append("has_consented is true but consent_timestamp is empty")
	if has_consented and consent_version.is_empty():
		warnings.append("has_consented is true but consent_version is empty")
	if telemetry_enabled and not has_consented:
		errors.append("telemetry_enabled requires has_consented = true")
	if crash_reporting_enabled and not has_consented:
		errors.append("crash_reporting_enabled requires has_consented = true")

	return {"errors": errors, "warnings": warnings}


func set_consent(enabled: bool, include_crashes: bool = true) -> void:
	has_consented = true
	telemetry_enabled = enabled
	crash_reporting_enabled = include_crashes
	consent_timestamp = Time.get_datetime_string_from_system(true)  # UTC
	consent_version = ProjectSettings.get_setting("application/config/version", "unknown")
	# session_id is generated per session, not saved


func request_deletion() -> void:
	deletion_requested = true
	telemetry_enabled = false
	crash_reporting_enabled = false