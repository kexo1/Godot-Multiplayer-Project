class_name WeaponLogic
extends Node3D

@export_category("References")
@export var WEAPON_TYPE: Weapons
@export var player_controller: Node3D
@export var camera: Camera3D
@export var model_weapon_holder: BoneAttachment3D
@export var weapon_raycast: RayCast3D
@export var weapon_clipping_raycast: RayCast3D
@export var weapon_clipping_raycast_2: RayCast3D
@export_category("Raycast & Clipping")
@export var wall_distance_threshold : float
@export var raycast_distance : int
@export var lerp_speed : float
@export var max_weapon_distance : float
@export_category("Clipping Positions")
@export var clipped_position : Vector3 = Vector3(-0.25, 0, 0.35)
@export var clipped_rotation_deg : Vector3 = Vector3(0, 90, 0)

@onready var weapon_object_parent: Node3D = self
@onready var reload_timer: Timer = $"../ReloadTimer"

var uid : int
var weapon_instance: Node3D = null
var screen_center : Vector2

# Weapon clipping state
var target_weapon_distance : float = 1.0

var all_weapons: Dictionary = {
	"glock": load("res://assets/objects/weapons/glock/glock.tres"),
	"ak47": load("res://assets/objects/weapons/ak47/ak47.tres")
}

var model_weapons: Dictionary = {}

func _ready() -> void:
	uid = player_controller.name.to_int()
	_get_model_weapon_holder()
	_configure_local_player()

func _configure_local_player() -> void:
	if not _is_local():
		set_physics_process(false)
		set_process_input(false)
		ToolLib.create_delay(self, 0.05, _send_weapon_sync)
		visible = false
	else:
		reload_timer.timeout.connect(_on_reload_timeout)
		weapon_raycast.target_position = Vector3(0, 0, -raycast_distance)
		_equip_weapon("glock")

func _is_local() -> bool:
	return uid == multiplayer.get_unique_id()

func _get_model_weapon_holder() -> void:
	for weapon in model_weapon_holder.get_children():
		model_weapons[weapon.name] = weapon

func _physics_process(delta: float) -> void:
	_process_shooting(delta)
	_update_weapon_clipping(delta)	

func _update_weapon_clipping(delta: float) -> void:
	var clip_amount: float = 0.0
	
	var hit_point : Vector3 = Vector3.ZERO
	if weapon_clipping_raycast.is_colliding():
		hit_point = weapon_clipping_raycast.get_collision_point()
	elif weapon_clipping_raycast_2.is_colliding():
		hit_point = weapon_clipping_raycast_2.get_collision_point()
	
	if not hit_point.is_zero_approx():
		var closest: float = INF
		var distance = hit_point.distance_to(weapon_clipping_raycast.global_transform.origin)
		if distance < closest:
			closest = distance

		if closest < wall_distance_threshold:
			clip_amount = 1.0
		elif closest < max_weapon_distance:
			clip_amount = inverse_lerp(max_weapon_distance, wall_distance_threshold, closest)

	_lerp_weapon_transform(delta, clip_amount)

func _lerp_weapon_transform(delta: float, clip_amount: float) -> void:
	# authority does its normal logic
	var target_position = WEAPON_TYPE.position + (clipped_position * clip_amount)
	weapon_instance.position = weapon_instance.position.lerp(target_position, lerp_speed * delta)

	var target_rotation_deg = WEAPON_TYPE.rotation + (clipped_rotation_deg * clip_amount)
	var target_rotation_rad = Vector3(
		deg_to_rad(target_rotation_deg.x),
		deg_to_rad(target_rotation_deg.y),
		deg_to_rad(target_rotation_deg.z)
	)
	weapon_instance.rotation = weapon_instance.rotation.lerp(target_rotation_rad, lerp_speed * delta)
	
func _process_shooting(delta: float):
	if not WEAPON_TYPE.can_shoot:
		WEAPON_TYPE.shoot_timer -= delta
		if WEAPON_TYPE.shoot_timer <= 0.0:
			WEAPON_TYPE.can_shoot = true
	
	if Input.is_action_pressed("mouse1") and WEAPON_TYPE.can_shoot and not WEAPON_TYPE.is_reloading and GameData.is_mouse_captured():
		if WEAPON_TYPE.current_ammo > 0:
			_shoot()

