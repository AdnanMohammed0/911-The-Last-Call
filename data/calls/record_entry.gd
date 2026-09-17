## Police database record or incident archive entry (GAMEPLAY_MECHANICS §5.2).
class_name RecordEntry
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var content: String = ""
@export var unlocked_by_default: bool = false

func validate() -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	var warnings: PackedStringArray = PackedStringArray()

	if id == &"":
		errors.append("id is empty")
	if title.is_empty():
		warnings.append("title is empty")

	return {"errors": errors, "warnings": warnings}