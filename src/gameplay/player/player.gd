class_name Player
extends CharacterBody2D

## Seraphine Valcourt — the player character.
##
## This node is the *context* for the state machine: it owns physics, timers,
## facing, the whip hitbox and the link to [GameState]. States under
## `StateMachine` read and drive it but hold no persistent data of their own.
##
## All tuning comes from `assets/data/balance.json` via the [Balance] autoload —
## see design/gdd/traversal-moveset.md for what each number is for.

## Imported at native resolution from the Metroidvania asset pack by
## tools/asset-pipeline/import_pack_assets.py. Frames are 80x80 in a 16-column
## grid; the 38x56 character's feet sit on the last row of the frame.
const SPRITE_SHEET: String = "res://assets/art/characters/hero.png"
const PROJECTILE_SCENE: String = "res://src/gameplay/combat/projectile.tscn"
const VFX_SCENE: String = "res://src/gameplay/vfx/effect.tscn"

## Physics layer index (1-based, as used by set_collision_mask_value) for
## drop-through platforms. Matches "one_way" in project.godot.
const ONE_WAY_PHYSICS_LAYER: int = 8
## Node group applied to platform TileMapLayers by the room builder.
const ONE_WAY_GROUP: StringName = &"one_way_platform"
## Node group applied to mist-gate barriers.
const MIST_GATE_GROUP: StringName = &"mist_gates"

## Seconds of ignoring one-way platforms after a deliberate drop-through.
const DROP_THROUGH_TIME: float = 0.28

## Hurtbox heights for a 56px-tall character. Crouching roughly halves it so
## Medusa Heads pass over — see design/gdd/traversal-moveset.md 3.3.
const STAND_HURTBOX_HEIGHT: float = 44.0
const CROUCH_HURTBOX_HEIGHT: float = 24.0

## The whip sweeps at chest height and is tall enough to clip a crouching enemy
## without reaching anything directly overhead.
const WHIP_HITBOX_HEIGHT: float = 26.0
const WHIP_HITBOX_CENTRE_Y: float = -26.0

## Personal light. Cool and dim — it reveals the player's footing without
## competing with the warm torchlight that marks the room's landmarks.
const LANTERN_COLOR: Color = Color(0.74, 0.80, 1.0)
const LANTERN_ENERGY: float = 0.85
const LANTERN_SCALE: float = 3.4

## Emitted when the player finishes dying, after the death animation.
signal death_finished()

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var whip_hitbox: Hitbox = $WhipHitbox
@onready var whip_shape: CollisionShape2D = $WhipHitbox/CollisionShape2D
@onready var pickup_collector: Area2D = $PickupCollector
@onready var state_machine: StateMachine = $StateMachine

## -1 for left, 1 for right. Drives sprite flipping and whip placement.
var facing: int = 1

## Consumed by Jump; reset on landing.
var double_jump_available: bool = false

## Movement tuning, cached from balance.json on ready.
var move_cfg: Dictionary = {}

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _backdash_cooldown: float = 0.0
var _mist_cooldown: float = 0.0
var _invulnerable_timer: float = 0.0
var _flash_timer: float = 0.0

var _active_projectiles: Dictionary = {}
var _dead: bool = false
var _control_enabled: bool = true

## Downward speed on the last airborne frame. Sampled before `move_and_slide`
## zeroes it on contact, so the landing effect can scale with the impact.
var _last_fall_speed: float = 0.0
## Distance run since the last footfall puff.
var _run_dust_accumulator: float = 0.0


