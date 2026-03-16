extends Node

# ─── DarkBrawl Prototype v0.1 ────────────────────────────────
# Everything built in code for reliability.
# Host: run game, press H → share your IP
# Join: run game, enter IP in box, press J

const GRAVITY      = 980.0
const JUMP_FORCE   = -520.0
const MOVE_SPEED   = 280.0
const DASH_SPEED   = 580.0
const DASH_DUR     = 0.18
const MAX_STAMINA  = 100.0
const STAM_REGEN   = 20.0
const STAM_ATTACK  = 15.0
const STAM_DODGE   = 22.0
const STAM_JUMP    = 6.0
const PORT         = 7777

var players        : Dictionary = {}   # peer_id -> PlayerData
var pending_peers  : Array      = []   # peers waiting to spawn when game starts
var platform_nodes : Array      = []

var state          : String = "menu"   # menu | playing | dead
var ip_input       : String = ""
var status_text    : String = "Press [H] to Host  |  Type IP then press [J] to Join"
var local_peer_id  : int    = 1

# ─── PlayerData ──────────────────────────────────────────────
class PlayerData:
	var peer_id    : int
	var node       : CharacterBody2D
	var label      : Label             # name/damage above head
	var stamina_bar: ColorRect
	var velocity   : Vector2 = Vector2.ZERO
	var knockback  : Vector2 = Vector2.ZERO
	var damage_pct : float   = 0.0
	var lives      : int     = 3
	var is_dead    : bool    = false
	var on_floor   : bool    = false
	var dash_t     : float   = 0.0
	var attack_cd  : float   = 0.0
	var attack_active : float = 0.0
	var color      : Color
	var archetype  : String  = "warrior"

# ─── Node refs ───────────────────────────────────────────────
var canvas        : CanvasLayer
var status_label  : Label
var ip_label      : Label
var world         : Node2D

# ─────────────────────────────────────────────────────────────
func _ready():
	_setup_input_map()
	_build_ui()

# ─── Input Map ───────────────────────────────────────────────
func _setup_input_map():
	var binds = {
		"p1_left":   KEY_A,    "p1_right": KEY_D,
		"p1_jump":   KEY_W,    "p1_dodge": KEY_S,
		"p1_attack": KEY_F,    "p1_emote": KEY_G,
	}
	for action in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev = InputEventKey.new()
			ev.keycode = binds[action]
			InputMap.action_add_event(action, ev)

# ─── UI ──────────────────────────────────────────────────────
func _build_ui():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.10)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	canvas = CanvasLayer.new()
	add_child(canvas)

	status_label = Label.new()
	status_label.position = Vector2(20, 20)
	status_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(status_label)

	ip_label = Label.new()
	ip_label.position = Vector2(20, 50)
	ip_label.add_theme_font_size_override("font_size", 20)
	ip_label.modulate = Color(0.8, 0.9, 1.0)
	canvas.add_child(ip_label)

	world = Node2D.new()
	add_child(world)

	_update_status()

func _update_status():
	if status_label:
		status_label.text = status_text
	if ip_label:
		ip_label.text = "> " + ip_input if state == "menu" else ""

# ─── Input ───────────────────────────────────────────────────
func _input(event):
	if state == "menu":
		if event is InputEventKey and event.pressed:
			match event.keycode:
				KEY_H:
					_host()
				KEY_J:
					_join(ip_input if ip_input != "" else "127.0.0.1")
				KEY_BACKSPACE:
					if ip_input.length() > 0:
						ip_input = ip_input.left(ip_input.length() - 1)
						_update_status()
				KEY_PERIOD:
					ip_input += "."
					_update_status()
				_:
					var ch = event.as_text()
					if ch.length() == 1 and ch[0].is_valid_int():
						ip_input += ch
						_update_status()

# ─── Networking ──────────────────────────────────────────────
func _host():
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, 4)
	if err != OK:
		status_text = "ERROR: Could not host on port %d" % PORT
		_update_status()
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	local_peer_id = 1
	pending_peers.append(1)
	status_text = "HOSTING on port %d  |  Your IP: (check ipconfig)  |  Waiting for players... [SPACE to start]" % PORT
	_update_status()
	state = "hosting"

