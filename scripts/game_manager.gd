extends Node

# ─── Game State ──────────────────────────────────────────────
enum GameState { LOBBY, PLAYING, ROUND_END, GAME_OVER }
var state : GameState = GameState.LOBBY

var players         : Dictionary = {}   # peer_id -> player node
var player_lives    : Dictionary = {}
var scores          : Dictionary = {}

const STOCK_COUNT   = 3   # lives per player

signal game_over(winner_id)
signal round_end(loser_id)

# ─── Multiplayer Setup ───────────────────────────────────────
func host_game(port: int = 7777):
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(port, 8)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Hosting on port %d" % port)

func join_game(ip: String, port: int = 7777):
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	print("Connecting to %s:%d" % [ip, port])

func _on_peer_connected(id: int):
	print("Player connected: %d" % id)

func _on_peer_disconnected(id: int):
	print("Player disconnected: %d" % id)

func _on_connected_to_server():
	print("Connected to server!")

# ─── Player Tracking ─────────────────────────────────────────
func register_player(player_node, peer_id: int):
	players[peer_id]      = player_node
	player_lives[peer_id] = STOCK_COUNT
	scores[peer_id]       = 0
	player_node.player_died.connect(_on_player_died.bind(peer_id))

func _on_player_died(player_id: int):
	player_lives[player_id] -= 1
	if player_lives[player_id] <= 0:
		_check_game_over(player_id)
	else:
		emit_signal("round_end", player_id)

func _check_game_over(eliminated_id: int):
	var alive = []
	for pid in players:
		if players[pid] and is_instance_valid(players[pid]):
			alive.append(pid)
	if alive.size() == 1:
		emit_signal("game_over", alive[0])
		state = GameState.GAME_OVER
