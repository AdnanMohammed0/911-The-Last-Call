## Builds the editable, static Station 4 interior dressing scene.
## Run: godot --headless --path . tools/level_kit/furnish_station.tscn
## Rebuilds station_interior.tscn only. Imported models retain their scene references.
extends Node

const OUTPUT: String = "res://scenes/dispatch/station/station_interior.tscn"
const FLOOR: float = 0.85
const ART: String = "res://assets/3D/"
const CHAIR: String = ART + "chair/office_chair_modern.glb"
const WAITING: String = ART + "chair/waiting_chair.glb"
const FILES: String = ART + "lockers/box_for_documents_or_other_papers..glb"
const PAPERS: String = ART + "growd_papers/papers__envelopes.glb"
const PHONE: String = ART + "phone/office_phone.glb"
const PLANT: String = ART + "Plants/house_plant.glb"
const POT: String = ART + "Plants/potted_plant.glb"
const LOCKER: String = ART + "station_props/metal_locker.glb"
const BIN: String = ART + "stuff/trash_can(1).glb"

var interior: Node3D
var kit: LevelKit
var mats: Dictionary[String, StandardMaterial3D] = {}
var model_count: int = 0


func _ready() -> void:
	call_deferred("build")


func build() -> void:
	interior = Node3D.new()
	interior.name = "StationInterior"
	kit = LevelKit.new(interior)
	_materials()
	_dispatch()
	_break_room()
	_operations()
	_evidence()
	_staff_support()
	_gallery()
	_corridor()
	_washroom()
	_garage()
	_utilities()
	var packed: PackedScene = PackedScene.new()
	var result: Error = packed.pack(interior)
	if result == OK:
		result = ResourceSaver.save(packed, OUTPUT)
	print("STATION_INTERIOR: %d imported model instances; save result %d" % [model_count, result])
	interior.free()
	get_tree().quit(0 if result == OK else 1)


func _materials() -> void:
	_material("enamel", Color("424d49"), 0.67, 0.3)
	_material("steel", Color("798281"), 0.38, 0.75)
	_material("dark", Color("202a2d"), 0.75, 0.25)
	_material("wood", Color("6d4f35"), 0.8)
	_material("laminate", Color("9e9b84"), 0.68)
	_material("paper", Color("d3c8a8"), 1.0)
	_material("cardboard", Color("8b7450"), 0.95)
	_material("cork", Color("776046"), 1.0)
	_material("white", Color("c8cbbd"), 0.45)
	_material("red", Color("9e352b"), 0.6)
	_material("amber", Color("c28e3e"), 0.65)
	_material("teal", Color("345854"), 0.85)
	_material("rubber", Color("262b2b"), 0.95)
	_material("water", Color("152f33"), 0.1, 0.5)
	_material("tube", Color("d9e4cc"), 0.35)
	mats["tube"].emission_enabled = true
	mats["tube"].emission = Color("bfd4c7")
	mats["tube"].emission_energy_multiplier = 1.4


func _material(key: String, color: Color, roughness: float, metallic: float = 0.0) -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.resource_name = "Interior_" + key
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mats[key] = mat


func _zone(label: String) -> Node3D:
	return kit.group(interior, label)


func _box(parent: Node3D, label: String, at: Vector3, size: Vector3, material: String, solid: bool = false) -> Node3D:
	return kit.box(parent, label, at, size, mats[material], 0.0, solid)


func _model(parent: Node3D, path: String, label: String, at: Vector3, yaw: float, size: float,
		fit: ModelKit.Fit = ModelKit.Fit.HEIGHT, solid: bool = true, base_yaw: float = 0.0) -> Node3D:
	if parent.has_node(NodePath(label)):
		label += "_%03d" % model_count
	var prop: Node3D = ModelKit.place(parent, path, label, at, yaw, fit, size, base_yaw)
	assert(prop != null, "Missing interior model: " + path)
	prop.owner = interior
	var model: Node3D = prop.get_node("Model") as Node3D
	model.owner = interior
	if solid:
		var body: StaticBody3D = ModelKit.add_collider(prop)
		body.owner = interior
		body.get_child(0).owner = interior
	model_count += 1
	return prop


