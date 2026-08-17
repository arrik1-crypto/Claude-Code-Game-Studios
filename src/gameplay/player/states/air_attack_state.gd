extends PlayerState

## Whip swing performed in the air. Single hit, no combo, and the player keeps
## full air control so the swing never costs a landing.

enum Phase { WINDUP, ACTIVE, RECOVERY }

var _phase: Phase = Phase.WINDUP
var _phase_timer: float = 0.0
var _cfg: Dictionary = {}


func enter(_payload: Dictionary) -> void:
	_cfg = Balance.section("combo").get("airAttack", {}) as Dictionary
	player.play_animation(&"air_attack")
	_enter_phase(Phase.WINDUP)


func exit() -> void:
	player.end_whip()


func _enter_phase(phase: Phase) -> void:
	_phase = phase
	match phase:
		Phase.WINDUP:
			_phase_timer = float(_cfg.get("windup", 0.05))
		Phase.ACTIVE:
			_phase_timer = float(_cfg.get("active", 0.12))
			player.begin_whip(float(_cfg.get("multiplier", 1.1)))
			var reach: float = GameState.weapon_reach()
			Vfx.whip_smear(
				player.effect_host(),
				player.global_position + Vector2(float(player.facing) * reach * 0.6, -18.0),
				player.facing, 0, reach)
		Phase.RECOVERY:
			_phase_timer = float(_cfg.get("recovery", 0.14))
			player.end_whip()


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.apply_horizontal_movement(delta, false)
	try_subweapon()

	if player.is_on_floor():
		player.end_whip()
		state_machine.transition_to(&"Idle", {})
		return

	_phase_timer -= delta
	if _phase_timer > 0.0:
		return

	match _phase:
		Phase.WINDUP:
			_enter_phase(Phase.ACTIVE)
		Phase.ACTIVE:
			_enter_phase(Phase.RECOVERY)
		Phase.RECOVERY:
			state_machine.transition_to(&"Fall", {})
