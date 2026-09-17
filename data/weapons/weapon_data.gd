## Firearm definition (GAMEPLAY_MECHANICS §6 loadout table, §7 combat). One .tres per weapon.
## Authority: LOCAL (static data shared by every peer)
class_name WeaponData
extends Resource

enum Slot { PRIMARY, SIDEARM }

@export var id: StringName = &""
@export var display_name: String = ""
@export var slot: Slot = Slot.PRIMARY

@export_group("Damage")
@export var damage: float = 25.0
## Projectiles per trigger pull (shotgun > 1).
@export var pellets: int = 1
@export var max_range: float = 120.0
## Damage starts dropping after this distance and reaches `falloff_min_ratio` at `max_range`.
@export var falloff_start: float = 25.0
@export_range(0.0, 1.0) var falloff_min_ratio: float = 0.5

@export_group("Handling")
@export var fire_interval: float = 0.12
@export var automatic: bool = false
@export var magazine_size: int = 30
@export var max_reserve: int = 90
@export var reload_seconds: float = 2.2
## Cone half-angle in degrees.
@export var hip_spread: float = 2.5
@export var aim_spread: float = 0.4
## Extra spread while moving (degrees at walk speed).
@export var move_spread: float = 2.0
@export var aim_fov: float = 55.0

@export_group("Recoil")
## Per-shot camera kick (x = pitch up, y = yaw) in degrees; the pattern repeats past its end.
@export var recoil_pattern: PackedVector2Array = PackedVector2Array([Vector2(0.9, 0.0)])
@export var recoil_recovery: float = 12.0
@export var recoil_reset_seconds: float = 0.35

@export_group("Loadout")
@export var cost: int = 0
## Empty = every class may carry it.
@export var allowed_classes: Array[StringName] = []
@export var noise_radius: float = 60.0

@export_group("Look")
@export var body_length: float = 0.55
@export var barrel_length: float = 0.25
@export var body_color: Color = Color(0.08, 0.08, 0.09)


func is_allowed_for(class_id: StringName) -> bool:
	return allowed_classes.is_empty() or class_id in allowed_classes


## Damage after distance falloff.
func damage_at(distance: float) -> float:
	if distance <= falloff_start:
		return damage
	var t: float = clampf((distance - falloff_start) / maxf(max_range - falloff_start, 0.01), 0.0, 1.0)
	return damage * lerpf(1.0, falloff_min_ratio, t)


func recoil_for_shot(index: int) -> Vector2:
	if recoil_pattern.is_empty():
		return Vector2.ZERO
	return recoil_pattern[index % recoil_pattern.size()]
