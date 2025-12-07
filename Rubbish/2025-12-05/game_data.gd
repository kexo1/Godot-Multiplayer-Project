extends Node

var mouse_captured : bool = false
var ui_link : UI

func _ready() -> void:
	Engine.max_fps = 141 

func capture_mouse(capture: bool):
	if capture:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = capture

func set_ui_link(ui: UI) -> void:
	ui_link = ui

func is_mouse_captured() -> bool:
	return mouse_captured