func _ready() -> void:
	move_cfg = Balance.section("movement")

	if not SpriteSheetLoader.apply(sprite, SPRITE_SHEET, "idle"):
		push_error("Player: could not load sprite sheet %s" % SPRITE_SHEET)
	SpriteFx.attach(sprite)

	health.setup(GameState.max_hp, GameState.current_hp)
	health.changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	hurtbox.hit_taken.connect(_on_hit_taken)
	pickup_collector.area_entered.connect(_on_pickup_area_entered)

	# Announce initial values so a freshly built HUD is correct without polling.
	EventBus.player_health_changed.emit(GameState.current_hp, GameState.max_hp)
	EventBus.player_mp_changed.emit(GameState.current_mp, GameState.max_mp)
	EventBus.player_hearts_changed.emit(GameState.hearts, GameState.max_hearts)
	EventBus.player_gold_changed.emit(GameState.gold)

	whip_hitbox.attacker = self
	whip_hitbox.deactivate()
	_position_whip()
	_add_lantern()

	# Last, once every `@onready` reference above is live. Entering the first
	# state calls straight back into this node to set an animation, so the
	# machine cannot be allowed to start itself during its own `_ready`.
	state_machine.start()


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_regenerate_mp(delta)

	if _control_enabled:
		state_machine.physics_update(delta)

	if not is_on_floor():
		_last_fall_speed = maxf(0.0, velocity.y)

	move_and_slide()

	if is_on_floor():
		_coyote_timer = Balance.field(move_cfg, "coyoteTime", 0.1)
		double_jump_available = GameState.has_ability(GameState.ABILITY_DOUBLE_JUMP)

	_update_flash(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _control_enabled:
		return
	if event.is_action_pressed(&"jump"):
		_jump_buffer_timer = Balance.field(move_cfg, "jumpBufferTime", 0.12)
	state_machine.handle_input(event)


func _tick_timers(delta: float) -> void:
	_coyote_timer = maxf(0.0, _coyote_timer - delta)
	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	_backdash_cooldown = maxf(0.0, _backdash_cooldown - delta)
	_mist_cooldown = maxf(0.0, _mist_cooldown - delta)
	if _invulnerable_timer > 0.0:
		_invulnerable_timer = maxf(0.0, _invulnerable_timer - delta)
		if is_zero_approx(_invulnerable_timer):
			sprite.modulate.a = 1.0


func _regenerate_mp(delta: float) -> void:
	var rate: float = float(Balance.section("player").get("mpRegenPerSecond", 0.0))
	if rate > 0.0 and GameState.current_mp < GameState.max_mp:
		GameState.set_mp(GameState.current_mp + rate * delta)


## Give the player a soft personal light.
##
## Two jobs: it guarantees the character is never lost against a dark room —
## which on a phone screen in daylight is a real failure mode, not a stylistic
## one — and it is the only light permitted to cast shadows, so the castle gets
## moving shadows without paying for them per torch.
func _add_lantern() -> void:
	var lantern: PointLight2D = LightingQuality.make_light(
		LANTERN_COLOR, LANTERN_ENERGY, LANTERN_SCALE, true)
	if lantern == null:
		return
	lantern.position = Vector2(0, -30)
	add_child(lantern)


# -- Movement helpers used by states ----------------------------------------


## Horizontal input axis in -1..1.
func move_axis() -> float:
	return Input.get_axis(&"move_left", &"move_right")


## Apply gravity, clamped to terminal velocity.
func apply_gravity(delta: float, scale: float = 1.0) -> void:
	var gravity: float = Balance.field(move_cfg, "gravity", 900.0) * scale
	var max_fall: float = Balance.field(move_cfg, "maxFallSpeed", 420.0)
	velocity.y = minf(velocity.y + gravity * delta, max_fall)


## Accelerate towards the input direction, or decelerate to a stop.
func apply_horizontal_movement(delta: float, grounded: bool) -> void:
	var axis: float = move_axis()
	var speed: float = Balance.field(move_cfg, "runSpeed", 118.0) if grounded \
		else Balance.field(move_cfg, "airControlSpeed", 104.0)
	var accel: float = Balance.field(move_cfg, "groundAcceleration", 1400.0) if grounded \
		else Balance.field(move_cfg, "airAcceleration", 900.0)
	var friction: float = Balance.field(move_cfg, "groundFriction", 1600.0) if grounded \
		else Balance.field(move_cfg, "airFriction", 320.0)

	if is_zero_approx(axis):
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	else:
		velocity.x = move_toward(velocity.x, axis * speed, accel * delta)
		set_facing(int(signf(axis)))


func set_facing(direction: int) -> void:
	if direction == 0 or direction == facing:
		return
	facing = direction
	sprite.flip_h = facing < 0
	_position_whip()


func _position_whip() -> void:
	# The whip reaches out in front of the character; the hitbox is a wide, short
	# rectangle so it clips low enemies without hitting things above the player.
	var reach: float = GameState.weapon_reach()
	var shape := whip_shape.shape as RectangleShape2D
	if shape != null:
		shape.size = Vector2(reach, WHIP_HITBOX_HEIGHT)
	whip_shape.position = Vector2(
		float(facing) * (reach * 0.5 + 8.0), WHIP_HITBOX_CENTRE_Y)


# -- Jump gating -------------------------------------------------------------


func wants_jump() -> bool:
	return _jump_buffer_timer > 0.0


func consume_jump_input() -> void:
	_jump_buffer_timer = 0.0


## Grounded jumps are allowed for a short window after walking off a ledge.
func can_ground_jump() -> bool:
	return is_on_floor() or _coyote_timer > 0.0


func can_double_jump() -> bool:
	return double_jump_available and GameState.has_ability(GameState.ABILITY_DOUBLE_JUMP)


func consume_double_jump() -> void:
	double_jump_available = false


func clear_coyote_time() -> void:
	_coyote_timer = 0.0


func can_backdash() -> bool:
	return is_zero_approx(_backdash_cooldown)


func start_backdash_cooldown() -> void:
	_backdash_cooldown = Balance.field(move_cfg, "backdashCooldown", 0.35)


func can_mist_dash() -> bool:
	return is_zero_approx(_mist_cooldown)


func start_mist_cooldown() -> void:
	_mist_cooldown = Balance.field(move_cfg, "mistDashCooldown", 0.55)


## True while the player is intangible and passing through mist gates.
func is_misting() -> bool:
	return state_machine.is_state(&"MistDash")


# -- Presentation ------------------------------------------------------------


## Play an animation, ignoring redundant restarts so looping anims stay smooth.
func play_animation(anim: StringName) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim):
		return
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


