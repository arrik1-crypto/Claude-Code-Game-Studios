extends TestCase

## Touch controls must stay in the thumb corners on a real phone.
##
## The scene authors button positions against a 480x270 frame, but the project
## stretches with `expand`, so the visible canvas gets *wider* on a phone without
## getting taller: a 19.5:9 handset shows about 585x270 and a 20:9 about 600x270.
## Applied as raw coordinates, the right-hand cluster and the pause button land
## around 60% across — floating near the middle of the screen, out of reach of
## either thumb. A screenshot at 2340x1080 is what exposed it; every capture
## before that had been at 16:9, where the bug is invisible by construction.
##
## `TouchControls.anchored_position` is deliberately static and pure so this can
## be checked at any screen size without standing up a viewport.

const REFERENCE: Vector2 = Vector2(480, 270)

## Real handset canvases under `canvas_items` + `expand`, height pinned at 270.
const PHONE_16_9: Vector2 = Vector2(480, 270)
const PHONE_19_5_9: Vector2 = Vector2(585, 270)
const PHONE_20_9: Vector2 = Vector2(600, 270)

## How close to its edge a control must sit to count as thumb-reachable.
const REACHABLE_INSET: float = 140.0


func test_left_anchored_controls_do_not_move_when_the_screen_widens() -> void:
	# The stick is measured from the left edge, so a wider screen must not
	# shift it at all.
	var inset: Vector2 = Vector2(20, 68)
	for screen: Vector2 in [PHONE_16_9, PHONE_19_5_9, PHONE_20_9]:
		var at: Vector2 = TouchControls.anchored_position(inset, screen, 1.0, false, false)
		assert_eq(at.x, 20.0, "the stick stays %dpx from the left on a %dpx canvas"
			% [inset.x, screen.x])


func test_right_anchored_controls_track_the_right_edge() -> void:
	# BtnJump is authored at x=404 on a 480 frame, i.e. 76px in from the right.
	var inset: Vector2 = Vector2(76, 70)
	for screen: Vector2 in [PHONE_16_9, PHONE_19_5_9, PHONE_20_9]:
		var at: Vector2 = TouchControls.anchored_position(inset, screen, 1.0, true, false)
		assert_eq(at.x, screen.x - 76.0,
			"jump stays 76px from the right edge on a %dpx canvas" % screen.x)


func test_the_action_cluster_stays_in_the_right_thumb_zone_on_a_tall_phone() -> void:
	# This is the assertion that fails with the old fixed-coordinate layout: at
	# 585 wide, a hardcoded x=404 is 69% across rather than within reach of the
	# right edge.
	var jump: Vector2 = TouchControls.anchored_position(
		Vector2(76, 70), PHONE_19_5_9, 1.0, true, false)
	var distance_from_right: float = PHONE_19_5_9.x - jump.x
	var message: String = ("jump sits %.0fpx from the right edge on a 19.5:9 phone; "
		+ "anything beyond %.0fpx is outside the thumb zone") % [distance_from_right, REACHABLE_INSET]
	assert_lt(distance_from_right, REACHABLE_INSET, message)


func test_the_pause_button_stays_in_the_top_right_corner() -> void:
	# Authored at (448, 8): 32px from the right, 8px from the top.
	var at: Vector2 = TouchControls.anchored_position(
		Vector2(32, 8), PHONE_20_9, 1.0, true, true)
	assert_eq(at.x, PHONE_20_9.x - 32.0, "pause hugs the right edge")
	assert_eq(at.y, 8.0, "pause hugs the top edge")


func test_enlarging_the_controls_grows_them_inward_not_off_screen() -> void:
	# A player who scales the controls up for bigger targets must not have them
	# pushed past the edge of the display.
	var screen: Vector2 = PHONE_19_5_9
	for factor: float in [1.0, 1.5, 2.0]:
		var right: Vector2 = TouchControls.anchored_position(
			Vector2(76, 70), screen, factor, true, false)
		assert_lt(right.x, screen.x, "a %.1fx jump button stays on screen" % factor)
		assert_lt(right.y, screen.y, "a %.1fx jump button stays above the bottom" % factor)

		var left: Vector2 = TouchControls.anchored_position(
			Vector2(20, 68), screen, factor, false, false)
		assert_gt(left.x, 0.0, "a %.1fx stick stays right of the left edge" % factor)


