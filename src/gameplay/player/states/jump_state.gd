extends PlayerState

## Rising. Handles both the ground jump and the unlocked double jump.
##
## Jump height is variable: releasing the button early cuts the remaining upward
## velocity by `jump_cut_multiplier`, which is what lets a Metroidvania have both
## precise short hops and full-height leaps on one button.

var _is_double: bool = false


func enter(payload: Dictionary) -> void:
	_is_double = bool(payload.get("double", false))

	if _is_double:
		player.velocity.y = Balance.field(player.move_cfg, "doubleJumpVelocity", -236.0)
		player.consume_double_jump()
		# The mist flourish makes the second jump legible at a glance.
		player.spawn_vfx("mist", player.global_position + Vector2(0, -8))
		Vfx.jump_dust(player.effect_host(), player.global_position + Vector2(0, -6))
	else:
		player.velocity.y = Balance.field(player.move_cfg, "jumpVelocity", -268.0)
		player.clear_coyote_time()
		Vfx.jump_dust(player.effect_host(), player.feet_position())

	player.play_animation(&"jump")
	AudioDirector.play_sfx("jump")


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal_movement(delta, false)

	# Variable jump height.
	if not Input.is_action_pressed(&"jump") and player.velocity.y < 0.0:
		player.velocity.y *= Balance.field(player.move_cfg, "jumpCutMultiplier", 0.42)

	if try_attack() or try_dash():
		return
	try_subweapon()
	if try_jump():
		return

	if player.velocity.y >= 0.0:
		state_machine.transition_to(&"Fall", {})
