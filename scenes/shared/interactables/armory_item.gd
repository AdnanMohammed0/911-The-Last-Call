## Armory equipment points in Station 4: weapon racks (class-restricted), armor lockers and ammo crates.
## Builds its own display model (a gun on the rack, a vest in the locker, a crate) so level builders only
## place the node.
## Authority: HOST (gear is granted on the host and replicates through the player's HostSync)
class_name ArmoryItem
extends Interactable

enum Kind { WEAPON, ARMOR, AMMO }

const ARMOR_AMOUNT: float = 100.0

@export var kind: Kind = Kind.WEAPON
@export var weapon_id: StringName = &"rifle"
@export var build_display: bool = true


func _ready() -> void:
	super._ready()
	cooldown = 0.6
	if get_child_count() == 0:
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(0.9, 0.7, 0.5)
		shape.shape = box
		add_child(shape)
	if build_display and DisplayServer.get_name() != "headless":
		_build_display()


func get_prompt_text() -> String:
	var local: Player = Player.find_by_peer(get_tree(), multiplayer.get_unique_id())
	var my_rank: int = Career.rank()
	match kind:
		Kind.ARMOR:
			if my_rank < Career.ARMOR_RANK:
				return "Ballistic vest — requires %s" % Career.rank_name(Career.ARMOR_RANK)
			return "Put on ballistic vest"
		Kind.AMMO:
			return "Refill ammunition"
	var data: WeaponData = WeaponCatalog.get_data(weapon_id)
	if data == null:
		return ""
	if local != null and not data.is_allowed_for(local.class_id):
		return "%s — %s only" % [data.display_name, ", ".join(_class_names(data))]
	if my_rank < Career.required_rank(weapon_id):
		return "%s — requires rank %s" % [data.display_name, Career.rank_name(Career.required_rank(weapon_id))]
	if local != null and local.get_weapons().weapon_id(data.slot) == weapon_id:
		return "Refill %s" % data.display_name
	return "Take %s" % data.display_name


func _can_interact(peer_id: int) -> bool:
	var player: Player = Player.find_by_peer(get_tree(), peer_id)
	if player == null or not player.get_health().is_alive():
		return false
	var rank: int = Career.rank_of(peer_id)
	if kind == Kind.WEAPON:
		var data: WeaponData = WeaponCatalog.get_data(weapon_id)
		return data != null and data.is_allowed_for(player.class_id) and rank >= Career.required_rank(weapon_id)
	if kind == Kind.ARMOR:
		return rank >= Career.ARMOR_RANK
	return true


func _on_interact(peer_id: int) -> void:
	var player: Player = Player.find_by_peer(get_tree(), peer_id)
	if player == null:
		return
	match kind:
		Kind.WEAPON:
			var data: WeaponData = WeaponCatalog.get_data(weapon_id)
			player.get_weapons().set_weapon(data.slot, weapon_id)
		Kind.ARMOR:
			player.get_health().give_armor(ARMOR_AMOUNT)
		Kind.AMMO:
			player.get_weapons().refill_ammo()


func _class_names(data: WeaponData) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for class_id: StringName in data.allowed_classes:
		var class_data: ClassData = ClassCatalog.get_data(class_id)
		names.append(class_data.display_name if class_data != null else String(class_id))
	return names


func _build_display() -> void:
	match kind:
		Kind.WEAPON:
			var data: WeaponData = WeaponCatalog.get_data(weapon_id)
			if data == null:
				return
			var model: WeaponModel = WeaponModel.build(data)
			model.rotation_degrees = Vector3(0, 90, 0)
			model.position = Vector3(-data.body_length * 0.5, 0, 0)
			add_child(model)
			var label: Label3D = Label3D.new()
			label.text = data.display_name.to_upper()
			label.font_size = 28
			label.pixel_size = 0.004
			label.modulate = Color(0.85, 0.88, 0.9)
			label.position = Vector3(0, -0.22, 0.06)
			add_child(label)
		Kind.ARMOR:
			var vest: MeshInstance3D = MeshInstance3D.new()
			var mesh: BoxMesh = BoxMesh.new()
			mesh.size = Vector3(0.46, 0.55, 0.22)
			var material: StandardMaterial3D = StandardMaterial3D.new()
			material.albedo_color = Color(0.13, 0.15, 0.13)
			material.roughness = 0.9
			mesh.material = material
			vest.mesh = mesh
			add_child(vest)
			var plate: MeshInstance3D = MeshInstance3D.new()
			var plate_mesh: BoxMesh = BoxMesh.new()
			plate_mesh.size = Vector3(0.3, 0.2, 0.02)
			var text: StandardMaterial3D = StandardMaterial3D.new()
			text.albedo_color = Color(0.85, 0.8, 0.3)
			plate_mesh.material = text
			plate.mesh = plate_mesh
			plate.position = Vector3(0, 0.08, 0.12)
			add_child(plate)
		Kind.AMMO:
			var crate: MeshInstance3D = MeshInstance3D.new()
			var crate_mesh: BoxMesh = BoxMesh.new()
			crate_mesh.size = Vector3(0.8, 0.4, 0.45)
			var olive: StandardMaterial3D = StandardMaterial3D.new()
			olive.albedo_color = Color(0.23, 0.26, 0.17)
			olive.roughness = 0.85
			crate_mesh.material = olive
			crate.mesh = crate_mesh
			add_child(crate)
