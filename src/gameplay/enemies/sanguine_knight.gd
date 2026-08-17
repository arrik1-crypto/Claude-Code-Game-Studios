extends EnemyBase

## Sanguine Knight, Sir Kaelis — the wing boss.
##
## Three phases, each defined entirely in `balance.json`: as HP falls he moves
## faster, shortens his recovery and adds moves to his rotation. The pattern is a
## fixed cycle rather than random selection, because a readable, learnable
## sequence is what makes a boss feel fair when it finally kills you.
##
## Attacks:
##   slash  — committed overhead swing with a long tell and a wide arc.
##   charge — crosses the arena; the player is meant to jump it.
##   summon — spawns Nightwings, punishing players who camp a corner.

const NIGHTWING_SCENE: String = "res://src/gameplay/enemies/nightwing.tscn"

enum State { INTRO, IDLE, WINDUP, STRIKE, RECOVER, CHARGE, SUMMON, DEFEATED }

@onready var sword_hitbox: Hitbox = $SwordHitbox
@onready var sword_shape: CollisionShape2D = $SwordHitbox/CollisionShape2D

var _state: State = State.INTRO
var _timer: float = 0.0
var _pattern_index: int = 0
var _phase_index: int = -1
var _current_move: String = ""
var _charge_direction: int = -1
var _arena_bounds: Rect2 = Rect2()
var _summoned: Array[Node] = []


func _ready() -> void:
	stat_section = "bosses"
	enemy_id = "sanguine_knight"
	hurt_duration = 0.0  # A boss never staggers; only phase changes interrupt it.
	super()


func _on_configured() -> void:
	sword_hitbox.attacker = self
	sword_hitbox.deactivate()
	sword_hitbox.source = DamageInfo.Source.BOSS

	health.changed.connect(_on_health_changed)
	_state = State.INTRO
	_timer = 1.2
	play_animation(&"idle")

	EventBus.boss_encounter_started.emit(
		enemy_id,
		String(config.get("displayName", "Sanguine Knight")),
		health.max_hp)
	EventBus.boss_health_changed.emit(health.current_hp, health.max_hp)
	_refresh_phase()


## Called by the arena so the charge attack knows where the walls are.
func set_arena_bounds(bounds: Rect2) -> void:
	_arena_bounds = bounds


func _tick_ai(delta: float) -> void:
	apply_gravity(delta)
	_timer -= delta

	match _state:
		State.INTRO:
			velocity.x = 0.0
			if _timer <= 0.0:
				_begin_next_move()
		State.IDLE:
			_tick_approach(delta)
			if _timer <= 0.0:
				_begin_next_move()
		State.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			if _timer <= 0.0:
				# Both slash and charge share the wind-up state; the queued move
				# decides which one the tell resolves into.
				if _current_move == "charge":
					_start_charge_run()
				else:
					_begin_strike()
		State.STRIKE:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			if _timer <= 0.0:
				_begin_recover()
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if _timer <= 0.0:
				_enter_idle()
		State.CHARGE:
			_tick_charge(delta)
		State.SUMMON:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if _timer <= 0.0:
				_do_summon()
		State.DEFEATED:
			velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)


