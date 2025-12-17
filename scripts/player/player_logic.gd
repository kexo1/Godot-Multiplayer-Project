class_name PlayerController
extends CharacterBody3D

@export_group("References")
@export var current_weapon : WeaponLogic
@export var swat_model : Node3D

@export_group("Speeds")
@export var base_speed : float = 7.0
@export var jump_velocity : float = 4.5
@export var sprint_speed : float = 10.0
@export var can_freefly : bool = true
@export var freefly_speed : float = 25.0

@export_group("Coyote Time")
@export var coyote_time_frames: float = 12

var health : int = 100
const max_health : int = 100
var is_dead : bool = false
var coyote: bool = false
var last_floor: bool = true
var jumping: bool = false
var death_animations = ["Death1", "DeathFromTheBack1", "DeathFromTheFront1"]

var move_speed : float = 0.0
var freeflying : bool = false
var uid : int

@onready var player_collider: CollisionShape3D = $Collider
@onready var coyote_timer = $CoyoteTimer
@onready var camera_controller_anchor: Marker3D = $CameraControllerAnchor

func _ready() -> void:
	uid = name.to_int()
	_configure_local_player()
	
func _configure_local_player() -> void:
	if not _is_local():
		set_physics_process(false)
		set_process_unhandled_input(false)
	else:
		swat_model.visible = false
		GameData.ui_link.update_health_label(str(health))
		GameData.set_player_controller_link(self)
		coyote_timer.timeout.connect(_on_coyote_timer_timeout)
		coyote_timer.wait_time = coyote_time_frames / 60.0
	
func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _is_local() -> bool:
	return uid == multiplayer.get_unique_id()

##################################################### MOVEMENT #####################################################
func _unhandled_input(_event: InputEvent) -> void:
	if can_freefly and Input.is_action_just_pressed("freefly"):
		if not freeflying:
			_enable_freefly()
		else:
			_disable_freefly()

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	_process_animations(input_dir, move_dir)
	
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
	if Input.is_action_just_pressed("jump") and (is_on_floor() or coyote):
		velocity.y = jump_velocity
		jumping = true
		
	if !is_on_floor() and !jumping and last_floor:
		coyote = true
		last_floor = false
		$CoyoteTimer.start()
		
	# Modify speed based on sprinting
	if Input.is_action_pressed("sprint"):
		move_speed = sprint_speed
	else:
		move_speed = base_speed

	# Apply desired movement to velocity
	if move_dir and GameData.is_mouse_captured():
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()

func _process_animations(input_dir, move_dir) -> void:
	var animator : Dictionary = GameData.AnimationPreset
	var held_weapon : String = current_weapon.WEAPON_TYPE.name
	var new_animation := ""

	if is_dead:
		return
	
	if jumping:
		if $Swat/AnimationPlayer.current_animation != animator[held_weapon]["Jump"]:
			new_animation = "JumpLoop1"
	elif move_dir.x == 0:
		new_animation = animator[held_weapon]["Idle"]
	elif input_dir.y <= -0.7:
		new_animation = animator[held_weapon]["RunForward"]
	elif input_dir.y >= 0.7:
		new_animation = animator[held_weapon]["RunBackward"]
	elif input_dir.x <= -0.7:
		new_animation = animator[held_weapon]["RunLeft"]
	elif input_dir.x >= 0.7:
		new_animation = animator[held_weapon]["RunRight"]
	
	if Input.is_action_just_pressed("jump") and (is_on_floor() or coyote):
		new_animation = animator[held_weapon]["Jump"]
	
	if new_animation != $Swat/AnimationPlayer.current_animation:
		$Swat/AnimationPlayer.play(new_animation)
		rpc("sync_animation", new_animation)

@rpc("any_peer", "call_remote", "unreliable", 8)
func sync_animation(anim_name: String) -> void:
	if $Swat/AnimationPlayer.current_animation != anim_name:
		$Swat/AnimationPlayer.play(anim_name)

@rpc("any_peer", "call_remote", "reliable", 7)
func set_collider_state(dead: bool) -> void:
	player_collider.disabled = dead

@rpc("any_peer", "call_local", "reliable", 9)
func deal_damage(damage: int, player_uid: int) -> void:
	health -= damage
	if health <= 0:
		print("Killed by: ", player_uid)
		rpc("sync_animation", death_animations.pick_random())
		set_player_state(false)
		return
		
	GameData.ui_link.update_health_label(str(health))


##################################################### PLAYER RESPAWN #####################################################
func set_player_state(dead: bool) -> void:
	is_dead = !dead
	GameData.capture_mouse(dead)
	visible = dead
	# Disable physics
	set_process_input(dead)
	rpc("set_collider_state", !dead)
	current_weapon.set_process_input(dead)
	current_weapon.set_physics_process(dead)
	GameData.ui_link.set_death_screen(dead)

func respawn_player() -> void:
	health = max_health
	for weapon_name in current_weapon.all_weapons.keys():
		var weapon : Weapons = current_weapon.all_weapons[weapon_name]
		weapon.current_ammo = weapon.magazine_size
	
	current_weapon.finish_reload()
	
	var spawn_points : Array
	for spawn_point in GameData.spawner_link.get_children():
		spawn_points.append(spawn_point.position)
	
	position = spawn_points.pick_random()
	set_player_state(true)
	GameData.ui_link.update_health_label(str(health))

func _on_coyote_timer_timeout():
	coyote = false

func _enable_freefly():
	player_collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO

func _disable_freefly():
	player_collider.disabled = false
	freeflying = false
	
