class_name Projectile
extends Hitbox

## A thrown sub-weapon or enemy projectile.
##
## Extends [Hitbox] directly so it inherits hit detection and the
## already-hit registry — a piercing axe should hit each enemy once, not once per
## physics frame, and that logic already exists.
##
## Behaviour is entirely driven by the config block handed to [method launch],
## which comes straight from `balance.json`. Adding a fourth sub-weapon is a data
## change, not a code change.

const PROP_SHEET: String = "res://assets/art/props/props.png"

## Physics layer bit for solid world geometry, used for ground detection.
const WORLD_LAYER_MASK: int = 1

@onready var sprite: AnimatedSprite2D = $Sprite

var _velocity: Vector2 = Vector2.ZERO
var _gravity_scale: float = 0.0
var _lifetime: float = 2.0
var _pierces: bool = false
var _spin: bool = false

## Holy water becomes a lingering pool when it lands.
var _pool_duration: float = 0.0
var _pool_active: bool = false


func _ready() -> void:
	super()
	z_index = 20
	body_entered.connect(_on_body_entered)


## Configure and fire the projectile.
##
## Expected keys in [param params]: `config` (balance block), `sprite_animation`,
## `damage`, `direction`, `origin`, `attacker`, `source`, `target_layer`.
func launch(params: Dictionary) -> void:
	var cfg: Dictionary = params.get("config", {}) as Dictionary

	global_position = params.get("origin", Vector2.ZERO)
	attacker = params.get("attacker")
	source = params.get("source", DamageInfo.Source.SUBWEAPON)

	var direction: int = int(params.get("direction", 1))
	var speed: float = float(cfg.get("speed", 200.0))
	_velocity = Vector2(float(direction) * speed, float(cfg.get("launchVertical", 0.0)))
	_gravity_scale = float(cfg.get("gravityScale", 0.0))
	_lifetime = float(cfg.get("lifetime", 2.0))
	_pierces = bool(cfg.get("pierces", false))
	_pool_duration = float(cfg.get("poolDuration", 0.0))

	knockback_horizontal = float(cfg.get("knockbackHorizontal", 90.0))
	knockback_vertical = float(cfg.get("knockbackVertical", 40.0))

	# Detect both the intended victims and the world, so gravity-affected
	# sub-weapons can land.
	collision_mask = int(params.get("target_layer", 4)) | WORLD_LAYER_MASK

	var anim: String = String(params.get("sprite_animation", ""))
	if SpriteSheetLoader.apply(sprite, PROP_SHEET) and anim != "":
		if sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)
			# The axe's two-frame animation reads as a tumble; the dagger should
			# just point where it is going.
			_spin = anim == "axe"
	sprite.flip_h = direction < 0

	activate(int(params.get("damage", 1)))


func _physics_process(delta: float) -> void:
	super(delta)

	if _pool_active:
		_lifetime -= delta
		if _lifetime <= 0.0:
			queue_free()
		return

	if _gravity_scale > 0.0:
		_velocity.y += Balance.get_float("movement", "gravity", 900.0) * _gravity_scale * delta

	global_position += _velocity * delta
	if _spin:
		sprite.rotation += (12.0 if _velocity.x >= 0.0 else -12.0) * delta

	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()


func _try_hit(area: Area2D) -> void:
	var before: int = _hit_registry.size()
	super(area)
	# A non-piercing projectile is spent on its first successful hit.
	if not _pierces and _hit_registry.size() > before:
		_expire()


func _on_body_entered(body: Node2D) -> void:
	# Only solid geometry stops a projectile; enemies are handled through areas.
	if not (body is TileMapLayer or body is StaticBody2D):
		return
	if _pool_duration > 0.0 and not _pool_active:
		_become_pool()
	else:
		_expire()


## Holy water shatters into a burning pool that ticks damage.
func _become_pool() -> void:
	_pool_active = true
	_velocity = Vector2.ZERO
	_gravity_scale = 0.0
	_lifetime = _pool_duration
	continuous = true
	retrigger_interval = float(Balance.entry("subweapons", "holy_water")
		.get("poolTickInterval", 0.22))
	_hit_registry.clear()
	sprite.rotation = 0.0
	sprite.scale = Vector2(1.6, 0.8)
	# Only harm enemies now; the pool should not be stopped by the floor again.
	collision_mask = collision_mask & ~WORLD_LAYER_MASK


func _expire() -> void:
	deactivate()
	var effect: PackedScene = load("res://src/gameplay/vfx/effect.tscn") as PackedScene
	if effect != null and get_parent() != null:
		var vfx: Node = effect.instantiate()
		get_parent().add_child(vfx)
		if vfx is Node2D:
			(vfx as Node2D).global_position = global_position
		if vfx.has_method("play_effect"):
			vfx.play_effect("hit_spark")
	queue_free()