func animation_finished() -> bool:
	return not sprite.is_playing()


# -- Attacks -----------------------------------------------------------------


## Switch the whip hitbox on for the current combo step.
func begin_whip(combo_multiplier: float) -> void:
	var power: float = CombatMath.attack_power(
		GameState.strength, GameState.weapon_attack(), combo_multiplier)
	var crit_chance: float = CombatMath.critical_chance(
		GameState.luck, float(Balance.section("player").get("baseCritChance", 0.02)))
	var critical: bool = randf() < crit_chance
	# Defence is applied by the victim's own stats, so pass 0 here and let the
	# enemy's Hurtbox multiplier and defence handle mitigation at receive time.
	var damage: int = CombatMath.compute_damage(
		power, 0, 1.0, critical,
		float(Balance.section("player").get("criticalMultiplier", 2.0)))

	whip_hitbox.knockback_horizontal = 130.0
	whip_hitbox.knockback_vertical = 60.0
	whip_hitbox.source = DamageInfo.Source.MELEE
	whip_hitbox.activate(damage, critical)
	AudioDirector.play_sfx("whip")


func end_whip() -> void:
	whip_hitbox.deactivate()


## Throw the equipped sub-weapon. Returns false when none is equipped, the
## player cannot afford it, or the on-screen limit is reached.
func throw_subweapon() -> bool:
	var id: String = GameState.equipped_subweapon
	if id == "":
		return false

	var cfg: Dictionary = Balance.entry("subweapons", id)
	if cfg.is_empty():
		return false

	_prune_projectiles()
	var max_active: int = int(cfg.get("maxActive", 2))
	if _active_projectiles.size() >= max_active:
		return false

	var cost: int = int(cfg.get("heartCost", 1))
	if not GameState.try_spend_hearts(cost):
		return false

	var scene: PackedScene = load(PROJECTILE_SCENE) as PackedScene
	if scene == null:
		push_error("Player: missing projectile scene %s" % PROJECTILE_SCENE)
		return false

	var projectile: Node = scene.instantiate()
	get_tree().current_scene.add_child(projectile)

	var power: float = CombatMath.attack_power(
		GameState.strength, GameState.weapon_attack(),
		float(cfg.get("damageMultiplier", 1.0)))
	var damage: int = CombatMath.compute_damage(power, 0)

	if projectile.has_method("launch"):
		projectile.launch({
			"config": cfg,
			"sprite_animation": id,
			"damage": damage,
			"direction": facing,
			"origin": global_position + Vector2(float(facing) * 14.0, -30.0),
			"attacker": self,
			"source": DamageInfo.Source.SUBWEAPON,
			"target_layer": 4,  # "enemy"
		})

	_active_projectiles[projectile.get_instance_id()] = projectile
	AudioDirector.play_sfx("subweapon")
	return true


func _prune_projectiles() -> void:
	for id: int in _active_projectiles.keys():
		if not is_instance_valid(_active_projectiles[id]):
			_active_projectiles.erase(id)


# -- Damage ------------------------------------------------------------------


func _on_hit_taken(info: DamageInfo, _damage: int) -> void:
	if _dead:
		return
	var iframes: float = Balance.field(move_cfg, "invulnerabilityTime", 0.85)
	_invulnerable_timer = iframes
	hurtbox.grant_invulnerability(iframes)
	AudioDirector.play_sfx("player_hurt")
	SpriteFx.flash(sprite, Color(1.0, 0.45, 0.5))
	Vfx.blood(effect_host(), global_position + Vector2(0, -30))
	EventBus.screen_shake_requested.emit(3.0, 0.18)
	EventBus.hit_stop_requested.emit(0.06)

	if not _dead:
		state_machine.transition_to(&"Hurt", {"info": info})


