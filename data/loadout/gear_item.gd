## Gear Item Resource — defines an equipment item for the loadout armory (GAMEPLAY_MECHANICS §6).
## Authority: LOCAL (static data, identical on every peer)
class_name GearItem
extends Resource

enum Slot { SIDEARM, PRIMARY, HEAVY, GADGET, THROWABLE, CONSUMABLE }

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var cost: int = 0
@export var slot: Slot = Slot.PRIMARY
@export var icon: Texture2D = null

## Class restrictions — empty = available to all classes
@export var allowed_classes: PackedStringArray = PackedStringArray()

## Breacher discount (15% off heavy gear per GAMEPLAY_MECHANICS §6)
@export var breacher_discount: bool = false

## Quantity available per purchase (for consumables/throwables)
@export var quantity_per_purchase: int = 1

## Maximum quantity a player can carry
@export var max_carry: int = 1


func is_available_for_class(class_id: StringName) -> bool:
	if allowed_classes.is_empty():
		return true
	return class_id in allowed_classes


func get_effective_cost(class_id: StringName) -> int:
	var effective_cost: int = cost
	if breacher_discount and class_id == &"breacher":
		effective_cost = int(cost * 0.85)
	return effective_cost


func validate() -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	var warnings: PackedStringArray = PackedStringArray()

	if id == &"":
		errors.append("id is empty")
	if display_name.is_empty():
		warnings.append("display_name is empty")
	if cost < 0:
		errors.append("cost must be >= 0")
	if quantity_per_purchase <= 0:
		errors.append("quantity_per_purchase must be > 0")
	if max_carry <= 0:
		errors.append("max_carry must be > 0")

	return {"errors": errors, "warnings": warnings}