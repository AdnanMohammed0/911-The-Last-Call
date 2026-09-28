## Station 4 layout on top of the map_v13 building: the permanent fixtures (armory wall, garage deploy
## point, parked cruiser, signs, room lights) plus everything bought in StationMart, which appears in its own
## spot as soon as Economy's inventory changes (on every peer — the builds are deterministic, so the
## interactables inside have the same node paths everywhere).
##
## Room map (world metres, floor at y 0.85):
##   Dispatch room  x 0..16   z -27.7..-17.5   main computer + bought workstations
##   Break room     x 0..16   z -17.2..-10.6   coffee, vending, sofa, TV, arcade, pool table
##   Corridor       x 16..22  z -24..0         first aid, trauma kits, signs
##   Operations     x 22..38  z -24..-12.6     safe room, infirmary beds, CCTV wall
##   Armory         x 22..38  z -6.2..-0.2     weapon racks (south wall), armor lockers + ammo (north wall)
##   Garage         x 38.6..52.5 z -33..0      deploy door at the shutter, vehicles, reloading bench
##   Lobby          x 16..28  z -33..-24       metal detector, plants
## Authority: LOCAL (every peer builds the same props from the replicated Economy inventory)
class_name StationFurniture
extends Node3D

const FLOOR: float = 0.85
const CRUISER_SCENE: String = "res://assets/3D/cars/fairheaven_lt_80_cop_cruiser_-_low_poly_model.glb"
const TIRES_SCENE: String = "res://assets/3D/tires/dirty_old_tires.glb"
const TRASH_SCENE: String = "res://assets/3D/trash/trash_can.glb"
const RUG_SCENE: String = "res://assets/3D/rug/paloma_large_wool_rug.glb"
## Weapon rack x positions along the armory's south wall (item id → x).
const RACK_X: Dictionary[StringName, float] = {
	&"rack_pistol": 23.2, &"rack_revolver": 24.9, &"rack_shotgun": 26.6, &"rack_smg": 28.3, &"rack_pdw": 30.0,
	&"rack_rifle": 31.7, &"rack_dmr": 33.4, &"rack_auto_shotgun": 35.1, &"rack_lmg": 36.8,
}
const RACK_Z: float = -0.62
## Armor locker x positions along the armory's north wall.
const LOCKER_X: Dictionary[StringName, float] = {&"kevlar_vest": 23.6, &"plate_carrier": 25.2, &"riot_gear": 26.8}
const LOCKER_Z: float = -5.7
## Extra dispatch workstations (the old operator desk spots): [position, yaw].
const WORKSTATIONS: Array[Array] = [
	[Vector3(10.0, FLOOR, -24.2), 0.0], [Vector3(6.0, FLOOR, -20.8), 180.0], [Vector3(10.0, FLOOR, -20.8), 180.0],
]
## Bought cruisers park next to the station cruiser: [position, yaw].
const CRUISER_BAYS: Array[Array] = [[Vector3(48.6, FLOOR, -6.5), 180.0], [Vector3(42.4, FLOOR, -18.0), 180.0]]

## When set, this node only builds that one purchasable item (StationMart product photos).
var preview_item: StringName = &""

var _kit: LevelKit
var _fixtures: Node3D
var _items: Node3D
var _locked: Node3D


## A detached copy of `item_id` as it appears in the station (labels hidden), for product photos.
static func preview(item_id: StringName) -> Node3D:
	var builder: StationFurniture = StationFurniture.new()
	builder.preview_item = item_id
	return builder


func _ready() -> void:
	_kit = LevelKit.new(self)
	if preview_item != &"":
		_items = _kit.group(self, "Items")
		_locked = _kit.group(self, "LockedRacks")
		_build_item(preview_item, 0, _kit.group(_items, "Preview"))
		for label: Node in find_children("*", "Label3D", true, false):
			(label as Label3D).visible = false
		return
	_fixtures = _kit.group(self, "Fixtures")
	_items = _kit.group(self, "Items")
	_locked = _kit.group(self, "LockedRacks")
	_build_fixtures()
	sync_items()
	Economy.inventory_changed.connect(sync_items)


## Spawn every owned item that is missing and remove the ones no longer owned.
func sync_items() -> void:
	for item: Dictionary in ShopCatalog.ITEMS:
		var item_id: StringName = item["id"]
		var owned: int = Economy.count_of(item_id)
		var max_count: int = item.get("max", 1)
		for index: int in max_count:
			var node_name: String = "%s_%d" % [item_id, index]
			var existing: Node = _items.get_node_or_null(node_name)
			if index < owned and existing == null:
				var holder: Node3D = _kit.group(_items, node_name)
				_build_item(item_id, index, holder)
			elif index >= owned and existing != null:
				_items.remove_child(existing)
				existing.queue_free()
	for rack_id: StringName in RACK_X:
		var placeholder: Node3D = _locked.get_node_or_null(NodePath(String(rack_id))) as Node3D
		if placeholder != null:
			placeholder.visible = not Economy.owns(rack_id)


func item_node(item_id: StringName, index: int = 0) -> Node3D:
	return _items.get_node_or_null("%s_%d" % [item_id, index]) as Node3D


