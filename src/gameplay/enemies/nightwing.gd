extends EnemyBase

## Nightwing — a roosting bat that drops and swoops.
##
## Hangs asleep until the player comes near, then wakes and pursues in a lazy
## sine-weighted arc. Fragile, but it attacks from angles ground enemies cannot,
## which is what makes it dangerous over pits.

enum State { ROOST, WAKE, PURSUE }

var _state: State = State.ROOST
var _timer: float = 0.0
var _roost_position: Vector2 = Vector2.ZERO


func _on_configured() -> void:
	_roost_position = global_position
	play_animation(&"idle")
	# Bats ignore gravity entirely; all vertical motion is scripted.
	velocity = Vector2.ZERO


func _tick_ai(delta: float) -> void:
	match _state:
		State.ROOST:
			_tick_roost()
		State.WAKE:
			_tick_wake(delta)
		State.PURSUE:
			_tick_pursue(delta)


func _tick_roost() -> void:
	velocity = Vector2.ZERO
	global_position = _roost_position
	play_animation(&"idle")
	if player_in_aggro_range():
		_state = State.WAKE
		_timer = 0.25
		play_animation(&"fly")


## A short drop before the wings catch — sells the wake-up.
func _tick_wake(delta: float) -> void:
	velocity = Vector2(0.0, 60.0)
	_timer -= delta
	if _timer <= 0.0:
		_state = State.PURSUE


func _tick_pursue(_delta: float) -> void:
	var p: Player = player()
	if p == null or p.is_dead():
		velocity = velocity.move_toward(Vector2.ZERO, 4.0)
		return

	play_animation(&"fly")
	var to_player: Vector2 = p.global_position + Vector2(0, -28) - global_position
	var speed: float = float(config.get("moveSpeed", 62.0))

	# Hover offset: a vertical sine on top of the pursuit vector, so the bat
	# weaves instead of homing in a straight and easily-whipped line.
	var amplitude: float = float(config.get("hoverAmplitude", 16.0))
	var frequency: float = float(config.get("hoverFrequency", 2.4))
	var weave: float = sin(lifetime() * frequency) * amplitude

	var desired: Vector2 = to_player.normalized() * speed + Vector2(0.0, weave)
	velocity = velocity.lerp(desired, 0.08)

	if not is_zero_approx(velocity.x):
		set_facing(int(signf(velocity.x)))


## Bats stay airborne when hit rather than dropping like a ground enemy.
func _tick_stagger(_delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, 0.2)


func _tick_death(delta: float) -> void:
	# Gravity only applies once it is dead — the corpse tumbles.
	apply_gravity(delta, 0.6)
	velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)


func knockback_resistance() -> float:
	return 1.4