func _label(parent: Node3D, value: String, at: Vector3, size: float = 0.0025,
		color: Color = Color("d7d5bc")) -> Label3D:
	var label: Label3D = kit.own(Label3D.new(), parent, "Caption") as Label3D
	label.text = value
	label.position = at
	label.pixel_size = size
	label.font_size = 40
	label.outline_size = 0
	label.modulate = color
	label.no_depth_test = false
	label.shaded = true
	return label


func _sign(parent: Node3D, name_tag: String, value: String, at: Vector3, yaw: float, width: float = 1.5) -> void:
	var sign_node: Node3D = kit.group(parent, name_tag, at)
	sign_node.rotation_degrees.y = yaw
	_box(sign_node, "Plate", Vector3.ZERO, Vector3(width, 0.28, 0.035), "dark")
	_box(sign_node, "Stripe", Vector3(-width * 0.5 + 0.035, 0, 0.02), Vector3(0.03, 0.23, 0.008), "amber")
	_label(sign_node, value, Vector3(0, 0, 0.025), 0.002)


func _light(parent: Node3D, label: String, at: Vector3, warm: bool = false, shadow: bool = false) -> void:
	var fixture: Node3D = kit.group(parent, label, at)
	_box(fixture, "Housing", Vector3.ZERO, Vector3(1.28, 0.09, 0.32), "dark")
	for x: float in [-0.095, 0.095]:
		_box(fixture, "Tube", Vector3(0, -0.055, x), Vector3(1.18, 0.035, 0.045), "tube")
	var spot: SpotLight3D = kit.own(SpotLight3D.new(), fixture, "Light") as SpotLight3D
	spot.position.y = -0.12
	spot.rotation_degrees.x = -90
	spot.light_color = Color(1, 0.83, 0.61) if warm else Color(0.72, 0.85, 0.88)
	spot.light_energy = 2.8
	spot.spot_range = 7.0
	spot.spot_angle = 70.0
	spot.spot_attenuation = 0.7
	spot.shadow_enabled = shadow
	spot.distance_fade_enabled = true
	spot.distance_fade_begin = 22.0
	spot.distance_fade_length = 8.0
	var fill: OmniLight3D = kit.own(OmniLight3D.new(), fixture, "CeilingBounce") as OmniLight3D
	fill.position.y = -0.4
	fill.omni_range = 5.0
	fill.light_energy = 0.3
	fill.light_color = spot.light_color
	fill.distance_fade_enabled = true
	fill.distance_fade_begin = 18.0
	fill.distance_fade_length = 8.0


func _table(parent: Node3D, label: String, at: Vector3, width: float, depth: float, height: float = 0.76) -> Node3D:
	var table: Node3D = kit.group(parent, label, at)
	_box(table, "Top", Vector3(0, height, 0), Vector3(width, 0.07, depth), "wood", true)
	_box(table, "Inset", Vector3(0, height + 0.04, 0), Vector3(width - 0.08, 0.012, depth - 0.08), "laminate")
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			_box(table, "Leg", Vector3(x * (width / 2 - 0.13), height / 2, z * (depth / 2 - 0.13)), Vector3(0.055, height, 0.055), "dark")
	return table


func _cabinet(parent: Node3D, label: String, at: Vector3, width: float, yaw: float = 0.0) -> Node3D:
	var cabinet: Node3D = kit.group(parent, label, at)
	cabinet.rotation_degrees.y = yaw
	_box(cabinet, "Body", Vector3(0, 0.46, 0), Vector3(width, 0.86, 0.58), "enamel", true)
	_box(cabinet, "Countertop", Vector3(0, 0.92, 0), Vector3(width + 0.06, 0.06, 0.64), "laminate")
	var count: int = maxi(2, roundi(width / 0.65))
	for i: int in count:
		var x: float = -width / 2 + (i + 0.5) * width / count
		_box(cabinet, "Door", Vector3(x, 0.47, 0.3), Vector3(width / count - 0.025, 0.76, 0.025), "teal")
		_box(cabinet, "Handle", Vector3(x + width / count * 0.3, 0.57, 0.335), Vector3(0.025, 0.14, 0.035), "steel")
	return cabinet


