class_name Room
extends Node2D

## Builds a playable room from a JSON description.
##
## Rooms are data, not scenes. `assets/data/rooms/<id>.json` holds an ASCII tile
## grid plus a list of entity placements; this node turns that into TileMapLayers
## and instantiated nodes. Two reasons:
##
## * A level designer can add a room by writing one text file — no editor session,
##   no binary scene to merge.
## * Room layouts stay reviewable in a pull request, because a diff of ASCII art
##   is readable in a way that a diff of a .tscn is not.
##
## Layer routing is driven by the tile manifest, so whether a tile is solid,
## drop-through or decorative is decided in exactly one place.

const ROOM_DATA_DIR: String = "res://assets/data/rooms"

## Maps an entity `type` in room JSON to the scene instantiated for it.
const ENTITY_SCENES: Dictionary = {
	"bone_sentry": "res://src/gameplay/enemies/bone_sentry.tscn",
	"nightwing": "res://src/gameplay/enemies/nightwing.tscn",
	"gravewalker": "res://src/gameplay/enemies/gravewalker.tscn",
	"medusa_head": "res://src/gameplay/enemies/medusa_head.tscn",
	"cellar_slime": "res://src/gameplay/enemies/slime.tscn",
	"sanguine_knight": "res://src/gameplay/enemies/sanguine_knight.tscn",
	"save_point": "res://src/gameplay/world/save_point.tscn",
	"relic": "res://src/gameplay/world/relic_pedestal.tscn",
	"mist_gate": "res://src/gameplay/world/mist_gate.tscn",
	"pickup": "res://src/gameplay/items/pickup.tscn",
	"door": "res://src/gameplay/world/room_door.tscn",
	"prop": "res://src/gameplay/world/prop.tscn",
}

signal build_failed(room_id: String, reason: String)

var room_id: String = ""
var display_name: String = ""
var music_track: String = "explore"

## Room bounds in pixels, used for camera limits.
var bounds: Rect2 = Rect2()

## Grid cell this room occupies on the map screen.
var map_rect: Rect2i = Rect2i(0, 0, 1, 1)

var background: TileMapLayer
var solid: TileMapLayer
var platforms: TileMapLayer
var entities: Node2D

var _doors: Dictionary = {}
var _tile_size: int = 16
var _data: Dictionary = {}


func _ready() -> void:
	_create_layers()


func _create_layers() -> void:
	if background != null:
		return
	var tileset: TileSet = TileSetBuilder.build()
	_tile_size = tileset.tile_size.x if tileset != null else 16

	background = TileMapLayer.new()
	background.name = "Background"
	background.tile_set = tileset
	background.z_index = -10
	# Background tiles are decorative; switching collision off avoids building
	# physics bodies that could never be hit anyway.
	background.collision_enabled = false
	add_child(background)

	solid = TileMapLayer.new()
	solid.name = "Solid"
	solid.tile_set = tileset
	solid.z_index = -1
	add_child(solid)

	platforms = TileMapLayer.new()
	platforms.name = "Platforms"
	platforms.tile_set = tileset
	platforms.z_index = -1
	platforms.add_to_group(&"one_way_platform")
	add_child(platforms)

	entities = Node2D.new()
	entities.name = "Entities"
	add_child(entities)


## Load and construct a room. Returns false if the data is missing or invalid.
func build(id: String) -> bool:
	_create_layers()
	room_id = id

	_data = _load_room_data(id)
	if _data.is_empty():
		build_failed.emit(id, "missing or unreadable room data")
		return false

	display_name = String(_data.get("name", id))
	music_track = String(_data.get("music", "explore"))

	var map_info: Dictionary = _data.get("map", {}) as Dictionary
	map_rect = Rect2i(
		int(map_info.get("x", 0)), int(map_info.get("y", 0)),
		maxi(1, int(map_info.get("w", 1))), maxi(1, int(map_info.get("h", 1))))

	var legend: Dictionary = _data.get("legend", {}) as Dictionary
	if legend.is_empty():
		build_failed.emit(id, "room has no tile legend")
		return false

	var fg: Array = _data.get("fg", []) as Array
	var bg: Array = _data.get("bg", []) as Array

	_compute_bounds(fg, bg)
	# Most rooms want a uniform masonry backdrop; `bg_fill` paints it in one key
	# so room files only spell out the background where it actually varies.
	_fill_background(String(_data.get("bgFill", "")), fg)
	_paint(bg, legend, true)
	_paint(fg, legend, false)
	_spawn_entities()
	_spawn_doors()

	GameState.discover_room(room_id)
	return true


