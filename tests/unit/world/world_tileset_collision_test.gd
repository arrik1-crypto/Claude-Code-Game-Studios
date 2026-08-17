extends TestCase

## Asserts that the generated TileSet actually carries collision.
##
## Regression guard. The first version of [TileSetBuilder] created tiles before
## attaching the atlas source to the TileSet. Godot logs an error but keeps
## going, producing a TileSet whose tiles look correct and have *no collision
## polygons at all* — every floor in the castle became walk-through. Checking
## that tiles are present is not enough; the polygons have to be asserted.


func before_each() -> void:
	# Rebuild from scratch so the assertions never inspect a stale cache.
	TileSetBuilder.clear_cache()


func after_each() -> void:
	TileSetBuilder.clear_cache()


func _tile_data(tile_name: String) -> TileData:
	var tileset: TileSet = TileSetBuilder.build()
	if tileset == null:
		return null
	var source := tileset.get_source(0) as TileSetAtlasSource
	if source == null:
		return null
	return source.get_tile_data(TileSetBuilder.coord(tile_name), 0)


func test_tileset_declares_both_physics_layers() -> void:
	var tileset: TileSet = TileSetBuilder.build()
	assert_not_null(tileset, "the TileSet must build")
	assert_eq(tileset.get_physics_layers_count(), 2,
		"one layer for solid world geometry, one for drop-through platforms")
	assert_eq(tileset.get_physics_layer_collision_layer(TileSetBuilder.PHYSICS_LAYER_WORLD), 1,
		"solid geometry sits on the 'world' collision layer")
	assert_eq(tileset.get_physics_layer_collision_layer(TileSetBuilder.PHYSICS_LAYER_ONE_WAY), 128,
		"platforms sit on the 'one_way' collision layer")


func test_atlas_source_is_attached_to_the_tileset() -> void:
	var tileset: TileSet = TileSetBuilder.build()
	assert_eq(tileset.get_source_count(), 1, "exactly one atlas source")
	var source := tileset.get_source(0) as TileSetAtlasSource
	assert_not_null(source, "source 0 must be a TileSetAtlasSource")
	assert_not_null(source.texture, "the atlas source must carry the tile texture")


func test_solid_tiles_have_a_collision_polygon() -> void:
	for tile_name: String in ["brick_solid", "brick_top", "floor_stone", "pillar_mid"]:
		var data: TileData = _tile_data(tile_name)
		assert_not_null(data, "%s must exist in the atlas" % tile_name)
		if data == null:
			continue
		assert_eq(data.get_collision_polygons_count(TileSetBuilder.PHYSICS_LAYER_WORLD), 1,
			"%s must collide, or the player falls through the castle" % tile_name)
		assert_eq(
			data.get_collision_polygon_points(TileSetBuilder.PHYSICS_LAYER_WORLD, 0).size(), 4,
			"%s uses a full-cell quad" % tile_name)


func test_platform_tiles_collide_one_way_only() -> void:
	var data: TileData = _tile_data("platform")
	assert_not_null(data, "the platform tile must exist")
	if data == null:
		return
	assert_eq(data.get_collision_polygons_count(TileSetBuilder.PHYSICS_LAYER_WORLD), 0,
		"platforms must not be solid or they could not be dropped through")
	assert_eq(data.get_collision_polygons_count(TileSetBuilder.PHYSICS_LAYER_ONE_WAY), 1,
		"platforms need a polygon on the one-way layer")
	assert_true(data.is_collision_polygon_one_way(TileSetBuilder.PHYSICS_LAYER_ONE_WAY, 0),
		"the platform polygon must be flagged one-way")


func test_decorative_tiles_have_no_collision() -> void:
	for tile_name: String in ["bg_brick", "bg_window", "bg_arch", "iron_rail"]:
		var data: TileData = _tile_data(tile_name)
		assert_not_null(data, "%s must exist in the atlas" % tile_name)
		if data == null:
			continue
		assert_eq(data.get_collision_polygons_count(TileSetBuilder.PHYSICS_LAYER_WORLD), 0,
			"%s is scenery and must never block the player" % tile_name)
		assert_eq(data.get_collision_polygons_count(TileSetBuilder.PHYSICS_LAYER_ONE_WAY), 0,
			"%s must not act as a platform" % tile_name)


func test_hazard_tiles_are_solid_so_they_can_be_landed_on() -> void:
	var data: TileData = _tile_data("spikes")
	assert_not_null(data, "the spike tile must exist")
	if data == null:
		return
	assert_eq(data.get_collision_polygons_count(TileSetBuilder.PHYSICS_LAYER_WORLD), 1,
		"spikes collide, then damage on contact")


func test_every_tile_records_its_role_in_custom_data() -> void:
	var tileset: TileSet = TileSetBuilder.build()
	var source := tileset.get_source(0) as TileSetAtlasSource
	var checked: int = 0
	for tile_name: String in ["brick_solid", "platform", "spikes", "bg_brick"]:
		var data: TileData = source.get_tile_data(TileSetBuilder.coord(tile_name), 0)
		if data == null:
			continue
		var role: String = String(data.get_custom_data(TileSetBuilder.DATA_LAYER_ROLE))
		assert_eq(role, TileSetBuilder.role_of(tile_name),
			"%s custom data must agree with the manifest" % tile_name)
		checked += 1
	assert_eq(checked, 4, "all four sample tiles were inspected")
