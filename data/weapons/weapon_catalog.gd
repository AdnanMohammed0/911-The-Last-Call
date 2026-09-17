## Lookup for firearms in data/weapons/ plus the default class loadouts.
## Authority: LOCAL
class_name WeaponCatalog
extends RefCounted

const WEAPON_PATHS: Dictionary[StringName, String] = {
	&"pistol": "res://data/weapons/pistol.tres",
	&"smg": "res://data/weapons/smg.tres",
	&"shotgun": "res://data/weapons/shotgun.tres",
	&"rifle": "res://data/weapons/rifle.tres",
}


static func ids() -> Array[StringName]:
	return WEAPON_PATHS.keys()


static func has(weapon_id: StringName) -> bool:
	return WEAPON_PATHS.has(weapon_id)


static func get_data(weapon_id: StringName) -> WeaponData:
	if not WEAPON_PATHS.has(weapon_id):
		return null
	return load(WEAPON_PATHS[weapon_id]) as WeaponData


## Service pistol for everyone, plus the first primary the class may carry (ClassData.weapon_access).
static func default_loadout(class_data: ClassData) -> Dictionary[WeaponData.Slot, StringName]:
	var loadout: Dictionary[WeaponData.Slot, StringName] = {WeaponData.Slot.SIDEARM: &"pistol"}
	if class_data == null:
		return loadout
	for access: String in class_data.weapon_access:
		var data: WeaponData = get_data(StringName(access))
		if data != null and data.slot == WeaponData.Slot.PRIMARY and data.is_allowed_for(class_data.id):
			loadout[WeaponData.Slot.PRIMARY] = data.id
			break
	return loadout
