extends GutTest


func test_fullscreen_computer_maps_mouse_to_station_os_viewport() -> void:
	var computer: DispatchComputer = DispatchComputer.new()
	computer.viewport_path = NodePath("TerminalLayer")
	var screen: MeshInstance3D = MeshInstance3D.new()
	screen.name = "ScreenDisplay"
	screen.mesh = QuadMesh.new()
	computer.add_child(screen)
	var terminal_viewport: SubViewport = SubViewport.new()
	terminal_viewport.name = "TerminalLayer"
	terminal_viewport.size = Vector2i(1152, 864)
	computer.add_child(terminal_viewport)
	add_child_autofree(computer)
	await get_tree().process_frame
	var rect: Rect2 = computer._screen_view.get_global_rect()
	assert_true(rect.size.x > 0.0 and rect.size.y > 0.0)
	assert_true(rect.position.x >= 0.0 and rect.end.x <= get_viewport().get_visible_rect().size.x)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.position = rect.get_center()
	var mapped: InputEventMouseButton = computer._project_mouse_event(click, click.position) as InputEventMouseButton
	assert_not_null(mapped)
	assert_almost_eq(mapped.position.x, 576.0, 0.1)
	assert_almost_eq(mapped.position.y, 432.0, 0.1)
	assert_null(computer._project_mouse_event(click, Vector2(rect.position.x - 10.0, rect.position.y)))
