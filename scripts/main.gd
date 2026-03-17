extends Node

# ─── DarkBrawl v0.5 ──────────────────────────────────────────
# States: menu → hosting/joined → loadout → playing → gameover
# Loadout: UP/DOWN pick archetype | +/- allocate stats | ENTER ready | host SPACE starts
# H host | type IP + J join | TAB controls | R restart

const GRAVITY       = 980.0
const JUMP_FORCE    = -740.0
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
const STAT_POINTS   = 15   # total points to distribute
const STAT_MIN      = 1
const STAT_MAX      = 8

var players         : Dictionary = {}
var pending_peers   : Array      = []
var platform_nodes  : Array      = []
var state           : String     = "menu"
var ip_input        : String     = ""
var status_text     : String     = "Press [H] to Host  |  Type IP then [J] to Join  |  [TAB] Controls"
var local_peer_id   : int        = 1
var show_controls   : bool       = false

# Loadout state
var loadout_archetype_idx : int    = 0
var loadout_stat_idx      : int    = 0   # which stat is selected
var loadout_weapon_idx    : int    = 0   # which weapon is selected
var loadout_stats         : Array  = [3,3,2,4,3]  # STR DEX INT VIT END
var loadout_ready         : bool   = false
var loadout_panel         : Control
var loadout_labels        : Array  = []

# Map selection
var current_map  : int = 0
var MAP_NAMES    = ["Ashfall Arena", "Void Citadel", "Frozen Abyss"]

# ─── Archetype Data ──────────────────────────────────────────
const ARCHETYPES = [
	{
		"name": "Warrior",    "icon": "⚔️",
		"tagline": "The immovable wall.",
		"stats": {"str":1,"dex":-1,"int":-1,"vit":2,"end":1},
		"locked_out": ["int"],
		"color": Color(0.85,0.35,0.2),
		"weapons": ["Greatsword","War Axe","Tower Shield"],
		"special": "Ground Slam — AoE knockback, massive damage in close range"
	},
	{
		"name": "Rogue",      "icon": "🗡️",
		"tagline": "Blink and you miss it.",
		"stats": {"str":-1,"dex":2,"int":0,"vit":-1,"end":1},
		"locked_out": ["vit"],
		"color": Color(0.3,0.9,0.4),
		"weapons": ["Dual Daggers","Short Sword","Throwing Knives"],
		"special": "Triple Strike — three rapid hits in quick succession"
	},
	{
		"name": "Sorcerer",   "icon": "🔮",
		"tagline": "Keep your distance or die.",
		"stats": {"str":-2,"dex":0,"int":3,"vit":-1,"end":0},
		"locked_out": ["str"],
		"color": Color(0.4,0.4,1.0),
		"weapons": ["Staff","Spell Catalyst","Tome of Ruin"],
		"special": "Blast Wave — wide-range magic explosion"
	},
	{
		"name": "Berserker",  "icon": "🩸",
		"tagline": "The harder you hit him, the angrier he gets.",
		"stats": {"str":3,"dex":1,"int":-2,"vit":0,"end":-1},
		"locked_out": ["int","end"],
		"color": Color(1.0,0.15,0.15),
		"weapons": ["Great Maul","Battle Axe","Bone Cleaver"],
		"special": "Blood Rage — massive hit, lifesteal, scales with own damage %"
	},
	{
		"name": "Paladin",    "icon": "✝️",
		"tagline": "The judge, jury, and executioner.",
		"stats": {"str":1,"dex":0,"int":1,"vit":1,"end":0},
		"locked_out": [],
		"color": Color(1.0,0.85,0.3),
		"weapons": ["Holy Blade","Mace of Reckoning","Divine Hammer"],
		"special": "Divine Wrath — holy blast forward, stuns on hit"
	},
	{
		"name": "Phantom",    "icon": "👁️",
		"tagline": "You're fighting a ghost.",
		"stats": {"str":-1,"dex":2,"int":1,"vit":-1,"end":0},
		"locked_out": ["str","vit"],
		"color": Color(0.7,0.3,1.0),
		"weapons": ["Shadow Blade","Void Dart","Phase Dagger"],
		"special": "Phase Shift — teleport behind nearest enemy + instant strike"
	},
	{
		"name": "Hexblade",   "icon": "🌑",
		"tagline": "Every hit leaves a mark.",
		"stats": {"str":0,"dex":1,"int":2,"vit":0,"end":-1},
		"locked_out": ["end"],
		"color": Color(0.5,0.1,0.7),
		"weapons": ["Cursed Blade","Hex Staff","Soul Reaper"],
		"special": "Curse Brand — applies curse debuff, amplifying all damage received"
	},
	{
		"name": "Warden",     "icon": "⚖️",
		"tagline": "No crutch. Just skill.",
		"stats": {"str":0,"dex":0,"int":0,"vit":0,"end":0},
		"locked_out": [],
		"color": Color(0.7,0.7,0.7),
		"weapons": ["Longsword","Halberd","War Pick"],
		"special": "Counter — brief parry window; if hit during it, reflect damage × 2"
	},
	{
		"name": "Droid Netanyahu", "icon": "🎩",
		"tagline": "Ceasefire is not in my vocabulary.",
		"stats": {"str":2,"dex":-1,"int":2,"vit":2,"end":0},
		"locked_out": ["dex"],
		"color": Color(0.15,0.18,0.35),
		"weapons": ["Iron Fist","F-35 Targeting System","UN Veto Stamp"],
		"special": "GENOCIDE — calls in a full airstrike across the entire platform"
	},
]
const STAT_NAMES = ["STR","DEX","INT","VIT","END"]
const STAT_KEYS  = ["str","dex","int","vit","end"]

# ─── PlayerData ──────────────────────────────────────────────
class PlayerData:
	var peer_id         : int
	var node            : CharacterBody2D
	var pivot           : Node2D
	var label           : Label
	var stamina_bar     : ColorRect
	var ability_bar     : ColorRect
	var arrow_indicator : Control
	var body_rect       : ColorRect
	var leg_l           : ColorRect
	var leg_r           : ColorRect
	var arm_l           : ColorRect
	var arm_r           : ColorRect
	var facing          : float  = 1.0
	var velocity        : Vector2 = Vector2.ZERO
	var knockback       : Vector2 = Vector2.ZERO
	var damage_pct      : float  = 0.0
	var lives           : int    = 3
	var is_dead         : bool   = false
	var on_floor        : bool   = false
	var was_on_floor    : bool   = false
	var jumps_left      : int    = 2
	var dash_t          : float  = 0.0
	var attack_cd       : float  = 0.0
	var special_cd      : float  = 0.0
	var counter_active  : float  = 0.0   # Warden parry window
	var cursed          : float  = 0.0   # Hexblade debuff timer
	var anim_time       : float  = 0.0
	var color           : Color
	var archetype       : String = "warrior"
	var weapon          : String = ""
	var stat_str        : int    = 3
	var stat_dex        : int    = 3
	var stat_int        : int    = 2
	var stat_vit        : int    = 4
	var stat_end        : int    = 3

# ─── Node refs ───────────────────────────────────────────────
var canvas         : CanvasLayer
var status_label   : Label
var ip_label       : Label
var controls_panel : Control
var world          : Node2D

func _ready():
	_setup_input_map()
	_build_ui()

