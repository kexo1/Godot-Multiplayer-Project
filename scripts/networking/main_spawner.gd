class_name MAIN
extends Node3D

@export var spawner : Node3D

func _ready() -> void:
	GameData.set_spawner_link(spawner)
	multiplayer.peer_connected.connect(spawn_player)
	multiplayer.peer_disconnected.connect(despawn_player)
	multiplayer.server_disconnected.connect(_on_leave_to_title_screen)

##################################################### PLAYER SPAWNING #####################################################
func spawn_player(id: int) -> void:
	if !multiplayer.is_server(): return
	
	var player: Node = preload("res://scenes/player_controller.tscn").instantiate()
	player.name = str(id)
	
	get_node("Players").call_deferred("add_child", player, true)

func despawn_player(id: int):
	if !multiplayer.is_server(): return
	
	for child in get_node("Players").get_children():
		if child.name.to_int() == id:
			get_node("Players").call_deferred("remove_child", child)

##################################################### MULTIPLAYER EVENTS #####################################################

func _on_server_started(port: int) -> void:
	HighLevelNetworkHandler.start_server(port)


func _on_client_started(port: int, ip: String) -> void:
	HighLevelNetworkHandler.start_client(port, ip)
	
# Client and Server
func _on_leave_to_title_screen() -> void:
	for child in get_node("Players").get_children():
		get_node("Players").call_deferred("remove_child", child)
