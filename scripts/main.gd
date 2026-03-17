extends Node

# ─── DarkBrawl Prototype v0.2 ────────────────────────────────
# Controls: A/D move | W jump (double jump available) | S dodge
#           F attack | Q dash attack | E special ability | G emote
# TAB = toggle controls overlay
# Host: press H | Join: type IP then J | Start: SPACE

const GRAVITY       = 980.0
const JUMP_FORCE    = -740.0   # boosted — reaches all platforms
const MOVE_SPEED    = 290.0
const DASH_SPEED    = 600.0
const DASH_DUR      = 0.18
const MAX_STAMINA   = 100.0
const STAM_REGEN    = 22.0
const STAM_ATTACK   = 12.0
const STAM_DODGE    = 20.0
const STAM_JUMP     = 5.0
const STAM_SPECIAL  = 30.0
const PORT          = 7777

var players         : Dictionary = {}
var pending_peers   : Array      = []
var platform_nodes  : Array      = []

var state           : String = "menu"
var ip_input        : String = ""
var status_text     : String = "Press [H] to Host  |  Type IP then [J] to Join  |  [TAB] Controls"
var local_peer_id   : int    = 1
var show_controls   : bool   = false

# ─── PlayerData ──────────────────────────────────────────────
class PlayerData:
	var peer_id       : int
	var node          : CharacterBody2D
	var label         : Label
	var stamina_bar   : ColorRect
	var ability_bar   : ColorRect
	var arrow_indicator : Control  # off-screen direction arrow
	var facing        : float  = 1.0
	var velocity      : Vector2 = Vector2.ZERO
	var knockback     : Vector2 = Vector2.ZERO
	var damage_pct    : float  = 0.0
	var lives         : int    = 3
	var is_dead       : bool   = false
	var on_floor      : bool   = false
	var jumps_left    : int    = 2     # double jump
	var dash_t        : float  = 0.0
	var attack_cd     : float  = 0.0
	var special_cd    : float  = 0.0
	var color         : Color
	var archetype     : String = "warrior"
	
	# Animation fields
	var pivot         : Node2D
	var anim_time     : float  = 0.0
	var was_on_floor  : bool   = false
	var is_attacking_anim : bool = false
	var leg_l         : ColorRect
	var leg_r         : ColorRect
	var arm_r         : ColorRect
	var body_rect     : ColorRect

# ─── Node refs ───────────────────────────────────────────────
var canvas          : CanvasLayer
var status_label    : Label
var ip_label        : Label
var controls_panel  : Control
var world           : Node2D

# ─────────────────────────────────────────────────────────────
func _ready():
	_setup_input_map()
	_build_ui()

# ─── Input Map ───────────────────────────────────────────────
func _setup_input_map():
	var binds = {
		"p1_left":    KEY_A,
		"p1_right":   KEY_D,
		"p1_jump":    KEY_W,
		"p1_dodge":   KEY_S,
		"p1_attack":  KEY_F,
		"p1_special": KEY_E,
		"p1_dash_atk":KEY_Q,
		"p1_emote":   KEY_G,
	}
	for action in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev = InputEventKey.new()
			ev.keycode = binds[action]
			InputMap.action_add_event(action, ev)

# ─── UI ──────────────────────────────────────────────────────
func _build_ui():
	var bg = ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.10)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	canvas = CanvasLayer.new()
	add_child(canvas)

	# Title on menu
	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "⚔  DARKBRAWL  ⚔"
	title.position = Vector2(640, 180)
	title.add_theme_font_size_override("font_size", 52)
	title.modulate = Color(0.85, 0.25, 0.25)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas.add_child(title)

	status_label = Label.new()
	status_label.position = Vector2(20, 20)
	status_label.add_theme_font_size_override("font_size", 15)
	canvas.add_child(status_label)

	ip_label = Label.new()
	ip_label.position = Vector2(20, 48)
	ip_label.add_theme_font_size_override("font_size", 20)
	ip_label.modulate = Color(0.8, 0.9, 1.0)
	canvas.add_child(ip_label)

	_build_controls_panel()

	world = Node2D.new()
	add_child(world)

	_update_status()