# --- Permanent fixtures ------------------------------------------------------------------------

func _build_fixtures() -> void:
	_build_armory_room()
	_build_garage()
	_build_signs()
	_build_decor()


func _build_armory_room() -> void:
	var armory: Node3D = _kit.group(_fixtures, "Armory")
	# Pegboard along the south wall behind the racks, and a shelf under them.
	_kit.box(armory, "Pegboard", Vector3(30.3, FLOOR + 1.45, -0.32), Vector3(15.2, 1.5, 0.05), _kit.material("metal_dark"), 0.0, false)
	_kit.box(armory, "RackShelf", Vector3(30.3, FLOOR + 0.55, -0.45), Vector3(15.2, 0.06, 0.4), _kit.material("steel"))
	for rack_id: StringName in RACK_X:
		var item: Dictionary = ShopCatalog.get_item(rack_id)
		var price: int = item.get("price", 0)
		var slot: Node3D = _kit.group(_locked, String(rack_id), Vector3(RACK_X[rack_id], FLOOR + 1.45, RACK_Z))
		slot.rotation_degrees.y = 180.0
		var outline: BoxMesh = BoxMesh.new()
		outline.size = Vector3(1.4, 0.4, 0.02)
		_kit.mesh(slot, "Outline", outline, Vector3(0, 0, 0.25), _kit.material("hazard_yellow"), Vector3.ZERO, false)
		_label(slot, "LOCKED\n%s\n$%d · StationMart" % [str(item.get("name", rack_id)).to_upper(), price],
			Vector3(0, 0, 0.2), 0.0025, Color(1.0, 0.75, 0.3))
	# Workbench and crates in the north-east corner.
	_kit.box(armory, "Workbench", Vector3(36.4, FLOOR + 0.45, -5.6), Vector3(2.4, 0.9, 0.9), _kit.material("wood"))
	_kit.crate_stack(armory, "Crates", Vector3(34.6, FLOOR, -5.5), 0.0, 2)
	_label(armory, "ARMORY", Vector3(30.3, FLOOR + 2.7, -0.3), 0.008, Color(0.9, 0.92, 0.95), 180.0)
	_label(armory, "ARMOR", Vector3(25.2, FLOOR + 2.55, -6.05), 0.005, Color(0.9, 0.92, 0.95))
	for i: int in 3:
		_kit.ceiling_panel(armory, "Light%d" % i, Vector3(25.0 + i * 5.3, FLOOR + 3.7, -3.2), false, 2.4, 7.0, i == 1)


func _build_garage() -> void:
	var garage: Node3D = _kit.group(_fixtures, "Garage")
	# Deploy point at the overhead shutter.
	var deploy_root: Node3D = _kit.group(garage, "DeployPoint", Vector3(45.5, FLOOR, -0.7))
	deploy_root.rotation_degrees.y = 180.0
	var deploy: DeployDoor = DeployDoor.new()
	deploy.name = "DeployDoor"
	deploy.prompt_text = "Deploy"
	deploy.position = Vector3(0, 1.3, 0)
	deploy_root.add_child(deploy)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "Shape"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(6.6, 2.6, 0.6)
	shape.shape = box
	deploy.add_child(shape)
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.name = "StatusLight"
	lamp.position = Vector3(0, 2.6, 0.3)
	lamp.light_color = Color(1.0, 0.25, 0.2)
	lamp.light_energy = 2.0
	lamp.omni_range = 5.0
	deploy.add_child(lamp)
	var beacon: SphereMesh = SphereMesh.new()
	beacon.radius = 0.12
	beacon.height = 0.24
	_kit.mesh(deploy, "Beacon", beacon, Vector3(-3.7, 1.9, 0.1), _kit.material("led_red"), Vector3.ZERO, false)
	_label(deploy_root, "GARAGE · DEPLOY\nhold [F] at the shutter during a response", Vector3(0, 3.55, 0.25), 0.005, Color(0.9, 0.95, 1.0))
	# Floor markings for the two bays.
	var stripe: BoxMesh = BoxMesh.new()
	stripe.size = Vector3(0.15, 0.01, 11.0)
	for x: float in [45.5]:
		_kit.mesh(garage, "BayDivider", stripe, Vector3(x, FLOOR + 0.005, -6.6), _kit.material("hazard_yellow"), Vector3.ZERO, false)
	# The station's own cruiser in bay 1.
	_vehicle_model(garage, "StationCruiser", Vector3(42.4, FLOOR, -6.5), 180.0)
	# Tool wall, tires and barrels along the west wall.
	_kit.box(garage, "ToolWall", Vector3(38.85, FLOOR + 1.5, -16.0), Vector3(0.08, 1.4, 4.0), _kit.material("metal_painted"), 0.0, false)
	_kit.box(garage, "ToolBench", Vector3(39.2, FLOOR + 0.45, -16.0), Vector3(0.8, 0.9, 4.0), _kit.material("metal_dark"))
	_kit.barrel(garage, "Barrel0", Vector3(39.3, FLOOR, -23.5), "rust_red")
	_kit.barrel(garage, "Barrel1", Vector3(39.4, FLOOR, -24.3), "hazard_yellow")
	var tires: Node3D = _instance(TIRES_SCENE, garage, "Tires", Vector3(39.6, FLOOR, -26.0), 0.0, 0.01)
	if tires != null:
		_kit.collider(garage, "TiresCollider", Vector3(39.6, FLOOR + 0.5, -26.0), Vector3(1.4, 1.0, 1.4))
	_label(garage, "BAY 1", Vector3(42.4, FLOOR + 0.02, -12.0), 0.01, Color(1, 0.85, 0.3), 0.0, true)
	_label(garage, "BAY 2", Vector3(48.6, FLOOR + 0.02, -12.0), 0.01, Color(1, 0.85, 0.3), 0.0, true)
	for i: int in 3:
		_kit.ceiling_panel(garage, "Light%d" % i, Vector3(45.5, FLOOR + 4.4, -4.0 - i * 9.0), false, 3.0, 9.0, i == 0)


