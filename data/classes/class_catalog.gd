## Lookup for the playable classes. Order here is the order shown in the lobby.
## Authority: LOCAL
class_name ClassCatalog
extends RefCounted

const CLASS_PATHS: Dictionary[StringName, String] = {
	&"tech": "res://data/classes/tech.tres",
	&"profiler": "res://data/classes/profiler.tres",
	&"breacher": "res://data/classes/breacher.tres",
	&"medic": "res://data/classes/medic.tres",
}


static func ids() -> Array[StringName]:
	return CLASS_PATHS.keys()


static func has(class_id: StringName) -> bool:
	return CLASS_PATHS.has(class_id)


static func get_data(class_id: StringName) -> ClassData:
	if not CLASS_PATHS.has(class_id):
		return null
	return load(CLASS_PATHS[class_id]) as ClassData
