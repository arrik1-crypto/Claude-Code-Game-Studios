class_name VirtualStick
extends Node2D

## Circular analog movement control for the left thumb.
##
## Replaces the four-button d-pad, which was reported as unusable on a real
## phone. At the 480x270 reference on a 1080p handset each d-pad arrow measured
## about 6.1 mm — roughly two thirds of the ~9 mm minimum touch target, on the
## control the player holds down continuously. Worse, the four arrows tiled
## edge-to-edge around a *dead centre cell*, so a thumb resting in the middle of
## what looked like a d-pad registered nothing at all.
##
## This is one continuous ~18 mm target with no dead centre.
##
## It presses the same [InputMap] actions the keyboard and gamepad use, so no
## gameplay code branches on input method — the project forbids that, and it is
## why the player controller needs no changes at all to support this. Because
## [method Input.action_press] takes a strength and [Player.move_axis] reads the
## move actions through [method Input.get_axis], horizontal movement becomes
## genuinely analog for free: a small tilt walks, a full tilt runs.
##
## Godot 4.6 ships no virtual joystick node — one landed in 4.7 — and the project
## allows no third-party addons, so this is built directly from
## [InputEventScreenTouch] and [InputEventScreenDrag].
##
## See design/gdd/mobile-controls.md and docs/architecture/ADR-008-touch-input.md.

## Emitted when the stick's normalised vector changes. Purely for presentation;
## input is driven through the InputMap, not this signal.
signal vector_changed(vector: Vector2)

## Radius of the drawn base, in canvas units. 36 gives a 72-unit diameter, which
## is ~18 mm on a 1080p phone at 4x — twice the old d-pad arrow.
const BASE_RADIUS: float = 36.0

## Radius of the thumb disc.
const THUMB_RADIUS: float = 15.0

## How far the thumb travels from centre at full deflection.
const MAX_TRAVEL: float = 24.0

## A touch this far outside the base still grabs the stick, so a thumb that lands
## slightly wide is not simply ignored.
const GRAB_MARGIN: float = 14.0

## Below this fraction of full deflection the stick reads as centred. Stops a
## resting thumb from creeping the character sideways.
const DEADZONE: float = 0.24

## Fraction of vertical deflection needed to press up or down. Deliberately high:
## up and down are discrete actions (crouch, drop-through, interact) and must not
## fire while the player is simply running left or right. This, with the axis
## dominance below, is what answers the original design objection to a stick —
## that it "produces accidental diagonals".
const VERTICAL_THRESHOLD: float = 0.55

## Vertical input is ignored unless it clearly beats horizontal, so a diagonal
## push while running never crouches the player by accident.
const VERTICAL_DOMINANCE: float = 1.2

## Pressing up also fires `interact`, exactly as d-pad up used to, so resting at
## a save coffin still costs no extra button.
const UP_ALSO_PRESSES: StringName = &"interact"

const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_UP: StringName = &"move_up"
const ACTION_DOWN: StringName = &"move_down"

## Deliberately faint. The stick is the largest thing on the screen and sits over
## the playfield, so at the buttons' opacity it read as a bright bubble swallowing
## the character. It only needs to say "your thumb goes here"; the thumb itself
## covers it during play.
const COLOR_BASE: Color = Color(0.62, 0.60, 0.78, 0.13)
const COLOR_RING: Color = Color(0.78, 0.76, 0.92, 0.28)
const COLOR_THUMB: Color = Color(0.80, 0.78, 0.94, 0.30)
const COLOR_THUMB_HELD: Color = Color(0.94, 0.92, 1.0, 0.62)

## The touch index currently driving the stick, or -1 when released. Tracked so a
## second finger on the attack button cannot steal or cancel movement.
var _touch_index: int = -1

## Thumb offset from centre, in canvas units.
var _thumb: Vector2 = Vector2.ZERO

## Normalised deflection, -1..1 on each axis.
var _vector: Vector2 = Vector2.ZERO

## Actions this stick is currently holding down, so it releases exactly what it
## pressed and never strands an action belonging to something else.
var _held: Dictionary[StringName, bool] = {}


func _ready() -> void:
	# Must keep receiving input while the tree is paused, like the rest of the
	# touch layer; releasing a held direction on pause depends on it.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _draw() -> void:
	draw_circle(Vector2.ZERO, BASE_RADIUS, COLOR_BASE)
	draw_arc(Vector2.ZERO, BASE_RADIUS, 0.0, TAU, 32, COLOR_RING, 1.5, true)
	draw_circle(_thumb, THUMB_RADIUS, COLOR_THUMB_HELD if is_held() else COLOR_THUMB)


## True while a finger is on the stick.
func is_held() -> bool:
	return _touch_index != -1


## Current normalised deflection, -1..1 per axis. Exposed for tests.
func vector() -> Vector2:
	return _vector


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if is_held():
			return
		# `make_input_local` folds in the canvas and layer transforms, so this
		# works under `canvas_items` stretch at any resolution.
		var local: Vector2 = (make_input_local(event) as InputEventScreenTouch).position
		if local.length() > BASE_RADIUS + GRAB_MARGIN:
			return
		_touch_index = event.index
		get_viewport().set_input_as_handled()
		_move_thumb(local)
	elif event.index == _touch_index:
		_touch_index = -1
		_move_thumb(Vector2.ZERO)


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_index:
		return
	_move_thumb((make_input_local(event) as InputEventScreenDrag).position)


func _move_thumb(local: Vector2) -> void:
	_thumb = local.limit_length(MAX_TRAVEL) if is_held() else Vector2.ZERO
	var deflection: Vector2 = _thumb / MAX_TRAVEL
	if deflection.length() < DEADZONE:
		deflection = Vector2.ZERO

	if not deflection.is_equal_approx(_vector):
		_vector = deflection
		vector_changed.emit(_vector)
	_apply_actions()
	queue_redraw()


## Translate the deflection into InputMap action presses.
##
## Horizontal is analog — the press strength is the deflection, so the player
## controller's `Input.get_axis` yields a partial value and the character walks
## rather than sprints. Vertical is digital, because crouch, drop-through and
## interact are all on/off.
func _apply_actions() -> void:
	var horizontal: float = _vector.x
	_set_action(ACTION_LEFT, maxf(0.0, -horizontal))
	_set_action(ACTION_RIGHT, maxf(0.0, horizontal))

	var vertical: float = _vector.y
	var dominant: bool = absf(vertical) > absf(horizontal) * VERTICAL_DOMINANCE
	var up: bool = dominant and vertical <= -VERTICAL_THRESHOLD
	var down: bool = dominant and vertical >= VERTICAL_THRESHOLD

	_set_action(ACTION_UP, 1.0 if up else 0.0)
	_set_action(UP_ALSO_PRESSES, 1.0 if up else 0.0)
	_set_action(ACTION_DOWN, 1.0 if down else 0.0)


## Press, re-press at a new strength, or release a single action.
func _set_action(action: StringName, strength: float) -> void:
	if not InputMap.has_action(action):
		return
	if strength > 0.0:
		Input.action_press(action, strength)
		_held[action] = true
	elif _held.get(action, false):
		Input.action_release(action)
		_held.erase(action)


## Drop everything the stick is holding. Called when the controls are hidden for
## an overlay, and on teardown — a finger lifted after the node stops receiving
## input would otherwise leave the character running forever.
func release() -> void:
	_touch_index = -1
	_thumb = Vector2.ZERO
	_vector = Vector2.ZERO
	for action: StringName in _held.keys():
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)
	_held.clear()
	queue_redraw()


func _exit_tree() -> void:
	release()
