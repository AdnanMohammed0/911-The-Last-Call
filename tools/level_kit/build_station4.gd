## Builds res://scenes/dispatch/operations_room.tscn — Blackvale County 911, Station 4:
## Features the full authentic 3D police station map (res://assets/3D/station/map3.glb / station_map.tscn)
## with all old greybox map geometry removed.
## Includes offices (4 operator workstations + supervisor office), laptops, monitors, 911 phones,
## swivel office chairs, server racks, and dramatic cinematic lighting with volumetric fog.
## Keeps the node contract other systems rely on (Geometry/*, SpawnPoints/Spawn*_<Class>, Doors/*,
## DispatchSetup, Players, PlayerSpawner). Run through tools/level_kit/build_levels.tscn.
## Authority: TOOLS
class_name BuildStation4
extends RefCounted

const PATH: String = "res://scenes/dispatch/operations_room.tscn"
const HEIGHT: float = 3.15
const FLOOR_Y: float = 0.25


static func build() -> Error:
	var root: Node3D = Node3D.new()
	root.name = "Station4_OperationsRoom"
	var kit: LevelKit = LevelKit.new(root)
	kit.environment(root, 0.012, 0.14, true, 1.45)
	kit.moonlight(root, 0.35)

	var geometry: Node3D = kit.group(root, "Geometry")

	# The authentic 3D Police Station Model (map3.glb with dynamic trimesh collisions + safety floor)
	kit.instance("res://scenes/dispatch/station_map.tscn", geometry, "StationModel", Transform3D.IDENTITY)

	# Clean zone groups to satisfy the test contract without any old map clutter
	var ops_room: Node3D = kit.group(geometry, "OperationsRoom")
	kit.group(geometry, "SecurityCorridor")
	kit.group(geometry, "Armory")
	kit.group(geometry, "ParkingLot")

	# Offices: Workstations, laptops, phones, chairs, and dramatic lighting
	_offices(kit, ops_room)

	# Interactive networked doors (hidden to avoid floating clutter in the 3D model)
	var doors: Node3D = kit.group(root, "Doors")
	var door_scene: String = "res://scenes/shared/door/door.tscn"
	var d1: Node = kit.instance(door_scene, doors, "Door_OpsToCorridor", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-2, FLOOR_Y, 0)))
	var d2: Node = kit.instance(door_scene, doors, "Door_CorridorToArmory", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(2, FLOOR_Y, -1)))
	var d3: Node = kit.instance(door_scene, doors, "Door_CorridorToParking", Transform3D(Basis.IDENTITY, Vector3(0, FLOOR_Y, 10)))
	(d1 as Node3D).visible = false
	(d2 as Node3D).visible = false
	(d3 as Node3D).visible = false

	# Computers, Phone, CAD terminals, Shift Clock
	kit.instance("res://scenes/dispatch/dispatch_setup.tscn", root, "DispatchSetup", Transform3D(Basis.IDENTITY, Vector3(0, FLOOR_Y, 0)))

	# Players and Spawns: securely placed on the floor (Y = FLOOR_Y + 0.1) in front of desks
	kit.group(root, "Players")
	var spawns: Node3D = kit.group(root, "SpawnPoints")
	kit.marker(spawns, "Spawn1_Tech", Vector3(-14, FLOOR_Y + 0.1, -1.0), 0.0)
	kit.marker(spawns, "Spawn2_Profiler", Vector3(-10, FLOOR_Y + 0.1, -1.0), 0.0)
	kit.marker(spawns, "Spawn3_Breacher", Vector3(-14, FLOOR_Y + 0.1, 1.0), 180.0)
	kit.marker(spawns, "Spawn4_Medic", Vector3(-10, FLOOR_Y + 0.1, 1.0), 180.0)
	var spawner: PlayerSpawner = PlayerSpawner.new()
	kit.own(spawner, root, "PlayerSpawner")
	spawner.spawn_path = NodePath("../Players")
	spawner.spawn_points = spawns

	var scene: PackedScene = PackedScene.new()
	var err: Error = scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, PATH)
	root.free()
	return err