func _archive_shelf(parent: Node3D, label: String, at: Vector3, yaw: float, number: int) -> void:
	var shelf: Node3D = kit.group(parent, label, at)
	shelf.rotation_degrees.y = yaw
	for x: float in [-1.05, 1.05]:
		for z: float in [-0.3, 0.3]:
			_box(shelf, "Upright", Vector3(x, 1.12, z), Vector3(0.045, 2.24, 0.045), "dark")
	for tier: int in 4:
		var y: float = 0.17 + tier * 0.55
		_box(shelf, "Shelf", Vector3(0, y, 0), Vector3(2.15, 0.035, 0.65), "enamel")
		for col: int in 4:
			if (col + tier + number) % 7 == 0:
				continue
			var x: float = -0.78 + col * 0.52
			var box_node: Node3D = _box(shelf, "EvidenceBox", Vector3(x, y + 0.19, 0), Vector3(0.45, 0.34, 0.5), "cardboard")
			_box(box_node, "Lid", Vector3(0, 0.16, 0), Vector3(0.47, 0.035, 0.52), "paper")
			_box(box_node, "Label", Vector3(0, 0.01, 0.253), Vector3(0.24, 0.13, 0.006), "paper")
			_label(box_node, "%02d-%03d\nSEALED" % [number, tier * 4 + col + 1], Vector3(0, 0.01, 0.26), 0.00052, Color("343731"))
	kit.collider(shelf, "ShelfCollider", Vector3(0, 1.12, 0), Vector3(2.18, 2.24, 0.68))
	_sign(shelf, "BayNumber", "ARCHIVE / %02d" % number, Vector3(0, 2.33, 0.06), 0.0, 1.4)


func _board(parent: Node3D, label: String, title: String, at: Vector3, yaw: float, width: float = 2.4) -> void:
	var board: Node3D = kit.group(parent, label, at)
	board.rotation_degrees.y = yaw
	_box(board, "Frame", Vector3.ZERO, Vector3(width, 1.4, 0.075), "wood")
	_box(board, "Cork", Vector3(0, 0, 0.043), Vector3(width - 0.07, 1.33, 0.02), "cork")
	_sign(board, "Title", title, Vector3(0, 0.53, 0.07), 0, width - 0.15)
	for i: int in 6:
		var sheet: Node3D = kit.group(board, "Notice%d" % i, Vector3(-width * 0.32 + (i % 3) * width * 0.32, 0.12 - (i / 3) * 0.48, 0.065))
		sheet.rotation_degrees.z = float((i * 7) % 9 - 4)
		_box(sheet, "Paper", Vector3.ZERO, Vector3(width * 0.24, 0.4, 0.006), "paper")
		_box(sheet, "Pin", Vector3(0, 0.18, 0.008), Vector3(0.022, 0.022, 0.016), "red")
		for line: int in 5:
			_box(sheet, "TextLine", Vector3(-0.025, 0.12 - line * 0.05, 0.005), Vector3(width * (0.15 if line % 2 == 0 else 0.18), 0.008, 0.002), "dark")


func _mug(parent: Node3D, at: Vector3) -> void:
	var cup: Node3D = kit.group(parent, "CoffeeMug", at)
	kit.cylinder(cup, "Cup", Vector3(0, 0.055, 0), 0.042, 0.11, mats["white"], false)
	kit.cylinder(cup, "Coffee", Vector3(0, 0.112, 0), 0.034, 0.002, mats["wood"], false)
	_box(cup, "HandleTop", Vector3(0.055, 0.085, 0), Vector3(0.035, 0.015, 0.018), "white")
	_box(cup, "HandleSide", Vector3(0.071, 0.055, 0), Vector3(0.015, 0.06, 0.018), "white")
	_box(cup, "HandleBottom", Vector3(0.055, 0.025, 0), Vector3(0.035, 0.015, 0.018), "white")