func _build_signs() -> void:
	var signs: Node3D = _kit.group(_fixtures, "Signs")
	var white: Color = Color(0.88, 0.92, 0.95)
	# Corridor wayfinding (on the west corridor wall, facing east).
	_label(signs, "← DISPATCH ROOM", Vector3(16.35, FLOOR + 2.2, -21.8), 0.005, white, 90.0)
	_label(signs, "BREAK ROOM ←", Vector3(16.35, FLOOR + 2.2, -14.6), 0.005, white, 90.0)
	_label(signs, "ARMORY  →  GARAGE", Vector3(22.15, FLOOR + 2.2, -5.0), 0.005, Color(1, 0.8, 0.35), -90.0)
	_label(signs, "OPERATIONS →", Vector3(22.15, FLOOR + 2.2, -20.2), 0.005, white, -90.0)
	_label(signs, "MAIN COMPUTER · STATION OS", Vector3(6.0, FLOOR + 1.75, -24.75), 0.003, Color(0.45, 1, 0.6))


func _build_decor() -> void:
	var decor: Node3D = _kit.group(_fixtures, "Decor")
	_instance(RUG_SCENE, decor, "LobbyRug", Vector3(22.0, FLOOR + 0.01, -28.6), 0.0, 0.01)
	_instance(TRASH_SCENE, decor, "TrashGarage", Vector3(51.6, FLOOR + 0.75, -2.0), 0.0, 1.0)


# --- Purchasable items -------------------------------------------------------------------------