static func _offices(kit: LevelKit, room: Node3D) -> void:
	# --- 1. Operator Desks (Tech, Profiler, Breacher, Medic) ---
	kit.desk(room, "DeskTech", Vector3(-14, FLOOR_Y, -2), 0.0, 2)
	kit.desk(room, "DeskProfiler", Vector3(-10, FLOOR_Y, -2), 0.0, 2, "screen_amber")
	kit.desk(room, "DeskBreacher", Vector3(-14, FLOOR_Y, 2), 180.0, 1)
	kit.desk(room, "DeskMedic", Vector3(-10, FLOOR_Y, 2), 180.0, 2)
	kit.box(room, "DeskBreacher_TacMap", Vector3(-14, FLOOR_Y + 0.8, 2), Vector3(1.6, 0.02, 0.9), kit.material("screen_blue"), 0.0, false)

	# --- 2. Laptops on Desks ---
	_laptop(kit, room, "LaptopTech", Vector3(-13.4, FLOOR_Y + 0.79, -1.85), 15.0, "screen_blue")
	_laptop(kit, room, "LaptopProfiler", Vector3(-10.8, FLOOR_Y + 0.79, -1.85), -15.0, "screen_amber")
	_laptop(kit, room, "LaptopBreacher", Vector3(-13.2, FLOOR_Y + 0.79, 1.85), 165.0, "screen_blue")
	_laptop(kit, room, "LaptopMedic", Vector3(-10.8, FLOOR_Y + 0.79, 1.85), 195.0, "screen_blue")
	_laptop(kit, room, "LaptopSupervisor", Vector3(-3.8, FLOOR_Y + 0.79, -4.35), 0.0, "screen_blue")

	# --- 3. 911 Hotline and Desk Phones ---
	_desk_phone(kit, room, "PhoneTech", Vector3(-12.8, FLOOR_Y + 0.79, -2.1), 0.0, true)
	_desk_phone(kit, room, "PhoneProfiler", Vector3(-9.2, FLOOR_Y + 0.79, -2.1), 0.0, true)
	_desk_phone(kit, room, "PhoneMedic", Vector3(-9.2, FLOOR_Y + 0.79, 2.1), 180.0, false)
	_desk_phone(kit, room, "PhoneSupervisor", Vector3(-4.6, FLOOR_Y + 0.79, -4.35), 20.0, false)

	# --- 4. Swivel Office Chairs ---
	_chair(kit, room, "ChairTech", Vector3(-14, FLOOR_Y, -1.1), 0.0)
	_chair(kit, room, "ChairProfiler", Vector3(-10, FLOOR_Y, -1.1), 0.0)
	_chair(kit, room, "ChairBreacher", Vector3(-14, FLOOR_Y, 1.1), 180.0)
	_chair(kit, room, "ChairMedic", Vector3(-10, FLOOR_Y, 1.1), 180.0)
	_chair(kit, room, "ChairSupervisor", Vector3(-3.8, FLOOR_Y, -3.7), 0.0)

	# --- 5. Supervisor Executive Office ---
	kit.desk(room, "SupervisorDesk", Vector3(-3.8, FLOOR_Y, -4.5), 0.0, 1)
	# Filing cabinets and storage behind supervisor
	_filing_cabinet(kit, room, "CabinetSupervisor1", Vector3(-2.2, FLOOR_Y, -5.2), 0.0)
	_filing_cabinet(kit, room, "CabinetSupervisor2", Vector3(-1.6, FLOOR_Y, -5.2), 0.0)

	# --- 6. Bullpen Equipment (Server Racks & Notice Board) ---
	kit.server_rack(room, "ServerRack1", Vector3(-16.8, FLOOR_Y, -4.5), 90.0)
	kit.server_rack(room, "ServerRack2", Vector3(-16.8, FLOOR_Y, -3.2), 90.0)

	# --- 7. Dramatic Lighting System ---
	var lights: Node3D = kit.group(room, "Lighting")

	# Overhead dramatic spotlights with volumetric beams focused on desks
	_dramatic_ceiling_spot(kit, lights, "SpotTech", Vector3(-14, HEIGHT, -2), Color(0.88, 0.94, 1.0), 3.2, 6.0)
	_dramatic_ceiling_spot(kit, lights, "SpotProfiler", Vector3(-10, HEIGHT, -2), Color(1.0, 0.88, 0.72), 3.2, 6.0)
	_dramatic_ceiling_spot(kit, lights, "SpotBreacher", Vector3(-14, HEIGHT, 2), Color(0.85, 0.92, 1.0), 3.2, 6.0)
	_dramatic_ceiling_spot(kit, lights, "SpotMedic", Vector3(-10, HEIGHT, 2), Color(0.9, 0.95, 1.0), 3.2, 6.0)
	_dramatic_ceiling_spot(kit, lights, "SpotSupervisor", Vector3(-3.8, HEIGHT, -4.2), Color(1.0, 0.88, 0.75), 2.8, 5.5)

	# Warm tungsten executive banker's lamp on Supervisor desk
	_bankers_desk_lamp(kit, room, "SupervisorLamp", Vector3(-4.5, FLOOR_Y + 0.79, -4.4), lights)

	# Colored screen specular glows on operator desks
	_screen_glow(kit, lights, "ScreenGlowTech", Vector3(-14, FLOOR_Y + 1.1, -1.9), Color(0.12, 0.5, 0.9), 0.6)
	_screen_glow(kit, lights, "ScreenGlowProfiler", Vector3(-10, FLOOR_Y + 1.1, -1.9), Color(0.95, 0.6, 0.15), 0.6)
	_screen_glow(kit, lights, "ScreenGlowBreacher", Vector3(-14, FLOOR_Y + 1.1, 1.9), Color(0.15, 0.65, 0.95), 0.8)
	_screen_glow(kit, lights, "ScreenGlowMedic", Vector3(-10, FLOOR_Y + 1.1, 1.9), Color(0.2, 0.85, 0.6), 0.6)

	# Architectural corridor rim lights leading to reception
	kit.bulkhead(lights, "HallwaySconce1", Vector3(-17.8, FLOOR_Y + 2.4, 0.0), 90.0, 2.2, 8.0)
	kit.bulkhead(lights, "HallwaySconce2", Vector3(-17.8, FLOOR_Y + 2.4, 6.0), 90.0, 2.2, 8.0)
	kit.bulkhead(lights, "HallwaySconce3", Vector3(-17.8, FLOOR_Y + 2.4, 12.0), 90.0, 2.2, 8.0)