## Walk towards the player between attacks.
func _tick_approach(delta: float) -> void:
	var direction: int = direction_to_player()
	if direction != 0:
		set_facing(direction)
	var speed: float = _phase_value("moveSpeed", 42.0)
	# Stop closing once inside sword range so he does not shove the player.
	if distance_to_player() > 40.0:
		velocity.x = float(facing) * speed
		play_animation(&"walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		play_animation(&"idle")


func _enter_idle() -> void:
	_state = State.IDLE
	_timer = _phase_value("attackCooldown", 2.0)
	play_animation(&"idle")


func _begin_next_move() -> void:
	var pattern: Array = _phase_pattern()
	if pattern.is_empty():
		_enter_idle()
		return

	_current_move = String(pattern[_pattern_index % pattern.size()])
	_pattern_index += 1

	var direction: int = direction_to_player()
	if direction != 0:
		set_facing(direction)

	match _current_move:
		"charge":
			_begin_charge()
		"summon":
			_begin_summon()
		_:
			_begin_slash()


# -- Slash -------------------------------------------------------------------


func _begin_slash() -> void:
	var move: Dictionary = config.get("slash", {}) as Dictionary
	_state = State.WINDUP
	_timer = float(move.get("windup", 0.45))
	play_animation(&"attack")


func _begin_strike() -> void:
	var move: Dictionary = config.get("slash", {}) as Dictionary
	_state = State.STRIKE
	_timer = float(move.get("active", 0.18))

	var reach: float = float(move.get("reach", 46))
	var shape := sword_shape.shape as RectangleShape2D
	if shape != null:
		shape.size = Vector2(reach, 60.0)
	sword_shape.position = Vector2(float(facing) * (reach * 0.5 + 16.0), -38.0)

	sword_hitbox.knockback_horizontal = 190.0
	sword_hitbox.knockback_vertical = 150.0
	sword_hitbox.activate(_attack_damage(float(move.get("damageMultiplier", 1.0))))
	Vfx.boss_smear(
		get_parent(),
		global_position + Vector2(float(facing) * reach * 0.6, -40.0),
		facing, reach)
	EventBus.screen_shake_requested.emit(2.5, 0.15)


func _begin_recover() -> void:
	var move: Dictionary = config.get("slash", {}) as Dictionary
	sword_hitbox.deactivate()
	_state = State.RECOVER
	_timer = float(move.get("recovery", 0.5))
	play_animation(&"idle")


# -- Charge ------------------------------------------------------------------


func _begin_charge() -> void:
	var move: Dictionary = config.get("charge", {}) as Dictionary
	_state = State.WINDUP
	_timer = float(move.get("windup", 0.5))
	_charge_direction = direction_to_player()
	if _charge_direction == 0:
		_charge_direction = facing
	set_facing(_charge_direction)
	play_animation(&"attack")
	# Reuse the windup timer, then divert into CHARGE rather than STRIKE.
	_current_move = "charge"


func _tick_charge(_delta: float) -> void:
	var move: Dictionary = config.get("charge", {}) as Dictionary
	velocity.x = float(_charge_direction) * float(move.get("speed", 210.0))
	play_animation(&"charge")

	var hit_wall: bool = is_on_wall()
	if _arena_bounds.size.x > 0.0:
		if global_position.x <= _arena_bounds.position.x + 12.0 and _charge_direction < 0:
			hit_wall = true
		elif global_position.x >= _arena_bounds.end.x - 12.0 and _charge_direction > 0:
			hit_wall = true

	if hit_wall or _timer <= 0.0:
		sword_hitbox.deactivate()
		_state = State.RECOVER
		_timer = float(move.get("recovery", 0.7))
		velocity.x = 0.0
		if hit_wall:
			# Slamming into the wall is the player's window to punish him.
			EventBus.screen_shake_requested.emit(6.0, 0.3)
			_timer += 0.35
		play_animation(&"idle")


func _start_charge_run() -> void:
	var move: Dictionary = config.get("charge", {}) as Dictionary
	_state = State.CHARGE
	_timer = float(move.get("duration", 0.9))

	var shape := sword_shape.shape as RectangleShape2D
	if shape != null:
		shape.size = Vector2(70.0, 76.0)
	sword_shape.position = Vector2(float(_charge_direction) * 40.0, -42.0)

	sword_hitbox.knockback_horizontal = 220.0
	sword_hitbox.knockback_vertical = 120.0
	sword_hitbox.activate(_attack_damage(float(move.get("damageMultiplier", 1.25))))


# -- Summon ------------------------------------------------------------------


func _begin_summon() -> void:
	var move: Dictionary = config.get("summon", {}) as Dictionary
	_state = State.SUMMON
	_timer = float(move.get("windup", 0.6))
	play_animation(&"summon")


func _do_summon() -> void:
	var move: Dictionary = config.get("summon", {}) as Dictionary
	var scene: PackedScene = load(NIGHTWING_SCENE) as PackedScene
	var host: Node = get_parent()

	_summoned = _summoned.filter(func(n: Node) -> bool: return is_instance_valid(n))

	if scene != null and host != null:
		var count: int = int(move.get("count", 2))
		for i: int in range(count):
			var bat: Node = scene.instantiate()
			host.add_child(bat)
			if bat is Node2D:
				var spread: float = float(i) * 28.0 - float(count - 1) * 14.0
				(bat as Node2D).global_position = global_position + Vector2(spread, -92.0)
			_summoned.append(bat)

	_state = State.RECOVER
	_timer = float(move.get("recovery", 0.8))
	play_animation(&"idle")


# -- Phases ------------------------------------------------------------------


func _phases() -> Array:
	return config.get("phases", []) as Array


## Index of the phase matching the current HP fraction. Phases are listed from
## healthiest to most desperate.
func _resolve_phase_index() -> int:
	var fraction: float = health.health_fraction()
	var phases: Array = _phases()
	var index: int = 0
	for i: int in range(phases.size()):
		var threshold: float = float((phases[i] as Dictionary).get("hpThreshold", 1.0))
		if fraction <= threshold:
			index = i
	return index


func _refresh_phase() -> void:
	var index: int = _resolve_phase_index()
	if index == _phase_index:
		return
	_phase_index = index
	_pattern_index = 0
	if _phase_index > 0:
		# A brief flare and shake announces the escalation.
		EventBus.screen_shake_requested.emit(4.0, 0.35)
		_flash()


func _current_phase() -> Dictionary:
	var phases: Array = _phases()
	if phases.is_empty():
		return {}
	return phases[clampi(_phase_index, 0, phases.size() - 1)] as Dictionary


func _phase_value(key: String, fallback: float) -> float:
	return float(_current_phase().get(key, config.get(key, fallback)))


func _phase_pattern() -> Array:
	return _current_phase().get("pattern", ["slash"]) as Array


func _attack_damage(multiplier: float) -> int:
	var power: float = CombatMath.attack_power(int(config.get("attack", 16)), 0, multiplier)
	return CombatMath.compute_damage(power, 0)


# -- Damage and death --------------------------------------------------------


func _on_health_changed(current: int, maximum: int) -> void:
	EventBus.boss_health_changed.emit(current, maximum)
	if not is_dying():
		_refresh_phase()


func _on_damaged(_amount: int, info: DamageInfo) -> void:
	# Skip EnemyBase's knockback and stagger entirely; only the flash and spark.
	if is_dying():
		return
	AudioDirector.play_sfx("boss_hit", -2.0)
	var impact_at: Vector2 = info.impact_position if info != null else global_position
	Vfx.hit_spark(get_parent(), impact_at)
	Vfx.impact(get_parent(), impact_at, Vfx.TINT_STEEL)
	_flash()


func _on_died() -> void:
	_state = State.DEFEATED
	sword_hitbox.deactivate()
	GameState.set_flag("boss_sanguine_knight_defeated", true)
	EventBus.boss_encounter_ended.emit(enemy_id, true)
	EventBus.screen_shake_requested.emit(8.0, 0.8)

	for bat: Node in _summoned:
		if is_instance_valid(bat) and bat.has_method("queue_free"):
			bat.queue_free()

	super()


func death_lingering_time() -> float:
	return 2.4
