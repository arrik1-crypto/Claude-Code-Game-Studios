extends EnemyBase

## Gravewalker — a slow, heavy corpse that walks straight at the player.
##
## Deliberately the simplest AI in the game: no ranged attack, no ledge sense, it
## just closes distance. Its threat comes from HP and armour — it survives a full
## whip combo, so it forces the player to back up and re-space rather than
## trading hits.

@onready var wall_probe: RayCast2D = $WallProbe

var _idle_until: float = 0.0


func _on_configured() -> void:
	play_animation(&"idle")


func _tick_ai(delta: float) -> void:
	apply_gravity(delta)

	if not player_in_aggro_range():
		velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
		play_animation(&"idle")
		return

	var direction: int = direction_to_player()
	if direction != 0:
		set_facing(direction)

	# Walk into walls rather than turning: a Gravewalker pinned on geometry is a
	# free kill, and that is a fair reward for good positioning.
	wall_probe.target_position.x = absf(wall_probe.target_position.x) * float(facing)
	wall_probe.force_raycast_update()

	if wall_probe.is_colliding():
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		play_animation(&"idle")
		return

	velocity.x = float(facing) * float(config.get("moveSpeed", 20.0))
	play_animation(&"walk")


## Armoured and heavy: barely flinches.
func knockback_resistance() -> float:
	return 0.35


func death_lingering_time() -> float:
	return 0.8
