class_name SpriteSheetLoader
extends RefCounted

## Builds [SpriteFrames] at runtime from a generated atlas + JSON manifest.
##
## The art pipeline (tools/asset-pipeline/generate_assets.py) emits a horizontal
## strip PNG plus a manifest describing where each animation starts. Constructing
## SpriteFrames from that at load time — instead of committing large hand-written
## .tres resources — means regenerating art never produces a merge conflict and
## the animation table can never drift out of sync with the image.
##
## Results are cached per-path: every Nightwing in a room shares one SpriteFrames
## instance and therefore one set of AtlasTextures.

static var _cache: Dictionary = {}


## Load the SpriteFrames for an atlas.
##
## [param png_path] path to the strip image, e.g. `res://assets/art/characters/player.png`.
## The manifest is assumed to sit beside it with a `.json` extension.
## Returns null and pushes an error if either file is missing or malformed.
static func load_frames(png_path: String) -> SpriteFrames:
	if _cache.has(png_path):
		return _cache[png_path]

	var json_path: String = png_path.get_basename() + ".json"
	var manifest: Dictionary = _read_manifest(json_path)
	if manifest.is_empty():
		return null

	var texture: Texture2D = load(png_path) as Texture2D
	if texture == null:
		push_error("SpriteSheetLoader: could not load texture at %s" % png_path)
		return null

	var frame_w: int = int(manifest.get("frameWidth", 0))
	var frame_h: int = int(manifest.get("frameHeight", 0))
	if frame_w <= 0 or frame_h <= 0:
		push_error("SpriteSheetLoader: %s has invalid frame size %dx%d"
			% [json_path, frame_w, frame_h])
		return null

	var animations: Dictionary = manifest.get("animations", {}) as Dictionary
	if animations.is_empty():
		push_error("SpriteSheetLoader: %s declares no animations" % json_path)
		return null

	var frames: SpriteFrames = SpriteFrames.new()
	# SpriteFrames always ships with a "default" animation; drop it so callers
	# cannot accidentally play an empty track.
	frames.remove_animation("default")

	var total_frames: int = int(manifest.get("frameCount", 0))
	# Generated atlases are a single horizontal strip; imported third-party
	# sheets are grids. `columns` covers both — absent means one long row.
	var columns: int = int(manifest.get("columns", maxi(1, total_frames)))
	if columns <= 0:
		columns = maxi(1, total_frames)

	for anim_name: String in animations.keys():
		var info: Dictionary = animations[anim_name]
		var start: int = int(info.get("start", 0))
		var count: int = int(info.get("count", 0))
		if count <= 0:
			push_warning("SpriteSheetLoader: animation '%s' in %s has no frames"
				% [anim_name, json_path])
			continue
		if total_frames > 0 and start + count > total_frames:
			push_error("SpriteSheetLoader: animation '%s' in %s runs past the end of the strip"
				% [anim_name, json_path])
			continue

		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(info.get("fps", 10.0)))
		frames.set_animation_loop(anim_name, bool(info.get("loop", true)))

		for i: int in range(count):
			var index: int = start + i
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(
				float((index % columns) * frame_w),
				float((index / columns) * frame_h),
				float(frame_w), float(frame_h))
			# Keeps the sub-image from bleeding into its neighbour when the
			# viewport scales to a non-integer factor.
			atlas.filter_clip = true
			frames.add_frame(anim_name, atlas)

	_cache[png_path] = frames
	return frames


static func _read_manifest(json_path: String) -> Dictionary:
	if not FileAccess.file_exists(json_path):
		push_error("SpriteSheetLoader: missing manifest %s" % json_path)
		return {}

	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("SpriteSheetLoader: cannot open %s (error %d)"
			% [json_path, FileAccess.get_open_error()])
		return {}
	var text: String = file.get_as_text()
	file.close()

	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		push_error("SpriteSheetLoader: JSON error in %s line %d: %s"
			% [json_path, parser.get_error_line(), parser.get_error_message()])
		return {}
	if typeof(parser.data) != TYPE_DICTIONARY:
		push_error("SpriteSheetLoader: %s must contain a JSON object" % json_path)
		return {}
	return parser.data


## Apply an atlas to an [AnimatedSprite2D] and start an animation.
## Returns false if the atlas could not be loaded.
static func apply(sprite: AnimatedSprite2D, png_path: String, initial_animation: String = "") -> bool:
	var frames: SpriteFrames = load_frames(png_path)
	if frames == null:
		return false
	sprite.sprite_frames = frames
	if initial_animation != "" and frames.has_animation(initial_animation):
		sprite.play(initial_animation)
	return true


## Drop the cache. Only needed by tests and by hot-reloading tools.
static func clear_cache() -> void:
	_cache.clear()
