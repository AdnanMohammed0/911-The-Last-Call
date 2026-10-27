## Builds the editable, static Station 4 interior dressing scene, plus the dispatch console and CAD monitor
## scenes it (and StationFurniture's bought workstations) instance.
## Run: godot --headless --path . tools/level_kit/furnish_station.tscn
## Rebuilds station_interior.tscn, dispatch_console.tscn and cad_monitor.tscn. Imported models retain their
## scene references.
extends Node

const OUTPUT: String = "res://scenes/dispatch/station/station_interior.tscn"
const CONSOLE_SCENE: String = "res://scenes/dispatch/station/dispatch_console.tscn"
const MONITOR_SCENE: String = "res://scenes/dispatch/station/cad_monitor.tscn"
## Screen opening of the CAD monitor; matches DispatchComputer.SCREEN_SIZE and the 4:3 Station OS viewport.
const SCREEN_SIZE: Vector2 = Vector2(0.448, 0.336)
## Screen centre above the monitor's foot (the main computer's ScreenDisplay sits 0.006 in front of it).
const SCREEN_CENTER: Vector3 = Vector3(0, 0.472, 0.04)
const DESK_TOP: float = 0.785
const SCREEN_SHADER: Shader = preload("res://scenes/dispatch/station/props/screen_feed.gdshader")
const LED_SHADER: Shader = preload("res://scenes/dispatch/station/props/led_blink.gdshader")
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
const CORK_BOARD: String = ART + "paintings/psx_-_corkevidence_board_2.glb"
const WATER: String = ART + "station_props/water_dispenser.glb"
## CC0 props from Poly Haven (see assets/3D/polyhaven/CREDITS.md).
const PH: String = ART + "polyhaven/"
const AMMO_BOX: String = PH + "ammo_box/ammo_box_1k.gltf"
const BARREL_RED: String = PH + "barrel_01/Barrel_01_1k.gltf"
const BARREL_BLUE: String = PH + "barrel_03/barrel_03_1k.gltf"
const BOX: String = PH + "cardboard_box_01/cardboard_box_01_1k.gltf"
const CAMERA: String = PH + "security_camera_01/security_camera_01_1k.gltf"
const CRATE: String = PH + "wooden_military_crate/wooden_military_crate_1k.gltf"
const DESK: String = PH + "metal_office_desk/metal_office_desk_1k.gltf"
const DESK_LAMP: String = PH + "desk_lamp_arm_01/desk_lamp_arm_01_1k.gltf"
const FAN: String = PH + "ceiling_fan/ceiling_fan_1k.gltf"
const STATIONERY: String = PH + "stationery_supplies/stationery_supplies_1k.gltf"
const EXTINGUISHER: String = PH + "korean_fire_extinguisher_01/korean_fire_extinguisher_01_1k.gltf"
const FIRE_ALARM: String = PH + "fire_alarm/fire_alarm_1k.gltf"
const FIELD_CRATES: String = PH + "old_military_crate/old_military_crate_1k.gltf"
const GENERATOR: String = PH + "portable_generator/portable_generator_1k.gltf"
const HAND_TRUCK: String = PH + "hand_truck/hand_truck_1k.gltf"
const JERRYCAN: String = PH + "metal_jerrycan/metal_jerrycan_1k.gltf"
const LADDER: String = PH + "ladder_sectioned_01/ladder_sectioned_01_1k.gltf"
const MEDKIT: String = PH + "medical_box/medical_box_1k.gltf"
const MICROWAVE: String = PH + "vintage_microwave/vintage_microwave_1k.gltf"
const POWER_PANEL: String = PH + "power_box_01/power_box_01_1k.gltf"
const PROJECTOR: String = PH + "projector_screen/projector_screen_1k.gltf"
const PROPANE: String = PH + "propane_tank/propane_tank_1k.gltf"
const SHELVES: String = PH + "steel_frame_shelves_02/steel_frame_shelves_02_1k.gltf"
const SWITCHGEAR: String = PH + "utility_box_02/utility_box_02_1k.gltf"
const SWITCHGEAR_NARROW: String = PH + "utility_box_01/utility_box_01_1k.gltf"
const TIRE_PUMP: String = PH + "tire_pump/tire_pump_1k.gltf"
const TOOL_CART: String = PH + "tool_cart/tool_cart_1k.gltf"
const TOOL_CHEST: String = PH + "metal_tool_chest/metal_tool_chest_1k.gltf"
const TOOLBOX: String = PH + "metal_toolbox/metal_toolbox_1k.gltf"
const TV: String = PH + "television_01/Television_01_1k.gltf"
const VICE: String = PH + "bench_vice_01/bench_vice_01_1k.gltf"
const WELDER: String = PH + "portable_welding_cart/portable_welding_cart_1k.gltf"
const WET_FLOOR: String = PH + "wetfloorsign_01/WetFloorSign_01_1k.gltf"

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
	var result: Error = _build_console_scenes()
	_dispatch()
	_break_room()
	_operations()
	_evidence()
	_armory()
	_staff_support()
	_gallery()
	_corridor()
	_washroom()
	_garage()
	_utilities()
	if result == OK:
		result = _save(interior, OUTPUT)
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
	_material("carpet", Color("283236"), 1.0)
	_material("plastic", Color("b9b29c"), 0.55)
	_material("charcoal", Color("2b2d2f"), 0.5, 0.1)
	_material("glass", Color("0b1214"), 0.08, 0.3)
	_material("yellow", Color("d8c24a"), 0.8)
	_material("fabric", Color("3a4547"), 1.0)
	_material("on_air", Color("ff2a1a"), 0.4)
	mats["on_air"].emission_enabled = true
	mats["on_air"].emission = Color("ff2a1a")
	mats["on_air"].emission_energy_multiplier = 3.0


func _save(root: Node3D, path: String) -> Error:
	var packed: PackedScene = PackedScene.new()
	var result: Error = packed.pack(root)
	if result == OK:
		result = ResourceSaver.save(packed, path)
	return result


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
	prop.owner = kit.root
	var model: Node3D = prop.get_node("Model") as Node3D
	model.owner = kit.root
	if solid:
		var body: StaticBody3D = ModelKit.add_collider(prop)
		body.owner = kit.root
		body.get_child(0).owner = kit.root
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


func _light(parent: Node3D, label: String, at: Vector3, warm: bool = false, shadow: bool = false) -> Node3D:
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
	return fixture


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


## Analog wall clock whose hands AnalogClock drives; `at` is the bottom of the 0.36 m face.
func _clock(parent: Node3D, label: String, at: Vector3, yaw: float) -> void:
	var clock: Node3D = kit.own(AnalogClock.new(), parent, label) as Node3D
	clock.position = at + Vector3(0, 0.18, 0)
	clock.rotation_degrees.y = yaw
	var rim: CylinderMesh = CylinderMesh.new()
	rim.top_radius = 0.18
	rim.bottom_radius = 0.18
	rim.height = 0.045
	kit.mesh(clock, "Rim", rim, Vector3.ZERO, mats["charcoal"], Vector3(90, 0, 0), false)
	var face: CylinderMesh = CylinderMesh.new()
	face.top_radius = 0.162
	face.bottom_radius = 0.162
	face.height = 0.01
	kit.mesh(clock, "Face", face, Vector3(0, 0, 0.019), mats["white"], Vector3(90, 0, 0), false)
	for i: int in 12:
		var angle: float = TAU * i / 12.0
		var tick: Node3D = _box(clock, "Tick", Vector3(sin(angle) * 0.135, cos(angle) * 0.135, 0.025),
			Vector3(0.012, 0.03 if i % 3 == 0 else 0.016, 0.004), "dark")
		tick.rotation.z = -angle
	for spec: Array in [["HourHand", 0.085, 0.016, 0.028, "dark"], ["MinuteHand", 0.125, 0.011, 0.031, "dark"],
			["SecondHand", 0.14, 0.005, 0.034, "red"]]:
		var hand_name: String = spec[0]
		var length: float = spec[1]
		var width: float = spec[2]
		var depth: float = spec[3]
		var material: String = spec[4]
		var pivot: Node3D = kit.group(clock, hand_name, Vector3(0, 0, depth))
		_box(pivot, "Blade", Vector3(0, length * 0.4, 0), Vector3(width, length, 0.004), material)
	kit.cylinder(clock, "Cap", Vector3(0, 0, 0.037), 0.012, 0.006, mats["red"], false).rotation_degrees.x = 90