# ─── Input Map ───────────────────────────────────────────────
func _setup_input_map():
	var binds = {
		"p1_left":     KEY_A, "p1_right":    KEY_D,
		"p1_jump":     KEY_W, "p1_dodge":    KEY_S,
		"p1_attack":   KEY_F, "p1_special":  KEY_E,
		"p1_dash_atk": KEY_Q, "p1_emote":    KEY_G,
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
	bg.color = Color(0.07,0.05,0.10)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	canvas = CanvasLayer.new()
	add_child(canvas)

	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "⚔  DARKBRAWL  ⚔"
	title.position = Vector2(640,180)
	title.add_theme_font_size_override("font_size", 52)
	title.modulate = Color(0.85,0.25,0.25)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas.add_child(title)

	status_label = Label.new()
	status_label.position = Vector2(20,20)
	status_label.add_theme_font_size_override("font_size", 15)
	canvas.add_child(status_label)

	ip_label = Label.new()
	ip_label.position = Vector2(20,48)
	ip_label.add_theme_font_size_override("font_size", 20)
	ip_label.modulate = Color(0.8,0.9,1.0)
	canvas.add_child(ip_label)

	_build_controls_panel()

	world = Node2D.new()
	add_child(world)

	_update_status()

func _build_controls_panel():
	controls_panel = ColorRect.new()
	controls_panel.color = Color(0.0,0.0,0.0,0.82)
	controls_panel.size = Vector2(430,400)
	controls_panel.position = Vector2(425,170)
	controls_panel.visible = false
	canvas.add_child(controls_panel)
	var lines = [
		"  ─── IN GAME ────────────────────────",
		"  A / D        Move",
		"  W            Jump (again = double jump)",
		"  S            Dodge dash",
		"  F            Attack",
		"  Q            Dash Attack",
		"  E            Special Ability",
		"  G            Emote / taunt",
		"",
		"  ─── LOBBY ──────────────────────────",
		"  H            Host game",
		"  Type IP + J  Join game",
		"  SPACE        Start (host only)",
		"  R            Restart after game over",
		"  TAB          Toggle this panel",
		"",
		"  ─── LOADOUT SCREEN ──────────────────",
		"  ↑ / ↓        Select archetype",
		"  Z / X        Cycle weapon selection",
		"  ← / →        Select stat",
		"  + / -        Add / remove stat point",
		"  ENTER        Ready up",
		"  SPACE        Start (host, all ready)",
	]
	for i in range(lines.size()):
		var lbl = Label.new()
		lbl.text = lines[i]
		lbl.position = Vector2(10, 10 + i * 17)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.modulate = Color(0.9,0.85,1.0)
		controls_panel.add_child(lbl)

func _update_status():
	if status_label: status_label.text = status_text
	if ip_label: ip_label.text = ("> " + ip_input) if state == "menu" else ""
	var title = canvas.get_node_or_null("TitleLabel")
	if title: title.visible = (state == "menu")

# ─── Input ───────────────────────────────────────────────────
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		show_controls = not show_controls
		controls_panel.visible = show_controls
		return

	if state == "menu":
		if event is InputEventKey and event.pressed:
			match event.keycode:
				KEY_H: _host()
				KEY_J: _join(ip_input if ip_input != "" else "127.0.0.1")
				KEY_BACKSPACE:
					if ip_input.length() > 0:
						ip_input = ip_input.left(ip_input.length()-1)
						_update_status()
				KEY_PERIOD:
					ip_input += "."; _update_status()
				_:
					var ch = event.as_text()
					if ch.length() == 1 and ch[0].is_valid_int():
						ip_input += ch; _update_status()

	elif state == "loadout":
		_handle_loadout_input(event)

func _handle_loadout_input(event):
	if not (event is InputEventKey and event.pressed): return
	match event.keycode:
		KEY_UP:
			loadout_archetype_idx = (loadout_archetype_idx - 1 + ARCHETYPES.size()) % ARCHETYPES.size()
			loadout_weapon_idx = 0
			_refresh_loadout_panel()
		KEY_DOWN:
			loadout_archetype_idx = (loadout_archetype_idx + 1) % ARCHETYPES.size()
			loadout_weapon_idx = 0
			_refresh_loadout_panel()
		KEY_Z:
			var weapons = ARCHETYPES[loadout_archetype_idx]["weapons"]
			loadout_weapon_idx = (loadout_weapon_idx - 1 + weapons.size()) % weapons.size()
			_refresh_loadout_panel()
		KEY_X:
			var weapons = ARCHETYPES[loadout_archetype_idx]["weapons"]
			loadout_weapon_idx = (loadout_weapon_idx + 1) % weapons.size()
			_refresh_loadout_panel()
		KEY_LEFT:
			loadout_stat_idx = (loadout_stat_idx - 1 + STAT_NAMES.size()) % STAT_NAMES.size()
			_refresh_loadout_panel()
		KEY_RIGHT:
			loadout_stat_idx = (loadout_stat_idx + 1) % STAT_NAMES.size()
			_refresh_loadout_panel()
		KEY_EQUAL, KEY_KP_ADD:   # + key
			_adjust_stat(loadout_stat_idx, 1)
		KEY_MINUS, KEY_KP_SUBTRACT:  # - key
			_adjust_stat(loadout_stat_idx, -1)
		KEY_ENTER, KEY_KP_ENTER:
			loadout_ready = true
			_refresh_loadout_panel()
		KEY_SPACE:
			if loadout_ready:
				_finalize_loadout_and_start()

func _adjust_stat(idx: int, delta: int):
	var used = 0
	for s in loadout_stats: used += s
	var arch = ARCHETYPES[loadout_archetype_idx]
	var key = STAT_KEYS[idx]
	if key in arch["locked_out"]: return
	var new_val = loadout_stats[idx] + delta
	if new_val < STAT_MIN or new_val > STAT_MAX: return
	if delta > 0 and used >= STAT_POINTS: return
	loadout_stats[idx] = new_val
	_refresh_loadout_panel()

# ─── Loadout Screen ──────────────────────────────────────────
func _show_loadout_screen():
	state = "loadout"
	status_text = ""
	_update_status()
	# Reset to defaults
	loadout_archetype_idx = 0
	loadout_stats = [3,3,2,4,3]
	loadout_stat_idx = 0
	loadout_weapon_idx = 0
	loadout_ready = false
	_build_loadout_panel()

func _build_loadout_panel():
	if loadout_panel:
		loadout_panel.queue_free()
	loadout_panel = Control.new()
	canvas.add_child(loadout_panel)
	_refresh_loadout_panel()

func _refresh_loadout_panel():
	if not loadout_panel: return
	for c in loadout_panel.get_children(): c.queue_free()
	loadout_labels.clear()

	var vp = get_viewport().get_visible_rect().size
	var arch = ARCHETYPES[loadout_archetype_idx]

	# ── Background ──
	var bg = ColorRect.new()
	bg.color = Color(0.04,0.03,0.07,0.95)
	bg.size = vp; bg.position = Vector2.ZERO
	loadout_panel.add_child(bg)

	# ── Title ──
	var title = Label.new()
	title.text = "⚔  SELECT YOUR ARCHETYPE  ⚔"
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(0.85,0.25,0.25)
	title.position = Vector2(vp.x*0.5 - 260, 20)
	loadout_panel.add_child(title)

	# ── Archetype List (left panel) ──
	var list_bg = ColorRect.new()
	list_bg.color = Color(0.08,0.06,0.12); list_bg.size = Vector2(260, 480)
	list_bg.position = Vector2(30, 70)
	loadout_panel.add_child(list_bg)

	for i in range(ARCHETYPES.size()):
		var a = ARCHETYPES[i]
		var row_bg = ColorRect.new()
		row_bg.size = Vector2(256, 54)
		row_bg.position = Vector2(32, 72 + i*56)
		row_bg.color = a["color"] * 0.4 if i == loadout_archetype_idx else Color(0.1,0.08,0.14)
		loadout_panel.add_child(row_bg)

		if i == loadout_archetype_idx:
			var sel = ColorRect.new()
			sel.size = Vector2(4, 54); sel.position = Vector2(32, 72 + i*56)
			sel.color = a["color"]; loadout_panel.add_child(sel)

		var row_lbl = Label.new()
		row_lbl.text = "%s %s" % [a["icon"], a["name"]]
		row_lbl.position = Vector2(42, 80 + i*56)
		row_lbl.add_theme_font_size_override("font_size", 16)
		row_lbl.modulate = a["color"] if i == loadout_archetype_idx else Color(0.6,0.6,0.6)
		loadout_panel.add_child(row_lbl)

		var tag_lbl = Label.new()
		tag_lbl.text = a["tagline"]
		tag_lbl.position = Vector2(42, 98 + i*56)
		tag_lbl.add_theme_font_size_override("font_size", 11)
		tag_lbl.modulate = Color(0.5,0.5,0.5)
		loadout_panel.add_child(tag_lbl)

	# ── Selected Archetype Detail (center) ──
	var detail_bg = ColorRect.new()
	detail_bg.color = Color(0.08,0.06,0.12)
	detail_bg.size = Vector2(380, 480); detail_bg.position = Vector2(308, 70)
	loadout_panel.add_child(detail_bg)

	# Archetype name + icon
	var big_name = Label.new()
	big_name.text = "%s  %s" % [arch["icon"], arch["name"].to_upper()]
	big_name.position = Vector2(318, 85)
	big_name.add_theme_font_size_override("font_size", 32)
	big_name.modulate = arch["color"]
	loadout_panel.add_child(big_name)

	var big_tag = Label.new()
	big_tag.text = '"%s"' % arch["tagline"]
	big_tag.position = Vector2(318, 125)
	big_tag.add_theme_font_size_override("font_size", 14)
	big_tag.modulate = Color(0.6,0.6,0.7)
	loadout_panel.add_child(big_tag)

	# Special description
	var spec_hdr = Label.new()
	spec_hdr.text = "SPECIAL  [E]"
	spec_hdr.position = Vector2(318, 160)
	spec_hdr.add_theme_font_size_override("font_size", 13)
	spec_hdr.modulate = Color(0.7,0.2,1.0)
	loadout_panel.add_child(spec_hdr)

	var spec_lbl = Label.new()
	spec_lbl.text = arch["special"]
	spec_lbl.position = Vector2(318, 178)
	spec_lbl.add_theme_font_size_override("font_size", 12)
	spec_lbl.modulate = Color(0.8,0.8,0.9)
	spec_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spec_lbl.size = Vector2(360, 40)
	loadout_panel.add_child(spec_lbl)

	# Weapons
	var weap_hdr = Label.new()
	weap_hdr.text = "WEAPONS"
	weap_hdr.position = Vector2(318, 228)
	weap_hdr.add_theme_font_size_override("font_size", 13)
	weap_hdr.modulate = Color(0.9,0.6,0.2)
	loadout_panel.add_child(weap_hdr)

	for i in range(arch["weapons"].size()):
		var w = arch["weapons"][i]
		var selected_w = (i == loadout_weapon_idx)
		if selected_w:
			var wsel_bg = ColorRect.new()
			wsel_bg.color = Color(arch["color"].r,arch["color"].g,arch["color"].b,0.2)
			wsel_bg.size = Vector2(362,20); wsel_bg.position = Vector2(316, 246+i*20)
			loadout_panel.add_child(wsel_bg)
		var wl = Label.new()
		wl.text = ("▶ " if selected_w else "  ") + w + ("  [Z/X to cycle]" if i == loadout_weapon_idx else "")
		wl.position = Vector2(318, 248 + i*20)
		wl.add_theme_font_size_override("font_size", 13)
		wl.modulate = arch["color"] if selected_w else Color(0.5,0.5,0.5)
		loadout_panel.add_child(wl)

	# ── Stat Allocation ──
	var stat_hdr = Label.new()
	stat_hdr.text = "STAT ALLOCATION  (%d/%d points)" % [_stats_used(), STAT_POINTS]
	stat_hdr.position = Vector2(318, 315)
	stat_hdr.add_theme_font_size_override("font_size", 13)
	stat_hdr.modulate = Color(0.4,0.9,0.5) if _stats_used() < STAT_POINTS else Color(0.9,0.4,0.2)
	loadout_panel.add_child(stat_hdr)

	for i in range(STAT_NAMES.size()):
		var is_selected = (i == loadout_stat_idx)
		var is_locked = STAT_KEYS[i] in arch["locked_out"]
		var stat_y = 338 + i * 28

		# Selection highlight
		if is_selected and not is_locked:
			var sel_bg = ColorRect.new()
			sel_bg.color = Color(0.15,0.12,0.22)
			sel_bg.size = Vector2(362,24); sel_bg.position = Vector2(316, stat_y - 2)
			loadout_panel.add_child(sel_bg)

		var sname = Label.new()
		sname.text = STAT_NAMES[i] + ("  [LOCKED]" if is_locked else ("  ◀ ▶" if is_selected else ""))
		sname.position = Vector2(322, stat_y)
		sname.add_theme_font_size_override("font_size", 13)
		sname.modulate = Color(0.4,0.4,0.4) if is_locked else (arch["color"] if is_selected else Color(0.8,0.8,0.8))
		loadout_panel.add_child(sname)

		# Stat bar
		for b in range(STAT_MAX):
			var bar = ColorRect.new()
			bar.size = Vector2(18,12); bar.position = Vector2(390 + b*22, stat_y + 2)
			if is_locked:
				bar.color = Color(0.15,0.15,0.15)
			elif b < loadout_stats[i]:
				bar.color = arch["color"]
			else:
				bar.color = Color(0.2,0.2,0.2)
			loadout_panel.add_child(bar)

		var sval = Label.new()
		sval.text = str(loadout_stats[i])
		sval.position = Vector2(578, stat_y)
		sval.add_theme_font_size_override("font_size", 13)
		sval.modulate = Color(0.9,0.9,0.9)
		loadout_panel.add_child(sval)

	# ── Ready / Start prompt ──
	var ready_lbl = Label.new()
	if loadout_ready:
		ready_lbl.text = "✅ READY  —  Host: [SPACE] to start"
		ready_lbl.modulate = Color(0.3,1.0,0.4)
	else:
		ready_lbl.text = "[ENTER] Ready Up    |    ↑↓ archetype    |    ←→ stat    |    +/- adjust"
		ready_lbl.modulate = Color(0.6,0.6,0.7)
	ready_lbl.position = Vector2(30, 575)
	ready_lbl.add_theme_font_size_override("font_size", 15)
	loadout_panel.add_child(ready_lbl)

func _stats_used() -> int:
	var total = 0
	for s in loadout_stats: total += s
	return total

func _finalize_loadout_and_start():
	if loadout_panel:
		loadout_panel.queue_free()
		loadout_panel = null
	_start_game()

# ─── Networking ──────────────────────────────────────────────
func _host():
	var peer = ENetMultiplayerPeer.new()
	if peer.create_server(PORT, 4) != OK:
		status_text = "ERROR: Could not host on port %d" % PORT
		_update_status(); return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	local_peer_id = 1
	pending_peers.append(1)
	status_text = "HOSTING port %d  |  Share your IP  |  [SPACE] go to loadout  |  [TAB] controls" % PORT
	_update_status()
	state = "hosting"

func _join(ip: String):
	var peer = ENetMultiplayerPeer.new()
	if peer.create_client(ip, PORT) != OK:
		status_text = "ERROR: Could not connect to %s:%d" % [ip, PORT]
		_update_status(); return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_conn_failed)
	status_text = "Connecting to %s..." % ip
	_update_status()

