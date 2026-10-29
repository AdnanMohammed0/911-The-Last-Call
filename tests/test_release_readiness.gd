## P5-10 release readiness: the build identity and the player bug-report bundle.
## These are the parts of the release flow that can be asserted without Steam or a live Discord.
extends GutTest


# --- Build identity ------------------------------------------------------------------------------

func test_version_is_set_and_semver_shaped() -> void:
	var version: String = BuildInfo.version()
	assert_false(version.is_empty())
	var pattern: RegEx = RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z.-]+)?$")
	assert_not_null(pattern.search(version), "version '%s' is not semver-shaped" % version)


func test_channel_is_a_known_build_channel() -> void:
	assert_true(BuildInfo.channel() in ["dev", "rc", "demo", "release"])


func test_footer_label_names_the_version_and_channel() -> void:
	var label: String = BuildInfo.label()
	assert_true(label.contains(BuildInfo.version()))
	assert_true(label.contains(BuildInfo.channel().to_upper()))


# --- Bug report bundle ---------------------------------------------------------------------------

func test_report_keeps_the_description_and_build_identity() -> void:
	var report: Dictionary = BugReport.build("The door will not open", "Gameplay", false)
	assert_eq(str(report.get("description", "")), "The door will not open")
	var build: Dictionary = report.get("build", {})
	assert_eq(str(build.get("version", "")), BuildInfo.version())
	assert_false(report.has("diagnostics"), "diagnostics were not switched off")


func test_report_normalises_unknown_categories() -> void:
	var report: Dictionary = BugReport.build("something odd", "NotACategory", false)
	assert_eq(str(report.get("category", "")), "Other")


func test_diagnostics_are_anonymous_and_present_when_requested() -> void:
	var report: Dictionary = BugReport.build("Crash on load", "Crash", true)
	var diagnostics: Dictionary = report.get("diagnostics", {})
	assert_false(diagnostics.is_empty())
	assert_true(diagnostics.has("os"))
	assert_true(diagnostics.has("crash_dumps"))
	# The reporter must never carry the player's name or an address into a public Discord channel.
	assert_false(diagnostics.has("player_name"))
	assert_false(diagnostics.has("ip"))


func test_formatted_report_is_ready_to_paste() -> void:
	var report: Dictionary = BugReport.build("Crash on load", "Crash", true)
	var text: String = BugReport.format_text(report)
	assert_true(text.contains("Crash on load"))
	assert_true(text.contains(BuildInfo.version()))
	assert_true(text.contains("Diagnostics:"))


func test_saved_report_is_valid_json() -> void:
	var report: Dictionary = BugReport.build("Save round trip", "Other", false)
	var path: String = BugReport.save(report)
	assert_false(path.is_empty(), "report was not written")
	assert_true(FileAccess.file_exists(path))
	var content: String = FileAccess.get_file_as_string(path)
	assert_true(content.contains("\"description\": \"Save round trip\""))
	var dir: DirAccess = DirAccess.open(BugReport.REPORT_DIR)
	if dir != null:
		dir.remove(path.get_file())


# --- Reporter UI ---------------------------------------------------------------------------------

func test_bug_report_dialog_builds_and_closes() -> void:
	var dialog: BugReportDialog = BugReportDialog.new()
	add_child_autofree(dialog)
	assert_not_null(dialog._description)
	assert_true(dialog._include_diagnostics.button_pressed)
	watch_signals(dialog)
	dialog.close()
	assert_signal_emitted(dialog, "closed")