func _binders(parent: Node3D, at: Vector3) -> void:
	var files: Node3D = kit.group(parent, "CaseBinders", at)
	for i: int in 5:
		var binder: Node3D = _box(files, "Binder", Vector3(-0.15 + i * 0.075, 0.16, 0), Vector3(0.065, 0.32, 0.24), "teal" if i % 2 == 0 else "wood")
		_box(binder, "SpineLabel", Vector3(0, 0.035, 0.124), Vector3(0.042, 0.13, 0.006), "paper")
		_box(binder, "FingerHole", Vector3(0, -0.09, 0.128), Vector3(0.018, 0.02, 0.008), "dark")
	for side: float in [-0.22, 0.22]:
		_box(files, "Bookend", Vector3(side, 0.12, 0), Vector3(0.012, 0.24, 0.25), "steel")


func _dispatch() -> void:
	var room: Node3D = _zone("Dispatch")
	for i: int in 3:
		var cabinet: Node3D = _cabinet(room, "CallArchives%d" % i, Vector3(4.2 + i * 3.0, FLOOR, -17.88), 2.4, 180)
		_binders(cabinet, Vector3(0.4, 0.95, 0))
		_model(cabinet, PAPERS, "ShiftPaperwork", Vector3(-0.65, 0.95, 0), 12, 0.4, ModelKit.Fit.WIDTH, false)
	_board(room, "DutyRoster", "DISPATCH / NIGHT SHIFT", Vector3(9, 3.05, -17.58), 180, 3.2)
	_model(room, PHONE, "SupervisorTelephone", Vector3(2.6, 1.65, -22.3), 12, 0.3, ModelKit.Fit.WIDTH, false)
	_model(room, PAPERS, "SupervisorReports", Vector3(1.5, 1.65, -22.2), -8, 0.42, ModelKit.Fit.WIDTH, false)
	_model(room, BIN, "PaperBin", Vector3(3.8, FLOOR, -22.9), 0, 0.48)
	_sign(room, "DeskIdentifier", "04 / DISPATCH", Vector3(12, 3.2, -27.78), 0, 2.0)
	_model(room, FILES, "CallFileCabinet", Vector3(12.1, FLOOR, -27.3), 0, 1.75)


func _break_room() -> void:
	var room: Node3D = _zone("BreakRoom")
	var dining: Node3D = _table(room, "NightShiftTable", Vector3(7, FLOOR, -14.7), 2.4, 1.05)
	for x: float in [-0.72, 0.72]:
		_model(dining, CHAIR, "DiningChair", Vector3(x, 0, -1.04), 0, 0.95)
		_model(dining, CHAIR, "DiningChair", Vector3(x, 0, 1.04), 180, 0.95)
	_mug(dining, Vector3(-0.72, 0.805, -0.26))
	_mug(dining, Vector3(0.72, 0.805, 0.26))
	_model(dining, PAPERS, "Newspaper", Vector3(0, 0.805, 0), 9, 0.44, ModelKit.Fit.WIDTH, false)
	var counter: Node3D = _cabinet(room, "KitchenSideboard", Vector3(0.73, FLOOR, -14.1), 2.6, 90)
	_box(counter, "SinkRim", Vector3(0, 0.96, 0), Vector3(0.66, 0.025, 0.45), "steel")
	_box(counter, "SinkBowl", Vector3(0, 0.975, 0), Vector3(0.56, 0.015, 0.35), "dark")
	kit.cylinder(counter, "Tap", Vector3(0, 1.1, -0.22), 0.017, 0.27, mats["steel"], false)
	_box(counter, "Spout", Vector3(0, 1.23, -0.14), Vector3(0.03, 0.03, 0.18), "steel")
	_mug(counter, Vector3(0.75, 0.95, 0))
	_mug(counter, Vector3(1.0, 0.95, 0.1))
	_board(room, "StaffNotices", "STAFF NOTICES / NIGHT SHIFT", Vector3(9.5, 2.9, -17.12), 0)
	_model(room, BIN, "KitchenBin", Vector3(0.75, FLOOR, -12.15), 0, 0.58)
	_board(room, "SafetyNotice", "END OF SHIFT / CHECKLIST", Vector3(12.8, 2.85, -10.79), 180, 2.1)
	_sign(room, "RoomPlate", "STAFF / BREAK ROOM", Vector3(15.9, 3.55, -14.8), -90, 1.8)
	_light(room, "WarmFluorescent", Vector3(4, 4.48, -14), true)
	_light(room, "TableLight", Vector3(10, 4.48, -14.7), true, true)