func _on_peer_connected(id: int):
	pending_peers.append(id)
	status_text = "Player %d connected!  [SPACE] to go to loadout" % id
	_update_status()

func _on_peer_disconnected(id: int):
	if id in players:
		if players[id].node: players[id].node.queue_free()
		if players[id].arrow_indicator: players[id].arrow_indicator.queue_free()
		players.erase(id)

func _on_connected():
	local_peer_id = multiplayer.get_unique_id()
	pending_peers.append(local_peer_id)
	status_text = "Connected! ID: %d  |  Waiting for host..." % local_peer_id
	_update_status()
	state = "joined"

func _on_conn_failed():
	status_text = "Connection FAILED."
	_update_status(); state = "menu"

# ─── Game Start ──────────────────────────────────────────────
func _start_game():
	state = "playing"
	status_text = ""
	_update_status()
	current_map = randi() % MAP_NAMES.size()
	_build_map()
	for pid in pending_peers:
		_spawn_player(pid)
	pending_peers.clear()

# ─── Map ─────────────────────────────────────────────────────
func _build_map():
	for n in world.get_children(): n.queue_free()
	platform_nodes.clear()
	var vp = get_viewport().get_visible_rect().size

	match current_map:
		0: _build_map_ashfall(vp)
		1: _build_map_void_citadel(vp)
		2: _build_map_frozen_abyss(vp)
		_: _build_map_ashfall(vp)

