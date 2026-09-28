## Renders 3D models into transparent icon textures at runtime (weapon silhouettes for the HUD, product
## photos for StationMart). Requests are queued and rendered one at a time in an off-screen SubViewport with
## its own world and studio lighting; results are cached per key.
##   IconStudio.request(tree, &"weapon_rifle", builder, callback)  — builder returns a Node3D to photograph.
## Authority: LOCAL
class_name IconStudio
extends Node

const SIZE: Vector2i = Vector2i(384, 256)

static var _cache: Dictionary[StringName, Texture2D] = {}
static var _instance: IconStudio

var _queue: Array[Dictionary] = []
var _busy: bool = false
var _waiting: Dictionary[StringName, Array] = {}
var _viewport: SubViewport
var _stage: Node3D
var _camera: Camera3D


## Texture for `key`, or null until it has been rendered (then `callback(texture)` is called).
static func request(tree: SceneTree, key: StringName, builder: Callable, callback: Callable, view: Vector3 = Vector3(0.9, 0.35, 1.0)) -> Texture2D:
	if _cache.has(key):
		var cached: Texture2D = _cache[key]
		if callback.is_valid():
			callback.call(cached)
		return cached
	if DisplayServer.get_name() == "headless" or tree == null:
		return null
	if _instance == null or not is_instance_valid(_instance):
		_instance = IconStudio.new()
		_instance.name = "IconStudio"
		tree.root.add_child.call_deferred(_instance)
	_instance._enqueue(key, builder, callback, view)
	return null


static func cached(key: StringName) -> Texture2D:
	return _cache.get(key)


## Convenience: side view of a weapon (muzzle to the left like a loadout screen).
static func weapon(tree: SceneTree, model_id: StringName, callback: Callable) -> Texture2D:
	return request(tree, StringName("weapon_%s" % model_id), func() -> Node3D:
		var model: WeaponModel = WeaponModel.build_model(model_id, false)
		var holder: Node3D = Node3D.new()
		holder.add_child(model)
		return holder, callback, Vector3(-1.0, 0.05, 0.0))


func _enqueue(key: StringName, builder: Callable, callback: Callable, view: Vector3) -> void:
	if _waiting.has(key):
		if callback.is_valid():
			_waiting[key].append(callback)
		return
	_waiting[key] = [callback] if callback.is_valid() else []
	_queue.append({"key": key, "builder": builder, "view": view})
	if is_inside_tree() and not _busy:
		_pump.call_deferred()


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.65)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-40, 35, 0)
	key_light.light_energy = 1.6
	_viewport.add_child(key_light)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, -150, 0)
	rim.light_energy = 0.9
	rim.light_color = Color(0.7, 0.8, 1.0)
	_viewport.add_child(rim)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_viewport.add_child(_camera)
	_stage = Node3D.new()
	_viewport.add_child(_stage)
	_pump.call_deferred()


func _pump() -> void:
	if _busy or _queue.is_empty():
		return
	_busy = true
	while not _queue.is_empty():
		var job: Dictionary = _queue.pop_front()
		var key: StringName = job["key"]
		var builder: Callable = job["builder"]
		var view: Vector3 = job["view"]
		var subject: Node3D = builder.call()
		var texture: Texture2D = null
		if subject != null:
			_stage.add_child(subject)
			var box: AABB = ModelKit.bounds_in(subject, _stage)
			var centre: Vector3 = box.get_center()
			var dir: Vector3 = view.normalized()
			var radius: float = maxf(box.size.length() * 0.5, 0.05)
			_camera.position = centre + dir * radius * 4.0
			_camera.look_at(centre, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)
			# Fit the ortho frame to the projected bounds.
			var right: Vector3 = _camera.global_basis.x
			var up: Vector3 = _camera.global_basis.y
			var half_w: float = 0.0
			var half_h: float = 0.0
			for i: int in 8:
				var corner: Vector3 = box.get_endpoint(i) - centre
				half_w = maxf(half_w, absf(corner.dot(right)))
				half_h = maxf(half_h, absf(corner.dot(up)))
			var aspect: float = float(SIZE.x) / SIZE.y
			_camera.size = maxf(half_h, half_w / aspect) * 2.0 * 1.08
			_camera.near = 0.01
			_camera.far = radius * 10.0
			_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			await get_tree().process_frame
			_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			var image: Image = _viewport.get_texture().get_image()
			texture = ImageTexture.create_from_image(image)
			subject.queue_free()
			await get_tree().process_frame
		if texture != null:
			_cache[key] = texture
		var callbacks: Array = _waiting.get(key, [])
		_waiting.erase(key)
		for callback: Callable in callbacks:
			if callback.is_valid() and texture != null:
				callback.call(texture)
	_busy = false
