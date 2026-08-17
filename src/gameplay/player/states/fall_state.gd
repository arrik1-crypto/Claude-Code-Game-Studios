extends PlayerState

## Descending. Also the state entered when walking off a ledge, in which case the
## coyote window is still live and a jump is briefly allowed.


func enter(payload: Dictionary) -> void:
	player.play_animation(&"fall")
	# Walking off a ledge keeps the double jump; using it mid-air already
	# consumed it in JumpState.
	if bool(payload.get("from_ledge", false)):
		player.double_jump_available = GameState.has_ability(GameState.ABILITY_DOUBLE_JUMP)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal_movement(delta, false)

	if try_attack() or try_dash():
		return
	try_subweapon()
	if try_jump():
		return

	if player.is_on_floor():
		AudioDirector.play_sfx("land", -6.0)
		Vfx.land_dust(player.effect_host(), player.feet_position(), player.last_fall_speed())
		if is_zero_approx(player.move_axis()):
			state_machine.transition_to(&"Idle", {})
		else:
			state_machine.transition_to(&"Run", {})
