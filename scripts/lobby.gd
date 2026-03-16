extends Node

# Simple host/join lobby before scene exists
# Will be replaced by proper UI scene

func _ready():
	pass

func host(port: int = 7777):
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, 8)
	if err != OK:
		push_error("Failed to host: %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	print("[LOBBY] Hosting on port %d — share your IP with friends" % port)

func join(ip: String, port: int = 7777):
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		push_error("Failed to join: %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	print("[LOBBY] Joining %s:%d ..." % [ip, port])
