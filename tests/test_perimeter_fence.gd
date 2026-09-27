extends SceneTree

func _init() -> void:
	print("\n================== RUNNING PERIMETER FENCE TESTS ==================")
	var total_tests: int = 0
	var passed_tests: int = 0
	
	# Test 1: Load standalone perimeter_fence.tscn
	print("Test: Load perimeter_fence.tscn")
	var scene: PackedScene = load("res://scenes/dispatch/perimeter_fence.tscn") as PackedScene
	total_tests += 1
	if scene != null:
		print("  [PASS] perimeter_fence.tscn loaded successfully")
		passed_tests += 1
	else:
		print("  [FAIL] Failed to load perimeter_fence.tscn")
	
	var fence_inst: Node3D = scene.instantiate() as Node3D
	root.add_child(fence_inst)
	
	# Test 2: Colliders body and 4 walls exist
	print("Test: Verify 4 perimeter collision boundaries")
	var colliders: StaticBody3D = fence_inst.get_node_or_null("Colliders") as StaticBody3D
	total_tests += 1
	if colliders != null:
		print("  [PASS] Colliders StaticBody3D found")
		passed_tests += 1
	else:
		print("  [FAIL] Colliders StaticBody3D not found")
	
	var wall_names: Array[String] = ["NorthWall", "SouthWall", "WestWall", "EastWall"]
	for w_name: String in wall_names:
		total_tests += 1
		var col: CollisionShape3D = colliders.get_node_or_null(w_name) as CollisionShape3D
		if col != null and col.shape is BoxShape3D:
			var bs: BoxShape3D = col.shape as BoxShape3D
			print("  [PASS] %s exists with BoxShape3D size=%s at pos=%s" % [w_name, bs.size, col.position])
			passed_tests += 1
		else:
			print("  [FAIL] %s missing or invalid shape" % w_name)
	
	fence_inst.queue_free()
	
	# Test 3: Operations room scene integration with duplicated fence meshes
	print("Test: Operations room scene contains duplicated fence mesh instances")
	var op_scene: PackedScene = load("res://scenes/dispatch/operations_room.tscn") as PackedScene
	total_tests += 1
	if op_scene != null:
		var op_inst: Node = op_scene.instantiate()
		root.add_child(op_inst)
		var pf: Node = op_inst.get_node_or_null("PerimeterFence")
		if pf != null:
			print("  [PASS] PerimeterFence is properly instantiated in operations_room.tscn")
			passed_tests += 1
			
			total_tests += 1
			var op_colliders: Node = pf.get_node_or_null("Colliders")
			if op_colliders != null and op_colliders.get_child_count() == 4:
				print("  [PASS] 4 perimeter wall colliders active in operations_room.tscn")
				passed_tests += 1
			else:
				print("  [FAIL] Missing wall colliders in operations_room.tscn")
			
			total_tests += 1
			var fence_nodes: Array[Node] = []
			for child: Node in pf.get_children():
				if child.name.begins_with("Fence_"):
					fence_nodes.append(child)
			if fence_nodes.size() == 84:
				print("  [PASS] Exactly 84 duplicated concrete fence meshes found in operations_room.tscn")
				passed_tests += 1
			else:
				print("  [FAIL] Expected 84 duplicated fence meshes, found %d" % fence_nodes.size())
			
			total_tests += 1
			var first_fence: Node = pf.get_node_or_null("Fence_N_00")
			if first_fence != null and first_fence.get_child_count() > 0:
				print("  [PASS] Duplicated fence mesh model loaded with visual child: %s" % first_fence.get_child(0).name)
				passed_tests += 1
			else:
				print("  [FAIL] Fence_N_00 has no visual mesh children")
		else:
			print("  [FAIL] PerimeterFence node not found in operations_room.tscn")
		op_inst.queue_free()
	else:
		print("  [FAIL] Failed to load operations_room.tscn")
	
	print("===================================================================")
	print("Results: %d passed, %d failed" % [passed_tests, total_tests - passed_tests])
	
	quit(0 if (passed_tests == total_tests) else 1)