## Stick centre, as authored: (50, 202) on the 480x270 frame.
const STICK_INSET: Vector2 = Vector2(50, 68)

## Attack is the leftmost control of the right-hand cluster: (344, 214), with a
## 48-unit shape, so its left edge is 24 units further left again.
const ATTACK_INSET: Vector2 = Vector2(136, 56)
const ATTACK_HALF_WIDTH: float = 24.0


func test_the_two_thumb_clusters_never_collide() -> void:
	# The stick must stay well clear of the action cluster at every screen width
	# and every control scale, or a thumb press hits the wrong control. Measured
	# edge-to-edge from real geometry, not centre-to-centre — the stick is 72
	# units across and the buttons grew, so centres alone would hide an overlap.
	for screen: Vector2 in [PHONE_16_9, PHONE_19_5_9, PHONE_20_9]:
		for factor: float in [1.0, 1.5]:
			var stick_centre: Vector2 = TouchControls.anchored_position(
				STICK_INSET, screen, factor, false, false)
			var stick_right: float = stick_centre.x + VirtualStick.BASE_RADIUS * factor

			var attack_centre: Vector2 = TouchControls.anchored_position(
				ATTACK_INSET, screen, factor, true, false)
			var attack_left: float = attack_centre.x - ATTACK_HALF_WIDTH * factor

			var message: String = ("the stick reaches x=%.0f and the action cluster starts "
				+ "at x=%.0f on a %dpx canvas at %.1fx") % [
					stick_right, attack_left, screen.x, factor]
			assert_lt(stick_right, attack_left, message)


# -- Physical target size -----------------------------------------------------
#
# The check that was missing. The GDD has the right formula in section 4 but only
# ever applied it to the *largest* button, and against a 7 mm bar rather than the
# ~9 mm / 48 dp standard. Eight of the ten controls were under it, including
# every movement input, and nothing failed — it took playing on a phone to find.

## Canvas units are multiplied by (screen_height / 270) to reach physical pixels.
const PHONE_HEIGHT_PX: float = 1080.0
const REFERENCE_HEIGHT: float = 270.0

## A typical modern handset. Roughly 15.75 physical pixels per millimetre.
const PHONE_PPI: float = 400.0
const MM_PER_INCH: float = 25.4

## The accessibility floor for a touch target that is held or tapped in action.
const MIN_TARGET_MM: float = 9.0


## Convert a control's authored size in canvas units to millimetres on a phone.
static func _canvas_units_to_mm(units: float) -> float:
	var physical_px: float = units * (PHONE_HEIGHT_PX / REFERENCE_HEIGHT)
	return physical_px / PHONE_PPI * MM_PER_INCH


func test_the_size_conversion_matches_the_gdd_formula() -> void:
	# Sanity-check the maths itself before trusting the assertions built on it.
	# 40 canvas units -> 160 physical px at 4x -> ~10.2 mm at 400 ppi.
	assert_almost_eq(_canvas_units_to_mm(40.0), 10.16, 0.05,
		"40 canvas units is about 10.2 mm on a 1080p 400 ppi phone")


func test_every_touch_target_clears_the_minimum_size() -> void:
	# Authored sizes from touch_controls.tscn. Kept here as data rather than read
	# from the scene so the test states the intended contract outright.
	var targets: Dictionary[String, float] = {
		"BtnJump": 48.0,
		"BtnAttack": 48.0,
		"BtnDash": 40.0,
		"BtnSubweapon": 40.0,
		"BtnPause": 40.0,
		"BtnMap": 40.0,
	}
	for name: String in targets:
		var mm: float = _canvas_units_to_mm(targets[name])
		var message: String = "%s is %.1f mm on a 1080p phone; the minimum is %.1f mm" % [
			name, mm, MIN_TARGET_MM]
		assert_ge(mm, MIN_TARGET_MM, message)


func test_the_movement_stick_is_a_large_continuous_target() -> void:
	# The stick replaced a 24-unit arrow (6.1 mm) that also had a dead centre.
	# Its diameter is what the thumb actually gets.
	var diameter: float = VirtualStick.BASE_RADIUS * 2.0
	var mm: float = _canvas_units_to_mm(diameter)
	var message: String = "the movement stick is %.1f mm across; it must clear %.1f mm" % [
		mm, MIN_TARGET_MM]
	assert_ge(mm, MIN_TARGET_MM, message)
	assert_gt(mm, 15.0, "movement is held continuously and should be generous")
