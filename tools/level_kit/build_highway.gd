## Builds Old Highway 9, mile marker 47, for The Meat Truck ambush.
class_name BuildHighway
extends RefCounted

const PATH: String = "res://scenes/field/missions/abandoned_highway.tscn"


static func build() -> Error:
	var root: Node3D = Node3D.new()
	root.name = "OldHighway9"
	var kit: LevelKit = LevelKit.new(root)
	kit.environment(root, 0.018, 0.10, false, 1.9)
	kit.moonlight(root, 0.24)
	var nav: MissionNavigation = MissionNavigation.new()
	kit.own(nav, root, "Navigation")
	_ground(kit, nav)
	_truck(kit, nav)
	_debris(kit, nav)
	_lights(kit, root)
	_mission(kit, root, nav)
	var scene: PackedScene = PackedScene.new()
	var result: Error = scene.pack(root)
	if result == OK:
		result = ResourceSaver.save(scene, PATH)
	root.free()
	return result


static func _ground(kit: LevelKit, nav: MissionNavigation) -> void:
	var land: Node3D = kit.group(nav, "Highway")
	kit.box(land, "Ground", Vector3(0, -0.2, 0), Vector3(72, 0.35, 105), kit.material("grass"))
	kit.box(land, "OldHighway9", Vector3(0, 0.0, 0), Vector3(11, 0.06, 105), kit.material("asphalt"))
	kit.box(land, "WestShoulder", Vector3(-7.0, 0.01, 0), Vector3(3, 0.05, 105), kit.material("highway_gravel"))
	kit.box(land, "EastShoulder", Vector3(7.0, 0.01, 0), Vector3(3, 0.05, 105), kit.material("highway_gravel"))
	kit.box(land, "FlankDirtRoad", Vector3(-15.5, 0.02, -1), Vector3(4, 0.05, 82), kit.material("highway_dirt"))
	kit.box(land, "SouthFlankLink", Vector3(-10.0, 0.025, 30), Vector3(11, 0.05, 4), kit.material("highway_dirt"))
	kit.box(land, "NorthFlankLink", Vector3(-10.0, 0.025, -33), Vector3(11, 0.05, 4), kit.material("highway_dirt"))
	for z: int in range(-44, 45, 8):
		kit.box(land, "CenterStripe%d" % z, Vector3(0, 0.044, float(z)), Vector3(0.15, 0.01, 3), kit.material("highway_stripe"), 0.0, false)
	for side: int in [-1, 1]:
		for i: int in 7:
			var z: float = -42.0 + i * 14.0
			kit.box(land, "GuardPost%d_%d" % [side, i], Vector3(side * 10.4, 0.45, z),
				Vector3(0.12, 0.9, 0.12), kit.material("steel"))
		kit.box(land, "GuardRail%d" % side, Vector3(side * 10.4, 0.68, 0),
			Vector3(0.12, 0.22, 87), kit.material("metal_painted"))
	var sign: Node3D = kit.group(nav, "MileMarker47", Vector3(7.5, 0, 25))
	kit.box(sign, "Post", Vector3(0, 1.0, 0), Vector3(0.12, 2.0, 0.12), kit.material("steel"))
	kit.box(sign, "Plate", Vector3(0, 1.8, 0), Vector3(0.9, 0.65, 0.08), kit.material("highway_sign"), 0.0, false)
	var label: Label3D = kit.own(Label3D.new(), sign, "Text") as Label3D
	label.position = Vector3(0, 1.8, 0.052)
	label.text = "OLD HWY 9\nMILE 47"
	label.font_size = 36
	label.pixel_size = 0.004
	label.modulate = Color(0.9, 0.9, 0.8)