func _build_controls_panel():
	controls_panel = ColorRect.new()
	controls_panel.color = Color(0.0, 0.0, 0.0, 0.82)
	controls_panel.size = Vector2(420, 340)
	controls_panel.position = Vector2(430, 190)
	controls_panel.visible = false
	canvas.add_child(controls_panel)

	var lines = [
		"  ─── CONTROLS ───────────────────────",
		"",
		"  A / D          Move left / right",
		"  W              Jump  (press again = double jump)",
		"  S              Dodge dash  (costs stamina)",
		"  F              Attack  (melee)",
		"  Q              Dash Attack  (lunge + hit)",
		"  E              Special Ability",
		"  G              Emote / taunt",
		"",
		"  ─── LOBBY ──────────────────────────",
		"",
		"  H              Host a game",
		"  Type IP + J    Join a game",
		"  SPACE          Start match",
		"  R              Restart after game over",
		"  TAB            Toggle this panel",
	]
	for i in range(lines.size()):
		var lbl = Label.new()
		lbl.text = lines[i]
		lbl.position = Vector2(10, 10 + i * 18)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.modulate = Color(0.9, 0.85, 1.0)
		controls_panel.add_child(lbl)

func _update_status():
	if status_label:
		status_label.text = status_text
	if ip_label:
		ip_label.text = ("> " + ip_input) if state == "menu" else ""
	# Hide title when not in menu
	var title = canvas.get_node_or_null("TitleLabel")
	if title:
		title.visible = (state == "menu")

# ─── Input ───────────────────────────────────────────────────
func _input(event):
	# TAB toggles controls panel anywhere
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		show_controls = not show_controls
		controls_panel.visible = show_controls
		return

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
	status_text = "HOSTING port %d  |  Share your IP  |  [SPACE] start  |  [TAB] controls" % PORT
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
	status_text = "Player %d connected!  [SPACE] to start  |  [TAB] controls" % id
	_update_status()

func _on_peer_disconnected(id: int):
	if id in players:
		if players[id].node:
			players[id].node.queue_free()
		players.erase(id)

func _on_connected():
	local_peer_id = multiplayer.get_unique_id()
	pending_peers.append(local_peer_id)
	status_text = "Connected! ID: %d  |  Waiting for host...  |  [TAB] controls" % local_peer_id
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
	for pid in pending_peers:
		_spawn_player(pid)
	pending_peers.clear()

# ─── Map ─────────────────────────────────────────────────────
func _build_map():
	for n in world.get_children():
		n.queue_free()
	platform_nodes.clear()

	var vp = get_viewport().get_visible_rect().size

	# Dark fog atmosphere
	for i in range(10):
		var fog = ColorRect.new()
		fog.color = Color(randf_range(0.08,0.16), randf_range(0.04,0.08), randf_range(0.12,0.20), 0.15)
		fog.size = Vector2(randf_range(100,260), randf_range(60,180))
		fog.position = Vector2(randf_range(0, vp.x), randf_range(0, vp.y))
		world.add_child(fog)

	# Platform layout  [x%, y%, width, moving, axis, dist, speed]
	var plats = [
		[0.50, 0.82, 720, false, Vector2.ZERO,  0,   0  ],  # main floor
		[0.20, 0.62, 210, false, Vector2.ZERO,  0,   0  ],  # left solid
		[0.80, 0.62, 210, false, Vector2.ZERO,  0,   0  ],  # right solid
		[0.50, 0.47, 190, true,  Vector2(1,0),  160, 52 ],  # center moving H
		[0.28, 0.35, 150, false, Vector2.ZERO,  0,   0  ],  # upper left solid
		[0.72, 0.35, 150, false, Vector2.ZERO,  0,   0  ],  # upper right solid
		[0.50, 0.22, 130, true,  Vector2(0,1),  70,  65 ],  # top moving V
	]
	for p in plats:
		_add_platform(vp.x*p[0], vp.y*p[1], p[2], p[3], p[4], p[5], p[6])

