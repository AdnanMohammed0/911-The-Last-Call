## One Station Siege wave (GAMEPLAY_MECHANICS §11): which hostiles storm the station, how fast they arrive and
## how long the team gets to regroup before it. `archetypes[i]` spawns `counts[i]` times; the roster
## interleaves them so a wave never arrives as one block of the same type.
## Authority: DATA
class_name SiegeWave
extends Resource

@export var archetypes: Array[ArchetypeData] = []
@export var counts: Array[int] = []
## Countdown before the wave starts (the first one doubles as "arm up at the armory").
@export var intermission_sec: float = 25.0
## Seconds between two spawns of this wave.
@export var spawn_interval_sec: float = 1.5
## Never more than this many of the wave's hostiles alive at once (AI budget: 12 agents).
@export_range(1, 12) var max_alive: int = 6
## Scales health, accuracy and damage (EnemySpawner.scaled_archetype), on top of the shift scaling.
@export var difficulty: float = 1.0
## Subtitle shown when the wave begins.
@export var announcement: String = ""


func total() -> int:
	var sum: int = 0
	for i: int in mini(archetypes.size(), counts.size()):
		if archetypes[i] != null:
			sum += maxi(counts[i], 0)
	return sum


## Spawn order: one of each archetype in turn until every count is used up.
func roster() -> Array[ArchetypeData]:
	var left: Array[int] = []
	for i: int in mini(archetypes.size(), counts.size()):
		left.append(maxi(counts[i], 0) if archetypes[i] != null else 0)
	var order: Array[ArchetypeData] = []
	var remaining: int = total()
	while remaining > 0:
		for i: int in left.size():
			if left[i] > 0:
				order.append(archetypes[i])
				left[i] -= 1
				remaining -= 1
	return order
