extends Node

## Autoload: the persistent state of a run.
##
## GameState owns everything that survives a room transition: progression,
## resources, unlocked abilities, world flags and map discovery. Per-frame
## combat state does not live here — the Player's [Health] component is the
## runtime authority during play and pushes its value back into
## [member current_hp] whenever it changes, so there is exactly one write path.
##
## Persistence is plain JSON under `user://`. It is intentionally not encrypted
## or signed: this is a single-player game with no leaderboards, so tamper
## protection would cost complexity and buy nothing.

const SAVE_VERSION: int = 1
const SAVE_PATH_TEMPLATE: String = "user://crimson_vespers_slot_%d.json"

## Traversal abilities the player can unlock. Values are the flags checked by
## the player controller and by [MistGate] / ledge gating in the room scenes.
const ABILITY_DOUBLE_JUMP: String = "double_jump"
const ABILITY_MIST_DASH: String = "mist_dash"

# -- Progression -------------------------------------------------------------

var level: int = 1
var experience_total: int = 0
var strength: int = 6
var constitution: int = 8
var intelligence: int = 5
var luck: int = 4

# -- Resources ---------------------------------------------------------------

var current_hp: int = 60
var max_hp: int = 60
var current_mp: float = 20.0
var max_mp: float = 20.0
var hearts: int = 10
var max_hearts: int = 40
var gold: int = 0

# -- Loadout -----------------------------------------------------------------

## The weapon whose `reach` and `attack` drive the whip.
##
## Announced on change so the player can resize its hitbox. Without that, picking
## up the Chain Whip did nothing until the player happened to turn around:
## `_position_whip()` runs from `_ready` and `set_facing`, so the reward for
## beating the boss silently kept the old, shorter reach until the next flip.
var equipped_weapon: String = "leather_whip":
	set(value):
		if equipped_weapon == value:
			return
		equipped_weapon = value
		EventBus.weapon_equipped.emit(value)
var equipped_subweapon: String = ""
var unlocked_abilities: Dictionary = {}

# -- World -------------------------------------------------------------------

## Room the player is currently in, matching design/levels/room-graph.md.
var current_room: String = ""
## Door the player will emerge from when the room loads.
var spawn_door: String = ""
## Room + door the player respawns at after death.
var respawn_room: String = ""
var respawn_door: String = ""

## Rooms the player has visited, for the map screen.
var discovered_rooms: Dictionary = {}
## One-shot world flags: relics taken, gates opened, bosses defeated.
var world_flags: Dictionary = {}

## Wall-clock seconds of play, shown on the save screen.
var playtime_seconds: float = 0.0

var _accumulating_playtime: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _accumulating_playtime and not get_tree().paused:
		playtime_seconds += delta


## Begin a fresh run using the values in balance.json.
func new_game() -> void:
	var cfg: Dictionary = Balance.section("player")
	var start: Dictionary = cfg.get("startingStats", {}) as Dictionary

	level = int(cfg.get("startingLevel", 1))
	experience_total = 0
	strength = int(start.get("strength", 6))
	constitution = int(start.get("constitution", 8))
	intelligence = int(start.get("intelligence", 5))
	luck = int(start.get("luck", 4))

	_recalculate_derived_stats()
	current_hp = max_hp
	current_mp = max_mp

	max_hearts = int(cfg.get("maxHearts", 40))
	hearts = int(cfg.get("startingHearts", 10))
	gold = 0

	equipped_weapon = "leather_whip"
	equipped_subweapon = ""
	unlocked_abilities = {}

	current_room = ""
	spawn_door = ""
	respawn_room = ""
	respawn_door = ""
	discovered_rooms = {}
	world_flags = {}
	playtime_seconds = 0.0
	_accumulating_playtime = true


## Recompute HP/MP ceilings from level and stats, preserving current ratios.
func _recalculate_derived_stats() -> void:
	var cfg: Dictionary = Balance.section("player")
	max_hp = CombatMath.max_hp(
		level, constitution,
		int(cfg.get("hpBase", 60)),
		int(cfg.get("hpPerConstitution", 4)),
		int(cfg.get("hpPerLevel", 8)))
	max_mp = float(CombatMath.max_mp(
		level, intelligence,
		int(cfg.get("mpBase", 20)),
		int(cfg.get("mpPerIntelligence", 3)),
		int(cfg.get("mpPerLevel", 4))))
	current_hp = mini(current_hp, max_hp)
	current_mp = minf(current_mp, max_mp)


