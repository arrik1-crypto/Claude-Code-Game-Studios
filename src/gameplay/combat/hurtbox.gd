class_name Hurtbox
extends Area2D

## The receiving half of the combat pair: an area that can be hit.
##
## A Hurtbox owns no health of its own — it forwards resolved [DamageInfo] to a
## [Health] node and re-broadcasts the hit so the owning entity can react with
## knockback, hit-stop and flashing.
##
## Physics layer convention (see project.godot):
##   player hurtbox -> layer "player" (2)
##   enemy hurtbox  -> layer "enemy"  (3)
## Hurtboxes never set a collision *mask*; Hitboxes do the detecting.

## Emitted after damage has been applied to [member health].
signal hit_taken(info: DamageInfo, damage_applied: int)

## Emitted when a hit was ignored because the hurtbox was disabled or invulnerable.
signal hit_ignored(info: DamageInfo)

## The Health node this hurtbox feeds. Assigned in the scene, or resolved from a
## sibling named "Health" at ready time.
@export var health: Health

## While false, all incoming damage is ignored. Entities toggle this during
## i-frames, dodge rolls and death animations.
@export var active: bool = true

## Seconds of invulnerability granted after a successful hit. Zero disables the
## built-in cooldown, which is what enemies use — they can be hit every frame the
## whip is active, which is what makes multi-hit combos feel good.
@export var invulnerability_time: float = 0.0

## Multiplies incoming damage. Used for weak points (a boss's exposed helm) and
## armoured segments.
@export var damage_multiplier: float = 1.0

var _invulnerable_until_msec: int = 0


func _ready() -> void:
	if health == null:
		health = get_node_or_null("../Health") as Health
	if health == null:
		push_error("Hurtbox on %s has no Health node assigned" % get_parent().name)
	# Hurtboxes are passive: they are detected, they do not detect.
	monitoring = false
	monitorable = true


## True when the hurtbox will currently accept damage.
func can_be_hit() -> bool:
	if not active or health == null or health.is_dead():
		return false
	return Time.get_ticks_msec() >= _invulnerable_until_msec


## Apply a hit. Called by [Hitbox]; returns the damage actually dealt.
func receive_hit(info: DamageInfo) -> int:
	if info == null:
		return 0
	if not can_be_hit():
		hit_ignored.emit(info)
		return 0

	var scaled: int = maxi(1, int(round(float(info.amount) * damage_multiplier)))
	var applied: int = health.take_damage(scaled, info)
	if applied <= 0:
		hit_ignored.emit(info)
		return 0

	var cooldown: float = info.invulnerability_override
	if cooldown <= 0.0:
		cooldown = invulnerability_time
	if cooldown > 0.0:
		_invulnerable_until_msec = Time.get_ticks_msec() + int(cooldown * 1000.0)

	hit_taken.emit(info, applied)
	EventBus.damage_dealt.emit(get_parent(), applied, info.is_critical)
	return applied


## Start an invulnerability window without taking damage — used after a hit is
## resolved by the owner (the player controller drives its own i-frames).
func grant_invulnerability(seconds: float) -> void:
	_invulnerable_until_msec = maxi(
		_invulnerable_until_msec,
		Time.get_ticks_msec() + int(seconds * 1000.0))


func clear_invulnerability() -> void:
	_invulnerable_until_msec = 0
