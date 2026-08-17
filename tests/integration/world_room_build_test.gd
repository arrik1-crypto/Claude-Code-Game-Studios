extends TestCase

## Integration test: every room in the castle actually builds.
##
## The unit suites check the room *data*; this one instantiates the real [Room]
## node for each one and asserts the built result — tile layers populated,
## entities spawned, doors registered, spawn points on solid ground.
##
## It is the test that would have caught the missing tile collision, the doors
## embedded in walls and the spawn point inside the floor, all of which the data
## alone looked fine for.
##
## Runs headless: rooms are built under a detached parent, never rendered.

const EXPECTED_ROOM_COUNT: int = 11

var _host: Node2D


func before_each() -> void:
	_host = Node2D.new()
	Engine.get_main_loop().root.add_child(_host)
	# Every room starts from a clean progression state so `skipIfFlag` entities
	# (relics, the defeated boss) are present.
	GameState.new_game()


func after_each() -> void:
	if is_instance_valid(_host):
		_host.queue_free()


func _build(room_id: String) -> Room:
	var room := Room.new()
	_host.add_child(room)
	if not room.build(room_id):
		return null
	return room


## Read a room's raw JSON, for tests that compare declared content against what
## the builder actually produced.
func _load_room(room_id: String) -> Dictionary:
	var path: String = "res://assets/data/rooms/room_%s.json" % room_id
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	return parser.data


func _room_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for room_id: String in RoomIndex.all():
		ids.append(room_id)
	ids.sort()
	return ids


func test_the_slice_ships_the_expected_number_of_rooms() -> void:
	assert_eq(_room_ids().size(), EXPECTED_ROOM_COUNT,
		"the vertical slice is %d rooms" % EXPECTED_ROOM_COUNT)


func test_every_room_builds_without_failing() -> void:
	for room_id: String in _room_ids():
		var room: Room = _build(room_id)
		assert_not_null(room, "%s failed to build" % room_id)


func test_every_room_has_solid_geometry() -> void:
	for room_id: String in _room_ids():
		var room: Room = _build(room_id)
		if room == null:
			continue
		assert_gt(float(room.solid.get_used_cells().size()), 0.0,
			"%s has no solid tiles — the player would fall out of the world" % room_id)


func test_every_room_has_a_background() -> void:
	for room_id: String in _room_ids():
		var room: Room = _build(room_id)
		if room == null:
			continue
		assert_gt(float(room.background.get_used_cells().size()), 0.0,
			"%s renders against the void" % room_id)


func test_room_bounds_are_sane() -> void:
	for room_id: String in _room_ids():
		var room: Room = _build(room_id)
		if room == null:
			continue
		assert_gt(room.bounds.size.x, 0.0, "%s has zero width" % room_id)
		assert_gt(room.bounds.size.y, 0.0, "%s has zero height" % room_id)
		# Rooms should be at least a viewport wide so the camera has room.
		assert_ge(room.bounds.size.x, 480.0, "%s is narrower than the viewport" % room_id)


func test_every_declared_door_is_registered() -> void:
	for room_id: String in _room_ids():
		var room: Room = _build(room_id)
		if room == null:
			continue
		assert_gt(float(room.door_ids().size()), 0.0,
			"%s has no doors and would be a soft-lock" % room_id)


func test_spawn_points_resolve_for_every_door() -> void:
	for room_id: String in _room_ids():
		var room: Room = _build(room_id)
		if room == null:
			continue
		for door_id: Variant in room.door_ids():
			var point: Vector2 = room.spawn_point_for(String(door_id))
			assert_true(room.bounds.has_point(point),
				"%s spawn for door '%s' is outside the room" % [room_id, door_id])


func test_spawn_points_are_not_inside_solid_tile() -> void:
	for room_id: String in _room_ids():
		var room: Room = _build(room_id)
		if room == null:
			continue
		for door_id: Variant in room.door_ids():
			var point: Vector2 = room.spawn_point_for(String(door_id))
			# Convert to tile coordinates and check the cell the player's torso
			# occupies, one tile above their feet.
			var cell := Vector2i(int(point.x / 16.0), int(point.y / 16.0) - 1)
			assert_eq(room.solid.get_cell_source_id(cell), -1,
				"%s spawn for '%s' is embedded in solid tile at %s"
					% [room_id, door_id, cell])


func test_entities_are_spawned() -> void:
	var total: int = 0
	for room_id: String in _room_ids():
		var room: Room = _build(room_id)
		if room == null:
			continue
		total += room.entities.get_child_count()
		assert_gt(float(room.entities.get_child_count()), 0.0,
			"%s spawned no entities at all (doors alone should be present)" % room_id)
	assert_gt(float(total), 40.0, "the wing should be populated, not sparse")


func test_enemies_actually_enter_the_enemy_group() -> void:
	# entrance_hall carries a Bone Sentry and a Nightwing.
	var room: Room = _build("entrance_hall")
	assert_not_null(room, "entrance_hall must build")
	if room == null:
		return

	var found: int = 0
	for child: Node in room.entities.get_children():
		if child is EnemyBase:
			found += 1
	assert_ge(float(found), 2.0, "entrance_hall places at least two enemies")


