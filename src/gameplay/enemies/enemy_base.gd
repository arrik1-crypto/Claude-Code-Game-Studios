@abstract
class_name EnemyBase
extends CharacterBody2D

## Shared behaviour for every creature in Castle Vhorn.
##
## Handles the parts that are identical across the bestiary — loading stats from
## `balance.json`, damage reaction, knockback, death, drops and rewards — and
## leaves the actual decision-making to subclasses via [method _tick_ai].
##
## Subclasses set [member enemy_id] to a key under `enemies` (or `bosses`) in
## balance.json; every stat is read from there, so tuning a Gravewalker never
## requires touching code.

## Sub-classes override this to point at their balance.json block.
@export var enemy_id: String = ""

## Which balance.json section the stats live under.
@export var stat_section: String = "enemies"

## Flip the sprite when facing left. Disable for radially symmetric enemies.
@export var flip_sprite_with_facing: bool = true

## Seconds of stagger after taking a hit. Zero means the enemy never flinches.
@export var hurt_duration: float = 0.18

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var contact_hitbox: Hitbox = $ContactHitbox

## Loaded stat block from balance.json.
var config: Dictionary = {}

## -1 left, 1 right.
var facing: int = -1

var _hurt_timer: float = 0.0
var _dying: bool = false
var _player: Player = null
var _elapsed: float = 0.0


func _ready() -> void:
	add_to_group(&"enemies")

	config = Balance.entry(stat_section, enemy_id)
	if config.is_empty():
		push_error("EnemyBase: no balance entry for %s.%s" % [stat_section, enemy_id])

	var sheet: String = sprite_sheet_path()
	if not SpriteSheetLoader.apply(sprite, sheet, "idle"):
		push_error("%s: could not load sprite sheet %s" % [name, sheet])
	SpriteFx.attach(sprite)

	health.setup(int(config.get("maxHp", 10)))
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)

	contact_hitbox.attacker = self
	contact_hitbox.continuous = true
	contact_hitbox.source = DamageInfo.Source.CONTACT
	contact_hitbox.activate(int(config.get("contactDamage", 5)))

	_apply_facing()
	_on_configured()


## Path to the generated atlas. Defaults to the enemy id, which matches the
## filenames the asset pipeline emits.
func sprite_sheet_path() -> String:
	return "res://assets/art/characters/%s.png" % enemy_id


## Hook for subclasses to finish setup once [member config] is populated.
func _on_configured() -> void:
	pass


func _physics_process(delta: float) -> void:
	_elapsed += delta

	if _dying:
		_tick_death(delta)
		move_and_slide()
		return

	if _hurt_timer > 0.0:
		_hurt_timer -= delta
		_tick_stagger(delta)
		move_and_slide()
		return

	_tick_ai(delta)
	move_and_slide()


## Per-frame AI. Subclasses must implement their movement and attacks here.
@abstract
func _tick_ai(delta: float) -> void


## Motion while staggered. Ground-bound enemies slide to a stop; fliers override
## this to keep hovering.
func _tick_stagger(delta: float) -> void:
	apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)


## Motion during the death animation.
func _tick_death(delta: float) -> void:
	apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)


# -- Helpers available to subclasses ----------------------------------------


func apply_gravity(delta: float, scale: float = 1.0) -> void:
	velocity.y = minf(
		velocity.y + Balance.get_float("movement", "gravity", 900.0) * scale * delta,
		Balance.get_float("movement", "maxFallSpeed", 420.0))


func set_facing(direction: int) -> void:
	if direction == 0 or direction == facing:
		return
	facing = direction
	_apply_facing()


## All generated art faces right, so a left-facing enemy is the flipped one.
func _apply_facing() -> void:
	if flip_sprite_with_facing:
		sprite.flip_h = facing < 0


## Cached reference to the player, resolved lazily because enemies can be built
## before the player enters the tree.
func player() -> Player:
	if _player != null and is_instance_valid(_player):
		return _player
	_player = get_tree().get_first_node_in_group(&"player") as Player
	return _player


## Distance to the player, or INF when there is none.
func distance_to_player() -> float:
	var p: Player = player()
	if p == null:
		return INF
	return global_position.distance_to(p.global_position)