func _build_map_ashfall(vp: Vector2):
	_add_fog(vp, Color(0.12,0.06,0.16))
	var plats = [
		[0.50,0.82,720,false,Vector2.ZERO,0,0],
		[0.20,0.62,210,false,Vector2.ZERO,0,0],
		[0.80,0.62,210,false,Vector2.ZERO,0,0],
		[0.50,0.47,190,true, Vector2(1,0),160,52],
		[0.28,0.35,150,false,Vector2.ZERO,0,0],
		[0.72,0.35,150,false,Vector2.ZERO,0,0],
		[0.50,0.22,130,true, Vector2(0,1),70,65],
	]
	for p in plats: _add_platform(vp.x*p[0],vp.y*p[1],p[2],p[3],p[4],p[5],p[6],
		Color(0.28,0.20,0.14), Color(0.8,0.5,0.2,0.4))

func _build_map_void_citadel(vp: Vector2):
	_add_fog(vp, Color(0.06,0.04,0.18))
	var plats = [
		[0.50,0.85,600,false,Vector2.ZERO,0,0],
		[0.15,0.70,160,true, Vector2(0,1),80,55],
		[0.85,0.70,160,true, Vector2(0,1),80,55],
		[0.50,0.55,220,false,Vector2.ZERO,0,0],
		[0.30,0.40,140,true, Vector2(1,0),130,60],
		[0.70,0.40,140,true, Vector2(1,0),130,60],
		[0.50,0.25,100,false,Vector2.ZERO,0,0],
	]
	for p in plats: _add_platform(vp.x*p[0],vp.y*p[1],p[2],p[3],p[4],p[5],p[6],
		Color(0.12,0.08,0.28), Color(0.5,0.2,0.9,0.5))

func _build_map_frozen_abyss(vp: Vector2):
	_add_fog(vp, Color(0.06,0.10,0.18))
	var plats = [
		[0.50,0.82,800,false,Vector2.ZERO,0,0],
		[0.12,0.65,180,false,Vector2.ZERO,0,0],
		[0.88,0.65,180,false,Vector2.ZERO,0,0],
		[0.35,0.50,160,true, Vector2(1,0),140,48],
		[0.65,0.50,160,true, Vector2(1,0),140,48],
		[0.50,0.35,200,false,Vector2.ZERO,0,0],
		[0.22,0.22,120,true, Vector2(0,1),60,70],
		[0.78,0.22,120,true, Vector2(0,1),60,70],
	]
	for p in plats: _add_platform(vp.x*p[0],vp.y*p[1],p[2],p[3],p[4],p[5],p[6],
		Color(0.14,0.22,0.32), Color(0.3,0.7,1.0,0.4))

func _add_fog(vp: Vector2, tint: Color):
	for i in range(10):
		var fog = ColorRect.new()
		fog.color = Color(tint.r+randf_range(-0.03,0.03), tint.g+randf_range(-0.03,0.03), tint.b+randf_range(-0.03,0.03), 0.14)
		fog.size = Vector2(randf_range(100,260), randf_range(60,180))
		fog.position = Vector2(randf_range(0,vp.x), randf_range(0,vp.y))
		world.add_child(fog)

func _add_platform(cx,cy,w,moving,axis,dist,spd, col:Color, glow_col:Color):
	var body = AnimatableBody2D.new() if moving else StaticBody2D.new()
	body.position = Vector2(cx,cy)
	body.collision_layer = 1; body.collision_mask = 0
	var c2d = CollisionShape2D.new()
	var shape = RectangleShape2D.new(); shape.size = Vector2(w,18); c2d.shape = shape
	body.add_child(c2d)
	var vis = ColorRect.new()
	vis.size = Vector2(w,18); vis.position = Vector2(-w*0.5,-9)
	vis.color = Color(col.r*1.3,col.g*1.3,col.b*1.3) if moving else col
	body.add_child(vis)
	var glow = ColorRect.new()
	glow.size = Vector2(w,3); glow.position = Vector2(-w*0.5,-9)
	glow.color = glow_col; body.add_child(glow)
	if moving:
		body.set_meta("start_pos",Vector2(cx,cy)); body.set_meta("axis",axis)
		body.set_meta("dist",dist); body.set_meta("spd",spd); body.set_meta("t",0.0)
		platform_nodes.append(body)
	world.add_child(body)

# ─── Player Spawn ────────────────────────────────────────────
var SPAWN_POS = [Vector2(320,350),Vector2(960,350),Vector2(500,250),Vector2(780,250)]
var PLAYER_COLORS = [Color(0.3,0.6,1.0),Color(1.0,0.3,0.3),Color(0.3,1.0,0.5),Color(1.0,0.85,0.2)]