func _build_item(item_id: StringName, index: int, holder: Node3D) -> void:
	var item: Dictionary = ShopCatalog.get_item(item_id)
	if item.has("weapon"):
		_build_rack(item_id, item, holder)
		return
	match item_id:
		&"workstation":
			_build_workstation(index, holder)
		&"cad_server":
			holder.position = Vector3(0.9, FLOOR, -19.2)
			if not _model(holder, &"server_rack", "Rack", Vector3.ZERO, 90.0):
				_kit.server_rack(holder, "Rack", Vector3.ZERO, 90.0)
			_label(holder, "CAD SERVER", Vector3(0.95, 2.3, 0), 0.004, Color(0.4, 0.8, 1.0), 90.0)
		&"printer":
			holder.position = Vector3(13.6, FLOOR, -27.2)
			_kit.box(holder, "Stand", Vector3(0, 0.4, 0), Vector3(0.8, 0.8, 0.6), _kit.material("metal_painted"))
			_kit.box(holder, "Printer", Vector3(0, 1.0, 0), Vector3(0.6, 0.4, 0.5), _kit.material("plastic_black"), 0.0, false)
			_kit.box(holder, "Paper", Vector3(0, 1.21, 0.05), Vector3(0.3, 0.02, 0.4), _kit.material("paper_board"), 0.0, false)
		&"radio_console":
			holder.position = Vector3(15.3, FLOOR, -25.8)
			holder.rotation_degrees.y = -90.0
			_kit.desk(holder, "Console", Vector3.ZERO, 0.0, 1, "screen_amber")
			var radio: BoxMesh = BoxMesh.new()
			radio.size = Vector3(0.6, 0.25, 0.3)
			_kit.mesh(holder, "Radio", radio, Vector3(0.6, 0.92, -0.25), _kit.material("metal_dark"))
			_label(holder, "RADIO", Vector3(0, 1.6, -0.35), 0.004, Color(1, 0.72, 0.25))
		&"cctv":
			_build_cctv(holder)
		&"alarm":
			for spot: Vector3 in [Vector3(21.7, 3.9, -33.6), Vector3(19.2, 3.6, -0.35), Vector3(45.5, 5.1, -0.5), Vector3(28.2, 3.6, -29.8)]:
				_beacon(holder, "Beacon%d" % holder.get_child_count(), spot, Color(1, 0.1, 0.08))
		&"floodlights":
			for i: int in 3:
				var pole: Vector3 = Vector3(8.0 + i * 20.0, 0.5, -37.6)
				_kit.cylinder(holder, "Pole%d" % i, pole + Vector3(0, 3.0, 0), 0.08, 6.0, _kit.material("metal_dark"))
				_kit.floodlight(holder, "Flood%d" % i, pole + Vector3(0, 6.0, 0), 180.0, 55.0, 10.0, 30.0)
		&"barricades":
			_kit.jersey_barrier(holder, "BarrierWest", Vector3(17.0, 0.6, -39.4), 90.0)
			_kit.jersey_barrier(holder, "BarrierEast", Vector3(26.6, 0.6, -39.4), 90.0)
			for i: int in 4:
				_kit.cylinder(holder, "Bollard%d" % i, Vector3(19.4 + i * 1.6, 1.1, -39.0), 0.12, 1.0, _kit.material("hazard_yellow"))
		&"metal_detector":
			holder.position = Vector3(21.7, FLOOR, -31.6)
			for side: float in [-0.6, 0.6]:
				_kit.box(holder, "Post%d" % int(side * 10 + 10), Vector3(side, 1.05, 0), Vector3(0.14, 2.1, 0.5), _kit.material("metal_painted"))
			_kit.box(holder, "Top", Vector3(0, 2.15, 0), Vector3(1.34, 0.14, 0.5), _kit.material("metal_painted"), 0.0, false)
			_beacon(holder, "Led", Vector3(0, 2.3, 0), Color(0.2, 1.0, 0.4), 0.4)
		&"sandbags":
			for spot: Vector3 in [Vector3(40.2, FLOOR, -2.2), Vector3(50.8, FLOOR, -2.2)]:
				for layer: int in 3:
					_kit.box(holder, "Bags%d" % holder.get_child_count(), spot + Vector3(0, 0.15 + layer * 0.28, 0),
						Vector3(2.2 - layer * 0.2, 0.28, 0.6), _kit.material("cardboard"))
		&"safe_room":
			_build_safe_room(holder)
		&"ammo_crate":
			_armory_use(holder, "Crate", Vector3(32.8, FLOOR + 0.2, -5.5), 0.0, ArmoryItem.Kind.AMMO, &"", 0.0)
			_label(holder, "AMMO", Vector3(32.8, FLOOR + 0.75, -5.6), 0.004, Color(0.8, 0.9, 0.6))
		&"ammo_bench":
			_kit.box(holder, "Bench", Vector3(40.0, FLOOR + 0.45, -9.5), Vector3(0.9, 0.9, 2.0), _kit.material("wood"))
			_armory_use(holder, "Crate", Vector3(40.0, FLOOR + 1.1, -9.5), 90.0, ArmoryItem.Kind.AMMO, &"", 0.0)
			_label(holder, "RELOAD", Vector3(40.0, FLOOR + 1.6, -9.5), 0.004, Color(0.8, 0.9, 0.6), 90.0)
		&"kevlar_vest", &"plate_carrier", &"riot_gear":
			var x: float = LOCKER_X[item_id]
			var armor: float = item.get("armor", 100)
			var lockers: int = 0
			for offset: float in [-0.27, 0.27]:
				if _model(holder, &"metal_locker", "Locker%d" % lockers, Vector3(x + offset, FLOOR, LOCKER_Z - 0.32), 0.0):
					lockers += 1
			if lockers == 0:
				_kit.box(holder, "Locker", Vector3(x, FLOOR + 1.0, LOCKER_Z - 0.25), Vector3(1.2, 2.0, 0.4), _kit.material("metal_painted"))
			_armory_use(holder, "Vest", Vector3(x, FLOOR + 1.3, LOCKER_Z + 0.02), 0.0, ArmoryItem.Kind.ARMOR, &"", armor)
			_label(holder, "%s\n%d ARMOR" % [str(item["name"]).replace(" Locker", "").to_upper(), roundi(armor)],
				Vector3(x, FLOOR + 0.55, LOCKER_Z + 0.05), 0.0028, Color(0.9, 0.92, 0.95))
		&"first_aid":
			_appliance(holder, "FirstAid", Vector3(16.45, FLOOR + 1.4, -16.2), 90.0, Vector3(0.7, 0.8, 0.3), Color(0.9, 0.9, 0.92),
				StationAppliance.Kind.HEAL, 100.0, "Use first aid station", "Patched up")
			var cross: BoxMesh = BoxMesh.new()
			cross.size = Vector3(0.3, 0.08, 0.02)
			_kit.mesh(holder, "CrossH", cross, Vector3(16.61, FLOOR + 1.45, -16.2), _kit.material("led_red"), Vector3(0, 90, 0), false)
			_kit.mesh(holder, "CrossV", cross, Vector3(16.61, FLOOR + 1.45, -16.2), _kit.material("led_red"), Vector3(0, 90, 90), false)
		&"trauma_cabinet":
			_appliance(holder, "TraumaKits", Vector3(16.45, FLOOR + 1.3, -9.4), 90.0, Vector3(0.9, 1.0, 0.35), Color(0.75, 0.15, 0.12),
				StationAppliance.Kind.TRAUMA_KIT, 0.0, "Take trauma kit", "+1 trauma kit")
			_label(holder, "TRAUMA KITS", Vector3(16.65, FLOOR + 1.95, -9.4), 0.003, Color(1, 0.9, 0.9), 90.0)
		&"infirmary_bed":
			for i: int in 2:
				var at: Vector3 = Vector3(36.9, FLOOR, -14.4 - i * 2.4)
				_kit.box(holder, "Frame%d" % i, at + Vector3(0, 0.3, 0), Vector3(2.0, 0.6, 0.95), _kit.material("steel"))
				_kit.box(holder, "Mattress%d" % i, at + Vector3(0, 0.66, 0), Vector3(1.9, 0.14, 0.9), _kit.material("plaster_blue"), 0.0, false)
				var bed: StationAppliance = _appliance(holder, "Bed%d" % i, at + Vector3(0, 0.75, 0), 0.0, Vector3(2.1, 0.5, 1.05), Color.TRANSPARENT,
					StationAppliance.Kind.HEAL, 100.0, "Rest on the bed", "Rested — fully healed")
				bed.hold_duration = 3.0
			_label(holder, "INFIRMARY", Vector3(38.25, FLOOR + 2.4, -15.6), 0.005, Color(0.9, 0.95, 1.0), -90.0)
		&"coffee_machine":
			_counter(holder, Vector3(1.0, FLOOR, -16.7))
			var coffee_colour: Color = Color.TRANSPARENT if _model(holder, &"coffee_machine", "CoffeeModel", Vector3(1.0, FLOOR + 0.9, -16.78), 0.0, false) else Color(0.15, 0.12, 0.1)
			_appliance(holder, "Coffee", Vector3(1.0, FLOOR + 1.15, -16.75), 0.0, Vector3(0.45, 0.6, 0.4), coffee_colour,
				StationAppliance.Kind.HEAL, 15.0, "Drink coffee", "Coffee  +15 HP")
		&"vending_machine":
			if _model(holder, &"vending_machine", "VendingModel", Vector3(2.4, FLOOR, -16.72), 0.0):
				_appliance(holder, "Vending", Vector3(2.4, FLOOR + 0.95, -16.75), 0.0, Vector3(1.0, 1.9, 0.8), Color.TRANSPARENT,
					StationAppliance.Kind.HEAL, 10.0, "Buy a snack", "Snack  +10 HP")
			else:
				_appliance(holder, "Vending", Vector3(2.4, FLOOR + 0.95, -16.75), 0.0, Vector3(1.0, 1.9, 0.8), Color(0.12, 0.25, 0.55),
					StationAppliance.Kind.HEAL, 10.0, "Buy a snack", "Snack  +10 HP", true)
		&"water_cooler":
			if _model(holder, &"water_dispenser", "CoolerModel", Vector3(3.6, FLOOR, -16.85), 0.0):
				_appliance(holder, "Cooler", Vector3(3.6, FLOOR + 0.65, -16.8), 0.0, Vector3(0.4, 1.3, 0.4), Color.TRANSPARENT,
					StationAppliance.Kind.HEAL, 5.0, "Drink water", "Water  +5 HP")
			else:
				_appliance(holder, "Cooler", Vector3(3.6, FLOOR + 0.6, -16.8), 0.0, Vector3(0.4, 1.2, 0.4), Color(0.85, 0.87, 0.9),
					StationAppliance.Kind.HEAL, 5.0, "Drink water", "Water  +5 HP", true)
				_kit.cylinder(holder, "Bottle", Vector3(3.6, FLOOR + 1.45, -16.8), 0.14, 0.45, _kit.material("screen_blue"), false)
		&"sofa":
			holder.position = Vector3(5.0, FLOOR, -11.3)
			holder.rotation_degrees.y = 180.0
			if _model(holder, &"leather_couch", "Couch", Vector3.ZERO, 0.0):
				_model(holder, &"leather_armchair", "Armchair", Vector3(2.4, 0, 0.9), -35.0)
				return
			_kit.box(holder, "Seat", Vector3(0, 0.25, 0), Vector3(2.4, 0.5, 0.9), _kit.material("fabric_dark"))
			_kit.box(holder, "Back", Vector3(0, 0.7, 0.38), Vector3(2.4, 0.5, 0.18), _kit.material("fabric_dark"), 0.0, false)
			for side: float in [-1.15, 1.15]:
				_kit.box(holder, "Arm%d" % int(side * 10 + 20), Vector3(side, 0.45, 0), Vector3(0.18, 0.4, 0.9), _kit.material("fabric_dark"), 0.0, false)
		&"tv":
			holder.position = Vector3(5.0, FLOOR + 1.9, -17.1)
			_kit.box(holder, "Screen", Vector3.ZERO, Vector3(1.8, 1.0, 0.08), _kit.material("plastic_black"), 0.0, false)
			var panel: BoxMesh = BoxMesh.new()
			panel.size = Vector3(1.7, 0.92, 0.01)
			_kit.mesh(holder, "Picture", panel, Vector3(0, 0, 0.045), _kit.material("screen_map"), Vector3.ZERO, false)
			_label(holder, "CHANNEL 7 · LIVE", Vector3(0, -0.3, 0.06), 0.003, Color(1, 1, 1))
		&"arcade":
			_appliance(holder, "Arcade", Vector3(14.9, FLOOR + 0.95, -16.6), 0.0, Vector3(0.8, 1.9, 0.8), Color(0.35, 0.1, 0.45),
				StationAppliance.Kind.FLAVOR, 0.0, "Play NIGHT SHIFT (arcade)", "GAME OVER — insert coin", true)
			var screen: BoxMesh = BoxMesh.new()
			screen.size = Vector3(0.55, 0.45, 0.02)
			_kit.mesh(holder, "Screen", screen, Vector3(14.9, FLOOR + 1.35, -16.19), _kit.material("screen_amber"), Vector3(-15, 0, 0), false)
		&"pool_table":
			holder.position = Vector3(11.5, FLOOR, -13.9)
			_kit.box(holder, "Table", Vector3(0, 0.42, 0), Vector3(2.5, 0.84, 1.4), _kit.material("wood"))
			var felt: BoxMesh = BoxMesh.new()
			felt.size = Vector3(2.3, 0.02, 1.2)
			var cloth: StandardMaterial3D = StandardMaterial3D.new()
			cloth.albedo_color = Color(0.05, 0.38, 0.18)
			cloth.roughness = 1.0
			_kit.mesh(holder, "Felt", felt, Vector3(0, 0.85, 0), cloth, Vector3.ZERO, false)
			_appliance(holder, "Play", holder.position + Vector3(0, 0.95, 0), 0.0, Vector3(2.6, 0.3, 1.5), Color.TRANSPARENT,
				StationAppliance.Kind.FLAVOR, 0.0, "Shoot pool", "Nice shot")
		&"plants":
			for spot: Vector3 in [Vector3(0.6, FLOOR, -27.2), Vector3(15.5, FLOOR, -27.2), Vector3(17.0, FLOOR, -25.0),
					Vector3(27.8, FLOOR, -32.6), Vector3(0.6, FLOOR, -11.0), Vector3(37.8, FLOOR, -23.4)]:
				_plant(holder, "Plant%d" % holder.get_child_count(), spot)
		&"cruiser":
			var bay: Array = CRUISER_BAYS[mini(index, CRUISER_BAYS.size() - 1)]
			var at: Vector3 = bay[0]
			var yaw: float = bay[1]
			_vehicle_model(holder, "Cruiser", at, yaw)
		&"swat_van":
			if not _model(holder, &"armored_truck", "Van", Vector3(48.6, FLOOR, -18.0), 180.0):
				var van: Node3D = _kit.cruiser(holder, "Van", Vector3(48.6, FLOOR, -18.0), 180.0, true)
				_label(van, "SWAT", Vector3(1.0, 1.3, 0), 0.012, Color(0.9, 0.9, 0.9), 90.0)
		&"ambulance":
			var ambulance: Node3D = _kit.cruiser(holder, "Ambulance", Vector3(44.6, FLOOR, -30.0), 90.0, true)
			var body: MeshInstance3D = ambulance.get_node_or_null(^"Body/Mesh") as MeshInstance3D
			if body != null:
				body.material_override = _kit.material("car_white")
			var stripe: BoxMesh = BoxMesh.new()
			stripe.size = Vector3(1.94, 0.2, 5.62)
			_kit.mesh(ambulance, "Stripe", stripe, Vector3(0, 1.0, 0), _kit.material("led_red"), Vector3.ZERO, false)
			_label(ambulance, "AMBULANCE", Vector3(1.0, 1.4, 0), 0.008, Color(0.8, 0.1, 0.1), 90.0)
		&"training", &"union_deal", &"overtime":
			_certificate(holder, item_id)