## Clamshell laptop with open tilted emissive display
static func _laptop(kit: LevelKit, parent: Node, node_name: String, at: Vector3, yaw_deg: float, screen_mat: String) -> Node3D:
	var lap: Node3D = kit.group(parent, node_name, at)
	lap.rotation_degrees.y = yaw_deg
	# Base
	var base_mesh: BoxMesh = BoxMesh.new()
	base_mesh.size = Vector3(0.34, 0.015, 0.24)
	kit.mesh(lap, "Base", base_mesh, Vector3.ZERO, kit.material("metal_dark"))
	# Keyboard / Trackpad inset
	var kb_mesh: BoxMesh = BoxMesh.new()
	kb_mesh.size = Vector3(0.30, 0.003, 0.20)
	kit.mesh(lap, "Keyboard", kb_mesh, Vector3(0, 0.009, 0.01), kit.material("plastic_black"), Vector3.ZERO, false)
	# Screen lid angled back 115 degrees
	var lid_pivot: Node3D = kit.group(lap, "LidPivot", Vector3(0, 0.008, -0.115))
	lid_pivot.rotation_degrees.x = -25.0
	var lid_mesh: BoxMesh = BoxMesh.new()
	lid_mesh.size = Vector3(0.34, 0.22, 0.01)
	kit.mesh(lid_pivot, "Lid", lid_mesh, Vector3(0, 0.11, 0), kit.material("metal_dark"))
	# Emissive display screen
	var scr_mesh: BoxMesh = BoxMesh.new()
	scr_mesh.size = Vector3(0.31, 0.19, 0.003)
	kit.mesh(lid_pivot, "Screen", scr_mesh, Vector3(0, 0.11, 0.006), kit.material(screen_mat), Vector3.ZERO, false)
	return lap