## Ceiling-corner security camera aimed at `target` that slowly pans (decorative; the StationMart CCTV adds
## working feeds).
func _camera(parent: Node3D, label: String, at: Vector3, target: Vector3) -> void:
	var mount: PropMotion = kit.own(PropMotion.new(), parent, label) as PropMotion
	mount.position = at
	mount.rotation_degrees.y = rad_to_deg(atan2(target.x - at.x, target.z - at.z))
	mount.mode = PropMotion.Mode.SWEEP
	mount.sweep_degrees = 26.0
	mount.sweep_period = 11.0 + float(model_count % 5)
	mount.phase = float(model_count % 7)
	var cam: Node3D = _model(mount, CAMERA, "Camera", Vector3.ZERO, 0, 0.42, ModelKit.Fit.DEPTH, false)
	cam.rotation_degrees.x = -18.0


## Animated CRT feed facing +Z of `parent` (modes in screen_feed.gdshader).
func _screen(parent: Node3D, label: String, at: Vector3, size: Vector2, mode: int, tint: Color = Color("59f2bf"),
		seed: float = 0.0, brightness: float = 1.0) -> MeshInstance3D:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SCREEN_SHADER
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("seed", seed)
	mat.set_shader_parameter("brightness", brightness)
	return kit.mesh(parent, label, quad, at, mat, Vector3.ZERO, false)


## Strip of blinking status LEDs facing +Z of `parent` (led_blink.gdshader).
func _leds(parent: Node3D, label: String, at: Vector3, size: Vector2, columns: float, rows: float = 1.0,
		rate: float = 2.5) -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = LED_SHADER
	mat.set_shader_parameter("columns", columns)
	mat.set_shader_parameter("rows", rows)
	mat.set_shader_parameter("rate", rate)
	kit.mesh(parent, label, quad, at, mat, Vector3.ZERO, false)


## Spinning ceiling fan hung from a ceiling at `ceiling` height.
func _ceiling_fan(parent: Node3D, label: String, at: Vector3, ceiling: float = 4.8) -> void:
	var fan: PropMotion = kit.own(PropMotion.new(), parent, label) as PropMotion
	fan.position = Vector3(at.x, ceiling - 0.53, at.z)
	fan.speed = 150.0
	fan.phase = at.x
	_model(fan, FAN, "Fan", Vector3.ZERO, 0, 1.3, ModelKit.Fit.WIDTH, false)


## Builds dispatch_console.tscn (desk with live side monitors) and cad_monitor.tscn (the retro CAD monitor
## whose screen opening the main computer's Station OS display fills).
func _build_console_scenes() -> Error:
	var main_kit: LevelKit = kit
	var monitor: Node3D = Node3D.new()
	monitor.name = "CadMonitor"
	kit = LevelKit.new(monitor)
	_cad_monitor(monitor)
	var result: Error = _save(monitor, MONITOR_SCENE)
	monitor.free()
	var console: Node3D = Node3D.new()
	console.name = "DispatchConsole"
	kit = LevelKit.new(console)
	_dispatch_console(console)
	if result == OK:
		result = _save(console, CONSOLE_SCENE)
	console.free()
	kit = main_kit
	return result


func _cad_monitor(root: Node3D) -> void:
	var c: Vector3 = SCREEN_CENTER
	var w: float = SCREEN_SIZE.x
	var h: float = SCREEN_SIZE.y
	var side: float = 0.056
	var band: float = 0.064
	var bezel_z: float = c.z + 0.007
	var front: float = bezel_z + 0.015
	_box(root, "Foot", Vector3(0, 0.015, -0.1), Vector3(0.34, 0.03, 0.26), "plastic")
	_box(root, "Swivel", Vector3(0, 0.045, -0.1), Vector3(0.2, 0.03, 0.18), "plastic")
	_box(root, "Neck", Vector3(0, 0.15, -0.12), Vector3(0.1, 0.2, 0.08), "plastic")
	_box(root, "Housing", Vector3(0, c.y - 0.01, c.z - 0.17), Vector3(w + 0.09, h + 0.1, 0.32), "plastic")
	_box(root, "RearHousing", Vector3(0, c.y - 0.03, c.z - 0.4), Vector3(0.34, 0.28, 0.16), "plastic")
	for i: int in 5:
		_box(root, "Vent", Vector3(0, c.y + h / 2 + 0.042, c.z - 0.06 - i * 0.045), Vector3(0.3, 0.004, 0.018), "charcoal")
	_box(root, "BezelTop", Vector3(0, c.y + h / 2 + band / 2, bezel_z), Vector3(w + side * 2, band, 0.03), "plastic")
	_box(root, "BezelBottom", Vector3(0, c.y - h / 2 - band / 2, bezel_z), Vector3(w + side * 2, band, 0.03), "plastic")
	_box(root, "BezelLeft", Vector3(-w / 2 - side / 2, c.y, bezel_z), Vector3(side, h, 0.03), "plastic")
	_box(root, "BezelRight", Vector3(w / 2 + side / 2, c.y, bezel_z), Vector3(side, h, 0.03), "plastic")
	_box(root, "ScreenGlass", Vector3(0, c.y, c.z - 0.012), Vector3(w + 0.004, h + 0.004, 0.01), "glass")
	# Idle CAD feed; on the main computer the live ScreenDisplay sits just in front of it.
	_screen(root, "Screen", Vector3(0, c.y, c.z - 0.004), SCREEN_SIZE, 3, Color("6fb8ff"), 0.0, 0.85)
	var badge_y: float = c.y - h / 2 - band / 2
	_label(root, "STATION 04 · CAD", Vector3(-0.13, badge_y, front + 0.001), 0.0008, Color("4b4a42"))
	_box(root, "PowerLed", Vector3(0.2, badge_y, front + 0.002), Vector3(0.012, 0.006, 0.004), "tube")
	for x: float in [0.13, 0.155]:
		_box(root, "Knob", Vector3(x, badge_y, front + 0.004), Vector3(0.014, 0.014, 0.008), "charcoal")


