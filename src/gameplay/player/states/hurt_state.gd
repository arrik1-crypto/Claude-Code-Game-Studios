extends PlayerState

## Reeling from a hit. Control is taken away for `hurt_lockout` seconds so that
## damage has weight, but the window is short enough that it never feels like the
## game is playing itself.

var _timer: float = 0.0


func enter(payload: Dictionary) -> void:
	_timer = Balance.field(player.move_cfg, "hurtLockout", 0.28)
	player.play_animation(&"hurt")
	player.end_whip()

	var info: DamageInfo = payload.get("info") as DamageInfo
	var horizontal: float = Balance.field(player.move_cfg, "knockbackHorizontal", 150.0)
	var vertical: float = Balance.field(player.move_cfg, "knockbackVertical", 130.0)
	var direction: float = 0.0

	if info != null:
		if info.knockback_horizontal > 0.0:
			horizontal = info.knockback_horizontal
		if info.knockback_vertical > 0.0:
			vertical = info.knockback_vertical
		direction = info.resolve_direction_towards(player.global_position)

	# Fall back to pushing the player backwards when the source has no position,
	# e.g. scripted damage.
	if is_zero_approx(direction):
		direction = float(-player.facing)

	player.velocity = CombatMath.knockback_impulse(direction, horizontal, vertical)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	# Keep some air drag so knockback decays rather than carrying the player
	# across the whole room.
	player.velocity.x = move_toward(
		player.velocity.x, 0.0,
		Balance.field(player.move_cfg, "airFriction", 320.0) * delta)

	_timer -= delta
	if _timer > 0.0:
		return

	if not player.is_on_floor():
		state_machine.transition_to(&"Fall", {})
	elif is_zero_approx(player.move_axis()):
		state_machine.transition_to(&"Idle", {})
	else:
		state_machine.transition_to(&"Run", {})
