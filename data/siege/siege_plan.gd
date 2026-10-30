## The Station Siege horde mode: the waves in order plus the team-wide rewards. Outcome meters (trust, cult
## awareness, guilt) live in the consequence rules triggered by station_siege_survived / station_siege_fallen.
## Authority: DATA
class_name SiegePlan
extends Resource

@export var waves: Array[SiegeWave] = []
## Team XP for holding the station through the last wave.
@export var xp_survived: int = 400
## Team XP lost when the station falls.
@export var xp_fallen: int = -150
## XP per hostile neutralized during the siege (kill or arrest).
@export var xp_per_hostile: int = 15
## Seconds every officer must stay down before the station falls.
@export var wipe_grace_sec: float = 8.0


func total_hostiles() -> int:
	var sum: int = 0
	for wave: SiegeWave in waves:
		if wave != null:
			sum += wave.total()
	return sum
