## GUT Tests for the Localization pipeline (P5-06).
## Covers the string tables, language switching, English fallback, persistence and RTL layout.
class_name TestLocalization
extends GutTest


var _original_locale: String = ""


func before_each() -> void:
	_original_locale = Localization.current_locale


func after_each() -> void:
	# Restore English so other tests are not affected by the last language a test set.
	Localization.set_language(_original_locale, false)
	GameSettings.language = "en"


# --- String tables -------------------------------------------------------------------------------

func test_both_languages_are_registered() -> void:
	for locale: String in Localization.SUPPORTED_LOCALES:
		var found: Array[Translation] = TranslationServer.get_translations()
		var registered: bool = false
		for table: Translation in found:
			if table.locale == locale:
				registered = true
				break
		assert_true(registered, "no translation registered for '%s'" % locale)


func test_known_string_translates_to_arabic() -> void:
	Localization.set_language("ar", false)
	assert_eq(Localization.t("Settings"), "الإعدادات")
	assert_eq(Localization.t("Back"), "رجوع")
	assert_eq(Localization.t("Resume"), "استئناف")


func test_english_returns_the_source_string() -> void:
	Localization.set_language("en", false)
	assert_eq(Localization.t("Settings"), "Settings")
	assert_eq(Localization.t("Back"), "Back")


func test_format_strings_keep_their_placeholders() -> void:
	Localization.set_language("ar", false)
	# A dropped or reordered placeholder would crash the format call at runtime.
	assert_eq(Localization.t("Hosting · %d officers on shift") % 3, "استضافة · 3 ضابط في النوبة")
	assert_eq(Localization.t("Voice: %s") % Localization.t("Push to talk"),
		"الصوت: " + Localization.t("Push to talk"))


func test_unknown_key_returns_the_key_itself() -> void:
	Localization.set_language("ar", false)
	var missing: String = "definitely_not_a_real_key_1234"
	assert_eq(Localization.t(missing), missing)


# --- Switching -----------------------------------------------------------------------------------

func test_switching_locale_changes_translation() -> void:
	Localization.set_language("en", false)
	var english: String = Localization.t("Quit to desktop")
	Localization.set_language("ar", false)
	var arabic: String = Localization.t("Quit to desktop")
	assert_ne(english, arabic, "Arabic table did not override the English text")
	assert_eq(english, "Quit to desktop")


func test_translation_server_follows_the_selected_language() -> void:
	Localization.set_language("ar", false)
	assert_eq(TranslationServer.get_locale(), "ar")
	Localization.set_language("en", false)
	assert_eq(TranslationServer.get_locale(), "en")


func test_language_changed_signal_fires_once_per_switch() -> void:
	var seen: Array[String] = []
	var handler: Callable = func(locale: String) -> void: seen.append(locale)
	Localization.language_changed.connect(handler)
	Localization.set_language("ar", false)
	Localization.set_language("en", false)
	Localization.language_changed.disconnect(handler)
	assert_eq(seen, ["ar", "en"] as Array[String])


func test_unknown_locale_falls_back_to_english() -> void:
	Localization.set_language("fr", false)
	assert_eq(Localization.current_locale, "en")
	assert_eq(TranslationServer.get_locale(), "en")


# --- Right-to-left -------------------------------------------------------------------------------

func test_arabic_is_right_to_left_and_english_is_not() -> void:
	Localization.set_language("ar", false)
	assert_true(Localization.is_rtl())
	Localization.set_language("en", false)
	assert_false(Localization.is_rtl())


func test_controls_are_mirrored_for_arabic() -> void:
	# Window has no layout_direction in Godot 4.6, so Localization pushes the direction onto every
	# Control instead. Assert the property, not is_layout_rtl(): headless never resolves the layout
	# pass, so is_layout_rtl() reports false even for a Control explicitly set to RTL.
	var probe: Control = Control.new()
	add_child_autofree(probe)
	Localization.set_language("ar", false)
	assert_eq(probe.layout_direction, Control.LAYOUT_DIRECTION_RTL)
	Localization.set_language("en", false)
	assert_eq(probe.layout_direction, Control.LAYOUT_DIRECTION_LTR)


func test_a_nested_control_under_a_canvas_layer_is_mirrored() -> void:
	# Most of the interface hangs off CanvasLayers, which are plain Nodes, so a Control's nearest
	# Control ancestor can be far below the root. The walk has to reach those too.
	var layer: CanvasLayer = CanvasLayer.new()
	add_child_autofree(layer)
	var nested: Panel = Panel.new()
	layer.add_child(nested)
	Localization.set_language("ar", false)
	assert_eq(nested.layout_direction, Control.LAYOUT_DIRECTION_RTL)


func test_arabic_font_is_installed_on_the_theme() -> void:
	Localization.set_language("ar", false)
	assert_true(GameSettings.ui_theme != null, "UI theme missing")
	assert_true(GameSettings.ui_theme.default_font != null,
		"Arabic needs a real font or the glyphs render as empty boxes")
	Localization.set_language("en", false)
	assert_null(GameSettings.ui_theme.default_font, "English should use the engine default font")


# --- Settings ------------------------------------------------------------------------------------

func test_choosing_a_language_saves_it_to_settings() -> void:
	Localization.set_language("ar")
	assert_eq(GameSettings.language, "ar")
	Localization.set_language("en")
	assert_eq(GameSettings.language, "en")


func test_language_survives_a_settings_round_trip() -> void:
	GameSettings.language = "ar"
	GameSettings.save_settings()
	GameSettings.language = "en"
	GameSettings.load_settings()
	assert_eq(GameSettings.language, "ar", "saved language was not read back")
	GameSettings.language = "en"
	GameSettings.save_settings()


# --- Labels --------------------------------------------------------------------------------------

func test_language_names_are_shown_in_their_own_script() -> void:
	assert_eq(Localization.locale_label("en"), "English")
	assert_eq(Localization.locale_label("ar"), "العربية")
	assert_eq(Localization.locale_label("zz"), "zz", "unknown code should fall back to itself")
