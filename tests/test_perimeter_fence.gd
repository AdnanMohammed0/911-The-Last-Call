extends SceneTree

func _init() -> void:
	print("\n================== RUNNING PERIMETER FENCE TESTS ==================")
	var total_tests: int = 0
	var passed_tests: int = 0
	
	# Test 1: Load perimeter_fence.tscn
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
	
	# Test 3: Visual fence segments
	print("Test: Verify 84 visual fence segment instances")
	var fences: Node3D = fence_inst.get_node_or_null("Fences") as Node3D
	total_tests += 1
	if fences != null and fences.get_child_count() == 84:
		print("  [PASS] 84 fence segments instantiated around perimeter")
		passed_tests += 1
	else:
		var count: int = fences.get_child_count() if fences else 0
		print("  [FAIL] Expected 84 fence segments, got %d" % count)
	
	# Verify segments for all 4 sides exist
	var has_north: bool = fences.has_node("Fence_N_00") and fences.has_node("Fence_N_22")
	var has_south: bool = fences.has_node("Fence_S_00") and fences.has_node("Fence_S_22")
	var has_west: bool = fences.has_node("Fence_W_00") and fences.has_node("Fence_W_18")
	var has_east: bool = fences.has_node("Fence_E_00") and fences.has_node("Fence_E_18")
	total_tests += 1
	if has_north and has_south and has_west and has_east:
		print("  [PASS] All cardinal directions (North, South, West, East) have full segment chains")
		passed_tests += 1
	else:
		print("  [FAIL] Missing directional fence segments")
	
	fence_inst.queue_free()
	
	# Test 4: Operations room integration
	print("Test: Operations room scene integration")
	var op_scene: PackedScene = load("res://scenes/dispatch/operations_room.tscn") as PackedScene
	total_tests += 1
	if op_scene != null:
		var op_inst: Node = op_scene.instantiate()
		root.add_child(op_inst)
		var pf: Node = op_inst.get_node_or_null("PerimeterFence")
		if pf != null:
			print("  [PASS] PerimeterFence is properly instantiated in operations_room.tscn")
			passed_tests += 1
		else:
			print("  [FAIL] PerimeterFence node not found in operations_room.tscn")
		op_inst.queue_free()
	else:
		print("  [FAIL] Failed to load operations_room.tscn")
	
	print("===================================================================")
	print("Results: %d passed, %d failed" % [passed_tests, total_tests - passed_tests])
	
	quit(0 if (passed_tests == total_tests) else 1)
