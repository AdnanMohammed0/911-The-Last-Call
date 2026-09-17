## Per-role stats (GAMEPLAY_MECHANICS §2.1). One .tres per class in data/classes/.
## Authority: LOCAL (static data, identical on every peer)
class_name ClassData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var summary: String = ""
## Vest colour on the placeholder body and lobby accents.
@export var color: Color = Color.WHITE

@export_group("Survivability")
@export var max_health: float = 100.0
@export_range(0.0, 1.0, 0.01) var damage_resistance: float = 0.0
@export var max_sanity: float = 100.0
@export var sanity_drain_multiplier: float = 1.0

@export_group("Movement")
@export var move_speed_multiplier: float = 1.0
@export var sprint_duration: float = 7.0
@export var noise_multiplier: float = 1.0

@export_group("Combat & Gear")
@export var aim_stability: float = 1.0
@export var carry_slots: int = 3
@export var weapon_access: PackedStringArray = PackedStringArray()
