extends Node

const IP_ADRESS: String = "localhost"
const PORT: int = 42069
@onready var main: MAIN = get_tree().current_scene


var peer: ENetMultiplayerPeer

func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	main.spawn_player(1)
	print("Started Server")

func start_client() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_client(IP_ADRESS, PORT)
	multiplayer.multiplayer_peer = peer
	print("Started Client")
	
