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


func test_escape_leaves_computer_and_hides_fullscreen_view() -> void:
	var computer: DispatchComputer = DispatchComputer.new()
	add_child_autofree(computer)
	computer._screen_hud = CanvasLayer.new()
	computer._is_active = true
	computer._screen_hud.visible = true
	computer._hint_hud.visible = true
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	computer._input(escape)
	assert_false(computer._is_active)
	assert_false(computer._screen_hud.visible)
	assert_false(computer._hint_hud.visible)


func test_windows_logoff_leaves_computer() -> void:
	var computer: DispatchComputer = DispatchComputer.new()
	add_child_autofree(computer)
	var desktop: StationOS = StationOS.new()
	autofree(desktop)
	computer._bind_desktop(desktop)
	computer._is_active = true
	desktop.closed.emit()
	assert_false(computer._is_active)


func test_idle_workstation_does_not_freeze_active_shared_desktop() -> void:
	var active: DispatchComputer = DispatchComputer.new()
	var idle: DispatchComputer = DispatchComputer.new()
	add_child_autofree(active)
	add_child_autofree(idle)
	var shared: SubViewport = SubViewport.new()
	shared.size = Vector2i(1152, 864)
	active.add_child(shared)
	active._viewport = shared
	idle._viewport = shared
	active._is_active = true
	shared.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	idle._refresh_idle_screen()
	assert_eq(shared.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
