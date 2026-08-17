extends PlayerState

## The starting evasive move: a short hop backwards with no invulnerability.
##
## Deliberately weaker than the Mist Dash it is eventually replaced by — it
## repositions but does not let you pass through anything, so the Mist Dash
## relic still feels like a real upgrade.

var _timer: float = 0.0
var _direction: int = 1


func enter(_payload: Dictionary) -> void:
	_direction = -player.facing
	_timer = Balance.field(player.move_cfg, "backdashDuration", 0.22)
	player.velocity = Vector2(
		float(_direction) * Balance.field(player.move_cfg, "backdashSpeed", 240.0),
		0.0)
	player.play_animation(&"dash")
	player.start_backdash_cooldown()
	AudioDirector.play_sfx("dash", -4.0)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta, 0.4)

	# Ease out so the dash ends with a settle rather than a hard stop.
	_timer -= delta
	var remaining: float = maxf(0.0, _timer / maxf(0.001,
		Balance.field(player.move_cfg, "backdashDuration", 0.22)))
	player.velocity.x = float(_direction) \
		* Balance.field(player.move_cfg, "backdashSpeed", 240.0) \
		* ease(remaining, 0.4)

	# Attacking out of a backdash is the intended spacing tool.
	if try_attack():
		return

	if _timer <= 0.0:
		if not player.is_on_floor():
			state_machine.transition_to(&"Fall", {})
		else:
			state_machine.transition_to(&"Idle", {})