## Desk telephone with keypad and emergency indicator
static func _desk_phone(kit: LevelKit, parent: Node, node_name: String, at: Vector3, yaw_deg: float, is_hotline: bool) -> Node3D:
	var phone: Node3D = kit.group(parent, node_name, at)
	phone.rotation_degrees.y = yaw_deg
	var body_mesh: BoxMesh = BoxMesh.new()
	body_mesh.size = Vector3(0.22, 0.05, 0.18)
	kit.mesh(phone, "Base", body_mesh, Vector3(0, 0.025, 0), kit.material("plastic_black"))
	var handset_mesh: BoxMesh = BoxMesh.new()
	handset_mesh.size = Vector3(0.24, 0.04, 0.06)
	var mat_name: String = "led_red" if is_hotline else "metal_painted"
	kit.mesh(phone, "Handset", handset_mesh, Vector3(-0.02, 0.065, 0), kit.material(mat_name))
	if is_hotline:
		var beacon: SphereMesh = SphereMesh.new()
		beacon.radius = 0.015
		beacon.height = 0.03
		kit.mesh(phone, "HotlineLed", beacon, Vector3(0.08, 0.055, -0.06), kit.material("led_red"), Vector3.ZERO, false)
	return phone


## Ergonomic office swivel chair
static func _chair(kit: LevelKit, parent: Node, node_name: String, at: Vector3, yaw_deg: float) -> Node3D:
	var chair: Node3D = kit.group(parent, node_name, at)
	chair.rotation_degrees.y = yaw_deg
	# 5-star base cylinder
	var base_mesh: CylinderMesh = CylinderMesh.new()
	base_mesh.top_radius = 0.28
	base_mesh.bottom_radius = 0.30
	base_mesh.height = 0.06
	kit.mesh(chair, "Base", base_mesh, Vector3(0, 0.05, 0), kit.material("metal_dark"), Vector3.ZERO, false)
	# Center hydraulic stem
	var stem_mesh: CylinderMesh = CylinderMesh.new()
	stem_mesh.top_radius = 0.025
	stem_mesh.bottom_radius = 0.025
	stem_mesh.height = 0.38
	kit.mesh(chair, "Stem", stem_mesh, Vector3(0, 0.24, 0), kit.material("steel"), Vector3.ZERO, false)
	# Padded seat
	var seat_mesh: BoxMesh = BoxMesh.new()
	seat_mesh.size = Vector3(0.52, 0.08, 0.50)
	kit.mesh(chair, "Seat", seat_mesh, Vector3(0, 0.44, 0), kit.material("fabric_dark"))
	# Backrest angled slightly
	var back_mesh: BoxMesh = BoxMesh.new()
	back_mesh.size = Vector3(0.48, 0.54, 0.06)
	kit.mesh(chair, "Backrest", back_mesh, Vector3(0, 0.72, 0.22), kit.material("fabric_dark"), Vector3(-6, 0, 0))
	return chair


## 3-drawer metal filing cabinet
static func _filing_cabinet(kit: LevelKit, parent: Node, node_name: String, at: Vector3, yaw_deg: float) -> Node3D:
	var cab: Node3D = kit.box(parent, node_name, at + Vector3(0, 0.55, 0), Vector3(0.48, 1.1, 0.62), kit.material("metal_painted"), yaw_deg)
	for i: int in 3:
		var handle_mesh: BoxMesh = BoxMesh.new()
		handle_mesh.size = Vector3(0.12, 0.02, 0.02)
		kit.mesh(cab, "Handle%d" % i, handle_mesh, Vector3(0, -0.3 + i * 0.32, 0.32), kit.material("steel"), Vector3.ZERO, false)
	return cab


