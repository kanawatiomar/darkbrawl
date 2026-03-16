extends Node

# Call this from _ready() in your main scene to register all input actions
# Default keybinds — remappable later via settings menu

func setup():
	_add("p1_left",   KEY_A)
	_add("p1_right",  KEY_D)
	_add("p1_jump",   KEY_W)
	_add("p1_dodge",  KEY_S)
	_add("p1_attack", KEY_F)
	_add("p1_emote",  KEY_G)

	# P2 (for future local testing)
	_add("p2_left",   KEY_LEFT)
	_add("p2_right",  KEY_RIGHT)
	_add("p2_jump",   KEY_UP)
	_add("p2_dodge",  KEY_DOWN)
	_add("p2_attack", KEY_KP_1)
	_add("p2_emote",  KEY_KP_2)

func _add(action: String, keycode: int):
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		var ev = InputEventKey.new()
		ev.keycode = keycode
		InputMap.action_add_event(action, ev)
