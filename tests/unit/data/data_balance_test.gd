extends TestCase

## Guards the integrity of assets/data/game_balance.json.
##
## The coding standards forbid hardcoded gameplay values, which makes the balance
## file load-bearing: a missing key silently falls back to a default and the game
## quietly plays differently. These tests assert the shape of the data and that
## the numbers are inside sane ranges, so a bad edit fails CI instead of a
## playtest.

const REQUIRED_SECTIONS: PackedStringArray = [
	"movement", "player", "weapons", "combo", "subweapons",
	"enemies", "bosses", "pickups", "hazards", "economy",
]

const REQUIRED_MOVEMENT_KEYS: PackedStringArray = [
	"runSpeed", "airControlSpeed", "groundAcceleration", "groundFriction",
	"airAcceleration", "airFriction", "gravity", "maxFallSpeed",
	"jumpVelocity", "jumpCutMultiplier", "doubleJumpVelocity",
	"coyoteTime", "jumpBufferTime", "backdashSpeed", "backdashDuration",
	"mistDashSpeed", "mistDashDuration", "hurtLockout", "invulnerabilityTime",
	"knockbackHorizontal", "knockbackVertical",
]

const REQUIRED_ENEMY_KEYS: PackedStringArray = [
	"displayName", "level", "maxHp", "attack", "defense", "exp", "gold",
	"moveSpeed", "contactDamage",
]


func test_balance_file_loads() -> void:
	assert_true(Balance.is_loaded(), "game_balance.json must parse at startup")


func test_all_required_sections_exist() -> void:
	for section: String in REQUIRED_SECTIONS:
		assert_false(Balance.section(section).is_empty(),
			"missing balance section '%s'" % section)


func test_movement_has_every_tuning_key() -> void:
	var movement: Dictionary = Balance.section("movement")
	for key: String in REQUIRED_MOVEMENT_KEYS:
		assert_has(movement, key, "movement is missing '%s'" % key)


func test_gravity_and_jump_are_physically_sane() -> void:
	var movement: Dictionary = Balance.section("movement")
	assert_gt(float(movement["gravity"]), 0.0, "gravity pulls down")
	assert_lt(float(movement["jumpVelocity"]), 0.0, "jump velocity is negative (upward)")
	assert_lt(float(movement["doubleJumpVelocity"]), 0.0, "double jump is upward")
	assert_in_range(float(movement["jumpCutMultiplier"]), 0.0, 1.0,
		"jump cut must reduce, not amplify, upward velocity")


func test_double_jump_is_weaker_than_the_first_jump() -> void:
	var movement: Dictionary = Balance.section("movement")
	# Less negative == weaker. A stronger second jump would make the first
	# redundant and break every height gate in the level design.
	assert_gt(float(movement["doubleJumpVelocity"]), float(movement["jumpVelocity"]),
		"the double jump must be the weaker of the two")


func test_jump_height_clears_the_designed_gates() -> void:
	# design/levels/room-graph.md gates the Twin Step on an 80px climb that a
	# single jump must NOT clear and a double jump must.
	var movement: Dictionary = Balance.section("movement")
	var gravity: float = float(movement["gravity"])
	var single: float = pow(float(movement["jumpVelocity"]), 2.0) / (2.0 * gravity)
	var doubled: float = single + pow(float(movement["doubleJumpVelocity"]), 2.0) / (2.0 * gravity)

	assert_lt(single, 80.0, "a single jump must not clear the Twin Step gate")
	assert_gt(doubled, 80.0, "a double jump must clear the Twin Step gate")
	assert_gt(single, 48.0, "a single jump must still clear the ordinary 3-tile ledges")


func test_mist_dash_outclasses_the_backdash() -> void:
	var movement: Dictionary = Balance.section("movement")
	assert_gt(float(movement["mistDashSpeed"]), float(movement["backdashSpeed"]),
		"the relic upgrade must feel stronger than the starting move")


func test_every_enemy_has_a_complete_stat_block() -> void:
	var enemies: Dictionary = Balance.section("enemies")
	assert_gt(float(enemies.size()), 0.0, "the bestiary must not be empty")
	for enemy_id: String in enemies:
		var stats: Dictionary = enemies[enemy_id]
		for key: String in REQUIRED_ENEMY_KEYS:
			assert_has(stats, key, "%s is missing '%s'" % [enemy_id, key])
		assert_gt(float(stats["maxHp"]), 0.0, "%s must have positive HP" % enemy_id)
		assert_ge(float(stats["defense"]), 0.0, "%s cannot have negative defence" % enemy_id)
		assert_gt(float(stats["exp"]), 0.0, "%s must be worth some exp" % enemy_id)


func test_enemy_drop_chances_are_probabilities() -> void:
	var enemies: Dictionary = Balance.section("enemies")
	for enemy_id: String in enemies:
		for entry: Variant in (enemies[enemy_id].get("drops", []) as Array):
			var drop: Dictionary = entry as Dictionary
			assert_in_range(float(drop.get("chance", -1.0)), 0.0, 1.0,
				"%s drop chance must be between 0 and 1" % enemy_id)
			assert_false(Balance.entry("pickups", String(drop.get("item", ""))).is_empty(),
				"%s drops unknown item '%s'" % [enemy_id, drop.get("item", "")])


