extends TestCase

## Verifies the levelling curve in design/gdd/progression-and-stats.md.
##
## The curve has to satisfy two competing goals — fast early levels for a mobile
## session, meaningful late levels — so the shape is asserted, not just the
## arithmetic.


func test_exp_requirement_increases_with_level() -> void:
	var previous: int = 0
	for level: int in range(1, 20):
		var needed: int = CombatMath.exp_to_next_level(level)
		assert_gt(float(needed), float(previous),
			"level %d must cost more than level %d" % [level, level - 1])
		previous = needed


func test_first_level_is_cheap() -> void:
	# A new player should reach level 2 from roughly two Bone Sentries.
	assert_le(float(CombatMath.exp_to_next_level(1)), 30.0,
		"the first level-up must arrive quickly")


func test_curve_is_superlinear() -> void:
	# Doubling the level should more than double the cost, or late levels would
	# feel like a formality.
	var at_5: int = CombatMath.exp_to_next_level(5)
	var at_10: int = CombatMath.exp_to_next_level(10)
	assert_gt(float(at_10), float(at_5) * 2.0,
		"cost grows faster than linearly")


func test_exp_to_next_level_is_zero_below_level_one() -> void:
	assert_eq(CombatMath.exp_to_next_level(0), 0, "level 0 is not a real level")


func test_total_exp_is_the_sum_of_each_step() -> void:
	var manual: int = 0
	for level: int in range(1, 6):
		manual += CombatMath.exp_to_next_level(level)
	assert_eq(CombatMath.total_exp_for_level(6), manual,
		"total exp equals the sum of the individual requirements")


func test_level_for_exp_round_trips() -> void:
	for target: int in [1, 2, 5, 12, 30]:
		var total: int = CombatMath.total_exp_for_level(target)
		var result: Dictionary = CombatMath.level_for_exp(total)
		assert_eq(int(result["level"]), target,
			"exactly enough exp for level %d lands on level %d" % [target, target])
		assert_eq(int(result["exp_into_level"]), 0,
			"no leftover exp at an exact level boundary")


func test_level_for_exp_reports_leftover() -> void:
	var total: int = CombatMath.total_exp_for_level(4) + 7
	var result: Dictionary = CombatMath.level_for_exp(total)
	assert_eq(int(result["level"]), 4, "surplus below the next tier stays at level 4")
	assert_eq(int(result["exp_into_level"]), 7, "surplus is reported as progress")


func test_level_for_exp_respects_max_level() -> void:
	var result: Dictionary = CombatMath.level_for_exp(99999999, 10)
	assert_eq(int(result["level"]), 10, "levelling stops at the configured cap")


func test_level_for_exp_handles_zero_and_negative() -> void:
	assert_eq(int(CombatMath.level_for_exp(0)["level"]), 1, "zero exp is level 1")
	assert_eq(int(CombatMath.level_for_exp(-500)["level"]), 1, "negative exp is clamped")


func test_max_hp_grows_with_level_and_constitution() -> void:
	var base: int = CombatMath.max_hp(1, 8)
	assert_eq(base, 60 + 8 * 4, "level 1 HP is base plus constitution")
	assert_gt(float(CombatMath.max_hp(2, 8)), float(base), "levelling adds HP")
	assert_gt(float(CombatMath.max_hp(1, 12)), float(base), "constitution adds HP")


func test_max_mp_grows_with_level_and_intelligence() -> void:
	var base: int = CombatMath.max_mp(1, 5)
	assert_eq(base, 20 + 5 * 3, "level 1 MP is base plus intelligence")
	assert_gt(float(CombatMath.max_mp(4, 5)), float(base), "levelling adds MP")


func test_exp_reward_penalises_farming_weak_enemies() -> void:
	var even: int = CombatMath.exp_reward(100, 5, 5)
	var trivial: int = CombatMath.exp_reward(100, 1, 20)
	assert_eq(even, 100, "an even-level kill pays its listed value")
	assert_lt(float(trivial), float(even) * 0.5,
		"grinding far-below-level enemies pays very little")


func test_exp_reward_rewards_punching_up() -> void:
	assert_gt(float(CombatMath.exp_reward(100, 10, 5)), 100.0,
		"beating something above your level pays a bonus")


func test_exp_reward_always_at_least_one() -> void:
	assert_ge(float(CombatMath.exp_reward(1, 1, 99)), 1.0,
		"a kill always awards something")