func _operations() -> void:
	var room: Node3D = _zone("Briefing")
	var table: Node3D = _table(room, "BriefingTable", Vector3(31, FLOOR, -19.7), 4.5, 1.6)
	for x: float in [-1.5, 0.0, 1.5]:
		_model(table, CHAIR, "BriefingChair", Vector3(x, 0, -1.35), 0, 1.1)
		_model(table, CHAIR, "BriefingChair", Vector3(x, 0, 1.35), 180, 1.1)
	_model(table, CHAIR, "CommanderChair", Vector3(2.85, 0, 0), -90, 1.15)
	for x: float in [-1.5, 0.0, 1.5]:
		_model(table, PAPERS, "CaseNotes", Vector3(x, 0.805, 0.25), x * 9, 0.42, ModelKit.Fit.WIDTH, false)
		_mug(table, Vector3(x + 0.35, 0.805, -0.45))
	_box(table, "MapBacking", Vector3(0, 0.81, -0.15), Vector3(1.25, 0.012, 0.65), "teal")
	for i: int in 5:
		_box(table, "MapRoad", Vector3(-0.5 + i * 0.25, 0.819, -0.15), Vector3(0.01, 0.002, 0.6), "paper")
	_board(room, "CaseBriefing", "ACTIVE CASES / STATION 04", Vector3(31.5, 3.05, -23.86), 0, 4.0)
	var cabinet: Node3D = _cabinet(room, "BriefingCredenza", Vector3(31.5, FLOOR, -23.4), 4.0)
	_binders(cabinet, Vector3(-1.15, 0.95, 0))
	_model(cabinet, PHONE, "InternalPhone", Vector3(1.2, 0.95, 0), 0, 0.32, ModelKit.Fit.WIDTH, false)
	_model(room, PLANT, "CornerPlant", Vector3(35.2, FLOOR, -23.15), 25, 1.5)
	_model(room, FILES, "CaseCabinetA", Vector3(37.65, FLOOR, -21.5), -90, 1.8)
	_model(room, FILES, "CaseCabinetB", Vector3(37.65, FLOOR, -20.3), -90, 1.8)
	_sign(room, "BriefingSign", "OPERATIONS / BRIEFING", Vector3(28.7, 3.8, -23.88), 0, 2.3)
	_light(room, "TableFluorescentA", Vector3(29.3, 4.48, -19.7), false, true)
	_light(room, "TableFluorescentB", Vector3(33, 4.48, -19.7))
	_light(room, "MedicalCornerLight", Vector3(35.7, 4.48, -14.8))


func _evidence() -> void:
	var room: Node3D = _zone("EvidenceArchive")
	for i: int in 4:
		_archive_shelf(room, "NorthBay%d" % i, Vector3(25.1 + i * 3.4, FLOOR, -11.82), 0, i + 1)
		var south_x: float = [24.7, 27.2, 34.3, 36.8][i]
		_archive_shelf(room, "SouthBay%d" % i, Vector3(south_x, FLOOR, -7.05), 180, i + 5)
	var table: Node3D = _table(room, "IntakeTable", Vector3(32.0, FLOOR, -9.45), 2.8, 0.95, 0.9)
	_binders(table, Vector3(0.7, 0.945, 0))
	_model(table, PAPERS, "ChainOfCustody", Vector3(-0.8, 0.945, 0), 0, 0.48, ModelKit.Fit.WIDTH, false)
	_box(table, "SealedBag", Vector3(-0.05, 0.96, -0.1), Vector3(0.3, 0.04, 0.4), "paper")
	_box(table, "EvidenceSeal", Vector3(-0.05, 0.985, -0.1), Vector3(0.045, 0.008, 0.4), "red")
	_sign(room, "RestrictedSign", "EVIDENCE / AUTHORIZED STAFF ONLY", Vector3(30.4, 3.55, -12.28), 0, 3.4)
	_light(room, "ArchiveLightA", Vector3(26, 4.48, -9.4))
	_light(room, "ArchiveLightB", Vector3(33, 4.48, -9.4), false, true)