func _load_room_data(id: String) -> Dictionary:
	# Room files follow the project's `[system]_[name].json` data-file convention.
	var path: String = "%s/room_%s.json" % [ROOM_DATA_DIR, id]
	if not FileAccess.file_exists(path):
		push_error("Room: no data file at %s" % path)
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Room: cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return {}
	var text: String = file.get_as_text()
	file.close()

	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		push_error("Room: JSON error in %s line %d: %s"
			% [path, parser.get_error_line(), parser.get_error_message()])
		return {}
	if typeof(parser.data) != TYPE_DICTIONARY:
		push_error("Room: %s must contain a JSON object" % path)
		return {}
	return parser.data


## Paint an ASCII grid into the correct layers.
##
## [param force_background] sends every tile to the background layer regardless
## of role, which is what the `bg` grid wants.
func _paint(grid: Array, legend: Dictionary, force_background: bool) -> void:
	for y: int in range(grid.size()):
		var row: String = String(grid[y])
		for x: int in range(row.length()):
			var glyph: String = row[x]
			if glyph == "." or glyph == " ":
				continue
			if not legend.has(glyph):
				push_warning("Room %s: glyph '%s' at (%d,%d) is not in the legend"
					% [room_id, glyph, x, y])
				continue

			var tile_name: String = String(legend[glyph])
			var coords: Vector2i = TileSetBuilder.coord(tile_name)
			if coords.x < 0:
				continue

			var target: TileMapLayer = background
			if not force_background:
				match TileSetBuilder.role_of(tile_name):
					"solid", "hazard":
						target = solid
					"oneWay":
						target = platforms
					_:
						target = background
			target.set_cell(Vector2i(x, y), 0, coords)


## Paint a uniform backdrop across the whole room footprint.
func _fill_background(tile_name: String, fg: Array) -> void:
	if tile_name == "":
		return
	var coords: Vector2i = TileSetBuilder.coord(tile_name)
	if coords.x < 0:
		return
	var height: int = fg.size()
	for y: int in range(height):
		var width: int = String(fg[y]).length()
		for x: int in range(width):
			background.set_cell(Vector2i(x, y), 0, coords)


func _compute_bounds(fg: Array, bg: Array) -> void:
	var width: int = 0
	var height: int = maxi(fg.size(), bg.size())
	for row: Variant in fg:
		width = maxi(width, String(row).length())
	for row: Variant in bg:
		width = maxi(width, String(row).length())
	bounds = Rect2(
		Vector2.ZERO,
		Vector2(float(width * _tile_size), float(height * _tile_size)))


## Convert tile coordinates to a world position at the bottom-centre of the cell,
## which is where a character standing "on" that tile belongs.
func tile_to_world(tx: float, ty: float) -> Vector2:
	return Vector2(
		(tx + 0.5) * float(_tile_size),
		(ty + 1.0) * float(_tile_size))


func _spawn_entities() -> void:
	for entry: Variant in (_data.get("entities", []) as Array):
		var spec: Dictionary = entry as Dictionary
		var type: String = String(spec.get("type", ""))

		# A one-shot entity whose flag is already set is skipped entirely — this
		# is how collected relics and defeated bosses stay gone.
		var skip_flag: String = String(spec.get("skipIfFlag", ""))
		if skip_flag != "" and GameState.get_flag(skip_flag):
			continue

		if type == "medusa_spawner":
			_spawn_medusa_spawner(spec)
			continue

		if not ENTITY_SCENES.has(type):
			push_warning("Room %s: unknown entity type '%s'" % [room_id, type])
			continue

		var scene: PackedScene = load(ENTITY_SCENES[type]) as PackedScene
		if scene == null:
			push_error("Room %s: could not load scene for '%s'" % [room_id, type])
			continue

		var node: Node = scene.instantiate()
		# Configure BEFORE entering the tree. `add_child` runs `_ready`, and
		# several entities read their exported properties there — a RelicPedestal
		# checks its world flag on ready, so configuring afterwards left it
		# permanently un-collected.
		if node is Node2D:
			(node as Node2D).position = tile_to_world(
				float(spec.get("x", 0)), float(spec.get("y", 0)))
		_configure_entity(node, type, spec)
		entities.add_child(node)