static func _truck(kit: LevelKit, nav: MissionNavigation) -> void:
	var wreck: Node3D = kit.group(nav, "MeatTruck", Vector3(2.5, 0, -17))
	kit.box(wreck, "Cab", Vector3(0, 1.45, -4.3), Vector3(2.6, 2.9, 3.0), kit.material("rust_red"))
	kit.box(wreck, "Windshield", Vector3(0, 2.1, -5.83), Vector3(2.2, 0.9, 0.06), kit.material("glass_dark"), 0.0, false)
	kit.box(wreck, "ReeferBox", Vector3(0, 1.8, 1.6), Vector3(2.65, 3.5, 8.4), kit.material("metal_painted"))
	kit.box(wreck, "RearDoorLeft", Vector3(-0.66, 1.75, 5.85), Vector3(1.3, 3.35, 0.08), kit.material("steel"), 0.0, false)
	kit.box(wreck, "RearDoorRight", Vector3(0.66, 1.75, 5.85), Vector3(1.3, 3.35, 0.08), kit.material("steel"), 0.0, false)
	kit.box(wreck, "CoolingUnit", Vector3(0, 3.2, -2.85), Vector3(2.3, 0.8, 0.7), kit.material("metal_dark"), 0.0, false)
	for z: float in [-4.0, -1.0, 3.6]:
		for x: float in [-1.4, 1.4]:
			var wheel: CylinderMesh = CylinderMesh.new()
			wheel.top_radius = 0.48
			wheel.bottom_radius = 0.48
			wheel.height = 0.25
			kit.mesh(wreck, "Wheel%d_%d" % [int(x * 10), int(z * 10)], wheel,
				Vector3(x, 0.5, z), kit.material("rubber"), Vector3(0, 0, 90))
	var light: OmniLight3D = kit.own(OmniLight3D.new(), wreck, "DeadHazardLamp") as OmniLight3D
	light.position = Vector3(-1.4, 1.3, 5.95)
	light.light_color = Color(1.0, 0.08, 0.015)
	light.light_energy = 0.8
	light.omni_range = 5.0
	light.shadow_enabled = false


static func _debris(kit: LevelKit, nav: MissionNavigation) -> void:
	var props: Node3D = kit.group(nav, "RoadsideCover")
	kit.cruiser(props, "AbandonedCivilianCar", Vector3(7, 0, -31), 22.0)
	kit.jersey_barrier(props, "BlockedLaneA", Vector3(-2.8, 0, -38), 0.0)
	kit.jersey_barrier(props, "BlockedLaneB", Vector3(2.8, 0, -38), 0.0)
	for i: int in 4:
		kit.barrel(props, "RustBarrel%d" % i, Vector3(-7.0 + float(i % 2), 0, -18.0 - float(i / 2) * 4))
	for i: int in 3:
		kit.crate_stack(props, "Cargo%d" % i, Vector3(8 + float(i), 0, -9 - float(i) * 3), 10.0, 1)


static func _lights(kit: LevelKit, root: Node3D) -> void:
	var lights: Node3D = kit.group(root, "Lighting")
	kit.street_lamp(lights, "SouthSodium", Vector3(9, 0, 31), 0.0, 7.0, 5.0)
	kit.street_lamp(lights, "NorthSodium", Vector3(9, 0, -34), 180.0, 7.0, 4.0)
	for fixture: Node in lights.get_children():
		for light: Node in fixture.find_children("*", "Light3D", true, false):
			(light as Light3D).shadow_enabled = false


