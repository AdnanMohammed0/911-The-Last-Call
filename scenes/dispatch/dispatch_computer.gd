## Dispatch Computer (Station OS): An in-world interactive CAD workstation (scenes/dispatch/station/cad_monitor.tscn).
## The CRT monitor screen shows the live Windows 11 / Station OS desktop rendered from a SubViewport; bought
## workstations that have no viewport of their own mirror the station's shared Station OS viewport.
## Interacting seats the player at the desk and shows the viewport at readable screen size.
## Mouse and keyboard input are forwarded into the same viewport used by the in-world display.
## Pressing [Esc] or clicking Stand Up smoothly returns the player to first-person walking.
class_name DispatchComputer
extends Interactable

const SCREEN_SIZE: Vector2 = Vector2(0.448, 0.336)
const SEAT_DISTANCE: float = 0.28
const TRANSITION_TIME: float = 0.30

@export var screen_mesh_path: NodePath = NodePath("ScreenDisplay")
@export var viewport_path: NodePath = NodePath("../TerminalLayer")

var _screen_mesh: MeshInstance3D
var _viewport: SubViewport
var _player: Player = null
var _camera: Camera3D = null
var _orig_cam_xform: Transform3D
var _cam_tween: Tween = null
var _is_active: bool = false
var _world_3d_was_disabled: bool = false
var _hint_hud: CanvasLayer = null
var _screen_hud: CanvasLayer = null
var _screen_view: TextureRect = null


func _ready() -> void:
	add_to_group(&"dispatch_computers")
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	prompt_text = "Use computer (Station OS)"
	max_distance = 4.0
	cooldown = 0.2
	
	_setup_screen_material()
	_create_screen_hud()
	_create_hint_hud()
	_refresh_idle_screen()
	
	var desktop: StationOS = StationOS.find(get_tree())
	if desktop != null:
		_bind_desktop(desktop)


func _bind_desktop(desktop: StationOS) -> void:
	if not desktop.closed.is_connected(_on_desktop_closed):
		desktop.closed.connect(_on_desktop_closed)


func _setup_screen_material() -> void:
	_screen_mesh = get_node_or_null(screen_mesh_path) as MeshInstance3D
	_viewport = get_node_or_null(viewport_path) as SubViewport
	if _viewport == null:
		var desktop: StationOS = StationOS.find(get_tree())
		if desktop != null:
			_viewport = desktop.get_viewport() as SubViewport
	if _screen_mesh == null or _viewport == null:
		return
	
	# Find and free the model's built-in black CRT screen mesh
	var model_node: Node = get_node_or_null("Model")
	if model_node != null:
		_remove_built_in_screen_mesh(model_node)
	
	# Keep the world-space monitor image, but render the desktop only while in use.
	if not _shared_viewport_in_use():
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _viewport.get_texture()
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.render_priority = 2
	_screen_mesh.material_override = mat


func _refresh_idle_screen() -> void:
	if _viewport == null or _shared_viewport_in_use():
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if is_instance_valid(_viewport) and not _shared_viewport_in_use():
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _shared_viewport_in_use() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"dispatch_computers"):
		var computer: DispatchComputer = node as DispatchComputer
		if computer != null and computer._is_active and computer._viewport == _viewport:
			return true
	return false


func _remove_built_in_screen_mesh(node: Node) -> void:
	if node.name == "Monitor" or node.name == "0":
		node.queue_free()
		return
	for child: Node in node.get_children():
		_remove_built_in_screen_mesh(child)


func _create_screen_hud() -> void:
	if _viewport == null:
		return
	_screen_hud = CanvasLayer.new()
	_screen_hud.layer = 49
	_screen_hud.visible = false
	add_child(_screen_hud)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.008, 0.012, 0.018, 0.98)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_hud.add_child(backdrop)
	_screen_view = TextureRect.new()
	_screen_view.texture = _viewport.get_texture()
	_screen_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen_view.stretch_mode = TextureRect.STRETCH_SCALE
	_screen_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_hud.add_child(_screen_view)
	_fit_screen_view()
	get_viewport().size_changed.connect(_fit_screen_view)


func _fit_screen_view() -> void:
	if _screen_view == null or _viewport == null:
		return
	var window_size: Vector2 = get_viewport().get_visible_rect().size
	var available: Vector2 = (window_size - Vector2(32, 80)).max(Vector2.ONE)
	var aspect: float = float(_viewport.size.x) / float(_viewport.size.y)
	var height: float = minf(available.y, available.x / aspect)
	_screen_view.size = Vector2(height * aspect, height)
	_screen_view.position = Vector2((window_size.x - _screen_view.size.x) * 0.5, 16.0 + (available.y - height) * 0.5)


