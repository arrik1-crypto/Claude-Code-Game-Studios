extends EnemyBase

## Bone Sentry — a patrolling skeleton that throws bones.
##
## The workhorse enemy of the outer castle. Walks a platform, turns at ledges and
## walls, and once the player is in its firing arc it stops to throw. The wind-up
## is generous on purpose: it teaches the player to read tells before the harder
## rooms punish them for not doing so.

const PROJECTILE_SCENE: String = "res://src/gameplay/combat/projectile.tscn"

enum State { PATROL, AIM, THROW, RECOVER }

@onready var floor_probe: RayCast2D = $FloorProbe
@onready var wall_probe: RayCast2D = $WallProbe

var _state: State = State.PATROL
var _timer: float = 0.0
var _cooldown: float = 0.0


func _on_configured() -> void:
	# Stagger initial cooldowns so a row of sentries does not fire in lockstep.
	_cooldown = randf_range(0.0, float(config.get("attackCooldown", 1.9)))


func _tick_ai(delta: float) -> void:
	apply_gravity(delta)
	_cooldown = maxf(0.0, _cooldown - delta)

	match _state:
		State.PATROL:
			_tick_patrol(delta)
		State.AIM:
			_tick_timed(delta, State.THROW)
		State.THROW:
			_throw_bone()
		State.RECOVER:
			_tick_timed(delta, State.PATROL)


func _tick_patrol(_delta: float) -> void:
	velocity.x = float(facing) * float(config.get("moveSpeed", 34.0))
	play_animation(&"walk")
	_update_probes()

	if _should_turn():
		set_facing(-facing)
		_update_probes()

	if _cooldown <= 0.0 and _can_see_player():
		_state = State.AIM
		_timer = 0.35
		velocity.x = 0.0
		play_animation(&"attack")


func _tick_timed(delta: float, next: State) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	_timer -= delta
	if _timer <= 0.0:
		_state = next
		if next == State.PATROL:
			play_animation(&"walk")


## Turn at a wall, or at the edge of the platform when configured to do so.
func _should_turn() -> bool:
	if wall_probe.is_colliding():
		return true
	if bool(config.get("turnAtLedge", true)) and not floor_probe.is_colliding():
		return is_on_floor()
	return false


func _update_probes() -> void:
	floor_probe.position.x = absf(floor_probe.position.x) * float(facing)
	wall_probe.target_position.x = absf(wall_probe.target_position.x) * float(facing)
	floor_probe.force_raycast_update()
	wall_probe.force_raycast_update()


## The player must be in range, roughly level, and in front of the sentry.
func _can_see_player() -> bool:
	var p: Player = player()
	if p == null or p.is_dead():
		return false
	var delta: Vector2 = p.global_position - global_position
	if absf(delta.x) > float(config.get("attackRange", 116.0)):
		return false
	if absf(delta.y) > 64.0:
		return false
	return signf(delta.x) == float(facing)


func _throw_bone() -> void:
	_state = State.RECOVER
	_timer = 0.45
	_cooldown = float(config.get("attackCooldown", 1.9))

	var scene: PackedScene = load(PROJECTILE_SCENE) as PackedScene
	if scene == null or get_parent() == null:
		return

	var bone: Node = scene.instantiate()
	get_parent().add_child(bone)
	if bone.has_method("launch"):
		bone.launch({
			"config": {
				"speed": float(config.get("projectileSpeed", 118.0)),
				"lifetime": 3.0,
				"gravityScale": 0.25,
				"pierces": false,
				"knockbackHorizontal": 110.0,
				"knockbackVertical": 60.0,
			},
			"sprite_animation": "bone",
			"damage": int(config.get("attack", 8)),
			"direction": facing,
			"origin": global_position + Vector2(float(facing) * 18.0, -36.0),
			"attacker": self,
			"source": DamageInfo.Source.CONTACT,
			"target_layer": 2,  # "player"
		})