func test_combo_multipliers_escalate() -> void:
	var steps: Array = Balance.section("combo").get("steps", []) as Array
	assert_eq(steps.size(), 3, "the whip combo is three hits")
	var previous: float = 0.0
	for entry: Variant in steps:
		var step: Dictionary = entry as Dictionary
		var multiplier: float = float(step["multiplier"])
		assert_gt(multiplier, previous, "each combo step must hit harder than the last")
		previous = multiplier
		assert_gt(float(step["active"]), 0.0, "every combo step needs an active window")


func test_subweapons_cost_hearts_and_do_damage() -> void:
	var subweapons: Dictionary = Balance.section("subweapons")
	assert_gt(float(subweapons.size()), 0.0, "at least one sub-weapon must exist")
	for id: String in subweapons:
		var cfg: Dictionary = subweapons[id]
		assert_gt(float(cfg.get("heartCost", 0)), 0.0, "%s must cost hearts" % id)
		assert_gt(float(cfg.get("damageMultiplier", 0.0)), 0.0, "%s must do damage" % id)
		assert_gt(float(cfg.get("maxActive", 0)), 0.0, "%s needs an on-screen cap" % id)


func test_expensive_subweapons_hit_harder() -> void:
	# Otherwise the dagger dominates and the axe is never worth its four hearts.
	var dagger: Dictionary = Balance.entry("subweapons", "dagger")
	var axe: Dictionary = Balance.entry("subweapons", "axe")
	assert_gt(float(axe["heartCost"]), float(dagger["heartCost"]), "the axe costs more")
	assert_gt(float(axe["damageMultiplier"]), float(dagger["damageMultiplier"]),
		"the axe must out-damage the dagger it costs four times as much as")


func test_boss_phases_descend_and_escalate() -> void:
	var boss: Dictionary = Balance.entry("bosses", "sanguine_knight")
	var phases: Array = boss.get("phases", []) as Array
	assert_gt(float(phases.size()), 1.0, "the boss needs more than one phase")

	var previous_threshold: float = 2.0
	var previous_cooldown: float = 999.0
	for entry: Variant in phases:
		var phase: Dictionary = entry as Dictionary
		var threshold: float = float(phase["hpThreshold"])
		assert_lt(threshold, previous_threshold,
			"phase thresholds must descend so the right phase is selected")
		previous_threshold = threshold

		var cooldown: float = float(phase["attackCooldown"])
		assert_lt(cooldown, previous_cooldown,
			"each phase must attack faster than the last")
		previous_cooldown = cooldown

		assert_gt(float((phase["pattern"] as Array).size()), 0.0,
			"every phase needs an attack pattern")


func test_boss_pattern_only_names_implemented_moves() -> void:
	var boss: Dictionary = Balance.entry("bosses", "sanguine_knight")
	var known: PackedStringArray = ["slash", "charge", "summon"]
	for entry: Variant in (boss.get("phases", []) as Array):
		for move: Variant in ((entry as Dictionary)["pattern"] as Array):
			assert_true(known.has(String(move)),
				"boss pattern names unimplemented move '%s'" % move)


func test_boss_is_meaningfully_tougher_than_regular_enemies() -> void:
	var boss_hp: float = float(Balance.entry("bosses", "sanguine_knight")["maxHp"])
	var toughest: float = 0.0
	for enemy_id: String in Balance.section("enemies"):
		toughest = maxf(toughest, float(Balance.entry("enemies", enemy_id)["maxHp"]))
	assert_gt(boss_hp, toughest * 4.0, "the boss should be a real wall")


func test_weapons_upgrade_monotonically() -> void:
	var leather: Dictionary = Balance.entry("weapons", "leather_whip")
	var chain: Dictionary = Balance.entry("weapons", "chain_whip")
	assert_gt(float(chain["attack"]), float(leather["attack"]),
		"the chain whip must out-damage the starting whip")
	assert_gt(float(chain["reach"]), float(leather["reach"]),
		"the chain whip must out-reach the starting whip")


func test_pickups_all_grant_something() -> void:
	var pickups: Dictionary = Balance.section("pickups")
	for id: String in pickups:
		var cfg: Dictionary = pickups[id]
		var total: float = float(cfg.get("hearts", 0)) + float(cfg.get("hp", 0)) \
			+ float(cfg.get("gold", 0))
		assert_gt(total, 0.0, "pickup '%s' grants nothing" % id)


func test_starting_player_can_survive_a_few_hits() -> void:
	# A first-room mistake should not be lethal: the starting HP pool must absorb
	# at least four Bone Sentry hits.
	var player_cfg: Dictionary = Balance.section("player")
	var stats: Dictionary = player_cfg["startingStats"]
	var hp: int = CombatMath.max_hp(
		int(player_cfg["startingLevel"]), int(stats["constitution"]),
		int(player_cfg["hpBase"]), int(player_cfg["hpPerConstitution"]),
		int(player_cfg["hpPerLevel"]))
	var hit: float = float(Balance.entry("enemies", "bone_sentry")["contactDamage"])
	assert_ge(float(hp) / hit, 4.0, "a new player must survive at least four hits")
