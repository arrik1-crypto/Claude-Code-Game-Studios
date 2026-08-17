extends TestCase

## In-engine validation of the room graph.
##
## `tools/ci/validate_rooms.py` checks the same data before the engine ever sees
## it; this suite covers what only the engine can answer — that the atlas
## actually contains every tile the legends name, that entity scenes resolve, and
## that the map index the pause screen reads is coherent.

const ROOMS_DIR: String = "res://assets/data/rooms"
const START_ROOM: String = "outer_ward_gate"


func _room_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for room_id: String in RoomIndex.all():
		ids.append(room_id)
	ids.sort()
	return ids


func _load_room(room_id: String) -> Dictionary:
	var path: String = "%s/room_%s.json" % [ROOMS_DIR, room_id]
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	return parser.data


func test_room_index_finds_every_room() -> void:
	assert_gt(float(RoomIndex.all().size()), 0.0, "no rooms were indexed")
	assert_has(RoomIndex.all(), START_ROOM, "the starting room must exist")


func test_every_room_has_a_display_name() -> void:
	for room_id: String in _room_ids():
		var name: String = RoomIndex.display_name(room_id)
		assert_ne(name, "", "%s has no display name" % room_id)
		assert_ne(name, room_id, "%s falls back to its id instead of a title" % room_id)


func test_map_cells_are_unique() -> void:
	var seen: Dictionary = {}
	for room_id: String in _room_ids():
		var cell: Rect2i = RoomIndex.cell(room_id)
		var key: String = "%d,%d" % [cell.position.x, cell.position.y]
		assert_false(seen.has(key),
			"%s shares map cell %s with %s" % [room_id, key, seen.get(key, "")])
		seen[key] = room_id


func test_tileset_builds_from_the_generated_atlas() -> void:
	var tileset: TileSet = TileSetBuilder.build()
	assert_not_null(tileset, "the TileSet must build from the generated manifest")
	assert_eq(tileset.tile_size, Vector2i(16, 16), "tiles are 16x16")


func test_every_legend_tile_exists_in_the_atlas() -> void:
	for room_id: String in _room_ids():
		var data: Dictionary = _load_room(room_id)
		var legend: Dictionary = data.get("legend", {}) as Dictionary
		assert_false(legend.is_empty(), "%s has no legend" % room_id)
		for glyph: String in legend:
			var tile_name: String = String(legend[glyph])
			assert_ne(TileSetBuilder.coord(tile_name), Vector2i(-1, -1),
				"%s legend names unknown tile '%s'" % [room_id, tile_name])


func test_platform_tiles_are_one_way_and_bricks_are_solid() -> void:
	assert_eq(TileSetBuilder.role_of("platform"), "oneWay",
		"planks must be drop-through or the whole traversal design breaks")
	assert_eq(TileSetBuilder.role_of("brick_solid"), "solid", "bricks are solid")
	assert_eq(TileSetBuilder.role_of("spikes"), "hazard", "spikes are a hazard")
	assert_eq(TileSetBuilder.role_of("bg_brick"), "decor", "backdrops never collide")


func test_every_entity_type_resolves_to_a_scene() -> void:
	for room_id: String in _room_ids():
		var data: Dictionary = _load_room(room_id)
		for entry: Variant in (data.get("entities", []) as Array):
			var spec: Dictionary = entry as Dictionary
			var type: String = String(spec.get("type", ""))
			# The spawner is built in code rather than from a scene file.
			if type == "medusa_spawner":
				continue
			assert_has(Room.ENTITY_SCENES, type,
				"%s places unknown entity '%s'" % [room_id, type])
			var path: String = String(Room.ENTITY_SCENES.get(type, ""))
			assert_true(ResourceLoader.exists(path),
				"scene for '%s' is missing at %s" % [type, path])


func test_every_room_grid_is_rectangular() -> void:
	for room_id: String in _room_ids():
		var data: Dictionary = _load_room(room_id)
		var fg: Array = data.get("fg", []) as Array
		assert_gt(float(fg.size()), 0.0, "%s has no foreground grid" % room_id)
		var width: int = String(fg[0]).length()
		for y: int in range(fg.size()):
			assert_eq(String(fg[y]).length(), width,
				"%s row %d is a different width" % [room_id, y])


func test_doors_are_reciprocal() -> void:
	var rooms: Dictionary = {}
	for room_id: String in _room_ids():
		rooms[room_id] = _load_room(room_id)

	for room_id: String in rooms:
		for entry: Variant in ((rooms[room_id] as Dictionary).get("doors", []) as Array):
			var door: Dictionary = entry as Dictionary
			var target: String = String(door.get("to", ""))
			# An empty target is an anchor-only door, e.g. a save respawn point.
			if target == "":
				continue

			assert_has(rooms, target,
				"%s.%s leads to unknown room '%s'" % [room_id, door.get("id"), target])
			if not rooms.has(target):
				continue

			var target_door: String = String(door.get("toDoor", ""))
			var back: Dictionary = {}
			for other: Variant in ((rooms[target] as Dictionary).get("doors", []) as Array):
				if String((other as Dictionary).get("id", "")) == target_door:
					back = other as Dictionary
					break

			assert_false(back.is_empty(),
				"%s.%s points at missing door '%s.%s'"
					% [room_id, door.get("id"), target, target_door])
			if back.is_empty():
				continue
			assert_eq(String(back.get("to", "")), room_id,
				"the far side of %s.%s does not point back" % [room_id, door.get("id")])


func test_every_room_is_reachable_from_the_entrance() -> void:
	var rooms: Dictionary = {}
	for room_id: String in _room_ids():
		rooms[room_id] = _load_room(room_id)

	var seen: Dictionary = {START_ROOM: true}
	var queue: Array[String] = [START_ROOM]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for entry: Variant in ((rooms.get(current, {}) as Dictionary).get("doors", []) as Array):
			var target: String = String((entry as Dictionary).get("to", ""))
			if target != "" and rooms.has(target) and not seen.has(target):
				seen[target] = true
				queue.append(target)

	for room_id: String in rooms:
		assert_has(seen, room_id, "%s cannot be reached from the entrance" % room_id)


func test_relics_are_gated_behind_unique_flags() -> void:
	var flags: Dictionary = {}
	var relic_count: int = 0
	for room_id: String in _room_ids():
		var data: Dictionary = _load_room(room_id)
		for entry: Variant in (data.get("entities", []) as Array):
			var spec: Dictionary = entry as Dictionary
			if String(spec.get("type", "")) != "relic":
				continue
			relic_count += 1
			var flag: String = String(spec.get("flag", ""))
			assert_ne(flag, "", "%s has a relic with no flag" % room_id)
			assert_false(flags.has(flag),
				"flag '%s' is used by two relics" % flag)
			flags[flag] = room_id

	assert_ge(float(relic_count), 3.0,
		"the slice ships the dagger, Twin Step and Mist Dash relics")


func test_both_traversal_abilities_are_obtainable() -> void:
	var granted: Dictionary = {}
	for room_id: String in _room_ids():
		var data: Dictionary = _load_room(room_id)
		for entry: Variant in (data.get("entities", []) as Array):
			var spec: Dictionary = entry as Dictionary
			if String(spec.get("type", "")) == "relic" \
					and String(spec.get("relicType", "")) == "ability":
				granted[String(spec.get("relicId", ""))] = room_id

	assert_has(granted, GameState.ABILITY_DOUBLE_JUMP,
		"the Twin Step relic must be placed somewhere")
	assert_has(granted, GameState.ABILITY_MIST_DASH,
		"the Mist Dash relic must be placed somewhere")
