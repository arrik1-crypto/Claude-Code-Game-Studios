extends TestCase

## Guards the rendering stack against silently-invisible effects.
##
## This suite exists because of a specific bug class. The game shipped with
## `PointLight2D` nodes on every torch and no `CanvasModulate` anywhere, so the
## canvas was already at full brightness and each light rendered exactly zero
## pixels. Nothing errored, nothing failed, and the lights were simply absent.
##
## Asserting that a light *node exists* would not have caught it. These tests
## assert the conditions that make lights actually visible.

var _host: Node2D


func before_each() -> void:
	_host = Node2D.new()
	Engine.get_main_loop().root.add_child(_host)
	GameState.new_game()
	LightingQuality.clear_cache()


func after_each() -> void:
	if is_instance_valid(_host):
		_host.queue_free()
	LightingQuality.clear_cache()


func _build(room_id: String) -> Room:
	var room := Room.new()
	_host.add_child(room)
	room.build(room_id)
	return room


# -- Ambient darkness --------------------------------------------------------


func test_every_room_creates_a_canvas_modulate() -> void:
	# Without this node, every light in the room is a no-op.
	for room_id: String in RoomIndex.all():
		var room: Room = _build(room_id)
		assert_not_null(room.lighting, "%s has no RoomLighting" % room_id)


func test_ambient_is_actually_dark_enough_for_lights_to_register() -> void:
	var room: Room = _build("entrance_hall")
	assert_not_null(room.lighting, "entrance_hall needs ambient")
	if room.lighting == null:
		return
	var c: Color = room.lighting.color
	# At full white there is nothing for a light to add; at near-black the game
	# is unplayable on a phone in daylight. Both ends are real failure modes.
	assert_lt(maxf(maxf(c.r, c.g), c.b), 0.95,
		"ambient must be below full brightness or lights do nothing")
	assert_gt(minf(minf(c.r, c.g), c.b), 0.15,
		"ambient must stay playable on a mobile screen")


func test_ambient_presets_differ_from_each_other() -> void:
	assert_ne(RoomLighting.DEFAULT_AMBIENT, RoomLighting.DARK_AMBIENT,
		"the dark preset must actually be darker")
	assert_lt(RoomLighting.DARK_AMBIENT.r, RoomLighting.DEFAULT_AMBIENT.r,
		"'dark' must be dimmer than 'default'")
	assert_gt(RoomLighting.MOONLIT_AMBIENT.r, RoomLighting.DEFAULT_AMBIENT.r,
		"'moonlit' must be brighter than 'default'")


func test_room_ambient_preset_is_applied_from_data() -> void:
	var throne: Room = _build("throne_of_ash")
	assert_eq(throne.lighting.color, RoomLighting.DARK_AMBIENT,
		"throne_of_ash declares the dark preset")
	var ward: Room = _build("outer_ward_gate")
	assert_eq(ward.lighting.color, RoomLighting.MOONLIT_AMBIENT,
		"outer_ward_gate declares the moonlit preset")


func test_unknown_preset_falls_back_rather_than_going_black() -> void:
	var lighting := RoomLighting.new()
	_host.add_child(lighting)
	lighting.apply_preset("not_a_real_preset")
	assert_eq(lighting.color, RoomLighting.DEFAULT_AMBIENT,
		"an unknown preset must not leave the room unlit or pitch black")


# -- Light budget ------------------------------------------------------------


func test_lights_are_produced_with_a_texture_and_energy() -> void:
	LightingQuality.set_tier(LightingQuality.Tier.SIMPLE)
	var light: PointLight2D = LightingQuality.make_light(Color.WHITE, 1.0)
	assert_not_null(light, "SIMPLE tier must produce lights")
	if light == null:
		return
	# A PointLight2D with no texture renders nothing at all.
	assert_not_null(light.texture, "a light with no texture is invisible")
	assert_gt(light.energy, 0.0, "a light with zero energy is invisible")
	light.free()


func test_off_tier_produces_no_lights() -> void:
	LightingQuality.set_tier(LightingQuality.Tier.OFF)
	assert_true(LightingQuality.make_light(Color.WHITE, 1.0) == null,
		"the OFF tier must not allocate lights")
	assert_false(LightingQuality.lights_enabled(), "lights are reported disabled")


func test_shadows_only_at_the_highest_tier() -> void:
	LightingQuality.set_tier(LightingQuality.Tier.SIMPLE)
	var simple: PointLight2D = LightingQuality.make_light(Color.WHITE, 1.0, 2.0, true)
	assert_false(simple.shadow_enabled,
		"mobile tier must refuse shadows even when asked")
	simple.free()

	LightingQuality.set_tier(LightingQuality.Tier.SHADOWS)
	var full: PointLight2D = LightingQuality.make_light(Color.WHITE, 1.0, 2.0, true)
	assert_true(full.shadow_enabled, "the top tier honours a shadow request")
	full.free()


func test_light_texture_is_shared_not_reallocated() -> void:
	LightingQuality.set_tier(LightingQuality.Tier.SIMPLE)
	var a: PointLight2D = LightingQuality.make_light(Color.WHITE, 1.0)
	var b: PointLight2D = LightingQuality.make_light(Color.WHITE, 1.0)
	assert_true(a.texture == b.texture,
		"every light must share one gradient texture, not allocate its own")
	a.free()
	b.free()


func test_room_light_budget_is_capped() -> void:
	LightingQuality.set_tier(LightingQuality.Tier.SIMPLE)
	assert_gt(float(LightingQuality.max_lights()), 0.0, "mobile still gets lights")
	assert_le(float(LightingQuality.max_lights()), 12.0,
		"the mobile light cap must stay modest for fill rate")


# -- Occlusion ---------------------------------------------------------------


func test_solid_tiles_occlude_light_and_scenery_does_not() -> void:
	TileSetBuilder.clear_cache()
	var tileset: TileSet = TileSetBuilder.build()
	assert_eq(tileset.get_occlusion_layers_count(), 1,
		"one occlusion layer is needed for lantern shadows")

	var source := tileset.get_source(0) as TileSetAtlasSource
	var brick: TileData = source.get_tile_data(TileSetBuilder.coord("brick_solid"), 0)
	assert_not_null(brick.get_occluder(TileSetBuilder.OCCLUSION_LAYER),
		"masonry must cast shadows")

	var backdrop: TileData = source.get_tile_data(TileSetBuilder.coord("bg_brick"), 0)
	assert_true(backdrop.get_occluder(TileSetBuilder.OCCLUSION_LAYER) == null,
		"decorative backdrop must not cast shadows")

	var plank: TileData = source.get_tile_data(TileSetBuilder.coord("platform"), 0)
	assert_true(plank.get_occluder(TileSetBuilder.OCCLUSION_LAYER) == null,
		"a drop-through plank casting a shadow across the wall behind it is wrong")
	TileSetBuilder.clear_cache()


# -- Backdrop ----------------------------------------------------------------


func test_only_outdoor_rooms_request_the_skyline() -> void:
	var outdoor: int = 0
	for room_id: String in RoomIndex.all():
		if _build(room_id).shows_sky:
			outdoor += 1
	assert_gt(float(outdoor), 0.0, "at least one room must show the skyline")
	assert_lt(float(outdoor), float(RoomIndex.all().size()),
		"interior rooms must not draw a backdrop their masonry would hide")