func _on_health_changed(current: int, _maximum: int) -> void:
	# Health is the runtime authority; GameState is the persisted mirror.
	GameState.set_hp(current)


func _on_died() -> void:
	if _dead:
		return
	_dead = true
	_control_enabled = false
	velocity = Vector2.ZERO
	whip_hitbox.deactivate()
	hurtbox.active = false
	EventBus.player_died.emit()
	state_machine.transition_to(&"Dead", {})


func is_invulnerable() -> bool:
	return _invulnerable_timer > 0.0


func _update_flash(delta: float) -> void:
	if _invulnerable_timer <= 0.0:
		return
	# Blink at ~12 Hz while invulnerable so the state is unmistakable.
	_flash_timer += delta
	sprite.modulate.a = 0.35 if fmod(_flash_timer, 0.16) < 0.08 else 1.0


# -- Stance and traversal ----------------------------------------------------


## Shrink the hurtbox while crouching so Medusa Heads and high sweeps pass over.
## The *body* collider is left alone — changing it mid-frame causes the character
## to pop through floors.
func set_crouching(crouching: bool) -> void:
	var shape := hurtbox_shape.shape as CapsuleShape2D
	if shape == null:
		return
	if crouching:
		shape.height = CROUCH_HURTBOX_HEIGHT
		hurtbox_shape.position.y = -CROUCH_HURTBOX_HEIGHT * 0.5
	else:
		shape.height = STAND_HURTBOX_HEIGHT
		hurtbox_shape.position.y = -STAND_HURTBOX_HEIGHT * 0.5


## True when the surface underfoot is a drop-through platform.
func is_standing_on_one_way() -> bool:
	if not is_on_floor():
		return false
	for i: int in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider is Node and (collider as Node).is_in_group(ONE_WAY_GROUP):
			return true
	return false


## Temporarily stop colliding with one-way platforms so the player falls through.
func start_drop_through() -> void:
	set_collision_mask_value(ONE_WAY_PHYSICS_LAYER, false)
	# Re-enable after long enough to clear the plank, using a scene-tree timer so
	# it survives the state transition that follows.
	var timer: SceneTreeTimer = get_tree().create_timer(DROP_THROUGH_TIME)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			set_collision_mask_value(ONE_WAY_PHYSICS_LAYER, true))


## Enter or leave the intangible mist form used by the Mist Dash.
##
## Mist gates listen as a group rather than each checking the player every frame.
func set_mist_intangible(intangible: bool) -> void:
	hurtbox.active = not intangible
	SpriteFx.set_mist(sprite, 1.0 if intangible else 0.0)
	get_tree().call_group(MIST_GATE_GROUP, "set_permeable", intangible)


## Spawn a one-shot effect from the generated VFX atlas.
##
## Parented to the room rather than the player, so the effect stays where it was
## made instead of following the character.
func spawn_vfx(animation: String, at: Vector2) -> void:
	Vfx.spawn(effect_host(), Vfx.SHEET_VFX, animation, at)


## Where transient effects should be parented.
func effect_host() -> Node:
	return get_parent() if get_parent() != null else self


## World position of the character's feet, for dust.
func feet_position() -> Vector2:
	return global_position


## Downward speed at the moment of the last landing.
func last_fall_speed() -> float:
	return _last_fall_speed


## Emit a footfall puff every `interval` pixels of ground covered.
##
## Distance-based rather than time-based so the cadence matches the stride at any
## speed, and so a player pushing into a wall does not spray dust on the spot.
func tick_run_dust(delta: float, interval: float = 26.0) -> void:
	if not is_on_floor():
		_run_dust_accumulator = 0.0
		return
	_run_dust_accumulator += absf(velocity.x) * delta
	if _run_dust_accumulator < interval:
		return
	_run_dust_accumulator = 0.0
	Vfx.run_dust(effect_host(), feet_position(), facing)


## Disable input, e.g. during a room transition or a boss intro.
func set_control_enabled(enabled: bool) -> void:
	_control_enabled = enabled
	if not enabled:
		velocity.x = 0.0


func is_dead() -> bool:
	return _dead


# -- Pickups -----------------------------------------------------------------


func _on_pickup_area_entered(area: Area2D) -> void:
	if area.has_method("collect"):
		area.collect(self)
