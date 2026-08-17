extends PlayerState

## Moving along the ground.


func enter(_payload: Dictionary) -> void:
	player.play_animation(&"run")


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal_movement(delta, true)

	if try_attack() or try_dash():
		return
	try_subweapon()
	if try_jump():
		return
	if try_fall_off_ledge():
		return

	if Input.is_action_pressed(&"move_down"):
		state_machine.transition_to(&"Crouch", {})
		return
	# Fall back to Idle only once the character has actually stopped, so a quick
	# direction reversal does not flicker through the idle pose.
	if is_zero_approx(player.move_axis()) and absf(player.velocity.x) < 4.0:
		state_machine.transition_to(&"Idle", {})