func _spawn_player(peer_id: int):
	var pd     = PlayerData.new()
	pd.peer_id = peer_id
	var idx    = players.size() % 4

	# Apply loadout if this is the local player
	if peer_id == local_peer_id:
		var arch    = ARCHETYPES[loadout_archetype_idx]
		pd.archetype = arch["name"].to_lower()
		pd.weapon    = arch["weapons"][loadout_weapon_idx]
		pd.stat_str  = loadout_stats[0]
		pd.stat_dex  = loadout_stats[1]
		pd.stat_int  = loadout_stats[2]
		pd.stat_vit  = loadout_stats[3]
		pd.stat_end  = loadout_stats[4]
		pd.color     = arch["color"]
	else:
		pd.archetype = "warrior"
		pd.color     = PLAYER_COLORS[idx]

	var body = CharacterBody2D.new()
	body.position = SPAWN_POS[idx]
	body.collision_layer = 2; body.collision_mask = 1

	var col = CollisionShape2D.new()
	var shape = CapsuleShape2D.new(); shape.radius = 18; shape.height = 50; col.shape = shape
	body.add_child(col)

	var pivot = Node2D.new(); pivot.name = "pivot"; body.add_child(pivot); pd.pivot = pivot
	var c = pd.color
	var dark = Color(c.r*0.6,c.g*0.6,c.b*0.6)
	var lite = Color(min(c.r*1.3,1.0),min(c.g*1.3,1.0),min(c.b*1.3,1.0))

	var shadow = ColorRect.new(); shadow.size = Vector2(30,6); shadow.position = Vector2(-15,22)
	shadow.color = Color(0,0,0,0.35); pivot.add_child(shadow)

	var leg_l = ColorRect.new(); leg_l.name = "leg_l"; leg_l.size = Vector2(10,16); leg_l.position = Vector2(-14,8)
	leg_l.color = dark; pivot.add_child(leg_l); pd.leg_l = leg_l

	var leg_r = ColorRect.new(); leg_r.name = "leg_r"; leg_r.size = Vector2(10,16); leg_r.position = Vector2(4,8)
	leg_r.color = dark; pivot.add_child(leg_r); pd.leg_r = leg_r

	var body_rect = ColorRect.new(); body_rect.name = "body"; body_rect.size = Vector2(30,30); body_rect.position = Vector2(-15,-22)
	body_rect.color = c; pivot.add_child(body_rect); pd.body_rect = body_rect

	var arm_l = ColorRect.new(); arm_l.name = "arm_l"; arm_l.size = Vector2(8,18); arm_l.position = Vector2(-23,-18)
	arm_l.color = lite; pivot.add_child(arm_l); pd.arm_l = arm_l

	var arm_r = ColorRect.new(); arm_r.name = "arm_r"; arm_r.size = Vector2(8,18); arm_r.position = Vector2(15,-18)
	arm_r.color = lite; pivot.add_child(arm_r); pd.arm_r = arm_r

	if pd.archetype == "droid netanyahu":
		# Bald head (large, skin-tone)
		var big_head = ColorRect.new(); big_head.size = Vector2(32,26); big_head.position = Vector2(-16,-50)
		big_head.color = Color(0.85,0.68,0.52); pivot.add_child(big_head)
		# Jowls
		var jowl_l = ColorRect.new(); jowl_l.size = Vector2(7,10); jowl_l.position = Vector2(-20,-36)
		jowl_l.color = Color(0.78,0.62,0.48); pivot.add_child(jowl_l)
		var jowl_r = ColorRect.new(); jowl_r.size = Vector2(7,10); jowl_r.position = Vector2(13,-36)
		jowl_r.color = Color(0.78,0.62,0.48); pivot.add_child(jowl_r)
		# Suit collar (white shirt)
		var collar = ColorRect.new(); collar.size = Vector2(10,8); collar.position = Vector2(-5,-24)
		collar.color = Color(0.95,0.95,0.95); pivot.add_child(collar)
		# Red tie
		var tie = ColorRect.new(); tie.size = Vector2(6,18); tie.position = Vector2(-3,-22)
		tie.color = Color(0.85,0.12,0.12); pivot.add_child(tie)
		# Eyes (dark beady)
		var eye_l = ColorRect.new(); eye_l.size = Vector2(4,4); eye_l.position = Vector2(-9,-44)
		eye_l.color = Color(0.1,0.1,0.1); pivot.add_child(eye_l)
		var eye_r = ColorRect.new(); eye_r.size = Vector2(4,4); eye_r.position = Vector2(5,-44)
		eye_r.color = Color(0.1,0.1,0.1); pivot.add_child(eye_r)
		# Frown
		var frown = ColorRect.new(); frown.size = Vector2(12,3); frown.position = Vector2(-6,-36)
		frown.color = Color(0.4,0.25,0.2); pivot.add_child(frown)
	else:
		var head = ColorRect.new(); head.size = Vector2(24,20); head.position = Vector2(-12,-42); head.color = c
		pivot.add_child(head)
		var visor = ColorRect.new(); visor.size = Vector2(20,7); visor.position = Vector2(-10,-34)
		visor.color = Color(min(c.r*1.8,1.0),min(c.g*1.8,1.0),min(c.b*1.8,1.0),0.95); pivot.add_child(visor)

	var lbl = Label.new(); lbl.position = Vector2(-40,-68); lbl.add_theme_font_size_override("font_size", 13)
	lbl.text = "P%d [%s]  0%%  ♥♥♥" % [peer_id, pd.archetype.substr(0,3).to_upper()]; lbl.modulate = pd.color
	body.add_child(lbl); pd.label = lbl

	var stam_bg = ColorRect.new(); stam_bg.size = Vector2(44,5); stam_bg.position = Vector2(-22,-52)
	stam_bg.color = Color(0.15,0.15,0.15); body.add_child(stam_bg)
	var stam_fill = ColorRect.new(); stam_fill.size = Vector2(44,5); stam_fill.position = Vector2(-22,-52)
	stam_fill.color = Color(0.2,0.9,0.4); body.add_child(stam_fill); pd.stamina_bar = stam_fill

	var ab_bg = ColorRect.new(); ab_bg.size = Vector2(44,4); ab_bg.position = Vector2(-22,-46)
	ab_bg.color = Color(0.15,0.15,0.15); body.add_child(ab_bg)
	var ab_fill = ColorRect.new(); ab_fill.size = Vector2(44,4); ab_fill.position = Vector2(-22,-46)
	ab_fill.color = Color(0.7,0.2,1.0); body.add_child(ab_fill); pd.ability_bar = ab_fill

	var arrow_root = Control.new(); arrow_root.visible = false; arrow_root.z_index = 10
	var arrow_bg = ColorRect.new(); arrow_bg.size = Vector2(60,22); arrow_bg.position = Vector2(-30,-11)
	arrow_bg.color = Color(c.r,c.g,c.b,0.85); arrow_root.add_child(arrow_bg)
	var arrow_lbl = Label.new(); arrow_lbl.name = "ArrowLabel"
	arrow_lbl.add_theme_font_size_override("font_size",12); arrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; arrow_lbl.size = Vector2(60,22); arrow_lbl.position = Vector2(-30,-11)
	arrow_lbl.modulate = Color(0.05,0.05,0.05); arrow_root.add_child(arrow_lbl)
	canvas.add_child(arrow_root); pd.arrow_indicator = arrow_root

	pd.node = body; pd.velocity = Vector2.ZERO; pd.lives = 3
	pd.set_meta("stamina", MAX_STAMINA + pd.stat_end * 8.0)
	world.add_child(body)
	players[peer_id] = pd

