## Trait Data Resource — defines a persistent trait with stat modifiers and hooks (GAMEPLAY_MECHANICS §3.4).
## Authority: LOCAL (static data, identical on every peer)
class_name TraitData
extends Resource

enum Category { PHYSICAL, PSYCHOLOGICAL, POSITIVE, STORY }

## Unique identifier for this trait.
@export var id: StringName = &""
## Display name for UI.
@export var display_name: String = ""
## Category determines UI grouping and some system behavior.
@export var category: Category = Category.PHYSICAL
## Icon for UI display.
@export var icon: Texture2D
## Duration in shifts. -1 = permanent or conditional (see hooks).
@export var duration_shifts: int = -1
## Stat modifiers applied while trait is active.
## Keys use StringName (e.g. &"move_speed", &"noise", &"sanity_drain", &"max_health").
@export var stat_modifiers: Dictionary = {}
## Cost to cure (money). 0 = cannot be cured by money alone.
@export var cure_cost: int = 0
## Scripted behavior hooks (e.g. &"phantom_ringing", &"flashback_audio").
## Checked by various systems at runtime.
@export var hooks: Array[StringName] = []
## Description for UI tooltip.
@export_multiline var description: String = ""

## Validates the resource for authoring mistakes.
func validate() -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	var warnings: PackedStringArray = PackedStringArray()

	if id == &"":
		errors.append("id is empty")
	if display_name.is_empty():
		warnings.append("display_name is empty")
	if description.is_empty():
		warnings.append("description is empty")

	return {"errors": errors, "warnings": warnings}


## Returns a human-readable category name.
func get_category_name() -> String:
	match category:
		Category.PHYSICAL: return "Physical"
		Category.PSYCHOLOGICAL: return "Psychological"
		Category.POSITIVE: return "Positive"
		Category.STORY: return "Story"
	return "Unknown"