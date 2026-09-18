## Music Stinger Definition (P4-13).
## Data-only resource describing a music stinger/ambient drone for dynamic music system.
class_name MusicStinger
extends Resource

enum Category { TENSION, SCARE, RESOLUTION, AMBIENT_DRONE, TRANSITION, ENDING }

@export var id: StringName = &""
@export var name: String = ""
@export var description: String = ""
@export var category: Category = Category.TENSION
@export var intensity: float = 0.0        # -1.0 (relief) to 1.0 (max tension)
@export var file: String = ""
@export var alternates: Array[String] = []
@export var volume_db: float = -6.0
@export var fade_in: float = 1.0
@export var fade_out: float = 2.0
@export var loop: bool = false
@export var trigger_conditions: Array[StringName] = []
@export var cooldown_sec: float = 30.0
@export var priority: int = 1             # Higher = interrupts lower
@export var layerable: bool = true        # Can play simultaneously with other stingers


func get_file_to_play() -> String:
	if alternates.is_empty():
		return file
	var idx: int = randi() % (alternates.size() + 1)
	if idx == 0:
		return file
	return alternates[idx - 1]


func validate() -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	var warnings: PackedStringArray = PackedStringArray()

	if id == &"":
		errors.append("id is empty")
	if name.is_empty():
		warnings.append("name is empty")
	if file.is_empty() and alternates.is_empty():
		errors.append("no audio file specified")
	elif not file.is_empty() and not file.begins_with("res://"):
		warnings.append("file path should be res://")
	for i: int in alternates.size():
		if not alternates[i].begins_with("res://"):
			warnings.append("alternate %d: path should be res://" % i)
	if volume_db > 6.0:
		warnings.append("volume_db > 6dB may cause clipping on Master bus")
	if fade_in < 0.0 or fade_out < 0.0:
		errors.append("fade_in/fade_out must be >= 0")
	if cooldown_sec < 0.0:
		errors.append("cooldown_sec must be >= 0")
	if priority < 0 or priority > 10:
		warnings.append("priority should be 0-10")

	return {"errors": errors, "warnings": warnings}