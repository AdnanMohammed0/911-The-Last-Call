## Enlarges text inside the computer viewport without changing the game's global UI theme.
extends RefCounted

const SCALE: float = 1.35
const SCALED_META: StringName = &"computer_text_scaled"


static func enlarge_text(root: Node) -> void:
	if root is RichTextLabel and not root.has_meta(SCALED_META):
		var rich: RichTextLabel = root as RichTextLabel
		rich.add_theme_font_size_override(&"normal_font_size", roundi(rich.get_theme_font_size(&"normal_font_size") * SCALE))
		root.set_meta(SCALED_META, true)
	elif (root is Label or root is Button or root is LineEdit or root is TextEdit) and not root.has_meta(SCALED_META):
		var control: Control = root as Control
		control.add_theme_font_size_override(&"font_size", roundi(control.get_theme_font_size(&"font_size") * SCALE))
		root.set_meta(SCALED_META, true)
	for child: Node in root.get_children():
		enlarge_text(child)