func _dispatch_console(root: Node3D) -> void:
	_box(root, "Worktop", Vector3(0, DESK_TOP - 0.02, 0), Vector3(2.4, 0.04, 0.9), "charcoal")
	_box(root, "EdgeTrim", Vector3(0, DESK_TOP - 0.02, 0.452), Vector3(2.4, 0.045, 0.012), "rubber")
	_box(root, "ModestyPanel", Vector3(0, 0.42, -0.43), Vector3(2.34, 0.66, 0.025), "enamel")
	for x: float in [-1.18, 1.18]:
		_box(root, "EndPanel", Vector3(x, (DESK_TOP - 0.04) / 2, 0), Vector3(0.04, DESK_TOP - 0.04, 0.88), "enamel")
	var pedestal: Node3D = kit.group(root, "Pedestal", Vector3(-0.85, 0, 0))
	_box(pedestal, "Body", Vector3(0, 0.36, -0.02), Vector3(0.44, 0.7, 0.8), "enamel")
	for i: int in 3:
		_box(pedestal, "Drawer", Vector3(0, 0.15 + i * 0.22, 0.385), Vector3(0.4, 0.19, 0.02), "teal")
		_box(pedestal, "Pull", Vector3(0, 0.2 + i * 0.22, 0.4), Vector3(0.12, 0.018, 0.015), "steel")
	var tower: Node3D = kit.group(root, "Tower", Vector3(0.82, 0, -0.08))
	_box(tower, "Case", Vector3(0, 0.23, 0), Vector3(0.2, 0.46, 0.46), "plastic")
	_box(tower, "DriveBay", Vector3(0, 0.38, 0.232), Vector3(0.15, 0.05, 0.006), "charcoal")
	_leds(tower, "ActivityLeds", Vector3(0.05, 0.3, 0.234), Vector2(0.04, 0.012), 2.0, 1.0, 7.0)
	kit.collider(root, "ConsoleCollider", Vector3(0, DESK_TOP / 2, 0), Vector3(2.4, DESK_TOP, 0.9))
	for side: float in [-1.0, 1.0]:
		var arm: Node3D = kit.group(root, "SideMonitor", Vector3(side * 0.68, DESK_TOP, -0.16))
		arm.rotation_degrees.y = -side * 24.0
		_box(arm, "Base", Vector3(0, 0.008, 0), Vector3(0.22, 0.016, 0.16), "charcoal")
		_box(arm, "Pole", Vector3(0, 0.17, -0.03), Vector3(0.04, 0.32, 0.03), "charcoal")
		_box(arm, "Bezel", Vector3(0, 0.44, 0), Vector3(0.54, 0.34, 0.035), "charcoal")
		_screen(arm, "Feed", Vector3(0, 0.44, 0.0185), Vector2(0.5, 0.3), 0 if side > 0.0 else 1, Color("59f2bf"),
			side * 3.0 + 5.0, 0.95)
		_box(arm, "StickyNote", Vector3(-side * 0.22, 0.58, 0.02), Vector3(0.06, 0.06, 0.003), "yellow")
	var keys: Node3D = kit.group(root, "Keyboard", Vector3(0, DESK_TOP, 0.2))
	_box(keys, "Base", Vector3(0, 0.012, 0), Vector3(0.46, 0.024, 0.16), "plastic")
	for r: int in 5:
		_box(keys, "KeyRow", Vector3(-0.01, 0.026, -0.06 + r * 0.03), Vector3(0.42 - (0.12 if r == 4 else 0.0), 0.006, 0.022), "white")
	_box(root, "MousePad", Vector3(0.38, DESK_TOP + 0.002, 0.2), Vector3(0.22, 0.004, 0.18), "rubber")
	_box(root, "Mouse", Vector3(0.38, DESK_TOP + 0.017, 0.21), Vector3(0.06, 0.03, 0.1), "plastic")
	# Gooseneck desk mic whose ring lights up while a call is on the line.
	var mic: Node3D = kit.group(root, "DeskMic", Vector3(-0.45, DESK_TOP, 0.02))
	kit.cylinder(mic, "Base", Vector3(0, 0.015, 0), 0.06, 0.03, mats["charcoal"], false)
	_box(mic, "PushToTalk", Vector3(0, 0.035, 0.035), Vector3(0.04, 0.012, 0.025), "red")
	var neck: Node3D = kit.group(mic, "Neck", Vector3(0, 0.03, 0))
	neck.rotation_degrees.x = 25
	_box(neck, "Gooseneck", Vector3(0, 0.15, 0), Vector3(0.012, 0.3, 0.012), "steel")
	var capsule: Node3D = kit.group(neck, "Capsule", Vector3(0, 0.33, 0))
	kit.cylinder(capsule, "Foam", Vector3.ZERO, 0.02, 0.07, mats["rubber"], false)
	var lamp: Node3D = kit.own(OnAirLamp.new(), capsule, "OnAir") as Node3D
	kit.cylinder(lamp, "Off", Vector3(0, -0.04, 0), 0.022, 0.012, mats["dark"], false)
	kit.cylinder(lamp, "Lit", Vector3(0, -0.04, 0), 0.0225, 0.013, mats["on_air"], false).visible = false
	# Operator headset resting by the keyboard.
	var headset: Node3D = kit.group(root, "Headset", Vector3(0.7, DESK_TOP, 0.25))
	headset.rotation_degrees.y = -30
	var band: TorusMesh = TorusMesh.new()
	band.inner_radius = 0.074
	band.outer_radius = 0.084
	kit.mesh(headset, "Headband", band, Vector3(0, 0.07, 0), mats["charcoal"], Vector3(90, 0, 0), false)
	for x: float in [-0.08, 0.08]:
		kit.cylinder(headset, "EarCup", Vector3(x, 0.035, 0), 0.035, 0.03, mats["rubber"], false).rotation_degrees.z = 90
	_box(headset, "Boom", Vector3(-0.07, 0.03, 0.06), Vector3(0.008, 0.008, 0.12), "charcoal")
	_box(root, "Notepad", Vector3(-0.42, DESK_TOP + 0.004, 0.28), Vector3(0.15, 0.008, 0.21), "paper")
	_box(root, "Pen", Vector3(-0.31, DESK_TOP + 0.008, 0.28), Vector3(0.008, 0.008, 0.14), "teal")
	_mug(root, Vector3(-0.8, DESK_TOP, 0.25))
	_model(root, STATIONERY, "Organizer", Vector3(-1.0, DESK_TOP, -0.3), 15, 0.28, ModelKit.Fit.WIDTH, false)
	_model(root, PHONE, "Telephone", Vector3(0.98, DESK_TOP, -0.05), 180, 0.28, ModelKit.Fit.WIDTH, false)


## Floor-standing extinguisher with a wall pull station and sign above it; `at` sits 0.2 m off the wall.
func _fire_point(parent: Node3D, label: String, at: Vector3, yaw: float) -> void:
	var point: Node3D = kit.group(parent, label, at)
	point.rotation_degrees.y = yaw
	_model(point, EXTINGUISHER, "Extinguisher", Vector3.ZERO, 0, 0.62, ModelKit.Fit.HEIGHT, false)
	_model(point, FIRE_ALARM, "PullStation", Vector3(0.45, 1.25, -0.18), 0, 0.17, ModelKit.Fit.HEIGHT, false)
	_sign(point, "FireSign", "FIRE", Vector3(0, 1.75, -0.18), 0, 0.42)


## Painted floor line (no collision).
func _floor_line(parent: Node3D, label: String, center: Vector3, size: Vector3) -> void:
	_box(parent, label, Vector3(center.x, FLOOR + 0.004, center.z), Vector3(size.x, 0.006, size.z), "amber")


## A loose pile of cardboard boxes; `seed` varies the arrangement.
func _box_pile(parent: Node3D, label: String, at: Vector3, seed: int) -> void:
	var pile: Node3D = kit.group(parent, label, at)
	pile.rotation_degrees.y = float(seed * 37 % 90)
	_model(pile, BOX, "Box", Vector3(-0.25, 0, 0), 4, 0.4)
	_model(pile, BOX, "Box", Vector3(0.25, 0, 0.05), -6, 0.4)
	_model(pile, BOX, "Box", Vector3(0.0, 0.4, 0.02), seed * 11 % 20 - 10, 0.36, ModelKit.Fit.HEIGHT, false)


func _dispatch() -> void:
	var room: Node3D = _zone("Dispatch")
	for i: int in 3:
		var cabinet: Node3D = _cabinet(room, "CallArchives%d" % i, Vector3(4.2 + i * 3.0, FLOOR, -17.88), 2.4, 180)
		_binders(cabinet, Vector3(0.4, 0.95, 0))
		_model(cabinet, PAPERS, "ShiftPaperwork", Vector3(-0.65, 0.95, 0), 12, 0.4, ModelKit.Fit.WIDTH, false)
	_board(room, "DutyRoster", "DISPATCH / NIGHT SHIFT", Vector3(9, 3.05, -17.58), 180, 3.2)
	_sign(room, "DeskIdentifier", "04 / DISPATCH", Vector3(12, 3.2, -27.78), 0, 2.0)
	_model(room, FILES, "CallFileCabinet", Vector3(12.1, FLOOR, -27.3), 0, 1.75)
	_box(room, "CarpetTiles", Vector3(8.0, FLOOR + 0.004, -22.4), Vector3(7.6, 0.008, 5.6), "carpet")
	# Main 911 console: DispatchSetup's main computer and phone sit on it.
	kit.instance(CONSOLE_SCENE, room, "MainConsole", Transform3D(Basis.IDENTITY, Vector3(6.0, FLOOR, -24.32)))
	_label(room, "DISPATCH 1 · STATION OS", Vector3(6.0, FLOOR + DESK_TOP - 0.02, -23.862), 0.0011, Color("59f2bf"))
	_model(room, CHAIR, "DispatcherChair", Vector3(6.25, FLOOR, -23.2), 172, 1.05, ModelKit.Fit.HEIGHT, false)
	_supervisor_station(room)
	_equipment_racks(room)
	_video_wall(room)
	_coffee_corner(room)
	_dispatch_corners(room)
	_ceiling_fan(room, "DispatchCeilingFan", Vector3(8.0, 0, -22.4))
	_clock(room, "DispatchClock", Vector3(16.03, 3.42, -19.67), -90)


