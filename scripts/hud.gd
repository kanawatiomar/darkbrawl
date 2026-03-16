extends CanvasLayer

# Called by game manager to update player HUD elements
# Expects labels/bars named: P1Damage, P2Damage, P1Lives, P2Lives, P1Stamina, P2Stamina

func update_damage(player_id: int, pct: float):
	var label = get_node_or_null("P%dDamage" % player_id)
	if label:
		label.text = "%.0f%%" % pct
		# Color shifts red as damage increases
		var r = min(1.0, pct / 150.0)
		label.modulate = Color(1.0, 1.0 - r, 1.0 - r)

func update_lives(player_id: int, lives: int):
	var label = get_node_or_null("P%dLives" % player_id)
	if label:
		label.text = "♥ x%d" % lives

func update_stamina(player_id: int, stamina: float, max_stamina: float):
	var bar = get_node_or_null("P%dStamina" % player_id)
	if bar:
		bar.value = (stamina / max_stamina) * 100.0