func _join(ip: String):
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, PORT)
	if err != OK:
		status_text = "ERROR: Could not connect to %s:%d" % [ip, PORT]
		_update_status()
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_conn_failed)
	status_text = "Connecting to %s..." % ip
	_update_status()

func _on_peer_connected(id: int):
	pending_peers.append(id)
	status_text = "Player %d connected! [SPACE to start]" % id
	_update_status()

func _on_peer_disconnected(id: int):
	if id in players:
		if players[id].node:
			players[id].node.queue_free()
		players.erase(id)

func _on_connected():
	local_peer_id = multiplayer.get_unique_id()
	pending_peers.append(local_peer_id)
	status_text = "Connected! Peer ID: %d  |  Waiting for host to start..." % local_peer_id
	_update_status()
	state = "joined"

func _on_conn_failed():
	status_text = "Connection FAILED. Check IP and try again."
	_update_status()
	state = "menu"

# ─── Game Start ──────────────────────────────────────────────
func _start_game():
	state = "playing"
	status_text = ""
	_update_status()
	_build_map()
	# Spawn all pending players AFTER map is built
	for pid in pending_peers:
		_spawn_player(pid)
	pending_peers.clear()

# ─── Map ─────────────────────────────────────────────────────
func _build_map():
	# Clear old
	for n in world.get_children():
		n.queue_free()
	platform_nodes.clear()

	var vp = get_viewport().get_visible_rect().size

	# Fog background panels
	for i in range(8):
		var fog = ColorRect.new()
		fog.color = Color(randf_range(0.10,0.18), randf_range(0.06,0.10), randf_range(0.14,0.22), 0.18)
		fog.size = Vector2(randf_range(80,220), randf_range(60,160))
		fog.position = Vector2(randf_range(0, vp.x), randf_range(0, vp.y))
		world.add_child(fog)

	# Build platforms
	var plat_data = [
		# [x, y, w, moving, axis, dist, speed]
		[vp.x * 0.5, vp.y * 0.80, 700, false, Vector2.ZERO,  0,   0],   # main floor
		[vp.x * 0.22, vp.y * 0.58, 200, false, Vector2.ZERO, 0,   0],   # left solid
		[vp.x * 0.78, vp.y * 0.58, 200, false, Vector2.ZERO, 0,   0],   # right solid
		[vp.x * 0.50, vp.y * 0.44, 180, true,  Vector2(1,0), 170, 55],  # center moving H
		[vp.x * 0.50, vp.y * 0.26, 140, true,  Vector2(0,1), 90,  70],  # high moving V
	]

	for pd in plat_data:
		_add_platform(pd[0], pd[1], pd[2], pd[3], pd[4], pd[5], pd[6])

func _add_platform(cx, cy, w, moving, axis, dist, spd):
	var body : Node
	if moving:
		body = AnimatableBody2D.new()
	else:
		body = StaticBody2D.new()

	body.position = Vector2(cx, cy)

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(w, 18)
	col.shape = shape
	body.add_child(col)

	var vis = ColorRect.new()
	vis.size = Vector2(w, 18)
	vis.position = Vector2(-w * 0.5, -9)
	if moving:
		vis.color = Color(0.45, 0.15, 0.15)
	else:
		vis.color = Color(0.28, 0.20, 0.14)
	body.add_child(vis)

	# Rune decoration line
	var line = ColorRect.new()
	line.size = Vector2(w, 2)
	line.position = Vector2(-w * 0.5, -9)
	line.color = Color(0.8, 0.5, 0.2, 0.4)
	body.add_child(line)

	if moving:
		body.set_meta("start_pos", Vector2(cx, cy))
		body.set_meta("axis", axis)
		body.set_meta("dist", dist)
		body.set_meta("spd", spd)
		body.set_meta("t", 0.0)
		platform_nodes.append(body)

	world.add_child(body)

# ─── Player Spawn ────────────────────────────────────────────
var SPAWN_POSITIONS = [
	Vector2(320, 350), Vector2(960, 350),
	Vector2(640, 250), Vector2(640, 450)
]
var PLAYER_COLORS = [
	Color(0.3, 0.6, 1.0),    # blue
	Color(1.0, 0.3, 0.3),    # red
	Color(0.3, 1.0, 0.5),    # green
	Color(1.0, 0.85, 0.2),   # gold
]