func _add_platform(cx, cy, w, moving, axis, dist, spd):
	var body = AnimatableBody2D.new() if moving else StaticBody2D.new()
	body.position = Vector2(cx, cy)
	body.collision_layer = 1
	body.collision_mask  = 0

	var col   = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(w, 18)
	col.shape  = shape
	body.add_child(col)

	var vis = ColorRect.new()
	vis.size     = Vector2(w, 18)
	vis.position = Vector2(-w * 0.5, -9)
	vis.color    = Color(0.45, 0.15, 0.15) if moving else Color(0.28, 0.20, 0.14)
	body.add_child(vis)

	var glow = ColorRect.new()
	glow.size     = Vector2(w, 3)
	glow.position = Vector2(-w * 0.5, -9)
	glow.color    = Color(0.9, 0.4, 0.2, 0.5) if moving else Color(0.8, 0.5, 0.2, 0.3)
	body.add_child(glow)

	if moving:
		body.set_meta("start_pos", Vector2(cx, cy))
		body.set_meta("axis", axis)
		body.set_meta("dist", dist)
		body.set_meta("spd",  spd)
		body.set_meta("t",    0.0)
		platform_nodes.append(body)

	world.add_child(body)

# ─── Player Spawn ────────────────────────────────────────────
var SPAWN_POS = [
	Vector2(320, 350), Vector2(960, 350),
	Vector2(500, 250), Vector2(780, 250)
]
var PLAYER_COLORS = [
	Color(0.3, 0.6, 1.0),
	Color(1.0, 0.3, 0.3),
	Color(0.3, 1.0, 0.5),
	Color(1.0, 0.85, 0.2),
]
var ARCHETYPE_NAMES = ["warrior","rogue","sorcerer","berserker","paladin","phantom","hexblade","warden"]