func _build_rack(item_id: StringName, item: Dictionary, holder: Node3D) -> void:
	var weapon_id: StringName = item["weapon"]
	var x: float = RACK_X.get(item_id, 30.0)
	var hooks: BoxMesh = BoxMesh.new()
	hooks.size = Vector3(1.3, 0.05, 0.12)
	_kit.mesh(holder, "Hooks", hooks, Vector3(x, FLOOR + 1.3, -0.4), _kit.material("steel"), Vector3.ZERO, false)
	_armory_use(holder, "Weapon", Vector3(x, FLOOR + 1.45, RACK_Z), 180.0, ArmoryItem.Kind.WEAPON, weapon_id, 0.0)


func _build_workstation(index: int, holder: Node3D) -> void:
	var spot: Array = WORKSTATIONS[mini(index, WORKSTATIONS.size() - 1)]
	var at: Vector3 = spot[0]
	var yaw: float = spot[1]
	holder.position = at
	holder.rotation_degrees.y = yaw
	_kit.desk(holder, "Desk", Vector3.ZERO, 0.0, 2)
	_kit.box(holder, "Chair", Vector3(0, 0.25, 0.9), Vector3(0.5, 0.5, 0.5), _kit.material("fabric_dark"), 0.0, false)
	var computer: DispatchComputer = DispatchComputer.new()
	computer.name = "Computer"
	computer.position = Vector3(0, 1.18, -0.28)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.4, 0.55, 0.3)
	shape.shape = box
	computer.add_child(shape)
	holder.add_child(computer)
	_label(holder, "WORKSTATION %d" % (index + 2), Vector3(0, 1.48, -0.36), 0.003, Color(0.45, 1, 0.6))


