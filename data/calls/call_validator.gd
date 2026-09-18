## Checks authored CallData resources before they reach the game (P2-01).
## Use it from code (`CallValidator.validate(call)`), from GUT tests, or from the command line:
##   godot --headless --path . -s res://tools/validate_calls.gd
## Each result is {"errors": PackedStringArray, "warnings": PackedStringArray}.
## Authority: LOCAL (editor / CI tool, never runs during a match)
class_name CallValidator
extends RefCounted

const CALLS_DIR: String = "res://data/calls"
const SHIFT_MINUTES: int = 360     # 00:00 -> 06:00


## True when the call has a written conversation (drafts with an empty graph are skipped by the shift).
static func is_playable(call: CallData) -> bool:
	return call != null and call.dialogue != null and not call.dialogue.nodes.is_empty()


## Validates one call. Errors = the call is broken; warnings = worth a second look.
static func validate(call: CallData) -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	var warnings: PackedStringArray = PackedStringArray()
	if call == null:
		errors.append("resource is not a CallData")
		return {"errors": errors, "warnings": warnings}

	# 1) Identity
	if call.id == &"":
		errors.append("id is empty")
	elif not String(call.id).begins_with("call_"):
		warnings.append("id '%s' should start with 'call_'" % call.id)
	if call.title.strip_edges().is_empty():
		warnings.append("title is empty")

	# 2) Timing (GAMEPLAY_MECHANICS §5.5)
	if call.earliest_minute < 0 or call.earliest_minute >= SHIFT_MINUTES:
		errors.append("earliest_minute %d is outside the shift (0..%d)" % [call.earliest_minute, SHIFT_MINUTES - 1])
	if call.ring_timeout_seconds <= 0.0:
		errors.append("ring_timeout_seconds must be > 0")
	if call.patience_seconds <= 0.0:
		errors.append("patience_seconds must be > 0")
	elif call.patience_seconds < 60.0 or call.patience_seconds > 300.0:
		warnings.append("patience_seconds %.0f is outside the usual 60..300 s" % call.patience_seconds)

	# 3) Dialogue graph (P2-02)
	if call.dialogue == null:
		errors.append("dialogue graph is missing")
	elif call.dialogue.nodes.is_empty():
		warnings.append("draft: the dialogue has no nodes yet (the shift will not schedule this call)")
	else:
		var graph_result: Dictionary = call.dialogue.validate()
		var graph_errors: PackedStringArray = graph_result["errors"]
		var graph_warnings: PackedStringArray = graph_result["warnings"]
		for message: String in graph_errors:
			errors.append("dialogue: " + message)
		for message: String in graph_warnings:
			warnings.append("dialogue: " + message)

	# 4) Voice Stress Analyzer profile (§5.3)
	if call.stress_profile == null:
		warnings.append("stress_profile is missing (the VSA will show nothing)")
	else:
		var profile: StressProfile = call.stress_profile
		if profile.tremor_curve == null:
			warnings.append("stress_profile.tremor_curve is missing")
		for segment: Vector2 in profile.loop_segments:
			if segment.x < 0.0 or segment.y <= segment.x:
				errors.append("stress_profile loop segment %s must have 0 <= start < end" % segment)
		if profile.baseline_heart_rate < 30 or profile.baseline_heart_rate > 220:
			errors.append("stress_profile.baseline_heart_rate %d is not a human pulse" % profile.baseline_heart_rate)
		if call.truth == CallData.Truth.PARANORMAL and profile.emf_frequency <= 0.0:
			warnings.append("PARANORMAL call without emf_frequency (no Dead Frequency tell)")

	# 5) Police records (§5.2)
	var record_ids: Dictionary[StringName, bool] = {}
	for i: int in call.records.size():
		var record: RecordEntry = call.records[i]
		if record == null:
			errors.append("records[%d] is empty (null)" % i)
			continue
		if record.id == &"":
			errors.append("records[%d] has no id" % i)
		elif record_ids.has(record.id):
			errors.append("duplicate record id '%s'" % record.id)
		else:
			record_ids[record.id] = true
		if record.content.strip_edges().is_empty():
			warnings.append("record '%s' has no content" % record.id)

	# 6) A deceptive call must leave players at least one clue to find the truth.
	if call.truth != CallData.Truth.GENUINE and call.stress_profile != null \
			and call.stress_profile.loop_segments.is_empty() and call.stress_profile.background_tags.is_empty() \
			and call.stress_profile.emf_frequency <= 0.0 and call.records.is_empty():
		warnings.append("truth is %s but there is no clue (no loops, background tags, EMF or records)" % CallData.Truth.keys()[call.truth])

	return {"errors": errors, "warnings": warnings}


## Validates every CallData .tres under `dir` (recursive). Returns path -> result.
static func validate_directory(dir: String = CALLS_DIR) -> Dictionary:
	var results: Dictionary = {}
	var seen_ids: Dictionary[StringName, String] = {}
	for path: String in _find_resources(dir):
		var call: CallData = load(path) as CallData
		if call == null:
			continue  # other resource types (records, profiles) can live next to calls
		var result: Dictionary = validate(call)
		if call.id != &"" and seen_ids.has(call.id):
			var errors: PackedStringArray = result["errors"]
			errors.append("id '%s' is also used by %s" % [call.id, seen_ids[call.id]])
			result["errors"] = errors
		seen_ids[call.id] = path
		results[path] = result
	return results


## Human readable report. Totals are written into `counts` ({"errors": int, "warnings": int}).
static func format_report(results: Dictionary, counts: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var error_total: int = 0
	var warning_total: int = 0
	for path: String in results:
		var result: Dictionary = results[path]
		var errors: PackedStringArray = result["errors"]
		var warnings: PackedStringArray = result["warnings"]
		error_total += errors.size()
		warning_total += warnings.size()
		lines.append("%s %s" % ["FAIL" if not errors.is_empty() else "OK  ", path])
		for message: String in errors:
			lines.append("    error:   " + message)
		for message: String in warnings:
			lines.append("    warning: " + message)
	lines.append("%d call(s), %d error(s), %d warning(s)" % [results.size(), error_total, warning_total])
	counts["errors"] = error_total
	counts["warnings"] = warning_total
	return "\n".join(lines)


static func _find_resources(dir: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var access: DirAccess = DirAccess.open(dir)
	if access == null:
		return found
	for sub: String in access.get_directories():
		found.append_array(_find_resources(dir.path_join(sub)))
	for file: String in access.get_files():
		var clean: String = file.trim_suffix(".remap")
		if clean.ends_with(".tres") or clean.ends_with(".res"):
			found.append(dir.path_join(clean))
	return found