func _spawn_player(peer_id: int):
	var pd       = PlayerData.new()
	pd.peer_id   = peer_id
	var idx      = players.size() % 4
	pd.color     = PLAYER_COLORS[idx]
	pd.archetype = ARCHETYPE_NAMES[idx % ARCHETYPE_NAMES.size()]

	var body = CharacterBody2D.new()
	body.position        = SPAWN_POS[idx]
	body.collision_layer = 2
	body.collision_mask  = 1

	var col   = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 18
	shape.height = 50
	col.shape    = shape
	body.add_child(col)

	# Create pivot (Node2D) for all animations
	var pivot = Node2D.new()
	pivot.position = Vector2(0, 0)
	body.add_child(pivot)
	pd.pivot = pivot

	# Shadow (oval beneath feet)
	var shadow = ColorRect.new()
	shadow.size     = Vector2(30, 6)
	shadow.position = Vector2(-15, 20)
	shadow.color    = Color(0.2, 0.15, 0.15, 0.5)
	pivot.add_child(shadow)

	# Left leg
	var leg_l = ColorRect.new()
	leg_l.size     = Vector2(10, 16)
	leg_l.position = Vector2(-10, 12)
	leg_l.color    = pd.color * Color(0.7, 0.7, 0.7)  # darkened 30%
	pivot.add_child(leg_l)
	pd.leg_l = leg_l

	# Right leg
	var leg_r = ColorRect.new()
	leg_r.size     = Vector2(10, 16)
	leg_r.position = Vector2(0, 12)
	leg_r.color    = pd.color * Color(0.7, 0.7, 0.7)  # darkened 30%
	pivot.add_child(leg_r)
	pd.leg_r = leg_r

	# Body
	var body_rect = ColorRect.new()
	body_rect.size     = Vector2(30, 32)
	body_rect.position = Vector2(-15, -16)
	body_rect.color    = pd.color
	pivot.add_child(body_rect)
	pd.body_rect = body_rect

	# Left arm
	var arm_l = ColorRect.new()
	arm_l.size     = Vector2(8, 18)
	arm_l.position = Vector2(-18, -10)
	arm_l.color    = pd.color * Color(1.2, 1.2, 1.2)  # lightened 20%, clamped to max 1.0
	arm_l.color.r = min(1.0, arm_l.color.r)
	arm_l.color.g = min(1.0, arm_l.color.g)
	arm_l.color.b = min(1.0, arm_l.color.b)
	pivot.add_child(arm_l)

	# Right arm
	var arm_r = ColorRect.new()
	arm_r.size     = Vector2(8, 18)
	arm_r.position = Vector2(10, -10)
	arm_r.color    = pd.color * Color(1.2, 1.2, 1.2)  # lightened 20%, clamped to max 1.0
	arm_r.color.r = min(1.0, arm_r.color.r)
	arm_r.color.g = min(1.0, arm_r.color.g)
	arm_r.color.b = min(1.0, arm_r.color.b)
	pivot.add_child(arm_r)
	pd.arm_r = arm_r

	# Visor (bright accent)
	var visor = ColorRect.new()
	visor.size     = Vector2(20, 7)
	visor.position = Vector2(-10, -12)
	visor.color    = Color(pd.color.r*1.4, pd.color.g*1.4, pd.color.b*1.4, 0.9)
	visor.color.r = min(1.0, visor.color.r)
	visor.color.g = min(1.0, visor.color.g)
	visor.color.b = min(1.0, visor.color.b)
	pivot.add_child(visor)

	# Name + damage % (stays outside pivot)
	var lbl = Label.new()
	lbl.position = Vector2(-36, -58)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.text     = "P%d [%s]  0%%" % [peer_id, pd.archetype.substr(0,3).to_upper()]
	lbl.modulate = pd.color
	body.add_child(lbl)
	pd.label = lbl

	# Stamina bar bg (stays outside pivot)
	var stam_bg = ColorRect.new()
	stam_bg.size     = Vector2(42, 5)
	stam_bg.position = Vector2(-21, -42)
	stam_bg.color    = Color(0.15, 0.15, 0.15)
	body.add_child(stam_bg)

	# Stamina bar fill (green, stays outside pivot)
	var stam_fill = ColorRect.new()
	stam_fill.size     = Vector2(42, 5)
	stam_fill.position = Vector2(-21, -42)
	stam_fill.color    = Color(0.2, 0.9, 0.4)
	body.add_child(stam_fill)
	pd.stamina_bar = stam_fill

	# Ability cooldown bar bg (stays outside pivot)
	var ab_bg = ColorRect.new()
	ab_bg.size     = Vector2(42, 4)
	ab_bg.position = Vector2(-21, -36)
	ab_bg.color    = Color(0.15, 0.15, 0.15)
	body.add_child(ab_bg)

	# Ability bar fill (purple, stays outside pivot)
	var ab_fill = ColorRect.new()
	ab_fill.size     = Vector2(42, 4)
	ab_fill.position = Vector2(-21, -36)
	ab_fill.color    = Color(0.7, 0.2, 1.0)
	body.add_child(ab_fill)
	pd.ability_bar = ab_fill

	pd.node     = body
	pd.velocity = Vector2.ZERO
	pd.lives    = 3
	pd.set_meta("stamina", MAX_STAMINA)

	# Off-screen arrow indicator (lives in canvas layer so it's always visible)
	var arrow_root = Control.new()
	arrow_root.visible = false
	arrow_root.z_index = 10

	# Arrow triangle shape using a label emoji + bg panel
	var arrow_bg = ColorRect.new()
	arrow_bg.size     = Vector2(54, 22)
	arrow_bg.position = Vector2(-27, -11)
	arrow_bg.color    = Color(pd.color.r, pd.color.g, pd.color.b, 0.85)
	arrow_root.add_child(arrow_bg)

	var arrow_lbl = Label.new()
	arrow_lbl.name = "ArrowLabel"
	arrow_lbl.add_theme_font_size_override("font_size", 12)
	arrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	arrow_lbl.size     = Vector2(54, 22)
	arrow_lbl.position = Vector2(-27, -11)
	arrow_lbl.modulate = Color(0.05, 0.05, 0.05)
	arrow_root.add_child(arrow_lbl)

	canvas.add_child(arrow_root)
	pd.arrow_indicator = arrow_root

	world.add_child(body)
	players[peer_id] = pd