# -- Resource mutation -------------------------------------------------------


## Set current HP, clamped, and notify listeners. Called by the player's Health
## component — this is the single write path for player HP.
func set_hp(value: int) -> void:
	var clamped: int = clampi(value, 0, max_hp)
	if clamped == current_hp:
		return
	current_hp = clamped
	EventBus.player_health_changed.emit(current_hp, max_hp)


func heal(amount: int) -> void:
	set_hp(current_hp + maxi(0, amount))


func set_mp(value: float) -> void:
	var clamped: float = clampf(value, 0.0, max_mp)
	if is_equal_approx(clamped, current_mp):
		return
	current_mp = clamped
	EventBus.player_mp_changed.emit(current_mp, max_mp)


## Spend MP if affordable. Returns false and changes nothing otherwise.
func try_spend_mp(amount: float) -> bool:
	if current_mp < amount:
		return false
	set_mp(current_mp - amount)
	return true


func add_hearts(amount: int) -> void:
	var clamped: int = clampi(hearts + amount, 0, max_hearts)
	if clamped == hearts:
		return
	hearts = clamped
	EventBus.player_hearts_changed.emit(hearts, max_hearts)


## Spend hearts if affordable. Returns false and changes nothing otherwise.
func try_spend_hearts(amount: int) -> bool:
	if hearts < amount:
		return false
	add_hearts(-amount)
	return true


func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)
	EventBus.player_gold_changed.emit(gold)


# -- Progression -------------------------------------------------------------


## Award experience and apply any level-ups it triggers.
func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	experience_total += amount
	EventBus.exp_gained.emit(amount, experience_total)

	var cfg: Dictionary = Balance.section("player")
	var result: Dictionary = CombatMath.level_for_exp(
		experience_total,
		int(cfg.get("maxLevel", 99)),
		float(cfg.get("expCurveBase", 24.0)),
		float(cfg.get("expCurveExponent", 1.6)))

	var new_level: int = int(result["level"])
	while level < new_level:
		_apply_single_level_up()


func _apply_single_level_up() -> void:
	var gains: Dictionary = Balance.section("player").get("statGainPerLevel", {}) as Dictionary
	level += 1
	strength += int(gains.get("strength", 1))
	constitution += int(gains.get("constitution", 1))
	intelligence += int(gains.get("intelligence", 1))
	luck += int(gains.get("luck", 1))

	var previous_max: int = max_hp
	_recalculate_derived_stats()
	# A level-up restores the HP it grants, and tops off MP — the classic
	# Castlevania reward for pushing one room further.
	set_hp(current_hp + maxi(0, max_hp - previous_max))
	set_mp(max_mp)

	EventBus.level_up.emit(level, stat_snapshot())


## Experience still needed to reach the next level.
func exp_to_next_level() -> int:
	var cfg: Dictionary = Balance.section("player")
	var base: float = float(cfg.get("expCurveBase", 24.0))
	var exponent: float = float(cfg.get("expCurveExponent", 1.6))
	var result: Dictionary = CombatMath.level_for_exp(
		experience_total, int(cfg.get("maxLevel", 99)), base, exponent)
	var into: int = int(result["exp_into_level"])
	return maxi(0, CombatMath.exp_to_next_level(level, base, exponent) - into)


func stat_snapshot() -> Dictionary:
	return {
		"level": level,
		"strength": strength,
		"constitution": constitution,
		"intelligence": intelligence,
		"luck": luck,
		"maxHp": max_hp,
		"maxMp": max_mp,
	}


## Total attack rating: STR plus the equipped weapon's attack value.
func weapon_attack() -> int:
	var weapon: Dictionary = Balance.entry("weapons", equipped_weapon)
	return int(weapon.get("attack", 0))


func weapon_reach() -> float:
	var weapon: Dictionary = Balance.entry("weapons", equipped_weapon)
	return float(weapon.get("reach", 26))


# -- Abilities and flags -----------------------------------------------------


func has_ability(ability_id: String) -> bool:
	return unlocked_abilities.get(ability_id, false)


func unlock_ability(ability_id: String) -> void:
	if has_ability(ability_id):
		return
	unlocked_abilities[ability_id] = true
	EventBus.ability_unlocked.emit(ability_id)


func equip_subweapon(subweapon_id: String) -> void:
	if equipped_subweapon == subweapon_id:
		return
	equipped_subweapon = subweapon_id
	EventBus.subweapon_equipped.emit(subweapon_id)