func _respawn_player(pd: PlayerData):
	var idx = (pd.peer_id - 1) % 4
	pd.node.position = SPAWN_POS[idx]
	pd.velocity = Vector2.ZERO; pd.knockback = Vector2.ZERO
	pd.damage_pct = 0.0; pd.is_dead = false; pd.jumps_left = 2
	pd.pivot.scale = Vector2.ONE; pd.counter_active = 0.0; pd.cursed = 0.0
	pd.set_meta("stamina", MAX_STAMINA + pd.stat_end * 8.0)
	if pd.arrow_indicator: pd.arrow_indicator.visible = false

# ─── Process ─────────────────────────────────────────────────
func _process(delta):
	if (state == "hosting" or state == "joined") and Input.is_action_just_pressed("ui_accept"):
		_show_loadout_screen(); return
	if state != "playing": return
	_move_platforms(delta)
	_process_players(delta)
	_check_game_over()

func _move_platforms(delta):
	for body in platform_nodes:
		var t = body.get_meta("t") + delta; body.set_meta("t",t)
		body.position = body.get_meta("start_pos") + body.get_meta("axis") \
			* sin(t * body.get_meta("spd") / max(body.get_meta("dist"),1.0) * 1.2) * body.get_meta("dist")

# ─── Player Processing ───────────────────────────────────────
func _process_players(delta):
	var vp = get_viewport().get_visible_rect().size
	for peer_id in players:
		var pd : PlayerData = players[peer_id]
		if pd.is_dead or not pd.node: continue

		var stam : float = pd.get_meta("stamina")
		var max_stam = MAX_STAMINA + pd.stat_end * 8.0
		pd.was_on_floor = pd.on_floor

		if not pd.on_floor: pd.velocity.y += GRAVITY * delta

		if peer_id == local_peer_id:
			var dir = 0.0
			if Input.is_action_pressed("p1_left"):  dir -= 1.0
			if Input.is_action_pressed("p1_right"): dir += 1.0
			var spd = MOVE_SPEED + pd.stat_dex * 6.0
			pd.velocity.x = dir * spd
			if dir != 0: pd.facing = dir

			if Input.is_action_just_pressed("p1_jump") and pd.jumps_left > 0 and stam >= STAM_JUMP:
				var is_double = pd.jumps_left == 1
				pd.velocity.y = (JUMP_FORCE if not is_double else JUMP_FORCE * 0.80) - pd.stat_dex * 4.0
				pd.jumps_left -= 1; stam -= STAM_JUMP
				_spawn_particles(pd.node.position+Vector2(0,15),
					Color(0.5,0.5,0.5,0.7) if not is_double else Color(0.5,0.9,1.0),
					5 if not is_double else 14,
					Vector2(35,6) if not is_double else Vector2(75,75),
					0.3 if not is_double else 0.5, 3.0)
				if is_double: _show_popup(pd, "↑↑", Color(0.5,0.9,1.0))

			if Input.is_action_just_pressed("p1_dodge") and pd.on_floor and pd.dash_t <= 0 and stam >= STAM_DODGE:
				pd.dash_t = DASH_DUR; stam -= STAM_DODGE

			if Input.is_action_just_pressed("p1_attack") and pd.attack_cd <= 0 and stam >= STAM_ATTACK:
				var dmg = 8.0 + pd.stat_str * 1.5
				var kb  = 220.0 + pd.stat_str * 10.0
				pd.attack_cd = max(0.25, 0.45 - pd.stat_dex * 0.02); stam -= STAM_ATTACK
				_do_attack(pd, 85.0, dmg, kb)

			if Input.is_action_just_pressed("p1_dash_atk") and pd.attack_cd <= 0 and stam >= STAM_ATTACK+8:
				pd.dash_t = 0.12; pd.attack_cd = 0.55; stam -= STAM_ATTACK+8
				pd.velocity.y = -120.0
				_do_attack(pd, 100.0, 12.0+pd.stat_str, 300.0)
				_spawn_particles(pd.node.position, Color(1.0,0.6,0.1), 10, Vector2(110,25), 0.4, 4.0)
				_show_popup(pd, "LUNGE!", Color(1.0,0.6,0.2))

			if Input.is_action_just_pressed("p1_special") and pd.special_cd <= 0 and stam >= STAM_SPECIAL:
				pd.special_cd = 4.0; stam -= STAM_SPECIAL
				_do_special(pd)

			if Input.is_action_just_pressed("p1_emote"):
				_show_emote(pd)

		if pd.dash_t > 0:
			pd.dash_t -= delta
			pd.velocity.x = pd.facing * (DASH_SPEED + pd.stat_dex * 8.0)

		if pd.attack_cd  > 0: pd.attack_cd  -= delta
		if pd.special_cd > 0: pd.special_cd -= delta
		if pd.counter_active > 0: pd.counter_active -= delta
		if pd.cursed > 0:     pd.cursed     -= delta

		stam = min(max_stam, stam + STAM_REGEN * (1.0 + pd.stat_end * 0.06) * delta)
		pd.set_meta("stamina", stam)

		pd.velocity += pd.knockback * delta
		pd.knockback *= 0.78

		pd.node.velocity = pd.velocity
		pd.node.move_and_slide()
		pd.on_floor = pd.node.is_on_floor()
		if pd.on_floor: pd.velocity.y = 0.0; pd.jumps_left = 2

		_animate_player(pd, delta)

		var hearts = "♥".repeat(pd.lives) + "♡".repeat(max(0, 3 - pd.lives))
		pd.label.text = "P%d [%s]  %.0f%%  %s" % [peer_id, pd.archetype.substr(0,3).to_upper(), pd.damage_pct, hearts]
		pd.stamina_bar.size.x = max(0, (stam/max_stam)*44.0)
		pd.ability_bar.size.x = max(0, (1.0 - clamp(pd.special_cd/4.0,0.0,1.0))*44.0)
		_update_arrow(pd, vp)

		var margin = 320
		if pd.node.position.x < -margin or pd.node.position.x > vp.x+margin \
		or pd.node.position.y < -margin or pd.node.position.y > vp.y+margin:
			pd.lives -= 1
			if pd.lives <= 0: pd.is_dead = true; pd.node.visible = false
			else: _respawn_player(pd); _show_respawn_flash(pd)

