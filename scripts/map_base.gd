extends Node2D

# Base class for all maps
# Moving platforms register themselves here

var moving_platforms : Array = []

func _ready():
	for child in get_children():
		if child.is_in_group("moving_platform"):
			moving_platforms.append(child)

func get_spawn_points() -> Array:
	var points = []
	for child in get_children():
		if child.name.begins_with("Spawn"):
			points.append(child.global_position)
	return points