func _spawn_player(peer_id: int):
	var pd = PlayerData.new()
	pd.peer_id = peer_id
	var idx = players.size() % 4
	pd.color = PLAYER_COLORS[idx]

	# Body
	var body = CharacterBody2D.new()
	body.position = SPAWN_POSITIONS[idx]
	body.collision_layer = 2
	body.collision_mask = 1

	var col = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 18
	shape.height = 50
	col.shape = shape
	body.add_child(col)

	# Sprite (colored rect + armor details)
	var sprite = ColorRect.new()
	sprite.size = Vector2(36, 52)
	sprite.position = Vector2(-18, -26)
	sprite.color = pd.color
	body.add_child(sprite)

	# Visor accent
	var visor = ColorRect.new()
	visor.size = Vector2(24, 8)
	visor.position = Vector2(-12, -18)
	visor.color = Color(pd.color.r * 1.5, pd.color.g * 1.5, pd.color.b * 1.5, 0.8)
	body.add_child(visor)

	# Name/damage label
	var lbl = Label.new()
	lbl.position = Vector2(-30, -52)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.text = "P%d  0%%" % peer_id
	lbl.modulate = pd.color
	body.add_child(lbl)
	pd.label = lbl

	# Stamina bar background
	var stam_bg = ColorRect.new()
	stam_bg.size = Vector2(40, 5)
	stam_bg.position = Vector2(-20, -38)
	stam_bg.color = Color(0.2, 0.2, 0.2)
	body.add_child(stam_bg)

	# Stamina bar fill
	var stam_fill = ColorRect.new()
	stam_fill.size = Vector2(40, 5)
	stam_fill.position = Vector2(-20, -38)
	stam_fill.color = Color(0.2, 0.9, 0.4)
	body.add_child(stam_fill)
	pd.stamina_bar = stam_fill

	pd.node = body
	pd.velocity = Vector2.ZERO
	pd.lives = 3

	var stam_obj = RefCounted.new()
	pd.set_meta("stamina", MAX_STAMINA)

	world.add_child(body)
	players[peer_id] = pd

func _respawn_player(pd: PlayerData):
	var idx = (pd.peer_id - 1) % 4
	pd.node.position = SPAWN_POSITIONS[idx]
	pd.velocity = Vector2.ZERO
	pd.knockback = Vector2.ZERO
	pd.damage_pct = 0.0
	pd.is_dead = false
	pd.set_meta("stamina", MAX_STAMINA)

# ─── Process ─────────────────────────────────────────────────
func _process(delta):
	# Space to start from hosting state
	if (state == "hosting" or state == "joined") and Input.is_action_just_pressed("ui_accept"):
		_start_game()
		return

	if state != "playing":
		return

	_move_platforms(delta)
	_process_players(delta)
	_check_game_over()

func _move_platforms(delta):
	for body in platform_nodes:
		var t    = body.get_meta("t") + delta
		var axis = body.get_meta("axis")
		var dist = body.get_meta("dist")
		var spd  = body.get_meta("spd")
		var sp   = body.get_meta("start_pos")
		body.set_meta("t", t)
		body.position = sp + axis * sin(t * spd / dist * 1.2) * dist

