## Hostile archetype stats (GAMEPLAY_MECHANICS §8.1). One .tres per archetype in data/ai/archetypes/.
## Authority: LOCAL (static data)
class_name ArchetypeData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var color: Color = Color(0.4, 0.1, 0.1)

@export_group("Survivability")
@export var max_hp: float = 100.0
## 0..100 starting morale.
@export var morale: float = 50.0
## Fanatics never surrender or flee.
@export var fanatic: bool = false
## Surrenders when morale drops below this (Thug surrenders easily).
@export var surrender_threshold: float = 20.0

@export_group("Weapon")
## False for unarmed suspects (prank callers): they never shoot, only flee or give up.
@export var armed: bool = true
@export var weapon_name: String = "Pistol"
@export var damage: float = 12.0
@export var effective_range: float = 25.0
@export var fire_interval: float = 0.45
@export var burst_size: int = 3
@export var magazine: int = 12
@export var reload_seconds: float = 2.0
## Chance to hit a still target at 10 m (falls off with distance and target speed).
@export_range(0.0, 1.0) var accuracy: float = 0.55
@export var melee: bool = false
@export var melee_damage: float = 35.0

@export_group("Movement")
@export var walk_speed: float = 2.2
@export var run_speed: float = 4.2

@export_group("Tactics")
@export var uses_cover: bool = true
@export var uses_flanks: bool = false
## Charges the nearest player instead of taking cover.
@export var rushes: bool = false
## Zealot IED vest: detonates within this distance of a player (0 = none).
@export var ied_radius: float = 0.0
@export var ied_damage: float = 90.0
## Ambush Leader: allies spawned once when combat starts.
@export var reinforcements: int = 0
## Hostage Taker: chance to execute the hostage on a loud breach (door kick / gunshot nearby).
@export_range(0.0, 1.0) var hostage_execute_chance: float = 0.0
## Arresting this suspect yields intel (Ambush Leader).
@export var arrest_intel: bool = false