static func _mission(kit: LevelKit, root: Node3D, nav: MissionNavigation) -> void:
	var extraction: Node3D = kit.group(root, "Extraction", Vector3(-6, 0, 42))
	kit.cruiser(extraction, "PoliceVan", Vector3.ZERO, 90.0, true)
	kit.group(root, "Players")
	var spawns: Node3D = kit.group(root, "SpawnPoints")
	for i: int in 4:
		kit.marker(spawns, "Spawn%d" % (i + 1), Vector3(-6.0 + float(i) * 1.4, 0.05, 37), 180.0)
	var player_spawner: PlayerSpawner = PlayerSpawner.new()
	kit.own(player_spawner, root, "PlayerSpawner")
	player_spawner.spawn_path = NodePath("../Players")
	player_spawner.spawn_points = spawns
	var squad: AISquad = AISquad.new()
	kit.own(squad, root, "HighwayCultSquad")
	kit.group(root, "Enemies")
	var points: Node3D = kit.group(root, "EnemySpawnPoints")
	_enemy(kit, points, "AmbushLeader", "ambush_leader", Vector3(7, 0.05, -29))
	_enemy(kit, points, "RpgGunner", "cultist_gunman", Vector3(12, 0.05, -35))
	_enemy(kit, points, "TruckGuard", "cultist_gunman", Vector3(-2.0, 0.05, -20))
	_enemy(kit, points, "FlankGuard", "thug", Vector3(-18, 0.05, -27))
	var enemy_spawner: EnemySpawner = EnemySpawner.new()
	kit.own(enemy_spawner, root, "EnemySpawner")
	enemy_spawner.spawn_path = NodePath("../Enemies")
	enemy_spawner.spawn_points = points
	enemy_spawner.navigation = nav
	var controller: MissionController = MissionController.new()
	kit.own(controller, root, "MissionController")
	controller.extraction_point = extraction.get_node("PoliceVan") as Node3D
	controller.extraction_radius = 4.5
	_set_piece(kit, root)


static func _enemy(kit: LevelKit, parent: Node3D, name: String, archetype_name: String, at: Vector3) -> void:
	var point: EnemySpawnPoint = EnemySpawnPoint.new()
	kit.own(point, parent, name)
	point.position = at
	point.archetype = load("res://data/ai/archetypes/%s.tres" % archetype_name) as ArchetypeData
	point.squad = NodePath("../../HighwayCultSquad")
	point.mission_kinds = [&"ambush", &"raid"]


static func _set_piece(kit: LevelKit, root: Node3D) -> void:
	var event: HighwayRpgSetPiece = HighwayRpgSetPiece.new()
	kit.own(event, root, "RpgSetPiece")
	var cruiser: Node3D = kit.cruiser(event, "EmptyDecoyCruiser", Vector3(1, 0, 8), 0.0)
	event.cruiser = cruiser
	var trigger: Area3D = kit.own(Area3D.new(), event, "ApproachTrigger") as Area3D
	trigger.position = Vector3(0, 1.5, 25)
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	var trigger_shape: CollisionShape3D = kit.own(CollisionShape3D.new(), trigger, "Shape") as CollisionShape3D
	var trigger_box: BoxShape3D = BoxShape3D.new()
	trigger_box.size = Vector3(40, 3, 4)
	trigger_shape.shape = trigger_box
	event.trigger = trigger
	var control: HighwayDecoyControl = HighwayDecoyControl.new()
	kit.own(control, event, "RemoteDriveUplink")
	control.position = Vector3(-4.5, 1.0, 22.4)
	control.set_piece = event
	var control_shape: CollisionShape3D = kit.own(CollisionShape3D.new(), control, "Shape") as CollisionShape3D
	var control_box: BoxShape3D = BoxShape3D.new()
	control_box.size = Vector3(0.7, 1.0, 0.35)
	control_shape.shape = control_box
	kit.box(event, "UplinkStand", Vector3(-4.5, 0.5, 22.0), Vector3(0.5, 1.0, 0.4), kit.material("metal_dark"))
	kit.box(event, "UplinkScreen", Vector3(-4.5, 1.1, 22.23), Vector3(0.45, 0.3, 0.04), kit.material("led_blue"), 0.0, false)
	var launch: Marker3D = kit.marker(event, "RpgLaunch", Vector3(12, 1.8, -35))
	event.launch_point = launch
	var projectile_mesh: SphereMesh = SphereMesh.new()
	projectile_mesh.radius = 0.15
	projectile_mesh.height = 0.3
	event.projectile = kit.mesh(event, "RpgProjectile", projectile_mesh, launch.position, kit.material("led_red"), Vector3.ZERO, false)
	var blast_mesh: SphereMesh = SphereMesh.new()
	blast_mesh.radius = 1.7
	blast_mesh.height = 3.4
	event.blast = kit.mesh(event, "RpgBlast", blast_mesh, Vector3(1, 1.2, 8), kit.material("diffuser_warm"), Vector3.ZERO, false)