func _respawn_player(pd: PlayerData):
	var idx = (pd.peer_id - 1) % 4
	pd.node.position = SPAWN_POS[idx]
	pd.velocity  = Vector2.ZERO
	pd.knockback = Vector2.ZERO
	pd.damage_pct = 0.0
	pd.is_dead    = false
	pd.jumps_left = 2
	pd.set_meta("stamina", MAX_STAMINA)
	if pd.arrow_indicator:
		pd.arrow_indicator.visible = false

# ─── Process ─────────────────────────────────────────────────
func _process(delta):
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
		var t  = body.get_meta("t") + delta
		body.set_meta("t", t)
		var sp   = body.get_meta("start_pos")
		var axis = body.get_meta("axis")
		var dist = body.get_meta("dist")
		var spd  = body.get_meta("spd")
		body.position = sp + axis * sin(t * spd / max(dist, 1.0) * 1.2) * dist

# ─── Player Processing ───────────────────────────────────────
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

		# Local player input
		if peer_id == local_peer_id:
			var dir = 0.0
			if Input.is_action_pressed("p1_left"):  dir -= 1.0
			if Input.is_action_pressed("p1_right"): dir += 1.0
			pd.velocity.x = dir * MOVE_SPEED
			if dir != 0:
				pd.facing = dir

			# Jump / double jump
			if Input.is_action_just_pressed("p1_jump") and pd.jumps_left > 0 and stam >= STAM_JUMP:
				pd.velocity.y = JUMP_FORCE if pd.jumps_left == 2 else JUMP_FORCE * 0.80
				_spawn_particles(pd.node.position + Vector2(0,15), Color(0.5,0.5,0.5,0.7), 5, Vector2(35,6), 0.3, 3.0)
				if pd.jumps_left == 1:  # About to be 0 (double jump)
					_spawn_particles(pd.node.position, Color(0.5,0.9,1.0), 14, Vector2(75,75), 0.5, 4.0)
				pd.jumps_left -= 1
				stam -= STAM_JUMP
				if pd.jumps_left == 0:
					_show_popup(pd, "↑↑", Color(0.6, 0.9, 1.0))

			# Dodge dash
			if Input.is_action_just_pressed("p1_dodge") and pd.on_floor and pd.dash_t <= 0 and stam >= STAM_DODGE:
				pd.dash_t = DASH_DUR
				stam -= STAM_DODGE

			# Basic attack
			if Input.is_action_just_pressed("p1_attack") and pd.attack_cd <= 0 and stam >= STAM_ATTACK:
				pd.attack_cd = 0.42
				stam -= STAM_ATTACK
				_do_attack(pd, 85.0, 8.0, 240.0)

			# Dash attack (Q) — lunge forward and hit
			if Input.is_action_just_pressed("p1_dash_atk") and pd.attack_cd <= 0 and stam >= STAM_ATTACK + 8:
				pd.dash_t     = 0.12
				pd.attack_cd  = 0.55
				stam -= STAM_ATTACK + 8
				pd.velocity.y = -120.0
				_spawn_particles(pd.node.position, Color(1.0,0.6,0.1), 10, Vector2(110,25), 0.4, 4.0)
				_do_attack(pd, 100.0, 12.0, 300.0)
				_show_popup(pd, "LUNGE!", Color(1.0, 0.6, 0.2))

			# Special ability (E)
			if Input.is_action_just_pressed("p1_special") and pd.special_cd <= 0 and stam >= STAM_SPECIAL:
				pd.special_cd = 4.0
				stam -= STAM_SPECIAL
				_do_special(pd)

			# Emote
			if Input.is_action_just_pressed("p1_emote"):
				_show_emote(pd)

		# Dash velocity override
		if pd.dash_t > 0:
			pd.dash_t    -= delta
			pd.velocity.x = pd.facing * DASH_SPEED

		# Cooldowns
		if pd.attack_cd  > 0: pd.attack_cd  -= delta
		if pd.special_cd > 0: pd.special_cd -= delta

		# Stamina regen
		stam = min(MAX_STAMINA, stam + STAM_REGEN * delta)
		pd.set_meta("stamina", stam)

		# Knockback decay
		pd.velocity += pd.knockback * delta
		pd.knockback *= 0.78

		# Move + slide
		pd.node.velocity = pd.velocity
		pd.node.move_and_slide()
		pd.on_floor = pd.node.is_on_floor()
		if pd.on_floor:
			pd.velocity.y = 0.0
			pd.jumps_left  = 2   # reset double jump on landing

		# Update HUD bars
		pd.label.text = "P%d [%s]  %.0f%%" % [peer_id, pd.archetype.substr(0,3).to_upper(), pd.damage_pct]
		pd.stamina_bar.size.x = max(0, (stam / MAX_STAMINA) * 42.0)
		var ab_pct = 1.0 - clamp(pd.special_cd / 4.0, 0.0, 1.0)
		pd.ability_bar.size.x = max(0, ab_pct * 42.0)

		# Animation update
		_animate_player(pd, delta)

		# Off-screen arrow indicator
		_update_arrow(pd, vp)

		# Death zone
		var margin = 320
		if pd.node.position.x < -margin or pd.node.position.x > vp.x + margin \
		or pd.node.position.y < -margin or pd.node.position.y > vp.y + margin:
			pd.lives -= 1
			if pd.lives <= 0:
				pd.is_dead       = true
				pd.node.visible  = false
			else:
				_respawn_player(pd)
				_show_respawn_flash(pd)