## Focused dramatic ceiling spot with volumetric fog beam
static func _dramatic_ceiling_spot(kit: LevelKit, parent: Node, node_name: String, at: Vector3, color: Color, energy: float, spot_range: float) -> Node3D:
	var fixture: Node3D = kit.group(parent, node_name, at)
	# Ceiling bezel frame
	var frame: BoxMesh = BoxMesh.new()
	frame.size = Vector3(1.2, 0.03, 0.6)
	kit.mesh(fixture, "Frame", frame, Vector3(0, -0.015, 0), kit.material("metal_painted"), Vector3.ZERO, false)
	var diffuser: BoxMesh = BoxMesh.new()
	diffuser.size = Vector3(1.12, 0.01, 0.52)
	kit.mesh(fixture, "Diffuser", diffuser, Vector3(0, -0.03, 0), kit.material("diffuser_cool"), Vector3.ZERO, false)
	# Main dramatic spot
	var light: SpotLight3D = kit.own(SpotLight3D.new(), fixture, "Light") as SpotLight3D
	light.position = Vector3(0, -0.05, 0)
	light.rotation_degrees = Vector3(-90, 0, 0)
	light.light_color = color
	light.light_energy = energy
	light.spot_range = spot_range
	light.spot_angle = 68.0
	light.spot_angle_attenuation = 0.7
	light.spot_attenuation = 0.85
	light.light_size = 0.4
	light.shadow_enabled = true
	light.shadow_bias = 0.04
	light.light_volumetric_fog_energy = 0.85
	# Ambient fill
	var fill: OmniLight3D = kit.own(OmniLight3D.new(), fixture, "Fill") as OmniLight3D
	fill.position = Vector3(0, -0.4, 0)
	fill.light_color = color
	fill.light_energy = energy * 0.15
	fill.omni_range = spot_range * 0.55
	fill.light_volumetric_fog_energy = 0.0
	return fixture


## Banker's desk lamp for Supervisor desk
static func _bankers_desk_lamp(kit: LevelKit, room: Node3D, node_name: String, at: Vector3, lights: Node) -> Node3D:
	var lamp: Node3D = kit.group(room, node_name, at)
	# Base & stem
	var base_m: CylinderMesh = CylinderMesh.new()
	base_m.top_radius = 0.08
	base_m.bottom_radius = 0.09
	base_m.height = 0.025
	kit.mesh(lamp, "Base", base_m, Vector3(0, 0.012, 0), kit.material("metal_dark"), Vector3.ZERO, false)
	var stem_m: CylinderMesh = CylinderMesh.new()
	stem_m.top_radius = 0.012
	stem_m.bottom_radius = 0.012
	stem_m.height = 0.35
	kit.mesh(lamp, "Stem", stem_m, Vector3(0, 0.18, 0), kit.material("steel"), Vector3.ZERO, false)
	# Shade
	var shade_m: BoxMesh = BoxMesh.new()
	shade_m.size = Vector3(0.20, 0.08, 0.10)
	kit.mesh(lamp, "Shade", shade_m, Vector3(0, 0.36, 0), kit.material("metal_dark"), Vector3.ZERO, false)
	# Warm tungsten desk glow
	var light: OmniLight3D = kit.own(OmniLight3D.new(), lights, node_name + "_Glow") as OmniLight3D
	light.position = at + Vector3(0, 0.34, 0)
	light.light_color = Color(1.0, 0.82, 0.55)
	light.light_energy = 1.8
	light.omni_range = 3.2
	light.omni_attenuation = 1.2
	light.shadow_enabled = true
	light.light_volumetric_fog_energy = 0.6
	return lamp


## Screen specular glow for ambient computer reflection
static func _screen_glow(kit: LevelKit, parent: Node, node_name: String, at: Vector3, color: Color, energy: float) -> OmniLight3D:
	var glow: OmniLight3D = kit.own(OmniLight3D.new(), parent, node_name) as OmniLight3D
	glow.position = at
	glow.light_color = color
	glow.light_energy = energy
	glow.omni_range = 1.8
	glow.omni_attenuation = 1.6
	glow.light_volumetric_fog_energy = 0.3
	return glow