func _staff_support() -> void:
	var room: Node3D = _zone("StaffLockers")
	for i: int in 8:
		_model(room, LOCKER, "PersonalLocker%02d" % i, Vector3(0.8, FLOOR, -9.2 + i * 0.9), 90, 1.95)
		_sign(room, "LockerNumber%02d" % i, "%02d" % (i + 1), Vector3(1.16, 2.48, -9.2 + i * 0.9), 90, 0.23)
	for z: float in [-7.5, -4.0]:
		_table(room, "ChangingBench", Vector3(3.4, FLOOR, z), 3.4, 0.5, 0.43)
	var desk: Node3D = _table(room, "DutySergeantDesk", Vector3(8.9, FLOOR, -2.2), 2.6, 1.1)
	_model(desk, CHAIR, "SergeantChair", Vector3(0, 0, -1.05), 0, 1.1)
	_model(desk, PHONE, "DutyTelephone", Vector3(0.8, 0.805, -0.1), 180, 0.3, ModelKit.Fit.WIDTH, false)
	_binders(desk, Vector3(-0.7, 0.805, -0.1))
	_model(desk, PAPERS, "DutySheet", Vector3(0, 0.805, 0.1), 7, 0.4, ModelKit.Fit.WIDTH, false)
	_board(room, "RosterBoard", "ROLL CALL / LOCKER ASSIGNMENTS", Vector3(7, 3.0, -10.31), 0, 3.0)
	_model(room, WAITING, "StaffBench", Vector3(8.7, FLOOR, -9.5), 0, 2.5, ModelKit.Fit.WIDTH)
	_model(room, PLANT, "StaffPlant", Vector3(11.4, FLOOR, -0.9), 15, 1.45)
	_model(room, BIN, "StaffBin", Vector3(10.8, FLOOR, -2.2), 0, 0.55)
	_model(room, FILES, "PersonnelCabinet", Vector3(11.6, FLOOR, -3.8), -90, 1.75)
	_light(room, "LockerLight", Vector3(3.5, 4.48, -6), false, true)
	_light(room, "DutyLight", Vector3(9, 4.48, -4.5), true)


func _gallery() -> void:
	var room: Node3D = _zone("PublicGallery")
	_model(room, WAITING, "VisitorBenchA", Vector3(31.5, FLOOR, -32.65), 0, 2.4, ModelKit.Fit.WIDTH)
	_model(room, WAITING, "VisitorBenchB", Vector3(36, FLOOR, -32.65), 0, 2.4, ModelKit.Fit.WIDTH)
	var table: Node3D = _table(room, "PublicFormsTable", Vector3(33.8, FLOOR, -31.1), 1.4, 0.65, 0.5)
	_model(table, PAPERS, "PublicForms", Vector3(0, 0.545, 0), 0, 0.48, ModelKit.Fit.WIDTH, false)
	_model(room, PLANT, "GalleryPlant", Vector3(37.7, FLOOR, -25.0), 35, 1.6)
	_board(room, "CommunityNotices", "COMMUNITY / MISSING PERSONS", Vector3(33.3, 2.85, -24.43), 180, 3.6)
	var cabinet: Node3D = _cabinet(room, "PublicRecordsCabinet", Vector3(33.3, FLOOR, -24.95), 3.5, 180)
	_binders(cabinet, Vector3(0.9, 0.95, 0))
	_model(cabinet, POT, "CounterPlant", Vector3(-1.1, 0.95, 0), 0, 0.48, ModelKit.Fit.HEIGHT, false)
	_sign(room, "VisitorSign", "PUBLIC RECORDS / PLEASE TAKE A SEAT", Vector3(33.5, 3.6, -32.98), 0, 3.5)
	_light(room, "VisitorLightA", Vector3(31.4, 4.48, -28.9), true)
	_light(room, "VisitorLightB", Vector3(36.5, 4.48, -28.9), true)


