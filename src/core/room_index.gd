class_name RoomIndex
extends RefCounted

## A lightweight catalogue of every room in the castle.
##
## Scans `assets/data/rooms/` once and keeps only what the map screen needs,
## rather than the full tile grids. That keeps the map cheap to draw and means
## opening it never touches the room files again.
##
## "What the map needs" was originally just the display name and grid cell, and
## that narrowing turned out to be too aggressive: the map could not draw the
## connections between rooms, or mark relics and save points, because it had no
## access to the data describing them. It now also keeps each room's door targets
## and a small summary of its landmarks — still no tile grids, still one scan.

const ROOM_DATA_DIR: String = "res://assets/data/rooms"

static var _index: Dictionary = {}
static var _scanned: bool = false


## room_id -> { "name": String, "cell": Rect2i }
static func all() -> Dictionary:
	if not _scanned:
		_scan()
	return _index


static func entry(room_id: String) -> Dictionary:
	return all().get(room_id, {})


## Display name for a room, falling back to the id.
static func display_name(room_id: String) -> String:
	var e: Dictionary = entry(room_id)
	return String(e.get("name", room_id))


## Grid cell a room occupies on the map screen.
static func cell(room_id: String) -> Rect2i:
	var e: Dictionary = entry(room_id)
	return e.get("cell", Rect2i(0, 0, 1, 1))


## Bounding box of every known room's cells, used to centre the map.
static func grid_bounds() -> Rect2i:
	var rooms: Dictionary = all()
	if rooms.is_empty():
		return Rect2i(0, 0, 1, 1)
	var bounds := Rect2i()
	var first: bool = true
	for room_id: String in rooms:
		var c: Rect2i = rooms[room_id]["cell"]
		if first:
			bounds = c
			first = false
		else:
			bounds = bounds.merge(c)
	return bounds


static func _scan() -> void:
	_scanned = true
	_index = {}

	var dir: DirAccess = DirAccess.open(ROOM_DATA_DIR)
	if dir == null:
		push_error("RoomIndex: cannot open %s" % ROOM_DATA_DIR)
		return

	for file_name: String in dir.get_files():
		# Exported projects rename .json to .json.remap in some configurations;
		# tolerate both so the map is never empty in a release build.
		var clean: String = file_name.trim_suffix(".remap")
		if not clean.begins_with("room_") or not clean.ends_with(".json"):
			continue

		var path: String = "%s/%s" % [ROOM_DATA_DIR, clean]
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var text: String = file.get_as_text()
		file.close()

		var parser: JSON = JSON.new()
		if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
			push_warning("RoomIndex: skipping unreadable room file %s" % clean)
			continue

		var data: Dictionary = parser.data
		var room_id: String = String(data.get("id", clean.trim_prefix("room_").trim_suffix(".json")))
		var map_info: Dictionary = data.get("map", {}) as Dictionary
		_index[room_id] = {
			"name": String(data.get("name", room_id)),
			"cell": Rect2i(
				int(map_info.get("x", 0)), int(map_info.get("y", 0)),
				maxi(1, int(map_info.get("w", 1))), maxi(1, int(map_info.get("h", 1)))),
			"links": _links_of(data),
			"marks": _marks_of(data),
		}


## Which rooms this one connects to, and on which side.
##
## Kept because the map has to draw connections. Only the ids and directions are
## retained, never the tile coordinates — the point of this index is still to
## avoid holding the room grids in memory.
static func _links_of(data: Dictionary) -> Array[Dictionary]:
	var links: Array[Dictionary] = []
	for entry_variant: Variant in (data.get("doors", []) as Array):
		var door: Dictionary = entry_variant as Dictionary
		var target: String = String(door.get("to", ""))
		# An empty target is a save-point respawn anchor, not a way out.
		if target == "":
			continue
		links.append({
			"to": target,
			# `dir` is +1 for a door on the west wall, -1 for the east.
			"side": int(door.get("dir", 1)),
		})
	return links


## Landmarks worth drawing on a room's chip: save coffins, relics, the boss.
##
## `SAVE_ROOMS` used to be a hardcoded list in the map view — a second source of
## truth that would silently desync the first time a coffin moved, and a straight
## violation of the project's data-driven rule. This reads it from the room data
## instead, along with the relic flags so the map can show what is still uncollected.
static func _marks_of(data: Dictionary) -> Dictionary:
	var relic_flags: Array[String] = []
	var has_save: bool = false
	var has_boss: bool = false
	var has_gate: bool = false

	for entry_variant: Variant in (data.get("entities", []) as Array):
		var spec: Dictionary = entry_variant as Dictionary
		match String(spec.get("type", "")):
			"save_point":
				has_save = true
			"relic":
				relic_flags.append(String(spec.get("flag", "")))
			"mist_gate":
				has_gate = true
			"sanguine_knight":
				has_boss = true

	return {
		"save": has_save,
		"boss": has_boss,
		"gate": has_gate,
		"relicFlags": relic_flags,
	}


## True when the room contains a save coffin.
static func has_save_point(room_id: String) -> bool:
	return bool((entry(room_id).get("marks", {}) as Dictionary).get("save", false))


## Rooms this room has a door to, with the side each door sits on.
static func links(room_id: String) -> Array[Dictionary]:
	var value: Variant = entry(room_id).get("links", [])
	return value as Array[Dictionary] if value is Array else ([] as Array[Dictionary])


## Force a re-scan. Used by tests.
static func clear_cache() -> void:
	_scanned = false
	_index = {}
