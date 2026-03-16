extends CharacterBody2D

# ─── Constants ───────────────────────────────────────────────
const GRAVITY       = 980.0
const JUMP_FORCE    = -520.0
const MOVE_SPEED    = 280.0
const DASH_SPEED    = 600.0
const DASH_DURATION = 0.18
const KNOCKBACK_DECAY = 0.85

# Stamina
const MAX_STAMINA       = 100.0
const STAMINA_REGEN     = 18.0   # per second
const STAMINA_ATTACK    = 15.0
const STAMINA_DODGE     = 25.0
const STAMINA_JUMP      = 8.0

# Smash damage / knockback
const BASE_KNOCKBACK    = 200.0

# ─── State ───────────────────────────────────────────────────
var damage_percent  : float = 0.0   # Smash-style %, higher = launches farther
var stamina         : float = MAX_STAMINA
var lives           : int   = 3
var is_dead         : bool  = false

var is_dashing      : bool  = false
var dash_timer      : float = 0.0
var dash_direction  : float = 1.0

var attack_cooldown : float = 0.0
var is_attacking    : bool  = false
var attack_timer    : float = 0.0

var knockback_vel   : Vector2 = Vector2.ZERO

# Archetype stats (set from lobby/loadout)
var archetype       : String = "warrior"
var stat_str        : int    = 5
var stat_dex        : int    = 3
var stat_int        : int    = 2
var stat_vit        : int    = 4
var stat_end        : int    = 3

# Network
@export var player_id : int = 1
var input_prefix    : String = "p1"

# ─── Signals ─────────────────────────────────────────────────
signal player_died(player_id)
signal damage_taken(player_id, new_percent)

# ─── Ready ───────────────────────────────────────────────────
func _ready():
	input_prefix = "p%d" % player_id
	stamina = MAX_STAMINA + (stat_end * 10.0)

# ─── Physics ─────────────────────────────────────────────────
func _physics_process(delta):
	if is_dead:
		return

	_apply_gravity(delta)
	_handle_input(delta)
	_handle_stamina(delta)
	_handle_attack_timer(delta)
	_apply_knockback(delta)
	_check_death()

	move_and_slide()

func _apply_gravity(delta):
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func _handle_input(delta):
	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_direction * DASH_SPEED
		if dash_timer <= 0:
			is_dashing = false
		return

	# Horizontal movement
	var dir = 0.0
	if Input.is_action_pressed(input_prefix + "_left"):
		dir -= 1.0
	if Input.is_action_pressed(input_prefix + "_right"):
		dir += 1.0

	var speed = MOVE_SPEED + (stat_dex * 8)
	velocity.x = dir * speed

	# Jump
	if Input.is_action_just_pressed(input_prefix + "_jump") and is_on_floor():
		if stamina >= STAMINA_JUMP:
			velocity.y = JUMP_FORCE - (stat_dex * 5)
			stamina -= STAMINA_JUMP

	# Dodge / dash
	if Input.is_action_just_pressed(input_prefix + "_dodge") and is_on_floor():
		if stamina >= STAMINA_DODGE:
			is_dashing = true
			dash_timer = DASH_DURATION
			dash_direction = sign(dir) if dir != 0 else 1.0
			stamina -= STAMINA_DODGE

	# Attack
	if Input.is_action_just_pressed(input_prefix + "_attack"):
		if stamina >= STAMINA_ATTACK and not is_attacking and attack_cooldown <= 0:
			_do_attack()

	# Emote
	if Input.is_action_just_pressed(input_prefix + "_emote"):
		_do_emote()

func _handle_stamina(delta):
	if stamina < MAX_STAMINA + (stat_end * 10.0):
		stamina += STAMINA_REGEN * (1.0 + stat_end * 0.1) * delta
		stamina = min(stamina, MAX_STAMINA + (stat_end * 10.0))

func _handle_attack_timer(delta):
	if attack_cooldown > 0:
		attack_cooldown -= delta
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false

func _apply_knockback(delta):
	if knockback_vel.length() > 1.0:
		velocity += knockback_vel * delta
		knockback_vel *= KNOCKBACK_DECAY
	else:
		knockback_vel = Vector2.ZERO

func _check_death():
	var screen = get_viewport_rect().size
	var margin = 300
	if position.x < -margin or position.x > screen.x + margin \
	or position.y < -margin or position.y > screen.y + margin:
		_die()

# ─── Combat ──────────────────────────────────────────────────
func _do_attack():
	stamina      -= STAMINA_ATTACK
	is_attacking  = true
	attack_timer  = 0.3
	attack_cooldown = 0.4 - (stat_dex * 0.02)

	# Hitbox check — scan for nearby players
	var space = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 80.0
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 2  # player layer
	var results = space.intersect_shape(query)
	for r in results:
		var body = r["collider"]
		if body != self and body.has_method("take_hit"):
			var dir = (body.global_position - global_position).normalized()
			body.take_hit(stat_str * 3.0, dir, damage_percent)

func take_hit(raw_damage: float, direction: Vector2, attacker_percent: float):
	damage_percent += raw_damage
	emit_signal("damage_taken", player_id, damage_percent)

	# Knockback scales with victim damage% (Smash formula)
	var launch_power = BASE_KNOCKBACK * (1.0 + damage_percent / 80.0)
	# VIT reduces knockback
	launch_power *= max(0.4, 1.0 - (stat_vit * 0.04))
	knockback_vel = direction * launch_power

func _die():
	lives -= 1
	damage_percent = 0.0
	emit_signal("player_died", player_id)
	if lives <= 0:
		is_dead = true
		queue_free()
	else:
		# Respawn to center
		position = Vector2(640, 200)
		velocity = Vector2.ZERO

func _do_emote():
	# Placeholder — animation + voice line hook
	print("Player %d emotes!" % player_id)
