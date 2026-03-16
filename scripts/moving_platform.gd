extends AnimatableBody2D

@export var move_distance : float = 200.0
@export var move_speed    : float = 80.0
@export var move_axis     : Vector2 = Vector2(1, 0)  # horizontal by default

var start_pos : Vector2
var t         : float = 0.0

func _ready():
	start_pos = position
	add_to_group("moving_platform")

func _physics_process(delta):
	t += delta * move_speed / move_distance
	var offset = sin(t) * move_distance
	position = start_pos + move_axis * offset
