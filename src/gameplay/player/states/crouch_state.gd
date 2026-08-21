extends PlayerState

## Ducking. Halves the hurtbox height so the player can slip under Medusa Heads,
## and is the gateway to dropping through one-way platforms.


func enter(_payload: Dictionary) -> void:
	player.play_animation(&"crouch")
	player.set_crouching(true)


func exit() -> void:
	player.set_crouching(false)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	# Crouching pins the player in place; balance.json keeps the multiplier at 0
	# so this reads as a deliberate stance rather than a slow walk.
	var crouch_speed: float = Balance.field(player.move_cfg, "crouchSpeedMultiplier", 0.0)
	if is_zero_approx(crouch_speed):
		player.velocity.x = move_toward(
			player.velocity.x, 0.0,
			Balance.field(player.move_cfg, "groundFriction", 1600.0) * delta)
	else:
		player.velocity.x = player.move_axis() \
			* Balance.field(player.move_cfg, "runSpeed", 118.0) * crouch_speed

	if try_attack():
		return
	try_subweapon()

	# Down + jump drops through a one-way platform instead of jumping.
	if player.wants_jump():
		player.consume_jump_input()
		if player.is_standing_on_one_way():
			player.start_drop_through()
			state_machine.transition_to(&"Fall", {"from_ledge": true})
		else:
			state_machine.transition_to(&"Jump", {"double": false})
		return

	if try_dash():
		return
	if try_fall_off_ledge():
		return

	if not player.wants(&"move_down"):
		state_machine.transition_to(&"Idle", {})
