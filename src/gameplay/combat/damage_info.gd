class_name DamageInfo
extends RefCounted

## A single instance of damage travelling from a [Hitbox] to a [Hurtbox].
##
## Passing a value object rather than a bare integer keeps knockback, crit state
## and provenance together, so a Hurtbox can react to *how* it was hit — spikes
## push straight up, a whip pushes away from the attacker, holy water does
## neither.

enum Source {
	## Melee weapon swing.
	MELEE,
	## Thrown or fired sub-weapon.
	SUBWEAPON,
	## Walking into an enemy body.
	CONTACT,
	## Environmental hazard such as spikes.
	HAZARD,
	## Boss special attack.
	BOSS,
}

## Final damage after all math, already resolved by [CombatMath].
var amount: int = 0

## Where the damage came from; drives VFX and knockback style.
var source: Source = Source.MELEE

## Whether this hit rolled a critical.
var is_critical: bool = false

## Direction the victim should be pushed, normalised horizontally to -1/0/1.
var knockback_direction: float = 0.0

## Horizontal knockback force in pixels/second. 0 disables horizontal push.
var knockback_horizontal: float = 0.0

## Vertical knockback force in pixels/second. 0 disables the pop-up.
var knockback_vertical: float = 0.0

## Node that dealt the damage. May be freed by the time it is read, so always
## guard with `is_instance_valid()`.
var attacker: Node = null

## World position of the impact, used to place hit sparks.
var impact_position: Vector2 = Vector2.ZERO

## Seconds of invulnerability this hit grants the victim. 0 means "use the
## victim's own default".
var invulnerability_override: float = 0.0


static func create(
	damage: int,
	from: Node,
	source_type: Source = Source.MELEE,
	critical: bool = false
) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = maxi(0, damage)
	info.attacker = from
	info.source = source_type
	info.is_critical = critical
	if from is Node2D:
		info.impact_position = (from as Node2D).global_position
	return info


## Set the knockback vector, inferring direction from the attacker's position
## when [param direction] is left at zero.
func with_knockback(horizontal: float, vertical: float, direction: float = 0.0) -> DamageInfo:
	knockback_horizontal = horizontal
	knockback_vertical = vertical
	knockback_direction = direction
	return self


## Resolve the knockback direction against a victim's position. Called by the
## Hurtbox so the value object never needs to know about the scene tree.
func resolve_direction_towards(victim_position: Vector2) -> float:
	if not is_zero_approx(knockback_direction):
		return signf(knockback_direction)
	if attacker != null and is_instance_valid(attacker) and attacker is Node2D:
		var from: Vector2 = (attacker as Node2D).global_position
		var delta: float = victim_position.x - from.x
		if not is_zero_approx(delta):
			return signf(delta)
	return 0.0
