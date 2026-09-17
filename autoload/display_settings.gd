## Window mode: starts fullscreen at 1920x1080 (project settings); F11 toggles windowed/fullscreen.
## Run with `-- --windowed` to start in a window (handy for several local instances).
## Authority: LOCAL
extends Node

const WINDOWED_SIZE: Vector2i = Vector2i(1280, 720)


func _ready() -> void:
	if "--windowed" in OS.get_cmdline_user_args():
		set_fullscreen(false)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_F11:
		set_fullscreen(not is_fullscreen())
		get_viewport().set_input_as_handled()


func is_fullscreen() -> bool:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func set_fullscreen(enabled: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(WINDOWED_SIZE)
		var screen: Rect2i = DisplayServer.screen_get_usable_rect()
		DisplayServer.window_set_position(screen.position + (screen.size - WINDOWED_SIZE) / 2)