# ─── Animation ───────────────────────────────────────────────
func _animate_player(pd: PlayerData, delta: float):
	if not pd.pivot or not is_instance_valid(pd.pivot): return
	var v = pd.velocity

	if pd.on_floor and not pd.was_on_floor:
		var tw = create_tween()
		tw.tween_property(pd.pivot,"scale",Vector2(1.3,0.7),0.06)
		tw.tween_property(pd.pivot,"scale",Vector2(1.0,1.0),0.12)
		_spawn_particles(pd.node.position+Vector2(0,12), Color(0.6,0.5,0.4,0.8), 8, Vector2(60,10), 0.4)

	if not pd.on_floor:
		var target_scale = Vector2(0.8,1.25) if v.y < -100 else Vector2(1.1,0.9)
		pd.pivot.scale = pd.pivot.scale.lerp(target_scale, 0.2)
	elif pd.dash_t > 0:
		pd.pivot.scale = pd.pivot.scale.lerp(Vector2(1.4,0.7), 0.3)
	else:
		var breathe = 1.0 + sin(Time.get_ticks_msec()*0.002)*0.018
		pd.pivot.scale = pd.pivot.scale.lerp(Vector2(1.0,breathe), 0.15)

	if pd.on_floor and abs(v.x) > 20:
		pd.anim_time += delta
		var s = sin(pd.anim_time*10.0)
		pd.leg_l.position.y = 8.0 + s*5.0; pd.leg_r.position.y = 8.0 - s*5.0
		pd.body_rect.rotation = pd.facing * 0.07
	else:
		pd.leg_l.position.y = lerp(pd.leg_l.position.y,8.0,0.25)
		pd.leg_r.position.y = lerp(pd.leg_r.position.y,8.0,0.25)
		pd.body_rect.rotation = lerp(pd.body_rect.rotation,0.0,0.2)

	if pd.attack_cd > 0.3:
		pd.arm_r.rotation = lerp(pd.arm_r.rotation,-1.2*pd.facing,0.4)
		pd.body_rect.rotation = lerp(pd.body_rect.rotation,pd.facing*0.22,0.3)
	else:
		pd.arm_r.rotation = lerp(pd.arm_r.rotation,0.0,0.2)

	# Warden counter glow
	if pd.counter_active > 0:
		pd.body_rect.color = Color(1.0,1.0,0.3,0.9)
	elif pd.cursed > 0:
		pd.body_rect.color = Color(0.6,0.1,0.8)
	else:
		pd.body_rect.color = pd.color

# ─── Particles ───────────────────────────────────────────────
func _spawn_particles(pos:Vector2, color:Color, count:int, spread:Vector2, lifetime:float, size:float=5.0):
	for i in range(count):
		var p = ColorRect.new(); p.size = Vector2(size,size); p.color = color; p.position = pos
		world.add_child(p)
		var vel = Vector2(randf_range(-spread.x,spread.x), randf_range(-spread.y,spread.y))
		var tw = create_tween()
		tw.tween_property(p,"position",pos+vel,lifetime)
		tw.parallel().tween_property(p,"modulate:a",0.0,lifetime)
		tw.tween_callback(p.queue_free)

# ─── Off-Screen Arrow ────────────────────────────────────────
func _update_arrow(pd:PlayerData, vp:Vector2):
	if not pd.arrow_indicator or not pd.node: return
	var pos = pd.node.position; var pad = 32.0
	var on_screen = pos.x>pad and pos.x<vp.x-pad and pos.y>pad and pos.y<vp.y-pad
	if on_screen or pd.is_dead: pd.arrow_indicator.visible = false; return
	pd.arrow_indicator.visible = true
	var center = vp*0.5; var dir = (pos-center).normalized()
	pd.arrow_indicator.position = _ray_to_screen_edge(center,dir,vp,pad)
	var deg = fmod(rad_to_deg(dir.angle())+360.0,360.0)
	var arrows = ["→","↘","↓","↙","←","↖","↑","↗"]
	var lbl = pd.arrow_indicator.get_node_or_null("ArrowLabel")
	if lbl: lbl.text = "P%d %s %.0f%%" % [pd.peer_id,arrows[int(round(deg/45.0))%8],pd.damage_pct]

func _ray_to_screen_edge(origin:Vector2,dir:Vector2,vp:Vector2,pad:float)->Vector2:
	var t = INF
	if dir.x < -0.001: t = min(t,(pad-origin.x)/dir.x)
	if dir.x >  0.001: t = min(t,(vp.x-pad-origin.x)/dir.x)
	if dir.y < -0.001: t = min(t,(pad-origin.y)/dir.y)
	if dir.y >  0.001: t = min(t,(vp.y-pad-origin.y)/dir.y)
	return origin+dir*t

# ─── Combat ──────────────────────────────────────────────────
func _do_attack(attacker:PlayerData, radius:float, dmg_base:float, kb_base:float):
	if not attacker.node: return
	var atk_pos = attacker.node.global_position + Vector2(attacker.facing*30,0)
	for pid in players:
		if pid == attacker.peer_id: continue
		var target:PlayerData = players[pid]
		if target.is_dead or not target.node: continue
		if atk_pos.distance_to(target.node.global_position) < radius:
			# Warden counter check
			if target.counter_active > 0:
				_show_popup(target, "COUNTERED!", Color(1.0,1.0,0.2))
				var dir2 = (attacker.node.global_position - target.node.global_position).normalized()
				attacker.damage_pct += dmg_base * 2.0
				attacker.knockback = dir2 * kb_base * 2.5
				_flash_player(attacker, Color(1.0,1.0,0.0))
				target.counter_active = 0.0
				return
			var dir = (target.node.global_position - attacker.node.global_position).normalized()
			var dmg = dmg_base + randf_range(0,4)
			if target.cursed > 0: dmg *= 1.5
			target.damage_pct += dmg
			var vit_reduction = max(0.4, 1.0 - target.stat_vit * 0.04)
			target.knockback = dir * kb_base * (1.0 + target.damage_pct/80.0) * vit_reduction
			_flash_player(target, Color(1.0,0.25,0.25))
			_spawn_particles(target.node.global_position, Color(1.0,0.3,0.1), 10, Vector2(90,90), 0.35, 5.0)
			# Berserker lifesteal
			if attacker.archetype == "berserker":
				attacker.damage_pct = max(0.0, attacker.damage_pct - 3.0)

