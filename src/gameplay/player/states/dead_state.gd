extends PlayerState

## Terminal state. Plays the collapse, holds for a beat so the death registers,
## then hands off to [SceneDirector] for the game-over flow.

const HOLD_AFTER_ANIMATION: float = 1.1

var _timer: float = 0.0
var _handed_off: bool = false


func enter(_payload: Dictionary) -> void:
	_handed_off = false
	_timer = HOLD_AFTER_ANIMATION
	player.play_animation(&"dead")
	player.velocity = Vector2(0.0, -120.0)
	player.sprite.modulate.a = 1.0
	EventBus.screen_shake_requested.emit(5.0, 0.4)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 400.0 * delta)

	if _handed_off:
		return
	_timer -= delta
	if _timer <= 0.0:
		_handed_off = true
		player.death_finished.emit()
		SceneDirector.game_over()
