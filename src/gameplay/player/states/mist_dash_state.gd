extends PlayerState

## Mist Dash — the first traversal relic.
##
## Grants three things at once, which is what makes it the pivotal unlock:
## horizontal distance, invulnerability frames, and passage through mist gates.
## Works on the ground and in the air, and does not consume the double jump.

var _timer: float = 0.0
var _direction: int = 1


func enter(_payload: Dictionary) -> void:
	# Dash the way the player is holding, or forward if there is no input.
	var axis: float = player.move_axis()
	_direction = int(signf(axis)) if not is_zero_approx(axis) else player.facing
	player.set_facing(_direction)

	_timer = Balance.field(player.move_cfg, "mistDashDuration", 0.18)
	player.velocity = Vector2(
		float(_direction) * Balance.field(player.move_cfg, "mistDashSpeed", 300.0),
		0.0)

	player.play_animation(&"dash")
	player.start_mist_cooldown()
	player.set_mist_intangible(true)
	player.spawn_vfx("mist", player.global_position + Vector2(0, -10))
	AudioDirector.play_sfx("dash")


func exit() -> void:
	player.set_mist_intangible(false)
	player.sprite.modulate.a = 1.0


func physics_update(delta: float) -> void:
	# No gravity during the dash: a flat trajectory is what makes gaps crossable.
	player.velocity.y = 0.0
	player.velocity.x = float(_direction) \
		* Balance.field(player.move_cfg, "mistDashSpeed", 300.0)
	player.sprite.modulate.a = 0.55

	_timer -= delta
	if _timer <= 0.0:
		if player.is_on_floor():
			state_machine.transition_to(&"Idle", {})
		else:
			state_machine.transition_to(&"Fall", {})
