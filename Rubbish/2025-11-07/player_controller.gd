class_name PlayerController
extends CharacterBody3D
@export var can_freefly : bool = false

@export_group("Speeds")
@export var base_speed : float = 7.0
@export var jump_velocity : float = 4.5
@export var sprint_speed : float = 10.0
@export var freefly_speed : float = 25.0

@export_group("Coyote Time")
@export var coyote_time_frames: float = 12
var coyote: bool = false
var last_floor: bool = true
var jumping: bool = false

@export_group("Input Actions")
@export var input_left : String = "ui_left"
@export var input_right : String = "ui_right"
@export var input_forward : String = "ui_up"
@export var input_back : String = "ui_down"
@export var input_jump : String = "ui_accept"
@export var input_sprint : String = "sprint"
@export var input_freefly : String = "freefly"

var move_speed : float = 0.0
var freeflying : bool = false

@onready var collider: CollisionShape3D = $Collider
@onready var coyote_timer = $CoyoteTimer
@onready var camera_controller_anchor: Marker3D = $CameraControllerAnchor

func _ready() -> void:
	coyote_timer.timeout.connect(_on_coyote_timer_timeout)
	coyote_timer.wait_time = coyote_time_frames / 60.0

func _unhandled_input(_event: InputEvent) -> void:
	# Toggle freefly mode
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()

func _physics_process(delta: float) -> void:
	# If freeflying, handle freefly and nothing else
	var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
	
	if can_freefly and freeflying:
		var motion := (camera_controller_anchor.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return
	
	# Apply gravity to velocity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if is_on_floor():
		velocity += get_gravity() * delta
		jumping = false
		last_floor = true

	# Apply jumping with coyote time
	if Input.is_action_just_pressed(input_jump) and (is_on_floor() or coyote):
		velocity.y = jump_velocity
		jumping = true
		
	if !is_on_floor() and !jumping and last_floor:
		coyote = true
		last_floor = false
		$CoyoteTimer.start()
		
	# Modify speed based on sprinting
	if Input.is_action_pressed(input_sprint):
		move_speed = sprint_speed
	else:
		move_speed = base_speed

	# Apply desired movement to velocity (to be changed to desired movement)
	var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if move_dir:
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
	
	move_and_slide()

func _on_coyote_timer_timeout():
	coyote = false

func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO

func disable_freefly():
	collider.disabled = false
	freeflying = false
	
