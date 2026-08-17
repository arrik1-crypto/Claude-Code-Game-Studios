class_name CombatMath
extends RefCounted

## Pure combat and progression mathematics.
##
## Every function here is static and side-effect free: no engine singletons, no
## node lookups, no randomness unless a seed is passed in explicitly. That keeps
## the whole balance model unit-testable from a headless test run
## (see tests/unit/combat/combat_math_test.gd) and makes the formulas in
## design/gdd/combat-system.md verifiable rather than aspirational.
##
## All tuning constants live in assets/data/balance.json and are passed in by the
## caller — never hardcode a gameplay value in this file.

## Damage floor. A hit always registers so the player never feels ignored.
const MIN_DAMAGE: int = 1

## Fraction of a defender's DEF that is subtracted from incoming damage.
const DEFENSE_SCALE: float = 0.5

## Crit chance gained per point of luck, as a fraction (0.005 == 0.5%).
const LUCK_TO_CRIT: float = 0.005

## Hard ceiling on crit chance so late-game luck cannot trivialise combat.
const MAX_CRIT_CHANCE: float = 0.5


## Effective attack power for an attacker.
##
## [param strength] the attacker's STR stat.
## [param weapon_attack] flat attack rating of the equipped weapon.
## [param combo_multiplier] scaling for the current combo step (1.0 == neutral).
static func attack_power(strength: int, weapon_attack: int, combo_multiplier: float) -> float:
	return maxf(0.0, float(strength + weapon_attack) * combo_multiplier)


## Final damage for a single hit, after defence, element and crit.
##
## Returns an integer of at least [constant MIN_DAMAGE].
static func compute_damage(
	power: float,
	defense: int,
	element_multiplier: float = 1.0,
	is_critical: bool = false,
	critical_multiplier: float = 2.0
) -> int:
	var mitigated: float = power - float(defense) * DEFENSE_SCALE
	mitigated *= element_multiplier
	if is_critical:
		mitigated *= critical_multiplier
	return maxi(MIN_DAMAGE, int(roundf(mitigated)))


## Crit chance in the range 0.0..[constant MAX_CRIT_CHANCE].
static func critical_chance(luck: int, base_chance: float = 0.02) -> float:
	return clampf(base_chance + float(luck) * LUCK_TO_CRIT, 0.0, MAX_CRIT_CHANCE)


## Knockback impulse applied to a damaged body.
##
## [param direction_x] -1 or 1: the horizontal direction the hit came *from*
## reversed, i.e. the direction the victim should travel.
static func knockback_impulse(
	direction_x: float,
	horizontal_force: float,
	vertical_force: float
) -> Vector2:
	return Vector2(signf(direction_x) * horizontal_force, -absf(vertical_force))


# -- Progression -------------------------------------------------------------


## Experience required to advance *from* [param level] to the next level.
##
## A super-linear curve (exponent 1.6) keeps early levels fast — important for a
## mobile session — while making late levels a deliberate grind-or-explore choice.
static func exp_to_next_level(level: int, base: float = 24.0, exponent: float = 1.6) -> int:
	if level < 1:
		return 0
	return int(roundf(base * pow(float(level), exponent)))


## Total experience needed to reach [param level] from level 1.
static func total_exp_for_level(level: int, base: float = 24.0, exponent: float = 1.6) -> int:
	var total: int = 0
	for n: int in range(1, level):
		total += exp_to_next_level(n, base, exponent)
	return total


## How many levels the given experience total grants, and the leftover exp.
##
## Returns a dictionary with keys "level" and "exp_into_level". Loops rather than
## inverting the curve so it stays exact and matches [method exp_to_next_level].
static func level_for_exp(total_exp: int, max_level: int = 99, base: float = 24.0, exponent: float = 1.6) -> Dictionary:
	var level: int = 1
	var remaining: int = maxi(0, total_exp)
	while level < max_level:
		var needed: int = exp_to_next_level(level, base, exponent)
		if remaining < needed:
			break
		remaining -= needed
		level += 1
	return {"level": level, "exp_into_level": remaining}


## Maximum HP for a level and constitution score.
static func max_hp(level: int, constitution: int, base: int = 60, per_con: int = 4, per_level: int = 8) -> int:
	return base + constitution * per_con + maxi(0, level - 1) * per_level


## Maximum MP for a level and intelligence score.
static func max_mp(level: int, intelligence: int, base: int = 20, per_int: int = 3, per_level: int = 4) -> int:
	return base + intelligence * per_int + maxi(0, level - 1) * per_level


## Experience awarded for a kill, scaled by the level gap.
##
## Killing something far below your level pays almost nothing, which discourages
## farming trivial rooms; killing something above your level pays a bonus.
static func exp_reward(base_exp: int, enemy_level: int, player_level: int) -> int:
	var gap: int = enemy_level - player_level
	var scale: float = clampf(1.0 + float(gap) * 0.15, 0.1, 2.0)
	return maxi(1, int(roundf(float(base_exp) * scale)))