func _supervisor_station(room: Node3D) -> void:
	var desk: Node3D = _model(room, DESK, "SupervisorDesk", Vector3(3.0, FLOOR, -22.55), 0, 2.0, ModelKit.Fit.WIDTH)
	var top: float = 0.79
	kit.instance(MONITOR_SCENE, desk, "SupervisorMonitor", Transform3D(Basis(Vector3.UP, deg_to_rad(-12.0)), Vector3(0.45, top, -0.02)))
	_model(desk, DESK_LAMP, "ArmLamp", Vector3(-0.78, top, -0.25), 35, 0.55, ModelKit.Fit.HEIGHT, false)
	_model(desk, PHONE, "SupervisorTelephone", Vector3(-0.3, top, -0.2), 165, 0.28, ModelKit.Fit.WIDTH, false)
	_model(desk, PAPERS, "SupervisorReports", Vector3(-0.05, top, 0.2), -8, 0.42, ModelKit.Fit.WIDTH, false)
	_model(desk, STATIONERY, "DeskOrganizer", Vector3(-0.55, top, 0.12), 20, 0.28, ModelKit.Fit.WIDTH, false)
	_mug(desk, Vector3(0.85, top, 0.22))
	var plate: Node3D = kit.group(desk, "NamePlate", Vector3(0.35, top, 0.38))
	_box(plate, "Wedge", Vector3(0, 0.03, 0), Vector3(0.32, 0.06, 0.04), "charcoal")
	_label(plate, "SHIFT SUPERVISOR", Vector3(0, 0.03, 0.021), 0.0009, Color("d7d5bc"))
	_model(room, CHAIR, "SupervisorChair", Vector3(3.0, FLOOR, -21.55), 180, 1.1)
	_model(room, BIN, "PaperBin", Vector3(4.3, FLOOR, -22.75), 0, 0.48)
	_model(room, FILES, "SupervisorCabinetA", Vector3(0.45, FLOOR, -22.75), 90, 1.75)
	_model(room, FILES, "SupervisorCabinetB", Vector3(0.45, FLOOR, -21.8), 90, 1.75)


## Radio and CAD equipment racks against the west wall, every unit blinking.
func _equipment_racks(room: Node3D) -> void:
	for i: int in 2:
		var rack: Node3D = kit.group(room, "EquipmentRack%d" % i, Vector3(0.62, FLOOR, -25.65 + i * 0.85))
		rack.rotation_degrees.y = 90
		_box(rack, "Cabinet", Vector3(0, 1.0, 0), Vector3(0.8, 2.0, 1.0), "charcoal", true)
		for u: int in 7:
			var y: float = 0.35 + u * 0.22
			_box(rack, "Unit", Vector3(0, y, 0.505), Vector3(0.7, 0.16, 0.012), "dark")
			_leds(rack, "UnitLeds", Vector3(-0.18, y, 0.513), Vector2(0.26, 0.03), 9.0, 1.0, 1.6 + u * 0.35)
			if u % 3 == 1:
				_box(rack, "PatchPanel", Vector3(0.18, y, 0.513), Vector3(0.26, 0.06, 0.004), "white")
		_box(rack, "FanTray", Vector3(0, 1.93, 0.505), Vector3(0.7, 0.08, 0.012), "steel")
		_label(rack, "RADIO / CAD %02d" % (i + 1), Vector3(0, 1.84, 0.514), 0.0015, Color("8fd3ff"))


## Video wall on the north wall: live unit map, unit status list and incident log, with the ON AIR sign and a
## radio credenza below. DispatchSetup's line status label sits at the top of the left display.
func _video_wall(room: Node3D) -> void:
	var wall: Node3D = kit.group(room, "VideoWall", Vector3(8.0, 0, -27.9))
	_box(wall, "Frame", Vector3(0, 2.45, 0), Vector3(6.3, 1.3, 0.06), "charcoal")
	var tint: Color = Color("59f2bf")
	for spec: Array in [[-2.05, 2, 1.0], [0.0, 0, 2.0], [2.05, 1, 3.0]]:
		var x: float = spec[0]
		var mode: int = spec[1]
		var seed: float = spec[2]
		_screen(wall, "Display", Vector3(x, 2.45, 0.032), Vector2(1.95, 1.1), mode, tint, seed, 0.9)
	_label(wall, "COUNTY 04 · LIVE UNIT MAP", Vector3(0, 2.93, 0.036), 0.0018, tint)
	_label(wall, "INCIDENT LOG · RADIO", Vector3(2.05, 2.93, 0.036), 0.0018, tint)
	var board: UnitStatusBoard = kit.own(UnitStatusBoard.new(), wall, "UnitStatus") as UnitStatusBoard
	board.position = Vector3(-2.05, 2.28, 0.036)
	board.pixel_size = 0.0019
	board.font_size = 32
	board.outline_size = 0
	board.modulate = Color("9ff5d6")
	board.text = "UNITS"
	var glow: OmniLight3D = kit.own(OmniLight3D.new(), wall, "ScreenGlow") as OmniLight3D
	glow.position = Vector3(0, 2.4, 0.9)
	glow.light_color = Color("7fd8ff")
	glow.light_energy = 0.5
	glow.omni_range = 4.5
	var on_air: Node3D = kit.own(OnAirLamp.new(), wall, "OnAirSign") as Node3D
	on_air.position = Vector3(2.1, 3.55, 0.03)
	_box(on_air, "Housing", Vector3.ZERO, Vector3(0.62, 0.2, 0.06), "charcoal")
	_box(on_air, "Panel", Vector3(0, 0, 0.031), Vector3(0.56, 0.15, 0.004), "red")
	_box(on_air, "Lit", Vector3(0, 0, 0.034), Vector3(0.56, 0.15, 0.004), "on_air").visible = false
	_label(on_air, "ON AIR", Vector3(0, 0, 0.04), 0.0022, Color(1, 0.92, 0.88))
	var red: OmniLight3D = kit.own(OmniLight3D.new(), on_air, "Glow") as OmniLight3D
	red.position = Vector3(0, -0.1, 0.35)
	red.light_color = Color(1, 0.15, 0.1)
	red.light_energy = 1.2
	red.omni_range = 2.5
	red.visible = false
	var credenza: Node3D = _cabinet(room, "RadioCredenza", Vector3(8.0, FLOOR, -27.6), 5.4)
	var scanner: Node3D = kit.group(credenza, "RadioScanner", Vector3(-1.9, 0.95, 0.05))
	_box(scanner, "Body", Vector3(0, 0.065, 0), Vector3(0.45, 0.13, 0.28), "charcoal")
	_leds(scanner, "SignalMeter", Vector3(0.06, 0.08, 0.141), Vector2(0.24, 0.025), 12.0, 1.0, 5.0)
	_screen(scanner, "FrequencyReadout", Vector3(-0.14, 0.08, 0.141), Vector2(0.11, 0.045), 1, Color("ffb347"), 7.0)
	_box(scanner, "Antenna", Vector3(0.18, 0.3, -0.1), Vector3(0.008, 0.36, 0.008), "steel")
	var fax: Node3D = kit.group(credenza, "FaxMachine", Vector3(1.5, 0.95, 0))
	_box(fax, "Body", Vector3(0, 0.06, 0), Vector3(0.38, 0.12, 0.32), "plastic")
	var sheet: Node3D = _box(fax, "PaperFeed", Vector3(0, 0.16, -0.12), Vector3(0.22, 0.004, 0.2), "paper")
	sheet.rotation_degrees.x = -35
	_leds(fax, "StatusLed", Vector3(0.13, 0.08, 0.161), Vector2(0.03, 0.012), 2.0, 1.0, 0.8)
	_binders(credenza, Vector3(0.3, 0.95, 0))
	_model(credenza, PAPERS, "RadioLogs", Vector3(-0.85, 0.95, 0.05), -6, 0.42, ModelKit.Fit.WIDTH, false)
	_model(credenza, POT, "CredenzaPlant", Vector3(2.45, 0.95, 0.0), 0, 0.42, ModelKit.Fit.HEIGHT, false)


