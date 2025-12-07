@tool
extends Node3D

@export_category("References")
@export var WEAPON_TYPE: Weapons
@export var player_controller: Node3D
@export var camera: Camera3D
@export var weapon_raycast: RayCast3D
@export_category("Raycast & Clipping")
@export var wall_distance_threshold : float = 0.3
@export var raycast_distance : int = 1000
@export var lerp_speed : float = 10.0
@export var max_weapon_distance : float = 1.4    # Default extended position
@export var min_weapon_distance : float = 0.2   # Close to player when clipping
@export_category("Clipping Positions")
@export var clipped_position : Vector3 = Vector3(0.1, 0, -0.2)  # Closer + slight offset
@export var normal_position : Vector3 = Vector3(0, 0, -0.8)      # Default weapon position
@export var clipped_rotation_degrees : Vector3 = Vector3(0, 90, 0)  # 90° Y rotation
@export var clipped_position_offset : Vector3 = Vector3(0.1, 0, 0.6)  # Offset FROM original
@export var clipped_rotation_offset_deg : Vector3 = Vector3(0, 90, 0)  # Rotation offset

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

var player_weapons: Dictionary = {}

func _ready() -> void:
	uid = player_controller.name.to_int()
	player_weapons["glock"] = all_weapons["glock"].duplicate()
	player_weapons["ak47"] = all_weapons["ak47"].duplicate()
	_configure_local_player()

func _configure_local_player() -> void:
	var is_local := uid == multiplayer.get_unique_id()

	if not is_local:
		set_physics_process(false)
		set_process_input(false)
		ToolLib.create_delay(self, 0.05, _send_weapon_sync)
	else:
		reload_timer.timeout.connect(_on_reload_timeout)
		weapon_raycast.target_position = Vector3(0, 0, -raycast_distance)
		_equip_weapon("glock")

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not WEAPON_TYPE.can_shoot:
		WEAPON_TYPE.shoot_timer -= delta
		if WEAPON_TYPE.shoot_timer <= 0.0:
			WEAPON_TYPE.can_shoot = true

	if Input.is_action_pressed("mouse1") and WEAPON_TYPE.can_shoot and not WEAPON_TYPE.is_reloading and GameData.is_mouse_captured():
		if WEAPON_TYPE.current_ammo > 0:
			_shoot()
	
	_update_weapon_clipping(delta)

func _update_weapon_clipping(delta: float) -> void:
	weapon_raycast.force_raycast_update()
	var clip_amount : float = 0.0  # 0.0 = normal, 1.0 = fully clipped
	
	if weapon_raycast.is_colliding():
		var hit_distance : float = weapon_raycast.get_collision_point().distance_to(weapon_raycast.global_transform.origin)
		if hit_distance < wall_distance_threshold:
			clip_amount = 1.0
		elif hit_distance < max_weapon_distance:
			# Smooth interpolation
			clip_amount = inverse_lerp(max_weapon_distance, wall_distance_threshold, hit_distance)
	
	# Apply clipping transform smoothly
	_lerp_weapon_transform(delta, clip_amount)

func _lerp_weapon_transform(delta: float, clip_amount: float) -> void:
	# Calculate target position: original + offset * clip_amount
	var target_position = WEAPON_TYPE.position + (clipped_position_offset * clip_amount)
	weapon_instance.position = weapon_instance.position.lerp(target_position, lerp_speed * delta)
	
	# Calculate target rotation: original + offset * clip_amount
	var target_rotation_deg = WEAPON_TYPE.rotation + (clipped_rotation_offset_deg * clip_amount)
	var target_rotation_rad = Vector3(
		deg_to_rad(target_rotation_deg.x),
		deg_to_rad(target_rotation_deg.y),
		deg_to_rad(target_rotation_deg.z)
	)
	weapon_instance.rotation = weapon_instance.rotation.lerp(target_rotation_rad, lerp_speed * delta)

func _input(event: InputEvent) -> void:
	if not GameData.is_mouse_captured():
		return
	if event.is_action_pressed("weapon1") and WEAPON_TYPE.name != "glock":
		rpc("_equip_weapon", "glock")
	elif event.is_action_pressed("weapon2") and WEAPON_TYPE.name != "ak47":
		rpc("_equip_weapon", "ak47")
	elif event.is_action_pressed("reload"):
		_start_reload()

##################################################### RPC CALLS #####################################################
@rpc("any_peer", "call_remote", "reliable", 10)
func _request_weapon_sync(sender_uid: int) -> void:
	rpc_id(sender_uid, "_equip_weapon", WEAPON_TYPE.name)

func _send_weapon_sync() -> void:
	rpc_id(uid, "_request_weapon_sync", multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable", 10)
func _equip_weapon(weapon_id: String) -> void:
	var weapon_res: Weapons = player_weapons[weapon_id]
	if not weapon_res.starter_ammo_applied:
		weapon_res.current_ammo = weapon_res.magazine_size
		weapon_res.starter_ammo_applied = true

	WEAPON_TYPE = weapon_res
	_load_weapon()

##################################################### WEAPON LOGIC #####################################################
func _load_weapon() -> void:
	if not WEAPON_TYPE:
		return

	if weapon_instance:
		weapon_instance.queue_free()

	_cancel_reload()
	WEAPON_TYPE.is_reloading = false
	WEAPON_TYPE.can_shoot = true
	WEAPON_TYPE.shoot_timer = 0.0
	GameData.ui_link.update_ammo_label(_get_weapon_ammo_label())

	if WEAPON_TYPE.object:
		weapon_instance = WEAPON_TYPE.object.instantiate() as Node3D
		weapon_object_parent.add_child(weapon_instance)
		# Apply initial positions from Weapons resource, clipping will override
		weapon_instance.position = WEAPON_TYPE.position
		weapon_instance.rotation_degrees = WEAPON_TYPE.rotation
		weapon_instance.scale = WEAPON_TYPE.size

func _shoot() -> void:
	_shoot_raycast()
	WEAPON_TYPE.current_ammo -= 1
	WEAPON_TYPE.can_shoot = false
	WEAPON_TYPE.shoot_timer = 1.0 / WEAPON_TYPE.fire_rate
	GameData.ui_link.update_ammo_label(_get_weapon_ammo_label())

func _shoot_raycast() -> void:
	weapon_raycast.force_raycast_update()
	if weapon_raycast.is_colliding():
		var hit_object : Object = weapon_raycast.get_collider()
		var hit_point : Vector3 = weapon_raycast.get_collision_point()
		
		print(hit_object.name)
		print(hit_point)

func _start_reload() -> void:
	if WEAPON_TYPE.is_reloading or WEAPON_TYPE.current_ammo == WEAPON_TYPE.magazine_size:
		return
	WEAPON_TYPE.is_reloading = true
	GameData.ui_link.update_ammo_label("Reloading")

	reload_timer.wait_time = WEAPON_TYPE.reload_speed
	reload_timer.start()

func _on_reload_timeout() -> void:
	if WEAPON_TYPE.is_reloading:
		_finish_reload()

func _cancel_reload() -> void:
	reload_timer.stop()
	WEAPON_TYPE.is_reloading = false

func _finish_reload() -> void:
	WEAPON_TYPE.current_ammo = WEAPON_TYPE.magazine_size
	WEAPON_TYPE.is_reloading = false
	GameData.ui_link.update_ammo_label(_get_weapon_ammo_label())

func _get_weapon_ammo_label() -> String:
	return "{0}/{1}".format([str(WEAPON_TYPE.current_ammo), str(WEAPON_TYPE.magazine_size)])
