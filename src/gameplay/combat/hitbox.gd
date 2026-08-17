class_name Hitbox
extends Area2D

## The dealing half of the combat pair: an area that damages [Hurtbox]es.
##
## A Hitbox is normally disabled and switched on for a few frames by whatever
## drives it — an attack state, a projectile, an enemy's contact damage. It
## tracks which hurtboxes it has already hit during the current activation so a
## single whip crack cannot tick twice on one enemy.
##
## Physics layer convention (see project.godot):
##   player hitbox -> layer "player_hitbox" (4), mask "enemy" (3)
##   enemy hitbox  -> layer "enemy_hitbox"  (5), mask "player" (2)

## Emitted for each hurtbox actually damaged this activation.
signal hit_landed(hurtbox: Hurtbox, damage: int)

## Raw damage before the victim's multiplier. Set by the owner each activation.
@export var damage: int = 1

@export var source: DamageInfo.Source = DamageInfo.Source.MELEE

## Knockback applied to victims, in pixels/second.
@export var knockback_horizontal: float = 120.0
@export var knockback_vertical: float = 90.0

## When true the hitbox keeps damaging the same target every
## [member retrigger_interval] seconds instead of once per activation. Contact
## damage and holy-water pools use this; swung weapons do not.
@export var continuous: bool = false
@export var retrigger_interval: float = 0.4

## Marks the hit as critical. Set per-activation by the attacker.
var is_critical: bool = false

## Node credited as the attacker; defaults to the hitbox's owner entity.
var attacker: Node = null

## hurtbox instance id -> msec timestamp when it may be hit again.
var _hit_registry: Dictionary = {}
var _active: bool = false


func _ready() -> void:
	if attacker == null:
		attacker = get_parent()
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)
	set_deferred("monitoring", _active)


## Turn the hitbox on and clear its per-activation memory.
##
## [param damage_override] lets an attack set damage at the moment of activation
## without mutating the exported default.
func activate(damage_override: int = -1, critical: bool = false) -> void:
	if damage_override >= 0:
		damage = damage_override
	is_critical = critical
	_hit_registry.clear()
	_active = true
	set_deferred("monitoring", true)
	# Anything already overlapping when we switch on must still be hit; Godot
	# only emits area_entered on *new* overlaps.
	call_deferred("_sweep_existing_overlaps")


func deactivate() -> void:
	_active = false
	set_deferred("monitoring", false)
	_hit_registry.clear()


func is_active() -> bool:
	return _active


func _physics_process(_delta: float) -> void:
	# Continuous hitboxes re-check their overlaps so a target standing inside
	# them keeps taking damage on the retrigger cadence.
	if _active and continuous:
		_sweep_existing_overlaps()


func _sweep_existing_overlaps() -> void:
	if not _active:
		return
	for area: Area2D in get_overlapping_areas():
		_try_hit(area)


func _on_area_entered(area: Area2D) -> void:
	if _active:
		_try_hit(area)


func _try_hit(area: Area2D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null or not hurtbox.can_be_hit():
		return
	# Never damage our own entity — a projectile spawned inside its owner would
	# otherwise hit it on frame one.
	if attacker != null and hurtbox.get_parent() == attacker:
		return

	var id: int = hurtbox.get_instance_id()
	var now: int = Time.get_ticks_msec()
	if _hit_registry.has(id):
		if not continuous:
			return
		if now < int(_hit_registry[id]):
			return

	var info: DamageInfo = DamageInfo.create(damage, attacker, source, is_critical)
	info.impact_position = _impact_point(hurtbox)
	info.knockback_horizontal = knockback_horizontal
	info.knockback_vertical = knockback_vertical
	info.knockback_direction = info.resolve_direction_towards(hurtbox.global_position)

	var applied: int = hurtbox.receive_hit(info)
	if applied <= 0:
		return

	_hit_registry[id] = now + int(retrigger_interval * 1000.0)
	hit_landed.emit(hurtbox, applied)


## Midpoint between hitbox and hurtbox, which places sparks on the contact edge
## rather than inside either body.
func _impact_point(hurtbox: Hurtbox) -> Vector2:
	return global_position.lerp(hurtbox.global_position, 0.5)
