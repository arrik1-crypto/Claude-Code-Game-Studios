extends TestCase

## Verifies the damage model in design/gdd/combat-system.md.
##
## These are the formulas every balance decision rests on, so they are covered
## at the boundaries rather than only in the happy path.


func test_attack_power_combines_strength_and_weapon() -> void:
	assert_almost_eq(CombatMath.attack_power(6, 4, 1.0), 10.0,
		0.0001, "neutral combo step is STR + weapon attack")


func test_attack_power_scales_with_combo_multiplier() -> void:
	assert_almost_eq(CombatMath.attack_power(6, 4, 1.45), 14.5,
		0.0001, "third combo step multiplies the whole attack rating")


func test_attack_power_never_negative() -> void:
	assert_almost_eq(CombatMath.attack_power(-50, 0, 1.0), 0.0,
		0.0001, "a debuffed attacker floors at zero, not negative healing")


func test_damage_subtracts_half_of_defense() -> void:
	# 20 power against 8 DEF: 20 - (8 * 0.5) = 16
	assert_eq(CombatMath.compute_damage(20.0, 8), 16,
		"defence mitigates at DEFENSE_SCALE")


func test_damage_floors_at_one_against_heavy_armour() -> void:
	assert_eq(CombatMath.compute_damage(3.0, 200), CombatMath.MIN_DAMAGE,
		"an over-armoured target still takes chip damage")


func test_damage_never_goes_negative() -> void:
	assert_ge(float(CombatMath.compute_damage(0.0, 999)), 1.0,
		"damage can never heal the target")


func test_critical_hit_doubles_damage() -> void:
	var normal: int = CombatMath.compute_damage(20.0, 0, 1.0, false, 2.0)
	var critical: int = CombatMath.compute_damage(20.0, 0, 1.0, true, 2.0)
	assert_eq(critical, normal * 2, "a crit applies the critical multiplier")


func test_element_multiplier_scales_before_crit() -> void:
	# 20 power, no defence, 0.5x element, 2x crit -> 20 * 0.5 * 2 = 20
	assert_eq(CombatMath.compute_damage(20.0, 0, 0.5, true, 2.0), 20,
		"element multiplier and crit multiply together")


func test_critical_chance_rises_with_luck() -> void:
	var low: float = CombatMath.critical_chance(0, 0.02)
	var high: float = CombatMath.critical_chance(20, 0.02)
	assert_gt(high, low, "luck increases crit chance")
	assert_almost_eq(high, 0.12, 0.0001, "20 luck adds 10 percentage points")


func test_critical_chance_is_capped() -> void:
	assert_almost_eq(CombatMath.critical_chance(9999, 0.5), CombatMath.MAX_CRIT_CHANCE,
		0.0001, "crit chance cannot exceed the cap however high luck goes")


func test_critical_chance_never_negative() -> void:
	assert_ge(CombatMath.critical_chance(0, -5.0), 0.0,
		"a negative base chance clamps to zero")


func test_knockback_pushes_along_given_direction() -> void:
	var right: Vector2 = CombatMath.knockback_impulse(1.0, 150.0, 130.0)
	assert_almost_eq(right.x, 150.0, 0.0001, "positive direction pushes right")
	assert_lt(right.y, 0.0, "knockback always pops the victim upward")

	var left: Vector2 = CombatMath.knockback_impulse(-1.0, 150.0, 130.0)
	assert_almost_eq(left.x, -150.0, 0.0001, "negative direction pushes left")


func test_knockback_vertical_is_always_upward() -> void:
	# Passing a positive vertical force must still produce an upward impulse;
	# a sign mistake here would slam the player into the floor instead.
	var impulse: Vector2 = CombatMath.knockback_impulse(1.0, 100.0, 200.0)
	assert_almost_eq(impulse.y, -200.0, 0.0001, "vertical force is negated")