func test_collected_relic_renders_as_taken_and_cannot_be_regranted() -> void:
	# By design the plinth stays as a landmark; it is the *relic* that is gone.
	var before: RelicPedestal = _first_relic(_build("vault_twin_step"))
	assert_not_null(before, "the Twin Step relic is present on a fresh run")
	if before != null:
		assert_true(before.monitoring,
			"an uncollected relic must be able to detect the player")

	GameState.set_flag("relic_twin_step_taken", true)
	var after: RelicPedestal = _first_relic(_build("vault_twin_step"))
	assert_not_null(after, "the empty plinth remains as a landmark")
	if after != null:
		assert_false(after.monitoring,
			"a collected relic must not be collectable a second time")


func test_taking_a_relic_at_runtime_grants_the_ability_and_closes_the_plinth() -> void:
	# The test above covers the *build-time* path — a relic rebuilt from a saved
	# flag. This one drives the collision callback the player actually triggers,
	# which is a different code path and the one that was broken: disabling an
	# Area2D's `monitoring` from inside `body_entered` is refused by the physics
	# server, so the relic stayed live after being collected.
	var room: Room = _build("vault_twin_step")
	var relic: RelicPedestal = _first_relic(room)
	assert_not_null(relic, "the Twin Step relic must be present on a fresh run")
	if relic == null:
		return

	assert_false(GameState.has_ability(relic.relic_id),
		"the ability is not held before the relic is taken")

	relic._on_body_entered(_a_player())

	assert_true(GameState.get_flag(relic.flag), "taking a relic must set its flag")
	assert_true(GameState.has_ability(relic.relic_id),
		"taking the Twin Step relic must grant the double jump")

	# `monitoring` is turned off deferred and so cannot be observed inside this
	# frame. The guard that actually prevents a second grant is `_taken`, and
	# that is what a repeated touch must respect — walking back through a looted
	# plinth must not re-fire the pickup.
	assert_true(relic._taken, "the plinth must record itself as looted")
	relic._on_body_entered(_a_player())
	assert_eq(GameState.unlocked_abilities.size(), 1,
		"touching a looted plinth again must not grant a second ability")


func _a_player() -> Player:
	var scene: PackedScene = load("res://src/gameplay/player/player.tscn") as PackedScene
	var player: Player = scene.instantiate() as Player
	_host.add_child(player)
	return player


func _first_relic(room: Room) -> RelicPedestal:
	if room == null:
		return null
	for child: Node in room.entities.get_children():
		if child is RelicPedestal:
			return child as RelicPedestal
	return null


func test_defeated_boss_does_not_respawn() -> void:
	var before: Room = _build("throne_of_ash")
	assert_eq(_count_bosses(before), 1, "the boss is present on a fresh run")

	GameState.set_flag("boss_sanguine_knight_defeated", true)
	var after: Room = _build("throne_of_ash")
	assert_eq(_count_bosses(after), 0, "a defeated boss stays defeated")


func _count_bosses(room: Room) -> int:
	if room == null:
		return -1
	var count: int = 0
	for child: Node in room.entities.get_children():
		if child.is_in_group(&"boss"):
			count += 1
	return count


func test_building_a_room_marks_it_discovered() -> void:
	assert_false(GameState.is_room_discovered("bat_gallery"),
		"a fresh run has discovered nothing")
	_build("bat_gallery")
	assert_true(GameState.is_room_discovered("bat_gallery"),
		"entering a room reveals it on the map")


func test_every_placed_entity_actually_instantiates() -> void:
	# A script with a parse error still lets its room build — the scene simply
	# fails to instantiate and the entity is silently absent. Counting nodes
	# against the room data is what catches that; a broken SavePoint script
	# passed every other suite in this file.
	for room_id: String in _room_ids():
		var data: Dictionary = _load_room(room_id)
		var expected: int = 0
		for entry: Variant in (data.get("entities", []) as Array):
			var spec: Dictionary = entry as Dictionary
			var skip_flag: String = String(spec.get("skipIfFlag", ""))
			if skip_flag != "" and GameState.get_flag(skip_flag):
				continue
			expected += 1
		expected += (data.get("doors", []) as Array).size()

		var room: Room = _build(room_id)
		if room == null:
			continue
		var actual: int = room.entities.get_child_count()
		var message: String = "%s declares %d entities+doors but instantiated %d; a scene or script for one of them failed to load" % [room_id, expected, actual]
		assert_eq(actual, expected, message)


func test_save_points_instantiate_in_both_save_rooms() -> void:
	for room_id: String in ["chapel_landing", "boss_approach"]:
		var room: Room = _build(room_id)
		assert_not_null(room, "%s must build" % room_id)
		if room == null:
			continue
		var found: int = 0
		for child: Node in room.entities.get_children():
			if child is SavePoint:
				found += 1
		assert_eq(found, 1, "%s must contain exactly one save coffin" % room_id)


func test_medusa_gauntlet_has_a_mist_gate() -> void:
	var room: Room = _build("medusa_gauntlet")
	assert_not_null(room, "medusa_gauntlet must build")
	if room == null:
		return
	var gates: int = 0
	for child: Node in room.entities.get_children():
		if child is MistGate:
			gates += 1
	assert_eq(gates, 1, "the Mist Dash gate must exist or the boss is unreachable")


func test_platform_tiles_land_on_the_one_way_layer() -> void:
	# bat_gallery is built almost entirely from drop-through planks.
	var room: Room = _build("bat_gallery")
	assert_not_null(room, "bat_gallery must build")
	if room == null:
		return
	assert_gt(float(room.platforms.get_used_cells().size()), 0.0,
		"planks must be routed to the one-way layer, not the solid one")
	assert_true(room.platforms.is_in_group(&"one_way_platform"),
		"the platform layer must be discoverable for drop-through detection")
