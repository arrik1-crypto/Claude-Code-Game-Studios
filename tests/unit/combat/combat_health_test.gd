extends TestCase

## Covers the [Health] component.
##
## Health is shared by the player, every enemy and the boss, so its edge cases —
## overkill, healing past the cap, damage after death — are worth pinning down.

var health: Health


func before_each() -> void:
	health = Health.new()
	health.setup(50)


func after_each() -> void:
	health.free()


func test_setup_starts_at_full_health() -> void:
	assert_eq(health.current_hp, 50, "setup fills to maximum by default")
	assert_eq(health.max_hp, 50, "maximum is what was configured")
	assert_false(health.is_dead(), "a freshly configured entity is alive")


func test_setup_can_start_partially_damaged() -> void:
	health.setup(50, 20)
	assert_eq(health.current_hp, 20, "an explicit current value is honoured")


func test_take_damage_reduces_health() -> void:
	var applied: int = health.take_damage(12)
	assert_eq(applied, 12, "the full amount was applied")
	assert_eq(health.current_hp, 38, "health dropped by the damage dealt")


func test_overkill_is_clamped_to_remaining_health() -> void:
	var applied: int = health.take_damage(500)
	assert_eq(applied, 50, "only the remaining HP can be dealt")
	assert_eq(health.current_hp, 0, "health floors at zero, never negative")


func test_reaching_zero_marks_dead() -> void:
	health.take_damage(50)
	assert_true(health.is_dead(), "zero HP means dead")


func test_damage_after_death_is_ignored() -> void:
	health.take_damage(50)
	assert_eq(health.take_damage(10), 0, "a corpse takes no further damage")


func test_invulnerable_entities_take_nothing() -> void:
	health.invulnerable = true
	assert_eq(health.take_damage(20), 0, "invulnerability blocks all damage")
	assert_eq(health.current_hp, 50, "health is untouched")


func test_zero_and_negative_damage_are_ignored() -> void:
	assert_eq(health.take_damage(0), 0, "zero damage does nothing")
	assert_eq(health.take_damage(-30), 0, "negative damage cannot heal")
	assert_eq(health.current_hp, 50, "health is unchanged")


func test_healing_is_capped_at_maximum() -> void:
	health.take_damage(10)
	var healed: int = health.heal(999)
	assert_eq(healed, 10, "only the missing HP is restored")
	assert_eq(health.current_hp, 50, "health cannot exceed the cap")


func test_healing_a_dead_entity_does_nothing() -> void:
	health.take_damage(50)
	assert_eq(health.heal(20), 0, "healing does not resurrect")
	assert_true(health.is_dead(), "still dead")


func test_revive_restores_and_clears_death() -> void:
	health.take_damage(50)
	health.revive(0.5)
	assert_false(health.is_dead(), "revive clears the dead flag")
	assert_eq(health.current_hp, 25, "revive restores the requested fraction")


func test_revive_never_leaves_zero_health() -> void:
	health.take_damage(50)
	health.revive(0.0)
	assert_ge(float(health.current_hp), 1.0, "revive always leaves at least 1 HP")


func test_kill_bypasses_invulnerability() -> void:
	health.invulnerable = true
	health.kill()
	assert_true(health.is_dead(), "kill() ignores invulnerability")


func test_health_fraction_tracks_damage() -> void:
	assert_almost_eq(health.health_fraction(), 1.0, 0.0001, "full health is 1.0")
	health.take_damage(25)
	assert_almost_eq(health.health_fraction(), 0.5, 0.0001, "half health is 0.5")


func test_lowering_max_hp_clamps_current() -> void:
	health.max_hp = 20
	assert_le(float(health.current_hp), 20.0,
		"current HP cannot exceed a reduced maximum")


func test_died_signal_fires_exactly_once() -> void:
	var count: Array[int] = [0]
	health.died.connect(func() -> void: count[0] += 1)
	health.take_damage(50)
	health.take_damage(50)
	health.kill()
	assert_eq(count[0], 1, "death is announced once, not on every later hit")