func _coffee_corner(room: Node3D) -> void:
	var station: Node3D = _table(room, "CoffeeStation", Vector3(15.55, FLOOR, -23.4), 0.6, 1.5, 0.9)
	_model(station, ART + "station_props/coffee_machine.glb", "CoffeeMaker", Vector3(0.02, 0.94, -0.4), -90, 0.46,
		ModelKit.Fit.HEIGHT, false)
	kit.cylinder(station, "CupStack", Vector3(0.05, 1.05, 0.12), 0.04, 0.22, mats["white"], false)
	_box(station, "SugarTin", Vector3(-0.12, 0.99, 0.0), Vector3(0.09, 0.1, 0.09), "steel")
	_mug(station, Vector3(-0.1, 0.94, 0.38))
	_mug(station, Vector3(0.12, 0.94, 0.5))
	_steam(station, "CoffeeSteam", Vector3(-0.1, 1.06, 0.38))
	_model(room, WATER, "DispatchWaterCooler", Vector3(15.72, FLOOR, -22.15), -90, 1.3)
	_model(room, BIN, "CoffeeBin", Vector3(15.7, FLOOR, -21.62), 0, 0.5)
	_board(room, "ProceduresBoard", "CALL CODES / PROCEDURES", Vector3(16.03, 2.7, -24.2), -90, 2.0)


## Wisps of steam rising off a hot mug.
func _steam(parent: Node3D, label: String, at: Vector3) -> void:
	var steam: GPUParticles3D = kit.own(GPUParticles3D.new(), parent, label) as GPUParticles3D
	steam.position = at
	steam.amount = 10
	steam.lifetime = 2.4
	steam.visibility_aabb = AABB(Vector3(-0.3, -0.1, -0.3), Vector3(0.6, 1.0, 0.6))
	var motion: ParticleProcessMaterial = ParticleProcessMaterial.new()
	motion.direction = Vector3.UP
	motion.spread = 10.0
	motion.initial_velocity_min = 0.05
	motion.initial_velocity_max = 0.1
	motion.gravity = Vector3(0, 0.04, 0)
	motion.scale_min = 0.6
	motion.scale_max = 1.4
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.25, Color(1, 1, 1, 0.3))
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = fade
	motion.color_ramp = ramp
	steam.process_material = motion
	var puff: QuadMesh = QuadMesh.new()
	puff.size = Vector2(0.07, 0.07)
	var soft: Gradient = Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	var blob: GradientTexture2D = GradientTexture2D.new()
	blob.gradient = soft
	blob.fill = GradientTexture2D.FILL_RADIAL
	blob.fill_from = Vector2(0.5, 0.5)
	blob.fill_to = Vector2(1.0, 0.5)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = blob
	puff.material = mat
	steam.draw_pass_1 = puff


## Mobile whiteboard, photocopier and coat rack fill the remaining corners.
func _dispatch_corners(room: Node3D) -> void:
	var board: Node3D = kit.group(room, "MobileWhiteboard", Vector3(12.9, FLOOR, -25.9))
	board.rotation_degrees.y = -55
	for side: float in [-0.78, 0.78]:
		_box(board, "Leg", Vector3(side, 0.9, 0), Vector3(0.04, 1.8, 0.04), "steel")
		_box(board, "Foot", Vector3(side, 0.05, 0), Vector3(0.05, 0.04, 0.55), "steel")
		for z: float in [-0.25, 0.25]:
			kit.cylinder(board, "Caster", Vector3(side, 0.025, z), 0.025, 0.03, mats["rubber"], false).rotation_degrees.z = 90
	_box(board, "Frame", Vector3(0, 1.45, 0), Vector3(1.56, 0.96, 0.04), "steel")
	_box(board, "Surface", Vector3(0, 1.45, 0.022), Vector3(1.5, 0.9, 0.004), "white")
	_label(board, "SHIFT NOTES\n04-117  DOMESTIC  ·  ADAM-12\n04-118  ALARM  ·  KING-7\n04-121  WELFARE CHECK  ·  MARY-2",
		Vector3(-0.05, 1.55, 0.026), 0.0012, Color("2a3f6a"))
	for i: int in 3:
		var stroke: Node3D = _box(board, "MarkerStroke", Vector3(-0.45 + i * 0.4, 1.15, 0.025), Vector3(0.3, 0.012, 0.002), "red")
		stroke.rotation_degrees.z = float(i * 9 - 9)
	_box(board, "MarkerTray", Vector3(0, 0.96, 0.05), Vector3(1.3, 0.02, 0.06), "steel")
	kit.collider(board, "BoardCollider", Vector3(0, 0.9, 0), Vector3(1.6, 1.8, 0.55))
	var copier: Node3D = kit.group(room, "Photocopier", Vector3(12.75, FLOOR, -17.85))
	copier.rotation_degrees.y = 180
	_box(copier, "Body", Vector3(0, 0.5, 0), Vector3(0.9, 1.0, 0.65), "white", true)
	_box(copier, "Lid", Vector3(0, 1.03, -0.03), Vector3(0.88, 0.06, 0.58), "plastic")
	_box(copier, "ControlPanel", Vector3(0.28, 1.0, 0.3), Vector3(0.3, 0.05, 0.12), "charcoal")
	_leds(copier, "ReadyLeds", Vector3(0.28, 1.0, 0.361), Vector2(0.12, 0.02), 4.0, 1.0, 0.7)
	for i: int in 2:
		_box(copier, "PaperTray", Vector3(0, 0.25 + i * 0.22, 0.33), Vector3(0.8, 0.16, 0.02), "plastic")
		_box(copier, "TrayHandle", Vector3(0, 0.29 + i * 0.22, 0.345), Vector3(0.18, 0.02, 0.015), "charcoal")
	_box(copier, "OutputTray", Vector3(-0.53, 0.75, 0), Vector3(0.18, 0.02, 0.4), "plastic")
	_box(copier, "Copies", Vector3(-0.53, 0.77, 0), Vector3(0.15, 0.02, 0.3), "paper")
	_model(room, BIN, "CopierBin", Vector3(13.75, FLOOR, -17.75), 0, 0.48)
	var coats: Node3D = kit.group(room, "CoatRack", Vector3(2.2, FLOOR, -17.75))
	kit.cylinder(coats, "Base", Vector3(0, 0.02, 0), 0.22, 0.04, mats["charcoal"], false)
	kit.cylinder(coats, "Pole", Vector3(0, 0.9, 0), 0.02, 1.8, mats["charcoal"], true)
	for i: int in 4:
		var hook: Node3D = kit.group(coats, "Hook", Vector3(0, 1.72, 0))
		hook.rotation_degrees.y = i * 90.0
		_box(hook, "Peg", Vector3(0, 0, 0.09), Vector3(0.015, 0.015, 0.16), "steel")
	_box(coats, "PatrolJacket", Vector3(0.0, 1.3, 0.13), Vector3(0.38, 0.72, 0.12), "fabric")
	_box(coats, "HiVisVest", Vector3(0.13, 1.42, 0.0), Vector3(0.1, 0.5, 0.3), "yellow")
	kit.cylinder(coats, "PatrolCap", Vector3(0, 1.84, 0), 0.1, 0.07, mats["dark"], false)
	_box(coats, "CapBrim", Vector3(0, 1.81, 0.1), Vector3(0.16, 0.012, 0.09), "dark")


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
	_ceiling_fan(room, "BreakCeilingFan", Vector3(7.0, 0, -14.7))
	# Kitchenette along the north wall, under the staff notices.
	var kitchen: Node3D = _cabinet(room, "Kitchenette", Vector3(9.8, FLOOR, -16.93), 4.0)
	_model(kitchen, MICROWAVE, "Microwave", Vector3(-1.35, 0.95, -0.04), 0, 0.52, ModelKit.Fit.WIDTH, false)
	_box(kitchen, "SinkRim", Vector3(0.35, 0.96, 0), Vector3(0.66, 0.025, 0.45), "steel")
	_box(kitchen, "SinkBowl", Vector3(0.35, 0.975, 0), Vector3(0.56, 0.015, 0.35), "dark")
	kit.cylinder(kitchen, "Tap", Vector3(0.35, 1.1, -0.22), 0.017, 0.27, mats["steel"], false)
	_box(kitchen, "Spout", Vector3(0.35, 1.23, -0.14), Vector3(0.03, 0.03, 0.18), "steel")
	_box(kitchen, "DishRack", Vector3(1.15, 0.99, 0), Vector3(0.5, 0.06, 0.36), "steel")
	for i: int in 4:
		_box(kitchen, "Plate", Vector3(1.0 + i * 0.09, 1.1, 0), Vector3(0.012, 0.2, 0.2), "white")
	kit.cylinder(kitchen, "PaperTowel", Vector3(-0.45, 1.08, -0.15), 0.06, 0.26, mats["white"], false)
	_mug(kitchen, Vector3(-0.7, 0.95, 0.12))
	_mug(kitchen, Vector3(1.65, 0.95, 0.1))
	var fridge: Node3D = kit.group(room, "Refrigerator", Vector3(12.55, FLOOR, -16.86))
	_box(fridge, "Body", Vector3(0, 0.93, 0), Vector3(0.78, 1.86, 0.68), "white", true)
	_box(fridge, "DoorSeam", Vector3(0, 1.3, 0.342), Vector3(0.74, 0.012, 0.006), "dark")
	for y: float in [0.85, 1.55]:
		_box(fridge, "Handle", Vector3(0.3, y, 0.36), Vector3(0.03, 0.34, 0.035), "steel")
	for i: int in 3:
		var note: Node3D = _box(fridge, "Note", Vector3(-0.2 + i * 0.13, 1.0 - i * 0.12, 0.346), Vector3(0.1, 0.13, 0.004), "paper")
		note.rotation_degrees.z = float(i * 6 - 6)
	_clock(room, "BreakClock", Vector3(16.0, 3.4, -12.77), -90)
	var cues: Node3D = kit.group(room, "CueRack", Vector3(10.2, FLOOR + 0.9, -10.68))
	cues.rotation_degrees.y = 180
	_box(cues, "Backboard", Vector3(0, 0.62, 0), Vector3(0.62, 1.3, 0.03), "wood")
	for i: int in 4:
		_box(cues, "Cue", Vector3(-0.21 + i * 0.14, 0.62, 0.04), Vector3(0.025, 1.42, 0.025), "amber" if i % 2 == 0 else "wood")
	_fire_point(room, "BreakFirePoint", Vector3(15.2, FLOOR, -10.84), 180)


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
	# Investigators' desks against the evidence wall, under the case board.
	for i: int in 3:
		var x: float = 25.0 + i * 2.6
		var desk: Node3D = _model(room, DESK, "InvestigatorDesk%d" % i, Vector3(x, FLOOR, -13.06), 180, 2.0, ModelKit.Fit.WIDTH)
		kit.instance(MONITOR_SCENE, desk, "Terminal", Transform3D(Basis(Vector3.UP, deg_to_rad(8.0)), Vector3(0.45, 0.79, 0.0)))
		_model(desk, PAPERS, "CaseFile", Vector3(-0.35, 0.79, 0.05), i * 14 - 10, 0.4, ModelKit.Fit.WIDTH, false)
		if i != 1:
			_model(desk, PHONE, "DeskPhone", Vector3(-0.78, 0.79, -0.15), 160, 0.28, ModelKit.Fit.WIDTH, false)
		else:
			_binders(desk, Vector3(-0.7, 0.79, -0.2))
		_mug(desk, Vector3(0.0, 0.79, 0.2))
		_model(room, CHAIR, "InvestigatorChair%d" % i, Vector3(x + 0.2, FLOOR, -14.05), i * 9 - 9, 1.05)
	_model(room, CORK_BOARD, "CaseCorkBoard", Vector3(27.6, 2.05, -12.6), 180, 2.6, ModelKit.Fit.WIDTH, false)
	_sign(room, "InvestigationSign", "INVESTIGATIONS / OPEN CASES", Vector3(27.6, 3.84, -12.58), 180, 2.6)
	_model(room, PROJECTOR, "BriefingProjectorScreen", Vector3(27.45, FLOOR, -19.7), 90, 1.9)
	_model(room, WATER, "BriefingWaterCooler", Vector3(33.0, FLOOR, -12.86), 180, 1.3)
	_clock(room, "OperationsClock", Vector3(22.42, 3.2, -14.5), 90)
	_camera(room, "OperationsCamera", Vector3(38.1, 4.15, -12.8), Vector3(29, 0.85, -20))
	_fire_point(room, "OperationsFirePoint", Vector3(22.58, FLOOR, -15.2), 90)


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
	_camera(room, "EvidenceCamera", Vector3(38.1, 4.15, -6.75), Vector3(30, 0.85, -9.5))