## Horizontal direction towards the player (-1 or 1), or 0 if unavailable.
func direction_to_player() -> int:
	var p: Player = player()
	if p == null:
		return 0
	var delta: float = p.global_position.x - global_position.x
	return int(signf(delta)) if not is_zero_approx(delta) else 0


## True when the player is within the enemy's aggro radius.
func player_in_aggro_range() -> bool:
	return distance_to_player() <= float(config.get("aggroRange", 120.0))


## Seconds since the enemy spawned. Fliers use this to drive their wave motion.
func lifetime() -> float:
	return _elapsed


func play_animation(anim: StringName) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim):
		return
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


func is_dying() -> bool:
	return _dying


func is_staggered() -> bool:
	return _hurt_timer > 0.0


# -- Damage and death --------------------------------------------------------


func _on_damaged(_amount: int, info: DamageInfo) -> void:
	if _dying:
		return

	AudioDirector.play_sfx("enemy_hit", -3.0)
	var impact_at: Vector2 = info.impact_position if info != null else global_position
	Vfx.hit_spark(get_parent(), impact_at)
	Vfx.impact(get_parent(), impact_at)
	_flash()

	if info != null and info.knockback_horizontal > 0.0:
		var direction: float = info.resolve_direction_towards(global_position)
		velocity = CombatMath.knockback_impulse(
			direction,
			info.knockback_horizontal * knockback_resistance(),
			info.knockback_vertical * knockback_resistance())

	if hurt_duration > 0.0:
		_hurt_timer = hurt_duration
		play_animation(&"hurt")


## 0.0 means immovable, 1.0 means full knockback. Heavier enemies override this.
func knockback_resistance() -> float:
	return 1.0


## Flash the whole silhouette, not just a brightened tint — a dark enemy
## modulated towards white barely reads as hit at this sprite size.
func _flash() -> void:
	SpriteFx.flash(sprite)


func _on_died() -> void:
	if _dying:
		return
	_dying = true
	contact_hitbox.deactivate()
	hurtbox.active = false
	# Stop colliding with the player so the corpse is not a platform.
	set_collision_layer_value(3, false)
	play_animation(&"death")

	_award_rewards()
	_spawn_drops()
	Vfx.soul(get_parent(), global_position + Vector2(0, -10))
	# Burn the corpse away over its lingering time rather than letting it pop
	# out of existence.
	SpriteFx.dissolve(sprite, death_lingering_time())

	await get_tree().create_timer(death_lingering_time()).timeout
	if is_instance_valid(self):
		queue_free()


## How long the corpse stays before being freed.
func death_lingering_time() -> float:
	return 0.5


func _award_rewards() -> void:
	var exp_reward: int = CombatMath.exp_reward(
		int(config.get("exp", 0)),
		int(config.get("level", 1)),
		GameState.level)
	var gold_reward: int = int(config.get("gold", 0))

	GameState.add_experience(exp_reward)
	GameState.add_gold(gold_reward)
	EventBus.enemy_defeated.emit(enemy_id, exp_reward, gold_reward)


func _spawn_drops() -> void:
	var drops: Array = config.get("drops", []) as Array
	if drops.is_empty():
		return

	var scene: PackedScene = load("res://src/gameplay/items/pickup.tscn") as PackedScene
	if scene == null:
		return

	var host: Node = get_parent()
	if host == null:
		return

	for entry: Variant in drops:
		var drop: Dictionary = entry as Dictionary
		if randf() > float(drop.get("chance", 0.0)):
			continue
		var pickup: Node = scene.instantiate()
		host.add_child(pickup)
		if pickup is Node2D:
			(pickup as Node2D).global_position = global_position + Vector2(
				randf_range(-6.0, 6.0), -8.0)
		if pickup.has_method("configure"):
			pickup.configure(String(drop.get("item", "heart")))


func _spawn_effect(effect_name: String, at: Vector2) -> void:
	var scene: PackedScene = load("res://src/gameplay/vfx/effect.tscn") as PackedScene
	if scene == null or get_parent() == null:
		return
	var effect: Node = scene.instantiate()
	get_parent().add_child(effect)
	if effect is Node2D:
		(effect as Node2D).global_position = at
	if effect.has_method("play_effect"):
		effect.play_effect(effect_name)