# ─── Off-Screen Arrow ────────────────────────────────────────
func _update_arrow(pd: PlayerData, vp: Vector2):
	if not pd.arrow_indicator or not pd.node:
		return

	var pos = pd.node.position
	var padding = 30.0

	# Is the player on-screen?
	var on_screen = (pos.x > padding and pos.x < vp.x - padding
		and pos.y > padding and pos.y < vp.y - padding)

	if on_screen or pd.is_dead:
		pd.arrow_indicator.visible = false
		return

	pd.arrow_indicator.visible = true

	# Direction from screen center to player
	var center = vp * 0.5
	var dir    = (pos - center).normalized()

	# Find where the ray from center hits the screen edge
	var edge   = _ray_to_screen_edge(center, dir, vp, padding)
	pd.arrow_indicator.position = edge

	# Arrow symbol pointing in direction (8 directions)
	var angle  = dir.angle()
	var deg    = fmod(rad_to_deg(angle) + 360.0, 360.0)
	var arrows = ["→","↘","↓","↙","←","↖","↑","↗"]
	var idx    = int(round(deg / 45.0)) % 8
	var lbl    = pd.arrow_indicator.get_node_or_null("ArrowLabel")
	if lbl:
		lbl.text = "P%d %s %.0f%%" % [pd.peer_id, arrows[idx], pd.damage_pct]

func _ray_to_screen_edge(origin: Vector2, dir: Vector2, vp: Vector2, pad: float) -> Vector2:
	var t_min = INF
	# Left edge
	if dir.x < -0.001:
		t_min = min(t_min, (pad - origin.x) / dir.x)
	# Right edge
	if dir.x > 0.001:
		t_min = min(t_min, (vp.x - pad - origin.x) / dir.x)
	# Top edge
	if dir.y < -0.001:
		t_min = min(t_min, (pad - origin.y) / dir.y)
	# Bottom edge
	if dir.y > 0.001:
		t_min = min(t_min, (vp.y - pad - origin.y) / dir.y)
	return origin + dir * t_min