func _corridor() -> void:
	var room: Node3D = _zone("Corridor")
	_board(room, "ShiftNoticeboard", "STATION 04 / NIGHT WATCH", Vector3(16.43, 2.85, -3.4), 90, 2.0)
	for z: float in [-21.5, -14.5, -7.0, -2.0]:
		_light(room, "CorridorFluorescent", Vector3(19.1, 4.48, z))
	_sign(room, "NorthWayfinding", "DISPATCH  /  BRIEFING", Vector3(19.0, 3.65, -23.93), 0, 2.8)
	_sign(room, "SouthWayfinding", "ARMORY  /  EXIT", Vector3(19.2, 3.65, -0.38), 180, 2.2)
	for z: float in [-22.3, -10.6]:
		var extinguisher: Node3D = kit.group(room, "FirePoint", Vector3(21.96, 1.9, z))
		extinguisher.rotation_degrees.y = -90
		kit.cylinder(extinguisher, "Cylinder", Vector3.ZERO, 0.09, 0.45, mats["red"], false)
		_box(extinguisher, "Handle", Vector3(0, 0.26, 0), Vector3(0.16, 0.06, 0.05), "dark")
		_box(extinguisher, "InstructionLabel", Vector3(0, 0, 0.09), Vector3(0.09, 0.17, 0.006), "paper")
		_sign(extinguisher, "FireSign", "FIRE", Vector3(0, 0.6, 0), 0, 0.42)


func _washroom() -> void:
	var room: Node3D = _zone("Washroom")
	for x: float in [13.2, 14.9]:
		var toilet: Node3D = kit.group(room, "ToiletStall", Vector3(x, FLOOR, -9.7))
		_box(toilet, "Cistern", Vector3(0, 0.63, -0.16), Vector3(0.42, 0.65, 0.22), "white", true)
		kit.cylinder(toilet, "Pedestal", Vector3(0, 0.21, 0.2), 0.17, 0.42, mats["white"], false)
		var bowl: SphereMesh = SphereMesh.new()
		bowl.radius = 0.25
		bowl.height = 0.32
		kit.mesh(toilet, "Bowl", bowl, Vector3(0, 0.39, 0.25), mats["white"], Vector3.ZERO, false)
		_box(toilet, "Seat", Vector3(0, 0.53, 0.25), Vector3(0.42, 0.045, 0.52), "white")
		_box(toilet, "Flush", Vector3(0.12, 0.95, -0.15), Vector3(0.05, 0.025, 0.06), "steel")
		_box(toilet, "Partition", Vector3(0.7, 1.08, 0.35), Vector3(0.045, 1.9, 1.7), "enamel", true)
	var sink: Node3D = _cabinet(room, "WashbasinUnit", Vector3(14.0, FLOOR, -4.99), 2.3, 180)
	for x: float in [-0.57, 0.57]:
		_box(sink, "Basin", Vector3(x, 0.96, 0), Vector3(0.72, 0.04, 0.48), "white")
		_box(sink, "BasinInset", Vector3(x, 0.985, 0), Vector3(0.56, 0.01, 0.32), "water")
		kit.cylinder(sink, "Faucet", Vector3(x, 1.08, -0.2), 0.015, 0.23, mats["steel"], false)
		_box(sink, "Spout", Vector3(x, 1.19, -0.13), Vector3(0.03, 0.03, 0.16), "steel")
		_box(sink, "MirrorFrame", Vector3(x, 1.8, -0.29), Vector3(0.87, 1.05, 0.06), "dark")
		_box(sink, "SmokedMirror", Vector3(x, 1.8, -0.25), Vector3(0.8, 0.98, 0.012), "steel")
	_light(room, "WashroomLight", Vector3(14.3, 4.48, -7.4))


