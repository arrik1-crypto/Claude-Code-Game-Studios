extends EnemyBase

## Cellar Slime — a hopping blob that closes distance in arcs.
##
## Uses the asset pack's slime art. Mechanically it is the counterpoint to the
## Gravewalker: low HP and low damage, but it moves in unpredictable hops rather
## than a straight line, so it cannot be spaced with the same rhythm.
##
## The hop is driven by a timer rather than by an animation event, so the AI
## stays readable and does not depend on frame timings in the imported sheet.

enum State { GROUNDED, HOPPING }

@export var hop_interval: float = 1.3
@export var hop_velocity: float = -190.0
@export var hop_horizontal: float = 62.0

var _state: State = State.GROUNDED
var _timer: float = 0.0


## The imported sheet keeps the pack's filename, which does not match the
## enemy id, so the default id-derived path is overridden.
func sprite_sheet_path() -> String:
	return "res://assets/art/characters/slime.png"


func _on_configured() -> void:
	# Desynchronise a group of slimes so they do not hop in formation.
	_timer = randf_range(0.0, hop_interval)
	play_animation(&"idle")


func _tick_ai(delta: float) -> void:
	apply_gravity(delta)

	match _state:
		State.GROUNDED:
			_tick_grounded(delta)
		State.HOPPING:
			_tick_hopping(delta)


func _tick_grounded(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	play_animation(&"idle")

	if not is_on_floor():
		return

	_timer -= delta
	if _timer > 0.0:
		return

	_timer = hop_interval
	if player_in_aggro_range():
		_begin_hop(direction_to_player())
	else:
		# Idle slimes still shuffle, so a room never looks frozen.
		_begin_hop(facing if randf() < 0.7 else -facing)


func _begin_hop(direction: int) -> void:
	if direction == 0:
		direction = facing
	set_facing(direction)
	_state = State.HOPPING
	velocity = Vector2(float(direction) * hop_horizontal, hop_velocity)
	play_animation(&"walk")


func _tick_hopping(_delta: float) -> void:
	# Turn around rather than grinding against a wall mid-hop.
	if is_on_wall():
		velocity.x = -velocity.x
		set_facing(-facing)

	if is_on_floor() and velocity.y >= 0.0:
		_state = State.GROUNDED
		velocity.x = 0.0
		play_animation(&"idle")


## A slime knocked back mid-hop keeps its arc; it is mostly liquid.
func knockback_resistance() -> float:
	return 1.2


func death_lingering_time() -> float:
	# Long enough for the pack's six-frame burst animation to finish.
	return 0.55
