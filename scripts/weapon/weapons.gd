class_name Weapons extends Resource

@export var name : StringName
@export_category("Transform")
@export var position : Vector3
@export var rotation : Vector3
@export var size : Vector3
@export_category("Stats")
@export var damage : int
@export var fire_rate : float
@export var magazine_size : int
@export var reload_speed : float
@export_category("Visual Settings")
@export var object : PackedScene
@export_category("Weapon Logic")
var current_ammo : int = 0 # Can't apply magazine ammo to current ammo because it's Resource
var can_shoot : bool = true
var is_reloading : bool = false
var shoot_timer : float = 0.0
var starter_ammo_applied : bool = false
