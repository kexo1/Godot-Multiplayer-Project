extends Node

var mouse_captured : bool = false
var ui_link : UI
var player_controller_link : PlayerController
var spawner_link : Node3D
var AnimationPreset = {
	"glock": {"RunForward": "PistolRun1",
			  "RunBackward": "PistolRunBackward1",
			  "RunLeft": "PistolLeft1",
			  "RunRight": "PistolRight1",
			  "Idle": "PistolIdle1",
			  "Jump": "PistolJump1"
			},
	"ak47": {"RunForward": "RunForward1",
			  "RunBackward": "RunBackward1",
			  "RunLeft": "RunLeft1",
			  "RunRight": "RunRight1",
			  "Idle": "IdleAiming1",
			  "Jump": "RifleJump1"
			},
}
# Channels
# 10 - Weapon switch
# 9 - Player damage
# 8 - Animations

func _ready() -> void:
	Engine.max_fps = 141 

func capture_mouse(capture: bool):
	if capture:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = capture


func is_mouse_captured() -> bool:
	return mouse_captured

##################################################### COMPONENT LINKS #####################################################
func set_ui_link(ui: UI) -> void:
	ui_link = ui

func set_spawner_link(spawner: Node3D) -> void:
	spawner_link = spawner

func set_player_controller_link(player_controller: PlayerController) -> void:
	player_controller_link = player_controller