func _do_special(pd:PlayerData):
	match pd.archetype:
		"warrior":
			_do_attack(pd, 140.0, 18.0+pd.stat_str*2, 420.0)
			_spawn_particles(pd.node.position, Color(0.9,0.5,0.1), 20, Vector2(180,60), 0.6)
			_show_popup(pd, "SLAM!", Color(1.0,0.5,0.1))
		"rogue":
			for i in range(3):
				_do_attack(pd, 75.0, 7.0+pd.stat_dex, 200.0)
				_spawn_particles(pd.node.position+Vector2(pd.facing*40,0), Color(0.3,1.0,0.4), 6, Vector2(70,70), 0.35, 4.0)
				await get_tree().create_timer(0.1).timeout
			_show_popup(pd, "TRIPLE!", Color(0.3,1.0,0.4))
		"sorcerer":
			_do_attack(pd, 200.0+pd.stat_int*8, 14.0+pd.stat_int*2, 380.0)
			_spawn_particles(pd.node.position, Color(0.4,0.4,1.0), 25, Vector2(200,200), 0.7, 6.0)
			_show_popup(pd, "BLAST!", Color(0.4,0.4,1.0))
		"berserker":
			var rage_dmg = 28.0 + pd.damage_pct * 0.15 + pd.stat_str * 3
			_do_attack(pd, 90.0, rage_dmg, 500.0)
			_spawn_particles(pd.node.position, Color(1.0,0.1,0.1), 18, Vector2(110,110), 0.5, 5.0)
			var tw = create_tween()
			tw.tween_property(pd.pivot,"scale",Vector2(1.3,1.3),0.08)
			tw.tween_property(pd.pivot,"scale",Vector2(1.0,1.0),0.2)
			_show_popup(pd, "RAGE!", Color(1.0,0.1,0.1))
		"paladin":
			# Divine wrath — forward blast + brief stun (heavy knockback forward)
			_do_attack(pd, 130.0, 16.0+pd.stat_str+pd.stat_int, 450.0)
			_spawn_particles(pd.node.position+Vector2(pd.facing*60,0), Color(1.0,0.95,0.3), 22, Vector2(100,80), 0.6, 6.0)
			_show_popup(pd, "DIVINE WRATH!", Color(1.0,0.95,0.3))
		"phantom":
			# Teleport behind nearest enemy + instant strike
			var nearest = _get_nearest_enemy(pd)
			if nearest:
				pd.node.position = nearest.node.position + Vector2(-pd.facing*60, 0)
				_spawn_particles(pd.node.position, Color(0.7,0.3,1.0), 16, Vector2(60,60), 0.4, 4.0)
				_do_attack(pd, 90.0, 14.0+pd.stat_dex+pd.stat_int, 320.0)
				_show_popup(pd, "PHASE!", Color(0.7,0.3,1.0))
			else:
				_show_popup(pd, "NO TARGET", Color(0.5,0.5,0.5))
		"hexblade":
			# Apply curse to all nearby enemies — amplifies damage for 5 seconds
			var hit_any = false
			for pid in players:
				if pid == pd.peer_id: continue
				var t:PlayerData = players[pid]
				if not t.is_dead and t.node:
					if pd.node.global_position.distance_to(t.node.global_position) < 160.0:
						t.cursed = 5.0; hit_any = true
						_spawn_particles(t.node.position, Color(0.5,0.1,0.7), 12, Vector2(80,80), 0.5, 4.0)
			if hit_any:
				_show_popup(pd, "CURSED!", Color(0.6,0.1,0.9))
			else:
				pd.special_cd = 0.5  # refund most of cooldown
		"warden":
			# Counter stance — parry window, reflects on hit
			pd.counter_active = 0.6
			_show_popup(pd, "COUNTER!", Color(1.0,1.0,0.3))
			_spawn_particles(pd.node.position, Color(1.0,1.0,0.3), 10, Vector2(60,60), 0.4, 4.0)
		"droid netanyahu":
			_do_genocide(pd)
		_:
			_do_attack(pd, 110.0, 20.0, 360.0)
			_spawn_particles(pd.node.position, Color(1.0,0.8,0.2), 12, Vector2(100,100), 0.5)

func _do_genocide(pd: PlayerData):
	_show_popup(pd, "GENOCIDE", Color(1.0, 0.1, 0.1))
	var vp = get_viewport().get_visible_rect().size
	# Screen flash white
	var flash = ColorRect.new()
	flash.color = Color(1.0, 0.9, 0.8, 0.0)
	flash.size = vp; flash.position = Vector2.ZERO; flash.z_index = 20
	world.add_child(flash)
	var ftw = create_tween()
	ftw.tween_property(flash, "color:a", 0.6, 0.1)
	ftw.tween_property(flash, "color:a", 0.0, 0.4)
	ftw.tween_callback(flash.queue_free)

	# Drop 8 bombs across the map with staggered timing
	for i in range(8):
		var bomb_x = randf_range(80, vp.x - 80)
		await get_tree().create_timer(0.15).timeout
		_drop_bomb(pd, bomb_x, vp)

func _drop_bomb(pd: PlayerData, bomb_x: float, vp: Vector2):
	# Bomb visual — falls from top
	var bomb = ColorRect.new()
	bomb.size = Vector2(12, 20); bomb.color = Color(0.15, 0.15, 0.15)
	bomb.position = Vector2(bomb_x, -20); bomb.z_index = 5
	world.add_child(bomb)

	# Fin detail
	var fin = ColorRect.new(); fin.size = Vector2(18,8); fin.position = Vector2(-3,12)
	fin.color = Color(0.3,0.3,0.3); bomb.add_child(fin)

	var drop_tween = create_tween()
	drop_tween.tween_property(bomb, "position:y", vp.y * 0.75, 0.35)
	drop_tween.tween_callback(func():
		bomb.queue_free()
		# Explosion
		var exp_pos = Vector2(bomb_x, vp.y * 0.75)
		_spawn_particles(exp_pos, Color(1.0,0.6,0.1), 25, Vector2(160,120), 0.7, 7.0)
		_spawn_particles(exp_pos, Color(1.0,0.2,0.05), 15, Vector2(80,80),  0.5, 5.0)
		_spawn_particles(exp_pos, Color(0.3,0.3,0.3,0.8), 20, Vector2(120,200), 1.2, 4.0)  # smoke
		# Screen shake
		var cam_tween = create_tween()
		cam_tween.tween_property(world, "position", Vector2(randf_range(-8,8), randf_range(-8,8)), 0.05)
		cam_tween.tween_property(world, "position", Vector2.ZERO, 0.1)
		# Damage all enemies in blast radius
		for pid in players:
			if pid == pd.peer_id: continue
			var target: PlayerData = players[pid]
			if target.is_dead or not target.node: continue
			if abs(target.node.global_position.x - bomb_x) < 100:
				var dir = Vector2(target.node.global_position.x - bomb_x, -1).normalized()
				target.damage_pct += 14.0
				target.knockback = dir * 380.0 * (1.0 + target.damage_pct / 80.0)
				_flash_player(target, Color(1.0, 0.4, 0.0))
	)

func _get_nearest_enemy(pd:PlayerData) -> PlayerData:
	var nearest = null; var nearest_dist = INF
	for pid in players:
		if pid == pd.peer_id: continue
		var t:PlayerData = players[pid]
		if not t.is_dead and t.node:
			var d = pd.node.global_position.distance_to(t.node.global_position)
			if d < nearest_dist: nearest_dist = d; nearest = t
	return nearest

# ─── Visuals ─────────────────────────────────────────────────
func _flash_player(pd:PlayerData, col:Color):
	if not pd.body_rect or not is_instance_valid(pd.body_rect): return
	pd.body_rect.color = col
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(pd.body_rect): pd.body_rect.color = pd.color

func _show_popup(pd:PlayerData, text:String, col:Color):
	if not pd.node: return
	var lbl = Label.new(); lbl.text = text; lbl.position = pd.node.position+Vector2(-30,-80)
	lbl.add_theme_font_size_override("font_size", 18); lbl.modulate = col; world.add_child(lbl)
	var tw = create_tween()
	tw.tween_property(lbl,"position:y",lbl.position.y-55,1.0)
	tw.parallel().tween_property(lbl,"modulate:a",0.0,1.0)
	tw.tween_callback(lbl.queue_free)

func _show_emote(pd:PlayerData):
	var emotes = ["GG","EZ","skill issue","lol 💀","you're cooked","get bodied",
				  "imagine losing","L + ratio","stay free","not even close"]
	_show_popup(pd, emotes[randi()%emotes.size()], Color(1.0,0.9,0.2))

func _show_respawn_flash(pd:PlayerData):
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
		if not players[pid].is_dead: alive.append(pid)
	if alive.size() == 1 and players.size() > 1: _game_over(alive[0])
	elif alive.size() == 0 and players.size() > 0: _game_over(-1)

func _game_over(winner_id:int):
	state = "gameover"
	var arch_name = ""
	if winner_id in players: arch_name = " (%s)" % players[winner_id].archetype.capitalize()
	status_text = ("DRAW!" if winner_id==-1 else "PLAYER %d%s WINS!" % [winner_id,arch_name]) + "  |  [R] restart"
	_update_status()

func _unhandled_input(event):
	if state == "gameover" and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
