class_name CameraController
extends Node3D

var mouse_captured : bool = false
var mouse_input: Vector2
var input_rotation: Vector3
var uid : int

@export_category("Sensitivity")
@export var mouse_sensitivity : float = 0.002
@export_category("References")
@export var player_controller: CharacterBody3D
@export var swat_model: Node3D

@onready var camera: Camera3D = $Camera
# @onready var weapon_camera: Camera3D = $WeaponViewport/SubViewport/WeaponCamera

func _ready() -> void:
	GameData.capture_mouse(true)
	uid = player_controller.name.to_int()
	_configure_local_player()

func _configure_local_player() -> void:
	var is_local := uid == multiplayer.get_unique_id()
	camera.current = is_local
	# weapon_camera.current = is_local

	if not is_local:
		set_physics_process(false)
		set_process_input(false)
	
func _input(event: InputEvent) -> void:
	if GameData.mouse_captured and event is InputEventMouseMotion:
		mouse_input.x += -event.screen_relative.x * mouse_sensitivity
		mouse_input.y += -event.screen_relative.y * mouse_sensitivity

func _physics_process(_delta: float) -> void:
	input_rotation.x = clampf(input_rotation.x + mouse_input.y, deg_to_rad(-90), deg_to_rad(85))
	input_rotation.y += mouse_input.x
	# Rotate camera controller (up/down)
	player_controller.camera_controller_anchor.transform.basis = Basis.from_euler(Vector3(input_rotation.x, 0.0, 0.0))
	# Rotate player (left/right)
	player_controller.global_transform.basis = Basis.from_euler(Vector3(0.0, input_rotation.y, 0.0))
	global_transform = player_controller.camera_controller_anchor.global_transform
	mouse_input = Vector2.ZERO
