## In-game bug reporter (P5-10).
## The player writes what happened, optionally includes anonymous diagnostics, and gets a report on the
## clipboard ready to paste into Discord or the GitHub issue form. A copy is also written to
## `user://bug_reports/` so it survives a crash or a closed clipboard.
## Authority: LOCAL
class_name BugReportDialog
extends Control

signal closed()

var _description: TextEdit
var _category: OptionButton
var _include_diagnostics: CheckBox
var _status: Label
var _copy_button: KitButton


## Opens the dialog on top of `parent` (own CanvasLayer, like the settings menu).
static func open_over(parent: Node) -> BugReportDialog:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	parent.add_child(layer)
	var dialog: BugReportDialog = BugReportDialog.new()
	layer.add_child(dialog)
	dialog.closed.connect(layer.queue_free)
	return dialog


func _ready() -> void:
	add_to_group(DispatchTerminal.MODAL_GROUP)
	theme = GameSettings.ui_theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_description.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.012, 0.015, 0.022)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var blur: ShaderMaterial = ShaderMaterial.new()
	blur.shader = UiKit.ACRYLIC
	blur.set_shader_parameter(&"blur_lod", 4.0)
	blur.set_shader_parameter(&"tint_amount", 0.72)
	dim.material = blur
	add_child(dim)

	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel: PanelContainer = UiKit.glass(Color(0.03, 0.034, 0.044), 16, 36, 30, 0.86, 4.0)
	panel.custom_minimum_size = Vector2(780, 0)
	centre.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	panel.add_child(box)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 16)
	box.add_child(header)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.add_theme_constant_override(&"separation", -2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(UiKit.caps(tr("Support"), 11, GameTheme.ACCENT))
	titles.add_child(UiKit.label(tr("Report a bug"), 34, GameTheme.TEXT, &"black_italic"))
	var close_button: KitButton = KitButton.make("", &"close", KitButton.Variant.GHOST, close)
	close_button.custom_minimum_size = Vector2(44, 44)
	header.add_child(close_button)

	box.add_child(UiKit.paragraph(tr("Send a report to the team. Diagnostic details never include your name or IP address."), 15))
	box.add_child(UiKit.separator())

	var category_row: HBoxContainer = HBoxContainer.new()
	category_row.add_theme_constant_override(&"separation", 14)
	box.add_child(category_row)
	category_row.add_child(UiKit.caps(tr("Category"), 11, GameTheme.TEXT_DIM))
	_category = OptionButton.new()
	_category.custom_minimum_size = Vector2(240, 42)
	for category: String in BugReport.CATEGORIES:
		_category.add_item(tr(category))
	category_row.add_child(_category)

	box.add_child(UiKit.caps(tr("What did you expect to happen?"), 11, GameTheme.TEXT_DIM))
	_description = TextEdit.new()
	_description.custom_minimum_size = Vector2(0, 150)
	_description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_description.placeholder_text = tr("Describe the problem, what you were doing, and whether it repeats.")
	_description.add_theme_font_size_override(&"font_size", 16)
	box.add_child(_description)

	_include_diagnostics = CheckBox.new()
	_include_diagnostics.text = tr("Include diagnostics")
	_include_diagnostics.tooltip_text = tr("Diagnostics (build, hardware, session state, crash dump count)")
	_include_diagnostics.button_pressed = true
	box.add_child(_include_diagnostics)

	_status = UiKit.paragraph("", 13, GameTheme.TEXT_FAINT)
	_status.custom_minimum_size = Vector2(0, 34)
	box.add_child(_status)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 10)
	box.add_child(actions)
	_copy_button = KitButton.make(tr("Copy report"), &"copy", KitButton.Variant.PRIMARY, _on_copy)
	_copy_button.custom_minimum_size = Vector2(180, 46)
	actions.add_child(_copy_button)
	var issue: KitButton = KitButton.make(tr("Open GitHub issue"), &"file", KitButton.Variant.SUBTLE, _on_github)
	issue.custom_minimum_size = Vector2(0, 46)
	actions.add_child(issue)
	if BuildInfo.has_discord_invite():
		var discord: KitButton = KitButton.make(tr("Open Discord"), &"link", KitButton.Variant.SUBTLE, _on_discord)
		discord.custom_minimum_size = Vector2(0, 46)
		actions.add_child(discord)
	actions.add_child(UiKit.expand(Control.new()))
	var close_action: KitButton = KitButton.make(tr("Close"), &"back", KitButton.Variant.GHOST, close)
	close_action.custom_minimum_size = Vector2(0, 46)
	actions.add_child(close_action)


func _collect() -> Dictionary:
	var selected: String = _category.get_item_text(_category.selected)
	return BugReport.build(_description.text, selected, _include_diagnostics.button_pressed)


## Saves and copies the report. Returns false when the player has not written anything yet.
func _copy_report() -> bool:
	if _description.text.strip_edges().is_empty():
		_status.text = tr("Add a short description before sending.")
		_description.grab_focus()
		return false
	var report: Dictionary = _collect()
	var path: String = BugReport.save(report)
	DisplayServer.clipboard_set(BugReport.format_text(report))
	if path.is_empty():
		_status.text = tr("Could not save the report to disk. The report was still copied.")
	else:
		_status.text = tr("Report copied. Paste it into Discord or the GitHub issue.")
	return true


func _on_copy() -> void:
	_copy_report()


func _on_github() -> void:
	if not _copy_report():
		return
	var error: Error = OS.shell_open(BuildInfo.GITHUB_ISSUES_URL)
	if error != OK:
		_status.text = tr("GitHub issue could not be opened.")


func _on_discord() -> void:
	if not _copy_report():
		return
	var error: Error = OS.shell_open(BuildInfo.DISCORD_INVITE_URL)
	if error != OK:
		_status.text = tr("Discord could not be opened.")


func close() -> void:
	visible = false
	closed.emit()
