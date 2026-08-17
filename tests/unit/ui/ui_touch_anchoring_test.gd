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
	# The d-pad is measured from the left edge, so a wider screen must not
	# shift it at all.
	var inset: Vector2 = Vector2(20, 68)
	for screen: Vector2 in [PHONE_16_9, PHONE_19_5_9, PHONE_20_9]:
		var at: Vector2 = TouchControls.anchored_position(inset, screen, 1.0, false, false)
		assert_eq(at.x, 20.0, "the d-pad stays %dpx from the left on a %dpx canvas"
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
		assert_gt(left.x, 0.0, "a %.1fx d-pad stays right of the left edge" % factor)


func test_the_two_thumb_clusters_never_collide() -> void:
	# The d-pad must stay well clear of the action cluster at every screen width
	# and every control scale, or a thumb press hits the wrong button.
	for screen: Vector2 in [PHONE_16_9, PHONE_19_5_9, PHONE_20_9]:
		for factor: float in [1.0, 1.5]:
			var dpad_right_edge: Vector2 = TouchControls.anchored_position(
				Vector2(68, 68), screen, factor, false, false)
			var action_left_edge: Vector2 = TouchControls.anchored_position(
				Vector2(124, 58), screen, factor, true, false)
			var message: String = ("d-pad reaches x=%.0f and the action cluster starts "
				+ "at x=%.0f on a %dpx canvas at %.1fx") % [
					dpad_right_edge.x, action_left_edge.x, screen.x, factor]
			assert_lt(dpad_right_edge.x, action_left_edge.x, message)
