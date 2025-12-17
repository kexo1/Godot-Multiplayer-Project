extends Node

@onready var main: MAIN = get_tree().current_scene


var peer: ENetMultiplayerPeer

func start_server(port: int) -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_server(port)
	multiplayer.multiplayer_peer = peer
	main.spawn_player(1)
	print("Started Server")

func start_client(port: int, ip: String) -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer
	print("Started Client")
	
