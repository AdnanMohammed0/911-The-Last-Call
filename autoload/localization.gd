## Localization pipeline (P5-06): registers the English and Arabic string tables with Godot's
## TranslationServer, applies the saved language, and flips the whole UI between LTR and RTL.
## The English source string is the translation key, so existing `text = "..."` scene properties are
## auto-translated and `tr("...")` calls in code work without touching a single scene.
## Authority: LOCAL
extends Node

## Emitted after the active language changed, so open menus can rebuild their labels.
signal language_changed(locale: String)

## Supported languages, in the order the settings menu lists them.
const SUPPORTED_LOCALES: Array[String] = ["en", "ar"]
const DEFAULT_LOCALE: String = "en"
## Languages written right-to-left. Drives the root window's layout direction.
const RTL_LOCALES: Array[String] = ["ar"]
## Each language is written in its own script, so an Arabic player never has to read English labels.
const LOCALE_LABELS: Dictionary[String, String] = {
	"en": "English",
	"ar": "العربية",
}
const TABLE_DIR: String = "res://data/localization"
## Godot's built-in font has no Arabic glyphs, so Arabic needs its own font to avoid empty boxes.
const ARABIC_FONT_PATH: String = "res://assets/fonts/NotoSansArabic-Regular.ttf"

## Active language code, e.g. "en" or "ar".
var current_locale: String:
	get:
		return _locale

var _locale: String = DEFAULT_LOCALE
var _arabic_font: FontFile


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_tables()
	# GameSettings is registered before this autoload, so the saved language is already read.
	var saved: String = GameSettings.language
	set_language(saved if SUPPORTED_LOCALES.has(saved) else DEFAULT_LOCALE, false)


# --- Public API -----------------------------------------------------------------------------

## Switch language, persist the choice and refresh the UI direction. Unknown codes fall back to English.
func set_language(locale: String, save: bool = true) -> void:
	var target: String = locale if SUPPORTED_LOCALES.has(locale) else DEFAULT_LOCALE
	_locale = target
	TranslationServer.set_locale(target)
	_apply_layout()
	_apply_font()
	if save:
		GameSettings.set_value("language", target)
	language_changed.emit(target)


## True when the active language reads right-to-left.
func is_rtl() -> bool:
	return RTL_LOCALES.has(_locale)


## Native name of a language, for the settings dropdown.
static func locale_label(locale: String) -> String:
	return LOCALE_LABELS.get(locale, locale)


## Translate a string, for code paths that cannot use the built-in tr().
func t(message: String) -> String:
	return String(TranslationServer.translate(message))


# --- Tables ---------------------------------------------------------------------------------

## Reads `ui_<locale>.csv` for every supported language and hands the result to the TranslationServer.
func _load_tables() -> void:
	for locale: String in SUPPORTED_LOCALES:
		var path: String = "%s/ui_%s.csv" % [TABLE_DIR, locale]
		if not FileAccess.file_exists(path):
			push_warning("Localization: string table '%s' not found, '%s' falls back to English." % [path, locale])
			continue
		var table: Translation = _build_table(locale, path)
		TranslationServer.add_translation(table)


func _build_table(locale: String, path: String) -> Translation:
	var table: Translation = Translation.new()
	table.locale = locale
	var count: int = 0
	for row: PackedStringArray in _parse_csv(path):
		if row.size() < 2:
			continue
		var key: String = row[0].strip_edges()
		if key.is_empty() or key.begins_with("#"):
			continue
		if key == "key" and row[1].strip_edges() == "locale":
			continue  # the "key,locale" header row is not a message
		table.add_message(key, row[1])
		count += 1
	if count == 0:
		push_warning("Localization: string table '%s' has no usable rows." % path)
	return table


## Minimal RFC 4180 reader: quoted fields, doubled quotes as escapes, `\n` inside quotes.
func _parse_csv(path: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Localization: could not open '%s'." % path)
		return rows
	var content: String = file.get_as_text()
	file.close()
	var row: PackedStringArray = PackedStringArray()
	var field: String = ""
	var in_quotes: bool = false
	var index: int = 0
	while index < content.length():
		var glyph: String = content[index]
		if in_quotes:
			if glyph == "\"":
				if index + 1 < content.length() and content[index + 1] == "\"":
					field += "\""
					index += 1
				else:
					in_quotes = false
			elif glyph == "\n":
				field += "\n"
			else:
				field += glyph
		elif glyph == "\"" and field.is_empty():
			in_quotes = true
		elif glyph == ",":
			row.append(field)
			field = ""
		elif glyph == "\n":
			row.append(field)
			rows.append(row)
			row = PackedStringArray()
			field = ""
		elif glyph != "\r":
			field += glyph
		index += 1
	if not field.is_empty() or row.size() > 0:
		row.append(field)
		rows.append(row)
	return rows


# --- Layout and font --------------------------------------------------------------------------

## Mirrors the UI for right-to-left languages. Every Control inherits the direction from the root
## window, so scenes need no per-node changes.
##
## The direction is set explicitly instead of LAYOUT_DIRECTION_APPLICATION_LOCALE: the project keeps
## its own RTL list, so the layout should not depend on the engine's locale detection or the OS
## locale, and the result stays deterministic in tests.
func _apply_layout() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	tree.root.layout_direction = Window.LAYOUT_DIRECTION_RTL if is_rtl() else Window.LAYOUT_DIRECTION_LTR


## Swaps the theme font to the Arabic one. The engine default has no Arabic glyphs, so without this
## every Arabic label renders as empty boxes.
func _apply_font() -> void:
	var theme: Theme = GameSettings.ui_theme
	if theme == null:
		return
	if not is_rtl():
		theme.default_font = null
		return
	if _arabic_font == null:
		if not ResourceLoader.exists(ARABIC_FONT_PATH):
			push_warning("Localization: Arabic font '%s' is missing, Arabic text will not render." % ARABIC_FONT_PATH)
			return
		_arabic_font = load(ARABIC_FONT_PATH) as FontFile
		if _arabic_font == null:
			push_warning("Localization: '%s' is not a font, Arabic text will not render." % ARABIC_FONT_PATH)
			return
	theme.default_font = _arabic_font