func _configure_entity(node: Node, type: String, spec: Dictionary) -> void:
	match type:
		"relic":
			node.set("relic_id", String(spec.get("relicId", "")))
			node.set("display_name", String(spec.get("displayName", "Relic")))
			node.set("flag", String(spec.get("flag", "")))
			match String(spec.get("relicType", "ability")):
				"subweapon":
					node.set("relic_type", RelicPedestal.RelicType.SUBWEAPON)
				"weapon":
					node.set("relic_type", RelicPedestal.RelicType.WEAPON)
				_:
					node.set("relic_type", RelicPedestal.RelicType.ABILITY)
		"save_point":
			node.set("respawn_door", String(spec.get("respawnDoor", "save")))
			if node.has_method("set_room"):
				node.call_deferred("set_room", room_id)
		"pickup":
			if node.has_method("configure"):
				node.set("item_id", String(spec.get("item", "heart")))
				node.set("lifetime", 0.0)  # Placed pickups never despawn.
		"mist_gate":
			var height: float = float(spec.get("height", 48))
			_resize_mist_gate(node, height)
		"prop":
			node.set("prop_animation", String(spec.get("prop", "torch")))
			node.set("emits_light", bool(spec.get("light", false)))
		"sanguine_knight":
			# Give the boss the room rectangle so its charge knows where to stop.
			node.call_deferred("set_arena_bounds", bounds)


func _resize_mist_gate(node: Node, height: float) -> void:
	var shape_node := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		var rect := shape_node.shape as RectangleShape2D
		if rect != null:
			# Duplicate first: sub-resources are shared between instances of the
			# same scene, so resizing in place would resize every gate.
			rect = rect.duplicate() as RectangleShape2D
			rect.size = Vector2(16.0, height)
			shape_node.shape = rect
	var visual := node.get_node_or_null("Visual") as ColorRect
	if visual != null:
		visual.offset_top = -height * 0.5
		visual.offset_bottom = height * 0.5


func _spawn_medusa_spawner(spec: Dictionary) -> void:
	var spawner := MedusaSpawner.new()
	spawner.direction = int(spec.get("direction", -1))
	spawner.vertical_spread = float(spec.get("spread", 34.0))
	entities.add_child(spawner)
	spawner.position = tile_to_world(float(spec.get("x", 0)), float(spec.get("y", 0)))


func _spawn_doors() -> void:
	var scene: PackedScene = load(ENTITY_SCENES["door"]) as PackedScene
	if scene == null:
		push_error("Room: could not load the door scene")
		return

	for entry: Variant in (_data.get("doors", []) as Array):
		var spec: Dictionary = entry as Dictionary
		var door := scene.instantiate() as RoomDoor
		door.door_id = String(spec.get("id", ""))
		door.target_room = String(spec.get("to", ""))
		door.target_door = String(spec.get("toDoor", ""))
		door.entry_direction = int(spec.get("dir", 1))
		entities.add_child(door)
		door.position = tile_to_world(float(spec.get("x", 0)), float(spec.get("y", 0)))
		# Doors are full-height openings; centre the trigger on the gap.
		door.position.y -= float(spec.get("height", 2)) * float(_tile_size) * 0.5
		_doors[door.door_id] = door


## Where the player should appear when entering through [param door_id].
##
## Falls back to the room's declared `spawn` point, then to the room centre, so a
## bad door reference never drops the player into the void.
func spawn_point_for(door_id: String) -> Vector2:
	if _doors.has(door_id):
		return (_doors[door_id] as RoomDoor).spawn_position()

	var spawn: Dictionary = _data.get("spawn", {}) as Dictionary
	if not spawn.is_empty():
		return tile_to_world(float(spawn.get("x", 1)), float(spawn.get("y", 1)))

	if door_id != "":
		push_warning("Room %s has no door '%s'; using the default spawn"
			% [room_id, door_id])
	return bounds.get_center()


## Facing the player should adopt on arrival.
func entry_facing_for(door_id: String) -> int:
	if _doors.has(door_id):
		return (_doors[door_id] as RoomDoor).entry_direction
	return 1


func door_ids() -> Array:
	return _doors.keys()
