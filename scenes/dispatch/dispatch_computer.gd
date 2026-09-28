## Dispatch Computer (Station OS): An in-world interactive PC-9801 retro workstation.
## The CRT monitor screen shows the live Windows 11 / Station OS desktop rendered from a SubViewport.
## Interacting seats the player at the desk, framing the retro monitor realistically without covering
## the whole screen, and allowing direct mouse and keyboard interaction with all OS apps.
## Pressing [Esc] or clicking Stand Up smoothly returns the player to first-person walking.
class_name DispatchComputer
extends Interactable

const SCREEN_SIZE: Vector2 = Vector2(0.465, 0.35)
const SEAT_DISTANCE: float = 0.65
const ZOOM_DISTANCE: float = 0.38
const TRANSITION_TIME: float = 0.35

@export var screen_mesh_path: NodePath = NodePath("ScreenDisplay")
@export var viewport_path: NodePath = NodePath("../TerminalLayer")

var _screen_mesh: MeshInstance3D
var _viewport: SubViewport
var _player: Player = null
var _camera: Camera3D = null
var _orig_cam_xform: Transform3D
var _cam_tween: Tween = null
var _is_active: bool = false
var _is_zoomed: bool = false
var _hint_hud: CanvasLayer = null


func _ready() -> void:
	super()
	prompt_text = "Use computer (Station OS)"
	max_distance = 2.4
	cooldown = 0.3
	_setup_screen_material()
	_create_hint_hud()
	
	# Connect to desktop close signal to exit seated mode if user logs off
	var desktop: StationOS = StationOS.find(get_tree())
	if desktop != null:
		desktop.closed.connect(_on_desktop_closed)


func _setup_screen_material() -> void:
	_screen_mesh = get_node_or_null(screen_mesh_path) as MeshInstance3D
	_viewport = get_node_or_null(viewport_path) as SubViewport
	if _screen_mesh == null or _viewport == null:
		return
	
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = _viewport.get_texture()
	mat.emission_enabled = true
	mat.emission_texture = _viewport.get_texture()
	mat.emission_energy_multiplier = 1.0
	mat.roughness = 0.2
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	_screen_mesh.material_override = mat


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
	
	var zoom_label: Label = Label.new()
	zoom_label.text = "·   [Hold Right Click] Lean In"
	zoom_label.modulate = Color(0.8, 0.85, 0.9, 0.8)
	box.add_child(zoom_label)


func _on_interacted(peer_id: int) -> void:
	if peer_id != multiplayer.get_unique_id():
		return
	if _is_active:
		return
	
	var player: Player = Player.find_by_peer(get_tree(), peer_id)
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
	_is_zoomed = false
	
	_tween_camera_to_view(SEAT_DISTANCE)
	if _hint_hud != null:
		_hint_hud.visible = true
	
	var desktop: StationOS = StationOS.find(get_tree())
	if desktop != null:
		desktop.open()


func leave_computer() -> void:
	if not _is_active:
		return
	_is_active = false
	_is_zoomed = false
	
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
	if desktop != null and desktop.is_open():
		desktop.close()


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


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return
	
	if event.is_action_pressed(&"ui_cancel"):
		leave_computer()
		get_viewport().set_input_as_handled()
		return
	
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_is_zoomed = mb.pressed
			_tween_camera_to_view(ZOOM_DISTANCE if _is_zoomed else SEAT_DISTANCE)
			get_viewport().set_input_as_handled()
			return
	
	if event is InputEventMouse:
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var vp_event: InputEvent = _project_mouse_event(event, mouse_pos)
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
	if _camera == null or _screen_mesh == null or _viewport == null:
		return null
	
	var from: Vector3 = _camera.project_ray_origin(mouse_pos)
	var dir: Vector3 = _camera.project_ray_normal(mouse_pos)
	var screen_xform: Transform3D = _screen_mesh.global_transform
	var screen_normal: Vector3 = screen_xform.basis.z.normalized()
	
	var plane: Plane = Plane(screen_normal, screen_xform.origin.dot(screen_normal))
	var hit: Variant = plane.intersects_ray(from, dir)
	if not (hit is Vector3):
		return null
	
	var hit_pos: Vector3 = hit
	var local: Vector3 = screen_xform.affine_inverse() * hit_pos
	
	var w: float = SCREEN_SIZE.x
	var h: float = SCREEN_SIZE.y
	var u: float = (local.x + w * 0.5) / w
	var v: float = (h * 0.5 - local.y) / h
	
	u = clampf(u, 0.0, 1.0)
	v = clampf(v, 0.0, 1.0)
	
	var vp_pos: Vector2 = Vector2(u * float(_viewport.size.x), v * float(_viewport.size.y))
	var cloned: InputEvent = event.duplicate()
	if cloned is InputEventMouse:
		var me: InputEventMouse = cloned as InputEventMouse
		me.position = vp_pos
		me.global_position = vp_pos
	return cloned