## Armory dressing between the StationMart racks (south wall) and armor lockers (north wall).
func _armory() -> void:
	var room: Node3D = _zone("ArmoryPrep")
	var bench: Node3D = _table(room, "WeaponPrepBench", Vector3(27.0, FLOOR, -3.05), 3.0, 1.0, 0.9)
	_box(bench, "CleaningMat", Vector3(0.1, 0.945, 0), Vector3(1.3, 0.008, 0.6), "teal")
	_model(bench, ART + "weapons/rifle.glb", "RifleForCleaning", Vector3(0.1, 0.95, 0), 90, 0.95, ModelKit.Fit.LONGEST, false)
	_model(bench, TOOLBOX, "CleaningKit", Vector3(-1.05, 0.94, 0.1), 15, 0.42, ModelKit.Fit.WIDTH, false)
	for i: int in 3:
		_model(bench, AMMO_BOX, "AmmoCan", Vector3(1.0 + i * 0.13, 0.94, -0.2), 90, 0.2, ModelKit.Fit.HEIGHT, false)
	_model(bench, MEDKIT, "IFAKPouch", Vector3(1.1, 0.94, 0.22), -10, 0.42, ModelKit.Fit.WIDTH, false)
	var counter: Node3D = _table(room, "IssueCounter", Vector3(33.4, FLOOR, -3.05), 2.4, 0.9, 0.9)
	_model(counter, ART + "gear/plate_carrier.glb", "DisplayCarrier", Vector3(-0.55, 0.94, 0), 0, 0.6, ModelKit.Fit.HEIGHT, false)
	_model(counter, FIELD_CRATES, "MagazinePouches", Vector3(0.5, 0.94, 0), 0, 1.0, ModelKit.Fit.WIDTH, false)
	_model(counter, PAPERS, "SignOutSheets", Vector3(0.6, 1.1, 0.25), 6, 0.36, ModelKit.Fit.WIDTH, false)
	# Unloading point at the entrance: sand-filled clearing barrel and the rule above it.
	var clearing: Node3D = kit.group(room, "ClearingBarrel", Vector3(23.0, FLOOR, -4.95))
	kit.cylinder(clearing, "Drum", Vector3(0, 0.45, 0), 0.27, 0.9, mats["dark"], true)
	kit.cylinder(clearing, "Sand", Vector3(0, 0.905, 0), 0.24, 0.01, mats["cardboard"], false)
	_box(clearing, "HazardBand", Vector3(0, 0.75, 0.272), Vector3(0.3, 0.07, 0.01), "amber")
	_sign(room, "ClearingSign", "CLEAR ALL WEAPONS / MUZZLE IN", Vector3(22.42, 2.35, -4.95), 90, 1.8)
	# Gear shelf between the armor lockers and the evidence door.
	var shelf: Node3D = kit.group(room, "HelmetShelf", Vector3(28.2, FLOOR, -5.92))
	for x: float in [-0.5, 0.5]:
		_box(shelf, "Upright", Vector3(x, 1.0, 0), Vector3(0.04, 2.0, 0.42), "dark")
	for tier: int in 4:
		var y: float = 0.25 + tier * 0.55
		_box(shelf, "Shelf", Vector3(0, y, 0), Vector3(1.0, 0.03, 0.42), "steel")
		if tier == 0:
			_model(shelf, AMMO_BOX, "SpareAmmo", Vector3(-0.2, y + 0.015, 0), 90, 0.2, ModelKit.Fit.HEIGHT, false)
			_model(shelf, AMMO_BOX, "SpareAmmo", Vector3(0.15, y + 0.015, 0), 90, 0.2, ModelKit.Fit.HEIGHT, false)
			continue
		for side: float in [-0.24, 0.24]:
			var helmet: SphereMesh = SphereMesh.new()
			helmet.radius = 0.15
			helmet.height = 0.15
			helmet.is_hemisphere = true
			kit.mesh(shelf, "Helmet", helmet, Vector3(side, y + 0.015, 0), mats["rubber"], Vector3.ZERO, false)
			_box(shelf, "Visor", Vector3(side, y + 0.06, 0.13), Vector3(0.22, 0.06, 0.02), "water")
	kit.collider(shelf, "ShelfCollider", Vector3(0, 1.0, 0), Vector3(1.04, 2.0, 0.44))
	_floor_line(room, "RackSafetyLine", Vector3(30.3, 0, -1.05), Vector3(15.0, 0, 0.08))
	_model(room, MEDKIT, "WorkbenchMedkit", Vector3(37.0, FLOOR + 0.9, -5.55), -12, 0.5, ModelKit.Fit.WIDTH, false)
	_board(room, "SignOutLog", "WEAPON SIGN-OUT / LOG", Vector3(38.33, 2.55, -5.3), -90, 1.5)
	_clock(room, "ArmoryClock", Vector3(30.3, 3.35, -6.2), 0)


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
	_clock(room, "LockerRoomClock", Vector3(6.0, 3.2, -0.3), 180)
	_fire_point(room, "LockerFirePoint", Vector3(0.28, FLOOR, -1.6), 90)


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
	# Waiting corner facing a wall-mounted news set on the east wall.
	var bracket: Node3D = kit.group(room, "TVBracket", Vector3(38.2, 2.2, -27.6))
	bracket.rotation_degrees.y = -90
	_box(bracket, "WallPlate", Vector3(0, 0, -0.14), Vector3(0.3, 0.3, 0.02), "dark")
	_box(bracket, "Arm", Vector3(0, -0.05, -0.05), Vector3(0.06, 0.06, 0.18), "steel")
	_box(bracket, "Shelf", Vector3(0, -0.08, 0.1), Vector3(0.66, 0.03, 0.5), "dark")
	_model(bracket, TV, "NewsTelevision", Vector3(0, -0.065, 0.1), 0, 0.62, ModelKit.Fit.WIDTH, false)
	_screen(bracket, "NewsFeed", Vector3(-0.065, 0.18, 0.348), Vector2(0.34, 0.26), 4, Color.WHITE, 2.0, 0.9)
	_ceiling_fan(room, "GalleryCeilingFan", Vector3(33.95, 0, -28.9))
	_model(room, WAITING, "VisitorBenchC", Vector3(35.4, FLOOR, -27.6), 90, 2.4, ModelKit.Fit.WIDTH)
	_model(room, WATER, "VisitorWaterCooler", Vector3(29.05, FLOOR, -32.7), 0, 1.3)
	_model(room, WET_FLOOR, "WetFloorSign", Vector3(30.3, FLOOR, -26.9), 30, 0.62, ModelKit.Fit.HEIGHT, false)
	_model(room, BIN, "VisitorBin", Vector3(29.75, FLOOR, -31.9), 0, 0.5)
	_clock(room, "VisitorClock", Vector3(30.2, 3.15, -24.2), 180)
	_camera(room, "GalleryCamera", Vector3(28.75, 4.15, -32.9), Vector3(35, 0.85, -27))
	_fire_point(room, "GalleryFirePoint", Vector3(38.18, FLOOR, -26.4), -90)


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
		_model(extinguisher, FIRE_ALARM, "PullStation", Vector3(0.5, -0.3, -0.2), 0, 0.17, ModelKit.Fit.HEIGHT, false)
	_board(room, "WantedBoard", "COUNTY / MOST WANTED", Vector3(22.14, 2.65, -14.0), -90, 2.2)
	_clock(room, "CorridorClock", Vector3(16.22, 3.45, -12.77), 90)


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
	var washroom_light: Node3D = _light(room, "WashroomLight", Vector3(14.3, 4.48, -7.4))
	kit.own(FlickerLight.new(), washroom_light, "Flicker")
	_model(room, WET_FLOOR, "WetFloorSign", Vector3(13.1, FLOOR, -5.1), -20, 0.62, ModelKit.Fit.HEIGHT, false)


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
	# East wall service line beside bay 2.
	_model(room, TOOL_CART, "ServiceCart", Vector3(51.98, FLOOR, -10.6), -90, 1.25, ModelKit.Fit.WIDTH)
	_model(room, TOOL_CHEST, "RollerToolChest", Vector3(52.22, FLOOR, -8.9), -90, 0.95)
	_model(room, WELDER, "WeldingCart", Vector3(52.0, FLOOR, -7.5), -90, 1.5)
	for z: float in [-6.35, -5.75]:
		_model(room, SHELVES, "PartsShelf", Vector3(52.3, FLOOR, z), -90, 2.0)
	for z: float in [-4.9, -4.5]:
		_model(room, JERRYCAN, "FuelCan", Vector3(51.85, FLOOR, z), -90, 0.45)
	_model(room, TIRE_PUMP, "TirePump", Vector3(52.4, FLOOR, -3.9), -70, 0.58, ModelKit.Fit.HEIGHT, false)
	# West wall, between the reload bench and the tool bench, and past it.
	_model(room, LADDER, "WallLadder", Vector3(38.72, FLOOR, -12.3), 90, 2.1)
	_model(room, HAND_TRUCK, "HandTruck", Vector3(39.0, FLOOR, -11.3), 75, 1.25)
	_model(room, TOOL_CHEST, "BayToolChest", Vector3(38.95, FLOOR, -7.0), 90, 0.95)
	_model(room, GENERATOR, "PortableGenerator", Vector3(39.15, FLOOR, -19.4), 90, 0.8, ModelKit.Fit.WIDTH)
	_model(room, PROPANE, "PropaneTank", Vector3(38.95, FLOOR, -20.55), 0, 0.6)
	_model(room, PROPANE, "PropaneTank", Vector3(39.4, FLOOR, -20.75), 40, 0.6)
	for spot: Vector3 in [Vector3(42.2, 0, -7.1), Vector3(48.9, 0, -5.8), Vector3(42.6, 0, -18.6)]:
		_box(room, "OilStain", Vector3(spot.x, FLOOR + 0.003, spot.z), Vector3(1.1, 0.004, 0.75), "rubber")
	# Service aisle stores either side of the ambulance bay.
	_model(room, CRATE, "SupplyCrate", Vector3(39.35, FLOOR, -32.75), 0, 1.2, ModelKit.Fit.WIDTH)
	_model(room, CRATE, "SupplyCrate", Vector3(39.35, FLOOR + 0.45, -32.75), 4, 1.2, ModelKit.Fit.WIDTH, false)
	_box_pile(room, "ReturnedCartons", Vector3(40.75, FLOOR, -32.6), 1)
	for z: float in [-31.6, -30.95]:
		_model(room, BARREL_BLUE, "WaterDrum", Vector3(39.0, FLOOR, z), z * 40, 0.88)
	var pallet: Node3D = kit.group(room, "Pallet", Vector3(49.6, FLOOR, -32.45))
	for x: float in [-0.5, 0.0, 0.5]:
		_box(pallet, "Runner", Vector3(x, 0.05, 0), Vector3(0.1, 0.1, 1.0), "wood")
	_box(pallet, "Deck", Vector3(0, 0.12, 0), Vector3(1.2, 0.04, 1.0), "wood", true)
	_box_pile(pallet, "Cartons", Vector3(0, 0.14, 0), 3)
	_model(room, BARREL_RED, "FuelDrum", Vector3(48.2, FLOOR, -32.65), 20, 0.88)
	_model(room, BARREL_RED, "FuelDrum", Vector3(48.25, FLOOR, -32.0), -35, 0.88)
	_model(room, BARREL_BLUE, "WaterDrum", Vector3(48.85, FLOOR, -31.6), 10, 0.88)
	_model(room, WET_FLOOR, "WetFloorSign", Vector3(50.4, FLOOR, -28.2), -25, 0.62, ModelKit.Fit.HEIGHT, false)
	_light(room, "ServiceAisleLightWest", Vector3(41.5, 5.0, -30.4))
	var aisle_light: Node3D = _light(room, "ServiceAisleLightEast", Vector3(49.4, 5.0, -30.4))
	kit.own(FlickerLight.new(), aisle_light, "Flicker")


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
		_leds(machine, "StatusLeds", Vector3(0, 1.0, 2.011), Vector2(0.5, 0.05), 3.0, 1.0, 1.2)
		# Radiator fan spinning behind a guard ring on the back end.
		var fan: PropMotion = kit.own(PropMotion.new(), machine, "RadiatorFan") as PropMotion
		fan.position = Vector3(0, 1.15, -1.975)
		fan.axis = Vector3.BACK
		fan.speed = 420.0
		fan.phase = z
		kit.cylinder(fan, "Hub", Vector3.ZERO, 0.08, 0.04, mats["dark"], false).rotation_degrees.x = 90
		for b: int in 5:
			var arm: Node3D = kit.group(fan, "BladeArm", Vector3.ZERO)
			arm.rotation_degrees.z = b * 72.0
			var blade: Node3D = _box(arm, "Blade", Vector3(0, 0.27, 0), Vector3(0.13, 0.42, 0.012), "steel")
			blade.rotation_degrees.y = 18.0
		var guard: TorusMesh = TorusMesh.new()
		guard.inner_radius = 0.54
		guard.outer_radius = 0.58
		kit.mesh(machine, "FanGuard", guard, Vector3(0, 1.15, -1.995), mats["dark"], Vector3(90, 0, 0), false)
		for angle: float in [0.0, 90.0]:
			var bar: Node3D = _box(machine, "GuardBar", Vector3(0, 1.15, -2.0), Vector3(1.12, 0.025, 0.012), "dark")
			bar.rotation_degrees.z = angle
		kit.cylinder(machine, "Exhaust", Vector3(0.7, 2.8, -1.2), 0.09, 1.5, mats["steel"], false)
		_light(room, "UtilityFluorescent", Vector3(56.8, 4.48, z + 2.5))
	_archive_shelf(room, "MaintenanceStores", Vector3(53.6, FLOOR, -13.5), 90, 9)
	_sign(room, "UtilityWarning", "HIGH VOLTAGE / KEEP ACCESS CLEAR", Vector3(60.62, 3.3, -24), -90, 3.0)
	# Switchgear line-up in the south-east corner, fed up into a cable tray.
	for i: int in 3:
		var z: float = -5.6 + i * 1.3
		_model(room, SWITCHGEAR_NARROW if i == 1 else SWITCHGEAR, "Switchgear", Vector3(60.33, FLOOR, z), -90, 1.8)
		_box(room, "Conduit", Vector3(60.45, 3.47, z), Vector3(0.08, 1.65, 0.08), "steel")
	_box(room, "CableTray", Vector3(60.2, 4.3, -14.0), Vector3(0.45, 0.08, 26.5), "steel")
	_box(room, "CableBundle", Vector3(60.2, 4.36, -14.0), Vector3(0.34, 0.06, 26.5), "rubber")
	for z: float in [-18.5, -8.5]:
		_box(room, "CrossTray", Vector3(58.7, 4.3, z), Vector3(3.0, 0.08, 0.35), "steel")
		_box(room, "GeneratorFeed", Vector3(57.2, 3.62, z + 1.0), Vector3(0.1, 1.37, 0.1), "dark")
		for side: float in [-1.0, 1.0]:
			_floor_line(room, "KeepClearSide", Vector3(57.2 + side * 1.75, 0, z), Vector3(0.08, 0, 5.5))
			_floor_line(room, "KeepClearEnd", Vector3(57.2, 0, z + side * 2.75), Vector3(3.5, 0, 0.08))
	_model(room, POWER_PANEL, "DistributionPanel", Vector3(60.38, FLOOR + 0.4, -16.3), -90, 0.75, ModelKit.Fit.HEIGHT, false)
	_model(room, POWER_PANEL, "DistributionPanel", Vector3(60.38, FLOOR + 0.4, -25.2), -90, 0.75, ModelKit.Fit.HEIGHT, false)
	var tank: Node3D = kit.group(room, "DieselDayTank", Vector3(59.2, FLOOR, -1.05))
	for x: float in [-0.7, 0.7]:
		_box(tank, "Cradle", Vector3(x, 0.175, 0), Vector3(0.25, 0.35, 0.9), "dark")
	var drum: CylinderMesh = CylinderMesh.new()
	drum.top_radius = 0.42
	drum.bottom_radius = 0.42
	drum.height = 2.2
	kit.mesh(tank, "Tank", drum, Vector3(0, 0.77, 0), mats["enamel"], Vector3(0, 0, 90))
	kit.cylinder(tank, "FillPipe", Vector3(0.8, 1.35, 0), 0.05, 0.4, mats["steel"], false)
	kit.collider(tank, "TankCollider", Vector3(0, 0.6, 0), Vector3(2.2, 1.2, 0.9))
	_sign(tank, "FuelSign", "DIESEL / NO SMOKING", Vector3(0, 0.77, -0.44), 180, 1.3)
	var bench: Node3D = _table(room, "GeneratorWorkbench", Vector3(53.15, FLOOR, -19.0), 2.2, 0.8, 0.9)
	bench.rotation_degrees.y = 90
	_model(bench, TOOLBOX, "Toolbox", Vector3(-0.5, 0.94, 0), 10, 0.4, ModelKit.Fit.WIDTH, false)
	_model(bench, VICE, "BenchVice", Vector3(0.7, 0.94, 0.2), 0, 0.28, ModelKit.Fit.HEIGHT, false)
	for z: float in [-10.3, -9.7, -9.1]:
		_model(room, SHELVES, "SparesShelf", Vector3(52.95, FLOOR, z), 90, 2.0)
	_box_pile(room, "FilterCartons", Vector3(53.5, FLOOR, -7.9), 2)
	for z: float in [-0.95, -1.6]:
		_model(room, BARREL_BLUE, "CoolantDrum", Vector3(53.15, FLOOR, z), z * 50, 0.88)
	_model(room, JERRYCAN, "FuelCan", Vector3(53.75, FLOOR, -2.35), 90, 0.45)
	_model(room, GENERATOR, "SpareGenerator", Vector3(59.7, FLOOR, -26.75), -90, 0.8, ModelKit.Fit.WIDTH)
	for z: float in [-25.6, -25.15]:
		_model(room, PROPANE, "PropaneTank", Vector3(60.3, FLOOR, z), z * 30, 0.6)
	_fire_point(room, "GeneratorFirePointWest", Vector3(52.88, FLOOR, -22.0), 90)
	_fire_point(room, "GeneratorFirePointEast", Vector3(60.48, FLOOR, -8.0), -90)
	_light(room, "GeneratorHallNorthLight", Vector3(56.8, 4.48, -24.8))
	_light(room, "GeneratorHallSouthLight", Vector3(56.8, 4.48, -2.0))
	_camera(room, "GeneratorCamera", Vector3(60.4, 4.3, -0.6), Vector3(56, 0.85, -12))
	# Communications room: UPS cabinet, breaker panel and a clock.
	_model(room, SWITCHGEAR_NARROW, "UPSCabinet", Vector3(51.45, FLOOR, -29.0), 90, 1.8)
	_model(room, POWER_PANEL, "CommsBreakerPanel", Vector3(51.38, FLOOR + 0.45, -31.0), 90, 0.75, ModelKit.Fit.HEIGHT, false)
	_clock(room, "CommsClock", Vector3(57.0, 3.3, -33.1), 0)