func _build_cctv(holder: Node3D) -> void:
	for feed: Array in StationOS.CCTV_CAMERAS:
		var at: Vector3 = feed[1]
		var target: Vector3 = feed[2]
		var cam: Node3D = _kit.group(holder, "Cam%d" % holder.get_child_count(), at)
		cam.basis = Basis.looking_at(target - at, Vector3.UP)
		var body: BoxMesh = BoxMesh.new()
		body.size = Vector3(0.14, 0.12, 0.3)
		_kit.mesh(cam, "Body", body, Vector3.ZERO, _kit.material("metal_painted"))
		var lens: SphereMesh = SphereMesh.new()
		lens.radius = 0.035
		lens.height = 0.07
		_kit.mesh(cam, "Lens", lens, Vector3(0, 0, -0.16), _kit.material("glass_dark"), Vector3.ZERO, false)
		_beacon(cam, "Rec", Vector3(0.05, 0.07, -0.1), Color(1, 0.1, 0.1), 0.0)
	# Monitor wall in the dispatch room (west wall, next to the supervisor).
	var wall: Node3D = _kit.group(holder, "MonitorWall", Vector3(0.35, FLOOR + 2.1, -19.6))
	wall.rotation_degrees.y = 90.0
	for i: int in 6:
		var screen: BoxMesh = BoxMesh.new()
		screen.size = Vector3(0.62, 0.36, 0.04)
		_kit.mesh(wall, "Screen%d" % i, screen, Vector3((i % 3 - 1) * 0.66, 0.2 - (i / 3) * 0.4, 0), _kit.material("screen_blue"), Vector3.ZERO, false)
	_label(wall, "CCTV", Vector3(0, 0.62, 0.03), 0.004, Color(1, 0.4, 0.35))


