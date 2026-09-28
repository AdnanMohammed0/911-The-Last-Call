## Interaction prompt under the crosshair: a key cap with a circular hold-progress ring around it and the
## action text beside it, fading in when the PlayerInteractor focuses something.
## Authority: LOCAL
class_name InteractionPrompt
extends Control

@export var interactor: PlayerInteractor

var _box: HBoxContainer
var _ring: HoldRing
var _key_label: Label
var _verb: Label
var _label: Label
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = HBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 12)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_box.offset_top = 52
	_box.offset_bottom = 96
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ring = HoldRing.new()
	_ring.custom_minimum_size = Vector2(44, 44)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_ring)
	_key_label = UiKit.label("F", 17, Color(0.05, 0.06, 0.07), &"black")
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.add_child(_key_label)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.add_theme_constant_override(&"separation", -3)
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(texts)
	_verb = UiKit.caps("Press", 10, Color(1, 1, 1, 0.65), &"bold", 2)
	texts.add_child(_verb)
	_label = UiKit.label("Interact", 19, GameTheme.TEXT, &"semibold")
	_label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override(&"shadow_outline_size", 5)
	texts.add_child(_label)
	_box.modulate.a = 0.0
	if interactor != null:
		interactor.focus_changed.connect(_on_focus_changed)
		interactor.hold_progress_changed.connect(_on_hold_progress_changed)


func _on_focus_changed(target: Interactable) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_box, "modulate:a", 1.0 if target != null else 0.0, 0.12)
	if target == null:
		_ring.progress = -1.0
		_ring.queue_redraw()
		return
	_verb.text = "HOLD" if target.is_hold() else "PRESS"
	_key_label.text = GameSettings.binding_text(&"interact").to_upper()
	_label.text = target.get_prompt_text()


func _on_hold_progress_changed(progress: float) -> void:
	_ring.progress = progress
	_ring.queue_redraw()


## White key cap disc with the hold-progress arc.
class HoldRing:
	extends Control

	var progress: float = -1.0

	func _draw() -> void:
		var centre: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5
		draw_circle(centre + Vector2(0, 2), radius - 5.0, Color(0, 0, 0, 0.4))
		draw_circle(centre, radius - 5.0, Color(0.95, 0.96, 0.97))
		draw_arc(centre, radius - 1.5, 0.0, TAU, 48, Color(1, 1, 1, 0.18), 3.0, true)
		if progress >= 0.0:
			draw_arc(centre, radius - 1.5, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 48, GameTheme.ACCENT, 3.0, true)
