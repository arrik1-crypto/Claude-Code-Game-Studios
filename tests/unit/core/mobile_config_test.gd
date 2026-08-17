extends TestCase

## The project settings that only take effect on a phone.
##
## Everything asserted here is invisible during desktop development and during
## the headless screenshot capture, which is exactly why it needs a test. The
## handheld orientation shipped as SCREEN_PORTRAIT for this entire project —
## a landscape-only Metroidvania with a 16:9 viewport and a two-thumb touch
## layout — and nothing caught it until a built APK's binary manifest was
## decoded by hand. Desktop ignores the setting, so every screenshot looked
## correct.
##
## These are cheap reads of ProjectSettings. They cost nothing and they close a
## class of bug that otherwise only surfaces on a real device.

## DisplayServer.ScreenOrientation values that keep the long edge horizontal.
const LANDSCAPE_ORIENTATIONS: PackedInt32Array = [
	DisplayServer.SCREEN_LANDSCAPE,
	DisplayServer.SCREEN_REVERSE_LANDSCAPE,
	DisplayServer.SCREEN_SENSOR_LANDSCAPE,
]

const REFERENCE_WIDTH: int = 480
const REFERENCE_HEIGHT: int = 270


func _setting(key: String) -> Variant:
	return ProjectSettings.get_setting(key)


func test_the_game_is_locked_to_landscape_on_handhelds() -> void:
	var orientation: int = int(_setting("display/window/handheld/orientation"))
	var message: String = (
		"handheld orientation is %d; the game is landscape-only, so it must be one of %s"
		% [orientation, str(LANDSCAPE_ORIENTATIONS)])
	assert_true(LANDSCAPE_ORIENTATIONS.has(orientation), message)


func test_the_reference_viewport_is_landscape() -> void:
	# If this ever went portrait, the orientation assertion above would be
	# testing the wrong thing.
	var width: int = int(_setting("display/window/size/viewport_width"))
	var height: int = int(_setting("display/window/size/viewport_height"))
	assert_eq(width, REFERENCE_WIDTH, "reference width")
	assert_eq(height, REFERENCE_HEIGHT, "reference height")
	assert_gt(float(width), float(height), "the reference viewport must be wider than it is tall")


func test_android_export_prerequisite_is_enabled() -> void:
	# Godot refuses an Android export outright without this, and does it
	# silently — the validation sets its failure flag without writing a message,
	# so the export just says "configuration errors:" and stops.
	assert_true(bool(_setting("rendering/textures/vram_compression/import_etc2_astc")),
		"ETC2/ASTC import must be on or the Android export cannot run at all")


func test_the_mobile_renderer_is_selected() -> void:
	# The Android exporter warns that forward_plus is a desktop renderer.
	assert_eq(String(_setting("rendering/renderer/rendering_method.mobile")), "mobile",
		"phones must use the mobile renderer")


func test_pixel_art_is_not_smoothed_or_fractionally_scaled() -> void:
	assert_eq(int(_setting("rendering/textures/canvas_textures/default_texture_filter")), 0,
		"texture filter must be Nearest or the pixel art blurs")
	assert_eq(String(_setting("display/window/stretch/mode")), "canvas_items",
		"canvas_items stretch keeps the 480x270 reference grid")
	assert_eq(String(_setting("display/window/stretch/scale_mode")), "integer",
		"integer scaling stops pixels shimmering at non-multiple resolutions")


func test_the_game_ships_without_a_debug_orientation_override() -> void:
	# A window_width_override is a development convenience. It must not imply a
	# portrait window, which would contradict the handheld setting.
	var w: int = int(_setting("display/window/size/window_width_override"))
	var h: int = int(_setting("display/window/size/window_height_override"))
	if w > 0 and h > 0:
		assert_gt(float(w), float(h), "the dev window override must also be landscape")