func _garage() -> void:
	var room: Node3D = _zone("GarageWorkshop")
	var cabinet: Node3D = _cabinet(room, "WorkshopDrawers", Vector3(51.85, FLOOR, -14), 3.2, -90)
	_model(cabinet, ART + "station_props/ammo_crate.glb", "ToolCase", Vector3(-0.7, 0.95, 0), 0, 0.7, ModelKit.Fit.WIDTH, false)
	_model(cabinet, PAPERS, "ServiceManual", Vector3(0.8, 0.95, 0), 0, 0.4, ModelKit.Fit.WIDTH, false)
	_board(room, "MaintenanceBoard", "FLEET / SERVICE LOG", Vector3(52.36, 2.9, -14), -90, 2.7)
	_model(room, ART + "tires/dirty_old_tires.glb", "SpareTires", Vector3(51.7, FLOOR, -20.8), 0, 1.0)
	for i: int in 5:
		var tool: Node3D = kit.group(room, "HangingTool", Vector3(38.93, 2.45, -17.3 + i * 0.6))
		_box(tool, "Handle", Vector3.ZERO, Vector3(0.06, 0.36, 0.04), "amber")
		_box(tool, "Head", Vector3(0, 0.2, 0), Vector3(0.1, 0.07, 0.13), "steel")
	_sign(room, "GarageSafety", "FLEET MAINTENANCE / KEEP BAYS CLEAR", Vector3(51.4, 3.7, -32.96), 0, 3.1)
	_light(room, "WorkshopLight", Vector3(50.7, 4.75, -14.0), true)


func _utilities() -> void:
	var room: Node3D = _zone("UtilityRooms")
	for i: int in 3:
		_model(room, ART + "station_props/server_rack.glb", "CommunicationsRack%d" % i,
			Vector3(53.6 + i * 1.35, FLOOR, -32.55), 0, 2.05, ModelKit.Fit.HEIGHT, true, -90)
	var desk: Node3D = _table(room, "ServiceDesk", Vector3(58.9, FLOOR, -28.6), 2.6, 0.95)
	_model(desk, CHAIR, "ServiceChair", Vector3(0, 0, -1.0), 0, 1.05)
	_binders(desk, Vector3(-0.6, 0.805, 0))
	_model(desk, PHONE, "ServiceTelephone", Vector3(0.8, 0.805, 0), 180, 0.3, ModelKit.Fit.WIDTH, false)
	_sign(room, "CommsSign", "COMMUNICATIONS / UPS", Vector3(55, 3.6, -32.99), 0, 2.6)
	_light(room, "CommunicationsLight", Vector3(56.2, 4.48, -30.3))
	for z: float in [-18.5, -8.5]:
		var machine: Node3D = kit.group(room, "StandbyGenerator", Vector3(57.2, FLOOR, z))
		_box(machine, "Plinth", Vector3(0, 0.12, 0), Vector3(2.45, 0.24, 4.4), "dark", true)
		_box(machine, "Housing", Vector3(0, 1.13, 0), Vector3(2.1, 1.78, 3.9), "enamel", true)
		_box(machine, "TopPanel", Vector3(0, 2.04, 0), Vector3(2.2, 0.08, 4.0), "dark")
		for side: float in [-1.0, 1.0]:
			for louver: int in 12:
				_box(machine, "Vent", Vector3(side * 1.058, 0.62 + louver * 0.1, 0.35), Vector3(0.02, 0.035, 2.3), "dark")
			_box(machine, "WarningStripe", Vector3(side * 1.07, 0.35, 0), Vector3(0.015, 0.06, 3.7), "amber")
		_sign(machine, "EquipmentPlate", "STATION 04 / STANDBY POWER", Vector3(0, 1.55, 1.965), 0, 1.85)
		_box(machine, "ControlPanel", Vector3(0, 0.95, 1.97), Vector3(0.7, 0.5, 0.06), "dark")
		for i: int in 3:
			_box(machine, "StatusLed", Vector3(-0.2 + i * 0.2, 1.0, 2.01), Vector3(0.04, 0.04, 0.01), "tube")
		kit.cylinder(machine, "Exhaust", Vector3(0.7, 2.8, -1.2), 0.09, 1.5, mats["steel"], false)
		_light(room, "UtilityFluorescent", Vector3(56.8, 4.48, z + 2.5))
	_archive_shelf(room, "MaintenanceStores", Vector3(53.6, FLOOR, -13.5), 90, 9)
	_sign(room, "UtilityWarning", "HIGH VOLTAGE / KEEP ACCESS CLEAR", Vector3(60.62, 3.3, -24), -90, 3.0)