func _input(event: InputEvent) -> void:
	if not GameData.is_mouse_captured():
		return
	if event.is_action_pressed("weapon1") and WEAPON_TYPE.name != "glock":
		_equip_weapon("glock")
		rpc("_set_model_weapon", "glock")
	elif event.is_action_pressed("weapon2") and WEAPON_TYPE.name != "ak47":
		_equip_weapon("ak47")
		rpc("_set_model_weapon", "ak47")
	elif event.is_action_pressed("reload"):
		_start_reload()

##################################################### RPC CALLS #####################################################
@rpc("any_peer", "call_remote", "reliable", 10)
func _request_weapon_sync(sender_uid: int) -> void:
	rpc_id(sender_uid, "_set_model_weapon", WEAPON_TYPE.name)

func _send_weapon_sync() -> void:
	rpc_id(uid, "_request_weapon_sync", multiplayer.get_unique_id())

@rpc("any_peer", "call_remote", "reliable", 10)
func _set_model_weapon(weapon_id: String) -> void:
	for weapon: Node3D in model_weapons.values():
		weapon.visible = weapon.name == weapon_id

##################################################### WEAPON LOGIC #####################################################
func _equip_weapon(weapon_id: String) -> void:
	var weapon_res: Weapons = all_weapons[weapon_id]
	WEAPON_TYPE = weapon_res
	_apply_starter_ammo()
	_load_weapon()

func _load_weapon() -> void:
	# Delete previous held weapon
	if weapon_instance:
		weapon_instance.queue_free()
	
	_instantiate_weapon()
	_cancel_reload()
	WEAPON_TYPE.is_reloading = false
	WEAPON_TYPE.can_shoot = true
	WEAPON_TYPE.shoot_timer = 0.0
	GameData.ui_link.update_ammo_label(_get_weapon_ammo_label())

func _instantiate_weapon():
	# Spawn weapon object
	weapon_instance = WEAPON_TYPE.object.instantiate() as Node3D
	weapon_object_parent.add_child(weapon_instance)
	# Apply initial positions from Weapons resource, clipping will override
	weapon_instance.position = WEAPON_TYPE.position
	weapon_instance.rotation_degrees = WEAPON_TYPE.rotation
	weapon_instance.scale = WEAPON_TYPE.size

func _apply_starter_ammo():
	# Apply full magazine once
	if not WEAPON_TYPE.starter_ammo_applied and _is_local():
		WEAPON_TYPE.current_ammo = WEAPON_TYPE.magazine_size
		WEAPON_TYPE.starter_ammo_applied = true

func _shoot() -> void:
	_shoot_raycast()
	WEAPON_TYPE.current_ammo -= 1
	WEAPON_TYPE.can_shoot = false
	WEAPON_TYPE.shoot_timer = 1.0 / WEAPON_TYPE.fire_rate
	GameData.ui_link.update_ammo_label(_get_weapon_ammo_label())

func _shoot_raycast() -> void:
	weapon_raycast.force_raycast_update()
	if not weapon_raycast.is_colliding():
		return
		
	var hit_object : PlayerController = weapon_raycast.get_collider()
	# var hit_point : Vector3 = weapon_raycast.get_collision_point()
	if hit_object:
		hit_object.rpc_id(hit_object.uid, "deal_damage", WEAPON_TYPE.damage, uid)

func _start_reload() -> void:
	if WEAPON_TYPE.is_reloading or WEAPON_TYPE.current_ammo == WEAPON_TYPE.magazine_size:
		return
	WEAPON_TYPE.is_reloading = true
	GameData.ui_link.update_ammo_label("Reloading")

	reload_timer.wait_time = WEAPON_TYPE.reload_speed
	reload_timer.start()

func _on_reload_timeout() -> void:
	if WEAPON_TYPE.is_reloading:
		finish_reload()

func _cancel_reload() -> void:
	reload_timer.stop()
	WEAPON_TYPE.is_reloading = false

func finish_reload() -> void:
	WEAPON_TYPE.current_ammo = WEAPON_TYPE.magazine_size
	WEAPON_TYPE.is_reloading = false
	GameData.ui_link.update_ammo_label(_get_weapon_ammo_label())

func _get_weapon_ammo_label() -> String:
	return "{0}/{1}".format([str(WEAPON_TYPE.current_ammo), str(WEAPON_TYPE.magazine_size)])
