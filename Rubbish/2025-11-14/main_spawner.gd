class_name MAIN
extends Node3D


func _ready() -> void:
	multiplayer.peer_connected.connect(spawn_player)
	
func spawn_player(id: int) -> void:
	if !multiplayer.is_server(): return
	
	var player: Node = preload("res://scenes/player_controller.tscn").instantiate()
	player.name = str(id)
	
	get_node("Players").call_deferred("add_child", player)
	