func _create_hint_hud() -> void:
	_hint_hud = CanvasLayer.new()
	_hint_hud.layer = 50
	_hint_hud.visible = false
	add_child(_hint_hud)
	
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	_hint_hud.add_child(margin)
	
	var box: HBoxContainer = HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.size_flags_vertical = Control.SIZE_SHRINK_END
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	
	var exit_btn: Button = Button.new()
	exit_btn.text = "⏏ Stand Up [Esc]"
	exit_btn.focus_mode = Control.FOCUS_NONE
	exit_btn.pressed.connect(leave_computer)
	box.add_child(exit_btn)
	
	var view_label: Label = Label.new()
	view_label.text = "·   STATION OS"
	view_label.modulate = Color(0.8, 0.85, 0.9, 0.8)
	box.add_child(view_label)


func _can_interact(_peer_id: int) -> bool:
	return not _is_active


func _on_interact(peer_id: int) -> void:
	_start_using(peer_id)


func _on_interacted(peer_id: int) -> void:
	_start_using(peer_id)


func _start_using(peer_id: int) -> void:
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if peer_id != my_id and peer_id != 0:
		if NetManager.is_online():
			return
	if _is_active:
		return
	
	var player: Player = Player.find_by_peer(get_tree(), peer_id)
	if player == null:
		player = Player.find_by_peer(get_tree(), 1)
	if player == null:
		player = get_tree().get_first_node_in_group(&"players") as Player
	if player == null:
		return
	
	_player = player
	_camera = player.get_camera()
	if _camera == null:
		return
	
	_orig_cam_xform = _camera.global_transform
	_player.set_input_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_is_active = true
	_world_3d_was_disabled = get_viewport().disable_3d
	get_viewport().disable_3d = true
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	_tween_camera_to_view(SEAT_DISTANCE)
	if _screen_hud != null:
		_fit_screen_view()
		_screen_hud.visible = true
	if _hint_hud != null:
		_hint_hud.visible = true
	
	var desktop: StationOS = StationOS.find(get_tree())
	if desktop != null:
		_bind_desktop(desktop)
		desktop.open()


func leave_computer() -> void:
	if not _is_active:
		return
	_is_active = false
	get_viewport().disable_3d = _world_3d_was_disabled
	
	if _screen_hud != null:
		_screen_hud.visible = false
	if _hint_hud != null:
		_hint_hud.visible = false
	
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	
	if _camera != null and is_instance_valid(_camera):
		_cam_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_cam_tween.tween_property(_camera, "global_transform", _orig_cam_xform, TRANSITION_TIME * 0.85)
		_cam_tween.tween_callback(_finish_leave)
	else:
		_finish_leave()
	
	var desktop: StationOS = StationOS.find(get_tree())
	var terminal: DispatchTerminal = DispatchTerminal.find(get_tree())
	if terminal != null and terminal.visible:
		terminal.close()
	if desktop != null and desktop.is_open():
		desktop.close()
	_refresh_idle_screen()


func _finish_leave() -> void:
	if _player != null and is_instance_valid(_player):
		_player.set_input_enabled(true)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_player = null
	_camera = null


func _on_desktop_closed() -> void:
	if _is_active:
		leave_computer()


func _tween_camera_to_view(distance: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	
	var target_xform: Transform3D = _get_camera_view_transform(distance)
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(_camera, "global_transform", target_xform, TRANSITION_TIME)


func _get_camera_view_transform(distance: float) -> Transform3D:
	var screen_xform: Transform3D = _screen_mesh.global_transform if _screen_mesh != null else global_transform
	var screen_center: Vector3 = screen_xform.origin
	var screen_normal: Vector3 = screen_xform.basis.z.normalized()
	
	var eye_pos: Vector3 = screen_center + screen_normal * distance
	var target_basis: Basis = Basis.looking_at(screen_center - eye_pos, Vector3.UP)
	return Transform3D(target_basis, eye_pos)


func _input(event: InputEvent) -> void:
	if not _is_active:
		return
	if event.is_action_pressed(&"ui_cancel"):
		leave_computer()
		get_viewport().set_input_as_handled()
		return
	
	if event is InputEventMouse:
		var vp_event: InputEvent = _project_mouse_event(event, (event as InputEventMouse).position)
		if vp_event != null and _viewport != null:
			_viewport.push_input(vp_event)
			get_viewport().set_input_as_handled()
			return
	
	if event is InputEventKey:
		if _viewport != null:
			_viewport.push_input(event)
			get_viewport().set_input_as_handled()
			return


func _project_mouse_event(event: InputEvent, mouse_pos: Vector2) -> InputEvent:
	if _screen_view == null or _viewport == null:
		return null
	var rect: Rect2 = _screen_view.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not rect.has_point(mouse_pos):
		return null
	var ratio: Vector2 = Vector2(float(_viewport.size.x) / rect.size.x, float(_viewport.size.y) / rect.size.y)
	var vp_pos: Vector2 = (mouse_pos - rect.position) * ratio
	var cloned: InputEvent = event.duplicate()
	if cloned is InputEventMouse:
		var me: InputEventMouse = cloned as InputEventMouse
		me.position = vp_pos
		me.global_position = vp_pos
		if me is InputEventMouseMotion:
			(me as InputEventMouseMotion).relative *= ratio
	return cloned