func get_flag(flag: String) -> bool:
	return world_flags.get(flag, false)


func set_flag(flag: String, value: bool = true) -> void:
	world_flags[flag] = value


func discover_room(room_id: String) -> void:
	if discovered_rooms.has(room_id):
		return
	discovered_rooms[room_id] = true
	EventBus.room_discovered.emit(room_id)


func is_room_discovered(room_id: String) -> bool:
	return discovered_rooms.has(room_id)


## Record a save point as the death respawn location.
func set_respawn(room_id: String, door_id: String) -> void:
	respawn_room = room_id
	respawn_door = door_id


# -- Persistence -------------------------------------------------------------


func save_path(slot: int) -> String:
	return SAVE_PATH_TEMPLATE % slot


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(save_path(slot))


## Serialise the run. Returns true on success.
func save_to_slot(slot: int = 0) -> bool:
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"level": level,
		"experienceTotal": experience_total,
		"strength": strength,
		"constitution": constitution,
		"intelligence": intelligence,
		"luck": luck,
		"currentHp": current_hp,
		"currentMp": current_mp,
		"hearts": hearts,
		"maxHearts": max_hearts,
		"gold": gold,
		"equippedWeapon": equipped_weapon,
		"equippedSubweapon": equipped_subweapon,
		"unlockedAbilities": unlocked_abilities,
		"respawnRoom": respawn_room,
		"respawnDoor": respawn_door,
		"discoveredRooms": discovered_rooms,
		"worldFlags": world_flags,
		"playtimeSeconds": playtime_seconds,
	}

	var file: FileAccess = FileAccess.open(save_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("GameState: cannot write save slot %d (error %d)"
			% [slot, FileAccess.get_open_error()])
		return false
	# Godot 4.4+ : store_string returns a bool rather than void.
	var ok: bool = file.store_string(JSON.stringify(payload, "  "))
	file.close()
	if not ok:
		push_error("GameState: failed writing save slot %d" % slot)
		return false

	EventBus.game_saved.emit(slot)
	return true


## Restore a run from disk. Returns true on success; state is left untouched on
## failure so a corrupt save never destroys the in-memory run.
func load_from_slot(slot: int = 0) -> bool:
	var path: String = save_path(slot)
	if not FileAccess.file_exists(path):
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameState: cannot read save slot %d (error %d)"
			% [slot, FileAccess.get_open_error()])
		return false
	var text: String = file.get_as_text()
	file.close()

	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		push_error("GameState: corrupt save in slot %d: %s" % [slot, parser.get_error_message()])
		return false
	if typeof(parser.data) != TYPE_DICTIONARY:
		push_error("GameState: save slot %d is not a JSON object" % slot)
		return false

	var d: Dictionary = parser.data
	var version: int = int(d.get("version", 0))
	if version != SAVE_VERSION:
		push_warning("GameState: save slot %d is version %d, expected %d — loading anyway"
			% [slot, version, SAVE_VERSION])

	level = int(d.get("level", 1))
	experience_total = int(d.get("experienceTotal", 0))
	strength = int(d.get("strength", 6))
	constitution = int(d.get("constitution", 8))
	intelligence = int(d.get("intelligence", 5))
	luck = int(d.get("luck", 4))

	_recalculate_derived_stats()
	current_hp = clampi(int(d.get("currentHp", max_hp)), 1, max_hp)
	current_mp = clampf(float(d.get("currentMp", max_mp)), 0.0, max_mp)

	max_hearts = int(d.get("maxHearts", 40))
	hearts = clampi(int(d.get("hearts", 10)), 0, max_hearts)
	gold = int(d.get("gold", 0))

	equipped_weapon = String(d.get("equippedWeapon", "leather_whip"))
	equipped_subweapon = String(d.get("equippedSubweapon", ""))
	unlocked_abilities = d.get("unlockedAbilities", {}) as Dictionary

	respawn_room = String(d.get("respawnRoom", ""))
	respawn_door = String(d.get("respawnDoor", ""))
	current_room = respawn_room
	spawn_door = respawn_door

	discovered_rooms = d.get("discoveredRooms", {}) as Dictionary
	world_flags = d.get("worldFlags", {}) as Dictionary
	playtime_seconds = float(d.get("playtimeSeconds", 0.0))
	_accumulating_playtime = true

	EventBus.game_loaded.emit(slot)
	return true


func delete_save(slot: int = 0) -> void:
	var path: String = save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
