extends EnemyBase

## Medusa Head — a stone head that drifts across the room in a sine wave.
##
## The genre's oldest and most hated hazard, and it earns its place: it ignores
## geometry, dies to one hit, and exists purely to knock the player off a ledge
## mid-jump. Spawned in streams by [MedusaSpawner] rather than placed by hand.

## Horizontal travel direction, set by the spawner before the node enters the tree.
var travel_direction: int = -1

var _origin_y: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	# Radially symmetric art: flipping it would be a no-op that costs a draw
	# state change, so opt out before EnemyBase applies facing.
	flip_sprite_with_facing = false
	super()


func _on_configured() -> void:
	_origin_y = global_position.y
	_phase = randf() * TAU
	play_animation(&"fly")
	set_facing(travel_direction)


func _tick_ai(delta: float) -> void:
	var speed: float = float(config.get("moveSpeed", 54.0))
	var amplitude: float = float(config.get("waveAmplitude", 26.0))
	var frequency: float = float(config.get("waveFrequency", 2.9))

	# Position is driven directly rather than through velocity so the wave stays
	# exact regardless of collisions — these pass through everything.
	global_position.x += float(travel_direction) * speed * delta
	global_position.y = _origin_y + sin(lifetime() * frequency + _phase) * amplitude
	velocity = Vector2.ZERO


## Never staggers — a flinch would break the wave and make it trivial to dodge.
func _tick_stagger(delta: float) -> void:
	_tick_ai(delta)


func _tick_death(delta: float) -> void:
	apply_gravity(delta, 0.8)


func death_lingering_time() -> float:
	return 0.35
