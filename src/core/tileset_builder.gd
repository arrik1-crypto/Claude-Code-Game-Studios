class_name TileSetBuilder
extends RefCounted

## Builds a [TileSet] at runtime from the generated tile atlas + manifest.
##
## Same rationale as [SpriteSheetLoader]: the tile atlas is generated, so the
## TileSet is derived from it rather than hand-maintained. The manifest declares
## which tiles are solid, one-way, hazardous or purely decorative, and this
## builder turns those declarations into physics polygons.
##
## Physics layers follow project.godot:
##   layer 1 "world"    — full collision
##   layer 8 "one_way"  — drop-through platforms

const TILESET_PNG: String = "res://assets/art/tiles/castle_tileset.png"
const TILESET_JSON: String = "res://assets/art/tiles/castle_tileset.json"

## Physics layer index (0-based) used for solid world geometry.
const PHYSICS_LAYER_WORLD: int = 0
## Physics layer index used for one-way platforms.
const PHYSICS_LAYER_ONE_WAY: int = 1

## Occlusion layer index used for shadow casting from solid tiles.
const OCCLUSION_LAYER: int = 0

## Custom data layer name recording each tile's role, so gameplay code can ask
## "is this a hazard?" without hardcoding atlas coordinates.
const DATA_LAYER_ROLE: String = "role"

static var _cached: TileSet = null
static var _tile_lookup: Dictionary = {}
static var _role_lookup: Dictionary = {}


## Build (or return the cached) castle TileSet.
static func build() -> TileSet:
	if _cached != null:
		return _cached

	var manifest: Dictionary = _read_manifest()
	if manifest.is_empty():
		return null

	var texture: Texture2D = load(TILESET_PNG) as Texture2D
	if texture == null:
		push_error("TileSetBuilder: could not load %s" % TILESET_PNG)
		return null

	var tile_size: int = int(manifest.get("tileSize", 16))
	var tiles: Dictionary = manifest.get("tiles", {}) as Dictionary
	if tiles.is_empty():
		push_error("TileSetBuilder: %s declares no tiles" % TILESET_JSON)
		return null

	var roles: Dictionary = _role_map(manifest)
	_role_lookup = roles

	var tileset: TileSet = TileSet.new()
	tileset.tile_size = Vector2i(tile_size, tile_size)

	# Append (-1) so the resulting indices match PHYSICS_LAYER_* in order.
	tileset.add_physics_layer(-1)
	tileset.set_physics_layer_collision_layer(PHYSICS_LAYER_WORLD, 1)  # "world"
	tileset.add_physics_layer(-1)
	tileset.set_physics_layer_collision_layer(PHYSICS_LAYER_ONE_WAY, 128)  # "one_way"

	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(0, DATA_LAYER_ROLE)
	tileset.set_custom_data_layer_type(0, TYPE_STRING)

	# Occlusion layer so solid masonry casts shadows from the player's lantern.
	# Building it is nearly free; it only costs anything when a shadow-casting
	# light exists, which is gated to the highest quality tier.
	tileset.add_occlusion_layer(-1)
	tileset.set_occlusion_layer_light_mask(OCCLUSION_LAYER, 1)

	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(tile_size, tile_size)

	# The source MUST be attached to the TileSet before any tile is created:
	# TileData resolves its physics and custom-data layers through the owning
	# TileSet, and a detached source silently produces tiles with no collision.
	tileset.add_source(source, 0)

	var half: float = float(tile_size) * 0.5
	var full_square: PackedVector2Array = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])
	# One-way platforms only occupy the top few pixels of their cell, so the
	# player's feet land on the plank rather than floating above the bracket.
	var platform_top: PackedVector2Array = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, -half + 4.0), Vector2(-half, -half + 4.0),
	])

	_tile_lookup.clear()

	for tile_name: String in tiles.keys():
		var coord_data: Dictionary = tiles[tile_name]
		var coords := Vector2i(int(coord_data.get("x", 0)), int(coord_data.get("y", 0)))
		source.create_tile(coords)
		var data: TileData = source.get_tile_data(coords, 0)

		var role: String = String(roles.get(tile_name, "decor"))
		data.set_custom_data(DATA_LAYER_ROLE, role)

		match role:
			"solid", "hazard":
				data.add_collision_polygon(PHYSICS_LAYER_WORLD)
				data.set_collision_polygon_points(PHYSICS_LAYER_WORLD, 0, full_square)
				# Only solid masonry blocks light. Platforms and scenery do not,
				# so a plank never casts a shadow across the wall behind it.
				var occluder := OccluderPolygon2D.new()
				occluder.polygon = full_square
				data.set_occluder(OCCLUSION_LAYER, occluder)
			"oneWay":
				data.add_collision_polygon(PHYSICS_LAYER_ONE_WAY)
				data.set_collision_polygon_points(PHYSICS_LAYER_ONE_WAY, 0, platform_top)
				data.set_collision_polygon_one_way(PHYSICS_LAYER_ONE_WAY, 0, true)
			_:
				pass  # Decorative tiles carry no collision at all.

		_tile_lookup[tile_name] = coords

	_cached = tileset
	return tileset


## Atlas coordinate for a logical tile name, e.g. `TileSetBuilder.coord("platform")`.
## Returns Vector2i(-1, -1) for an unknown name.
static func coord(tile_name: String) -> Vector2i:
	if _tile_lookup.is_empty():
		build()
	if not _tile_lookup.has(tile_name):
		push_error("TileSetBuilder: unknown tile name '%s'" % tile_name)
		return Vector2i(-1, -1)
	return _tile_lookup[tile_name]


## Role of a tile: "solid", "oneWay", "hazard" or "decor".
##
## The room builder uses this to route each tile to the correct TileMapLayer, so
## the manifest stays the single source of truth for what a tile does.
static func role_of(tile_name: String) -> String:
	if _role_lookup.is_empty():
		build()
	return String(_role_lookup.get(tile_name, "decor"))


static func _role_map(manifest: Dictionary) -> Dictionary:
	var roles: Dictionary = {}
	for role: String in ["solid", "oneWay", "hazard", "decor"]:
		var names: Array = manifest.get(role, []) as Array
		for n: Variant in names:
			roles[String(n)] = role
	return roles


static func _read_manifest() -> Dictionary:
	if not FileAccess.file_exists(TILESET_JSON):
		push_error("TileSetBuilder: missing %s" % TILESET_JSON)
		return {}
	var file: FileAccess = FileAccess.open(TILESET_JSON, FileAccess.READ)
	if file == null:
		push_error("TileSetBuilder: cannot open %s" % TILESET_JSON)
		return {}
	var text: String = file.get_as_text()
	file.close()

	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		push_error("TileSetBuilder: JSON error in %s line %d: %s"
			% [TILESET_JSON, parser.get_error_line(), parser.get_error_message()])
		return {}
	if typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	return parser.data


## Drop the cached TileSet. Tests use this to rebuild from modified manifests.
static func clear_cache() -> void:
	_cached = null
	_tile_lookup.clear()
	_role_lookup.clear()
