## Corner marks drawn after the screen pass, so the camera frame remains visible.
class_name BodycamFrame
extends Control

const FRAME: Color = Color(0.86, 0.92, 0.92, 0.85)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var inset: float = 24.0
	var length: float = 24.0
	var corners: Array[Vector2] = [Vector2(inset, inset), Vector2(size.x - inset, inset),
		Vector2(inset, size.y - inset), Vector2(size.x - inset, size.y - inset)]
	for corner: Vector2 in corners:
		var sx: float = 1.0 if corner.x < size.x * 0.5 else -1.0
		var sy: float = 1.0 if corner.y < size.y * 0.5 else -1.0
		draw_line(corner, corner + Vector2(sx * length, 0), FRAME, 2.0)
		draw_line(corner, corner + Vector2(0, sy * length), FRAME, 2.0)