func _build_safe_room(holder: Node3D) -> void:
	holder.position = Vector3(24.8, FLOOR, -21.6)
	var bars: Material = _kit.material("steel")
	# Cage 4 × 4 m with an opening on the east side.
	for i: int in 11:
		_kit.cylinder(holder, "BarN%d" % i, Vector3(-2.0 + i * 0.4, 1.3, -2.0), 0.03, 2.6, bars)
		_kit.cylinder(holder, "BarS%d" % i, Vector3(-2.0 + i * 0.4, 1.3, 2.0), 0.03, 2.6, bars)
		_kit.cylinder(holder, "BarW%d" % i, Vector3(-2.0, 1.3, -2.0 + i * 0.4), 0.03, 2.6, bars)
		if i < 3 or i > 7:
			_kit.cylinder(holder, "BarE%d" % i, Vector3(2.0, 1.3, -2.0 + i * 0.4), 0.03, 2.6, bars)
	_kit.box(holder, "Roof", Vector3(0, 2.62, 0), Vector3(4.1, 0.06, 4.1), _kit.material("metal_dark"), 0.0, false)
	_kit.box(holder, "Shelf", Vector3(-1.6, 0.5, 0), Vector3(0.6, 1.0, 1.6), _kit.material("metal_painted"))
	_appliance(holder, "MedKit", holder.position + Vector3(-1.6, 1.15, 0), 90.0, Vector3(0.5, 0.3, 0.7), Color(0.9, 0.9, 0.92),
		StationAppliance.Kind.HEAL, 100.0, "Use emergency med kit", "Safe room: fully healed")
	_label(holder, "SAFE ROOM", Vector3(2.05, 2.3, 0), 0.005, Color(1, 0.8, 0.3), 90.0)


func _certificate(holder: Node3D, item_id: StringName) -> void:
	var offsets: Dictionary[StringName, float] = {&"training": 0.0, &"union_deal": 1.0, &"overtime": 2.0}
	var x: float = 2.2 + offsets.get(item_id, 0.0) * 1.0
	holder.position = Vector3(x, FLOOR + 2.0, -27.62)
	_kit.box(holder, "Frame", Vector3.ZERO, Vector3(0.7, 0.5, 0.03), _kit.material("wood"), 0.0, false)
	var paper: BoxMesh = BoxMesh.new()
	paper.size = Vector3(0.6, 0.4, 0.01)
	_kit.mesh(holder, "Paper", paper, Vector3(0, 0, 0.02), _kit.material("paper_board"), Vector3.ZERO, false)
	_label(holder, str(ShopCatalog.get_item(item_id).get("name", item_id)).to_upper(), Vector3(0, 0, 0.03), 0.0018, Color(0.15, 0.15, 0.2))


# --- Builders ----------------------------------------------------------------------------------

func _armory_use(holder: Node3D, node_name: String, at: Vector3, yaw: float, kind: ArmoryItem.Kind, weapon_id: StringName, armor: float) -> ArmoryItem:
	var use: ArmoryItem = ArmoryItem.new()
	use.name = node_name
	use.kind = kind
	if weapon_id != &"":
		use.weapon_id = weapon_id
	if armor > 0.0:
		use.armor_amount = armor
	use.position = holder.transform.affine_inverse() * at
	use.rotation_degrees.y = yaw
	holder.add_child(use)
	return use


