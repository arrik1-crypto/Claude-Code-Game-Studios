extends PlayerState

## Grounded whip swing, and the three-hit combo built on top of it.
##
## Each step runs windup -> active -> recovery. Pressing attack again during the
## active or recovery phase queues the next step; the chain resets if the window
## in `combo.chain_window` lapses. The player is rooted during a swing, which is
## the Castlevania commitment that makes positioning matter.

enum Phase { WINDUP, ACTIVE, RECOVERY }

var _step: int = 0
var _phase: Phase = Phase.WINDUP
var _phase_timer: float = 0.0
var _queued_next: bool = false
var _steps: Array = []


func enter(payload: Dictionary) -> void:
	var combo: Dictionary = Balance.section("combo")
	_steps = combo.get("steps", []) as Array
	if _steps.is_empty():
		push_error("AttackState: balance.json defines no combo steps")
		state_machine.transition_to(&"Idle", {})
		return

	_step = clampi(int(payload.get("step", 0)), 0, _steps.size() - 1)
	_queued_next = false
	player.velocity.x = 0.0

	var step_cfg: Dictionary = _steps[_step]
	player.play_animation(StringName(String(step_cfg.get("name", "attack_1"))))
	_enter_phase(Phase.WINDUP)


func exit() -> void:
	player.end_whip()


func _enter_phase(phase: Phase) -> void:
	_phase = phase
	var step_cfg: Dictionary = _steps[_step]
	match phase:
		Phase.WINDUP:
			_phase_timer = float(step_cfg.get("windup", 0.06))
		Phase.ACTIVE:
			_phase_timer = float(step_cfg.get("active", 0.1))
			player.begin_whip(float(step_cfg.get("multiplier", 1.0)))
			# The arc is drawn where the lash actually sweeps, so the visual and
			# the hitbox agree about the weapon's reach.
			var reach: float = GameState.weapon_reach()
			Vfx.whip_smear(
				player.effect_host(),
				player.global_position + Vector2(float(player.facing) * reach * 0.6, -18.0),
				player.facing, _step, reach)
		Phase.RECOVERY:
			_phase_timer = float(step_cfg.get("recovery", 0.16))
			player.end_whip()


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	# Rooted: bleed off horizontal speed rather than sliding through the swing.
	player.velocity.x = move_toward(
		player.velocity.x, 0.0,
		Balance.field(player.move_cfg, "groundFriction", 1600.0) * delta)

	# Queue the next combo step from the active phase onward.
	if _phase != Phase.WINDUP and player.just_pressed(&"attack"):
		_queued_next = true
	try_subweapon()

	# Getting knocked into the air cancels the swing.
	if not player.is_on_floor() and _phase == Phase.RECOVERY:
		state_machine.transition_to(&"Fall", {})
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
			_finish()


func _finish() -> void:
	if _queued_next and _step + 1 < _steps.size():
		state_machine.transition_to(&"Attack", {"step": _step + 1})
		return
	if try_dash():
		return
	if not player.is_on_floor():
		state_machine.transition_to(&"Fall", {})
	elif is_zero_approx(player.move_axis()):
		state_machine.transition_to(&"Idle", {})
	else:
		state_machine.transition_to(&"Run", {})