func _process_players(delta):
	var vp = get_viewport().get_visible_rect().size
	for peer_id in players:
		var pd : PlayerData = players[peer_id]
		if pd.is_dead or not pd.node:
			continue

		var stam : float = pd.get_meta("stamina")

		# Gravity
		if not pd.on_floor:
			pd.velocity.y += GRAVITY * delta

		# Input — only drive local player
		if peer_id == local_peer_id:
			var dir = 0.0
			if Input.is_action_pressed("p1_left"):  dir -= 1.0
			if Input.is_action_pressed("p1_right"): dir += 1.0
			pd.velocity.x = dir * MOVE_SPEED

			# Jump
			if Input.is_action_just_pressed("p1_jump") and pd.on_floor and stam >= STAM_JUMP:
				pd.velocity.y = JUMP_FORCE
				stam -= STAM_JUMP

			# Dodge
			if Input.is_action_just_pressed("p1_dodge") and pd.on_floor and pd.dash_t <= 0 and stam >= STAM_DODGE:
				pd.dash_t = DASH_DUR
				stam -= STAM_DODGE

			# Attack
			if Input.is_action_just_pressed("p1_attack") and pd.attack_cd <= 0 and stam >= STAM_ATTACK:
				pd.attack_active = 0.25
				pd.attack_cd = 0.45
				stam -= STAM_ATTACK
				_do_attack(pd)

			# Emote
			if Input.is_action_just_pressed("p1_emote"):
				_show_emote(pd)

		# Dash override
		if pd.dash_t > 0:
			pd.dash_t -= delta
			pd.velocity.x = sign(pd.velocity.x if pd.velocity.x != 0 else 1.0) * DASH_SPEED

		# Stamina regen
		stam = min(MAX_STAMINA, stam + STAM_REGEN * delta)
		pd.set_meta("stamina", stam)

		# Cooldown tick
		if pd.attack_cd > 0:   pd.attack_cd -= delta
		if pd.attack_active > 0: pd.attack_active -= delta

		# Apply knockback
		pd.velocity += pd.knockback * delta
		pd.knockback *= 0.80

		# Move
		pd.node.velocity = pd.velocity
		pd.node.move_and_slide()
		pd.on_floor = pd.node.is_on_floor()
		if pd.on_floor:
			pd.velocity.y = 0.0

		# Update HUD
		pd.label.text = "P%d  %.0f%%" % [peer_id, pd.damage_pct]
		var stam_w = (stam / MAX_STAMINA) * 40.0
		pd.stamina_bar.size.x = max(0, stam_w)

		# Death check
		var margin = 320
		if pd.node.position.x < -margin or pd.node.position.x > vp.x + margin \
		or pd.node.position.y < -margin or pd.node.position.y > vp.y + margin:
			pd.lives -= 1
			if pd.lives <= 0:
				pd.is_dead = true
				pd.node.visible = false
			else:
				_respawn_player(pd)
				_show_respawn_flash(pd)

func _do_attack(attacker: PlayerData):
	if not attacker.node:
		return
	var atk_pos = attacker.node.global_position
	for peer_id in players:
		if peer_id == attacker.peer_id:
			continue
		var target : PlayerData = players[peer_id]
		if target.is_dead or not target.node:
			continue
		var dist = atk_pos.distance_to(target.node.global_position)
		if dist < 90.0:
			var dir = (target.node.global_position - atk_pos).normalized()
			var dmg = 8.0 + randf_range(0, 4)
			target.damage_pct += dmg
			# Knockback scales with victim damage %
			var launch = 240.0 * (1.0 + target.damage_pct / 75.0)
			target.knockback = dir * launch
			# Hit flash
			_flash_player(target, Color(1, 0.3, 0.3))

func _flash_player(pd: PlayerData, col: Color):
	if pd.node and pd.node.get_child_count() > 0:
		var sprite = pd.node.get_child(1)  # ColorRect sprite
		if sprite is ColorRect:
			var orig = pd.color
			sprite.color = col
			await get_tree().create_timer(0.1).timeout
			if sprite and is_instance_valid(sprite):
				sprite.color = orig

func _show_emote(pd: PlayerData):
	var emotes = ["GG", "EZ", "skill issue", "lol", "👋", "😂", "💀", "no way"]
	var e = emotes[randi() % emotes.size()]
	var lbl = Label.new()
	lbl.text = e
	lbl.position = pd.node.position + Vector2(-20, -80)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.modulate = Color(1, 0.9, 0.2)
	world.add_child(lbl)
	var tween = create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 50, 1.2)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tween.tween_callback(lbl.queue_free)

func _show_respawn_flash(pd: PlayerData):
	pd.node.visible = true
	for i in range(6):
		pd.node.modulate.a = 0.3
		await get_tree().create_timer(0.1).timeout
		pd.node.modulate.a = 1.0
		await get_tree().create_timer(0.1).timeout

func _check_game_over():
	var alive = []
	for pid in players:
		if not players[pid].is_dead:
			alive.append(pid)
	if alive.size() == 1 and players.size() > 1:
		_game_over(alive[0])
	elif alive.size() == 0 and players.size() > 0:
		_game_over(-1)

func _game_over(winner_id: int):
	state = "gameover"
	if winner_id == -1:
		status_text = "DRAW!"
	else:
		status_text = "PLAYER %d WINS!  [R] to restart" % winner_id
	_update_status()

func _unhandled_input(event):
	if state == "gameover" and event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()