## A usable box (`at` in world space): visual (unless `colour` is transparent), optional collision and the interaction area.
func _appliance(holder: Node3D, node_name: String, at: Vector3, yaw: float, box_size: Vector3, colour: Color,
		kind: StationAppliance.Kind, heal: float, prompt: String, message: String, solid: bool = false) -> StationAppliance:
	var local: Vector3 = holder.transform.affine_inverse() * at
	if colour.a > 0.0:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = 0.6
		_kit.box(holder, node_name + "Body", local, box_size, material, yaw, solid)
	var use: StationAppliance = StationAppliance.new()
	use.name = node_name
	use.kind = kind
	use.heal_amount = heal
	use.prompt_text = prompt
	use.use_message = message
	use.box_size = box_size + Vector3(0.1, 0.1, 0.1)
	use.position = local
	use.rotation_degrees.y = yaw
	holder.add_child(use)
	return use


func _counter(holder: Node3D, at: Vector3) -> void:
	_kit.box(holder, "Counter", at - holder.position + Vector3(0, 0.45, 0), Vector3(1.0, 0.9, 0.6), _kit.material("desk_laminate"))


func _plant(holder: Node3D, node_name: String, at: Vector3) -> void:
	var plant: Node3D = _kit.group(holder, node_name, at)
	_kit.cylinder(plant, "Pot", Vector3(0, 0.25, 0), 0.22, 0.5, _kit.material("rust_red"), true, 0.26)
	var leaves: StandardMaterial3D = StandardMaterial3D.new()
	leaves.albedo_color = Color(0.16, 0.42, 0.18)
	leaves.roughness = 0.9
	for i: int in 3:
		var bush: SphereMesh = SphereMesh.new()
		bush.radius = 0.32 - i * 0.06
		bush.height = (0.32 - i * 0.06) * 2.0
		_kit.mesh(plant, "Leaves%d" % i, bush, Vector3(0.05 * (i - 1), 0.75 + i * 0.28, 0.04 * i), leaves)


func _beacon(parent: Node3D, node_name: String, at: Vector3, colour: Color, energy: float = 1.2) -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 2.0
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.05 if energy <= 0.0 else 0.1
	sphere.height = sphere.radius * 2.0
	_kit.mesh(parent, node_name, sphere, at, material, Vector3.ZERO, false)
	if energy > 0.0:
		var light: OmniLight3D = _kit.own(OmniLight3D.new(), parent, node_name + "Light") as OmniLight3D
		light.position = at
		light.light_color = colour
		light.light_energy = energy
		light.omni_range = 3.0


## Imported prop `prop_id` (ModelKit.PROPS) at `at` in `holder` space (holders left at the origin take world
## positions), with a box collider unless `solid` is false. False when the model is missing (callers fall
## back to primitives).
func _model(holder: Node3D, prop_id: StringName, node_name: String, at: Vector3, yaw: float, solid: bool = true) -> bool:
	var wrapper: Node3D = ModelKit.prop(holder, prop_id, node_name, at, yaw)
	if wrapper == null:
		return false
	if solid:
		ModelKit.add_collider(wrapper)
	return true


## The imported cop car, centred on `at` with a box collider around it. Faces the shutter at yaw 180.
func _vehicle_model(parent: Node3D, node_name: String, at: Vector3, yaw: float) -> void:
	var wrapper: Node3D = _kit.group(parent, node_name, at)
	wrapper.rotation_degrees.y = yaw
	var model: Node3D = _instance(CRUISER_SCENE, wrapper, "Model", Vector3.ZERO, 90.0, 1.1)
	var size: Vector3 = Vector3(2.0, 1.7, 5.6)
	if model != null:
		var bounds: AABB = _local_bounds(model)
		model.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
		size = bounds.size
	_kit.collider(wrapper, "Collider", Vector3(0, size.y * 0.5, 0), size)


func _instance(path: String, parent: Node3D, node_name: String, at: Vector3, yaw: float, scale_factor: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return null
	var node: Node3D = scene.instantiate() as Node3D
	if node == null:
		return null
	node.name = node_name
	node.position = at
	node.rotation_degrees.y = yaw
	node.scale = Vector3.ONE * scale_factor
	parent.add_child(node)
	return node


## Bounds of every mesh under `model`, in the space of `model`'s parent.
func _local_bounds(model: Node3D) -> AABB:
	var parent_inverse: Transform3D = Transform3D.IDENTITY
	var bounds: AABB = AABB()
	var first: bool = true
	var to_parent: Transform3D = model.transform
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var local: Transform3D = parent_inverse * to_parent * _relative_transform(model, mesh_instance)
		var box: AABB = local * mesh_instance.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _relative_transform(ancestor: Node3D, node: Node3D) -> Transform3D:
	var result: Transform3D = Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		var spatial: Node3D = current as Node3D
		if spatial != null:
			result = spatial.transform * result
		current = current.get_parent()
	return result


func _label(parent: Node3D, text: String, at: Vector3, pixel: float, colour: Color, yaw: float = 0.0, flat: bool = false) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text
	label.pixel_size = pixel
	label.font_size = 64
	label.outline_size = 10
	label.modulate = colour
	label.position = at
	label.rotation_degrees = Vector3(-90.0 if flat else 0.0, yaw, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label