# ─── Combat ──────────────────────────────────────────────────
func _do_attack(attacker: PlayerData, radius: float, dmg_base: float, kb_base: float):
	if not attacker.node:
		return
	var atk_pos = attacker.node.global_position + Vector2(attacker.facing * 30, 0)
	for pid in players:
		if pid == attacker.peer_id:
			continue
		var target : PlayerData = players[pid]
		if target.is_dead or not target.node:
			continue
		if atk_pos.distance_to(target.node.global_position) < radius:
			var dir = (target.node.global_position - attacker.node.global_position).normalized()
			var dmg = dmg_base + randf_range(0, 4)
			target.damage_pct += dmg
			var launch = kb_base * (1.0 + target.damage_pct / 80.0)
			target.knockback = dir * launch
			_spawn_particles(target.node.global_position, Color(1.0, 0.3, 0.1), 10, Vector2(90, 90), 0.35, 5.0)
			_flash_player(target, Color(1.0, 0.25, 0.25))

func _do_special(pd: PlayerData):
	match pd.archetype:
		"warrior":
			# Ground slam — AoE knockback downward
			_do_attack(pd, 140.0, 18.0, 420.0)
			_spawn_particles(pd.node.position, Color(0.9,0.5,0.1), 20, Vector2(180,60), 0.6)
			_show_popup(pd, "SLAM!", Color(1.0, 0.5, 0.1))
		"rogue":
			# Triple quick strike
			_do_attack(pd, 75.0, 7.0, 200.0)
			_spawn_particles(pd.node.position, Color(0.3,1.0,0.4), 6, Vector2(70,70), 0.35, 4.0)
			await get_tree().create_timer(0.1).timeout
			_do_attack(pd, 75.0, 7.0, 200.0)
			_spawn_particles(pd.node.position, Color(0.3,1.0,0.4), 6, Vector2(70,70), 0.35, 4.0)
			await get_tree().create_timer(0.1).timeout
			_do_attack(pd, 75.0, 7.0, 200.0)
			_spawn_particles(pd.node.position, Color(0.3,1.0,0.4), 6, Vector2(70,70), 0.35, 4.0)
			_show_popup(pd, "TRIPLE!", Color(0.4, 1.0, 0.4))
		"sorcerer":
			# Blast wave — big range, moderate knockback
			_do_attack(pd, 200.0, 14.0, 380.0)
			_spawn_particles(pd.node.position, Color(0.4,0.4,1.0), 25, Vector2(200,200), 0.7, 6.0)
			_show_popup(pd, "BLAST!", Color(0.5, 0.5, 1.0))
		"berserker":
			# Rage slam — massive damage, short range
			_do_attack(pd, 90.0, 28.0, 500.0)
			_spawn_particles(pd.node.position, Color(1.0,0.1,0.1), 18, Vector2(110,110), 0.5, 5.0)
			_show_popup(pd, "RAGE!", Color(1.0, 0.1, 0.1))
		_:
			# Default: power strike
			_do_attack(pd, 110.0, 20.0, 360.0)
			_spawn_particles(pd.node.position, Color(1.0,0.8,0.2), 12, Vector2(100,100), 0.5)
			_show_popup(pd, "STRIKE!", Color(1.0, 0.8, 0.2))

