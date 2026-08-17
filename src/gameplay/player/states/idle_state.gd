extends PlayerState

## Standing still on solid ground.


func enter(_payload: Dictionary) -> void:
	player.play_animation(&"idle")


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
	if not is_zero_approx(player.move_axis()):
		state_machine.transition_to(&"Run", {})
