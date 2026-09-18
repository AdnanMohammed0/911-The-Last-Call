## Foley Sound Definition (P4-13).
## Data-only resource describing a foley sound effect with variations, class modifiers, and triggering.
class_name FoleyDefinition
extends Resource

enum Category { FOOTSTEPS, DOORS, EQUIPMENT, WEAPONS, INTERACTIONS, ENVIRONMENT }
enum Surface { CONCRETE, WOOD, DIRT, METAL, WATER, CARPET, GRAVEL }
enum MovementType { WALK, SPRINT, CROUCH }

@export var id: StringName = &""
@export var category: Category = Category.FOOTSTEPS
@export var surface: Surface = Surface.CONCRETE
@export var movement_type: MovementType = MovementType.WALK
@export var variations: Array[String] = []
@export var volume_db: float = 0.0
@export var pitch_range: Vector2 = Vector2(0.95, 1.05)
@export var distance_attenuation: bool = true
@export var max_distance: float = 10.0
@export var loop: bool = false
@export var trigger: StringName = &""
@export var class_modifiers: Dictionary = {}


func get_random_variation() -> String:
	if variations.is_empty():
		return ""
	return variations[randi() % variations.size()]


func get_random_pitch() -> float:
	return randf_range(pitch_range.x, pitch_range.y)


func get_class_multiplier(class_name: StringName) -> float:
	return class_modifiers.get(class_name, 1.0)


func validate() -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	var warnings: PackedStringArray = PackedStringArray()

	if id == &"":
		errors.append("id is empty")
	if variations.is_empty():
		errors.append("no variations defined")
	else:
		for i: int in variations.size():
			var path: String = variations[i]
			if not path.begins_with("res://"):
				warnings.append("variation %d: path should be res://" % i)
	if volume_db > 12.0:
		warnings.append("volume_db > 12dB may cause clipping")
	if max_distance <= 0.0:
		errors.append("max_distance must be > 0")
	if category == Category.FOOTSTEPS and (surface == Surface.CONCRETE or surface == Surface.WOOD) and variations.size() < 3:
		warnings.append("footstep surfaces should have at least 3-4 variations for natural feel")

	return {"errors": errors, "warnings": warnings}