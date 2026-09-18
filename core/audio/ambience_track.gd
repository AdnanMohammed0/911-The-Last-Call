## Ambience Track Definition (P4-13).
## Data-only resource describing a layered ambient soundscape for a location/state.
class_name AmbienceTrack
extends Resource

enum Category { STATION, FIELD_NORMAL, FIELD_HORROR, SIEGE, AFTERMATH }

@export var id: StringName = &""
@export var name: String = ""
@export var description: String = ""
@export var category: Category = Category.FIELD_NORMAL
## Array of layer dictionaries:
## { file: String, volume_db: float, loop: bool, fade_in: float, fade_out: float,
##   probability: float (0-1 for oneshots), interval_range: Vector2 (min,max seconds),
##   random_start: bool, random_pitch: float, trigger: StringName, condition: StringName }
@export var layers: Array[Dictionary] = []
@export var transition_to: Array[StringName] = []


func get_looping_layers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for layer in layers:
		if layer.get("loop", true):
			result.append(layer)
	return result


func get_oneshot_layers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for layer in layers:
		if not layer.get("loop", true):
			result.append(layer)
	return result


func validate() -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	var warnings: PackedStringArray = PackedStringArray()

	if id == &"":
		errors.append("id is empty")
	if name.is_empty():
		warnings.append("name is empty")
	if layers.is_empty():
		warnings.append("no layers defined")

	for i: int in layers.size():
		var layer: Dictionary = layers[i]
		if not layer.has("file"):
			errors.append("layer %d: missing 'file'" % i)
		elif not layer["file"].begins_with("res://"):
			warnings.append("layer %d: file path should be res://" % i)
		if not layer.has("volume_db"):
			warnings.append("layer %d: missing 'volume_db'" % i)
		if layer.get("loop", true) and layer.get("fade_in", 0.0) < 0.5:
			warnings.append("layer %d: looping layer should have fade_in >= 0.5s" % i)

	return {"errors": errors, "warnings": warnings}