# ─── Animation ───────────────────────────────────────────────
func _animate_player(pd: PlayerData, delta: float):
	if not pd.node or not pd.pivot:
		return
	
	pd.anim_time += delta
	
	var moving = abs(pd.velocity.x) > 20
	var on_floor = pd.on_floor
	
	# Walk cycle
	if moving and on_floor:
		var leg_oscillation = sin(pd.anim_time * 10.0) * 5.0
		pd.leg_l.position.y = 12 - leg_oscillation
		pd.leg_r.position.y = 12 + leg_oscillation
		pd.body_rect.rotation = pd.facing * 0.08
	else:
		# Idle
		if on_floor:
			pd.leg_l.position.y = 12
			pd.leg_r.position.y = 12
			var breathe = sin(Time.get_ticks_msec() * 0.002) * 0.02
			pd.pivot.scale.y = 1.0 + breathe
		pd.body_rect.rotation = 0.0
	
	# Jump state
	if pd.velocity.y < -100:
		pd.pivot.scale = Vector2(0.8, 1.25)
	# Fall state
	elif pd.velocity.y > 100 and not on_floor:
		pd.pivot.scale = Vector2(1.1, 0.9)
	# Landing
	elif pd.was_on_floor == false and on_floor == true:
		_spawn_particles(pd.node.position + Vector2(0,10), Color(0.6,0.5,0.4,0.8), 8, Vector2(60,10), 0.4)
		var tw = create_tween()
		tw.tween_property(pd.pivot, "scale", Vector2(1.3, 0.7), 0.06)
		tw.tween_property(pd.pivot, "scale", Vector2(1.0, 1.0), 0.12)
	# Dodge
	elif pd.dash_t > 0:
		pd.pivot.scale = Vector2(1.4, 0.7)
	# Normal idle/walk
	elif moving == false and on_floor:
		pd.pivot.scale = Vector2(1.0, 1.0)
	
	# Attack animation
	if pd.attack_cd > 0.3:
		pd.arm_r.rotation = -1.2 * pd.facing
		pd.body_rect.rotation = pd.facing * 0.2
	else:
		if not (moving and on_floor):
			pd.arm_r.rotation = 0.0
	
	pd.was_on_floor = on_floor

# ─── Particle System ──────────────────────────────────────────
func _spawn_particles(pos: Vector2, color: Color, count: int, spread: Vector2, lifetime: float, size: float = 5.0):
	for i in range(count):
		var p = ColorRect.new()
		p.size = Vector2(size, size)
		p.color = color
		p.position = pos
		world.add_child(p)
		var vel = Vector2(randf_range(-spread.x, spread.x), randf_range(-spread.y, spread.y))
		var tw = create_tween()
		tw.tween_property(p, "position", pos + vel, lifetime)
		tw.parallel().tween_property(p, "modulate:a", 0.0, lifetime)
		tw.tween_callback(p.queue_free)

# ─── Visual Helpers ──────────────────────────────────────────
func _flash_player(pd: PlayerData, col: Color):
	if not pd.node or pd.node.get_child_count() < 2:
		return
	var sprite = pd.node.get_child(1)
	if sprite is ColorRect:
		sprite.color = col
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(sprite):
			sprite.color = pd.color

func _show_popup(pd: PlayerData, text: String, col: Color):
	if not pd.node:
		return
	var lbl = Label.new()
	lbl.text     = text
	lbl.position = pd.node.position + Vector2(-28, -75)
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.modulate = col
	world.add_child(lbl)
	var tw = create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 55, 1.0)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
	tw.tween_callback(lbl.queue_free)

func _show_emote(pd: PlayerData):
	var emotes = ["GG", "EZ", "skill issue", "lol 💀", "you're cooked", "get bodied",
				  "imagine losing", "L + ratio", "stay free", "not even close"]
	_show_popup(pd, emotes[randi() % emotes.size()], Color(1.0, 0.9, 0.2))

func _show_respawn_flash(pd: PlayerData):
	pd.node.visible = true
	for i in range(6):
		pd.node.modulate.a = 0.3
		await get_tree().create_timer(0.1).timeout
		pd.node.modulate.a = 1.0
		await get_tree().create_timer(0.1).timeout

# ─── Game Over ───────────────────────────────────────────────
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
	status_text = ("DRAW!" if winner_id == -1 else "PLAYER %d WINS!" % winner_id) + "  |  [R] restart"
	_update_status()

func _unhandled_input(event):
	if state == "gameover" and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
