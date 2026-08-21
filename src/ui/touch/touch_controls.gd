class_name TouchControls
extends CanvasLayer

## On-screen controls for touch devices.
##
## The buttons drive the same [InputMap] actions as a keyboard or gamepad, so no
## gameplay code ever branches on input method — [Player] just reads
## `Input.is_action_pressed("jump")` and neither knows nor cares where it came
## from. That is the whole reason the touch layer is this thin.
##
## Layout follows the standard landscape thumb zones: movement under the left
## thumb, actions under the right, with the two most-used actions (attack and
## jump) largest and closest to the corner.
##
## Every control is pinned to a screen *corner*, not to a fixed coordinate. The
## scene authors positions against the 480x270 reference frame, but the project
## stretches with `expand`, so on a 19.5:9 phone the visible canvas is about
## 585x270 — a third wider. Laid out by raw coordinate, the right-hand cluster
## and the pause button end up around 60% across, floating near the middle of
## the screen where no thumb reaches. This layer converts each authored position
## into an inset from its nearest corner once, then re-applies it whenever the
## viewport changes.
##
## Accessibility: scale and opacity are adjustable, and the whole layer can be
## hidden for players using a gamepad. See design/gdd/mobile-controls.md.

## Pushing the stick up also fires `interact`, so a save coffin can be used
## without a separate button competing for thumb space. The stick owns the press;
## this is listed here so the pause sweep releases it too.
const UP_ALSO_PRESSES: StringName = &"interact"

## The frame the scene's button positions are authored against.
const REFERENCE_SIZE: Vector2 = Vector2(480, 270)

## Controls that belong to the right thumb. Everything else pins to the left.
const RIGHT_ANCHORED: PackedStringArray = [
	"BtnJump", "BtnAttack", "BtnDash", "BtnSubweapon", "BtnPause", "BtnMap",
]

## Controls along the top edge. Everything else pins to the bottom.
const TOP_ANCHORED: PackedStringArray = ["BtnPause", "BtnMap"]

## Controls that stay live while an overlay is up.
##
## Everything else is hidden while the game is paused. This layer runs with
## `PROCESS_MODE_ALWAYS` — it has to, because the button that opens the pause
## menu is on this layer, and a `PAUSABLE` touch layer freezes the instant it is
## used, leaving a touch-only player with no way to close the menu and no choice
## but to force-quit and lose the run. Keeping the layer alive means the stick
## and attack buttons would otherwise still be pressable over a stopped world.
const LIVE_WHILE_PAUSED: PackedStringArray = ["BtnPause", "BtnMap"]

## Actions to release when the gameplay buttons are taken away, so nothing is
## left latched down across the pause.
const GAMEPLAY_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"jump", &"attack", &"subweapon", &"dash",
]

@onready var buttons: Node2D = $Buttons
@onready var stick: VirtualStick = $Buttons/Stick

## Multiplies the size of every control. Raise for players who need bigger
## targets; the layout re-anchors around the screen corners so nothing overlaps.
@export_range(0.6, 2.0, 0.05) var control_scale: float = 1.0:
	set(value):
		control_scale = value
		_apply_appearance()

@export_range(0.15, 1.0, 0.05) var control_opacity: float = 0.65:
	set(value):
		control_opacity = value
		_apply_appearance()

## When false the layer is hidden entirely (gamepad or desktop play).
@export var controls_visible: bool = true:
	set(value):
		controls_visible = value
		_apply_appearance()


## Authored corner insets, captured once from the scene: control -> inset.
##
## Keyed by [Node2D] rather than [TouchScreenButton] because the movement control
## is a [VirtualStick], which is not a button.
var _insets: Dictionary[Node2D, Vector2] = {}


## True while a pause or map overlay is covering the game.
var _overlay_open: bool = false


func _ready() -> void:
	layer = 20
	# ALWAYS, not PAUSABLE. See LIVE_WHILE_PAUSED — a pausable touch layer
	# soft-locks touch-only players out of their own pause menu.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Default to showing the controls only where they are useful. A desktop
	# playtest can force them on via `controls_visible`.
	if not DisplayServer.is_touchscreen_available():
		controls_visible = false

	EventBus.overlay_toggled.connect(_on_overlay_toggled)

	_capture_insets()
	get_viewport().size_changed.connect(_apply_appearance)
	_apply_appearance()


func _on_overlay_toggled(is_open: bool) -> void:
	_overlay_open = is_open
	if is_open:
		_release_gameplay_actions()
	_apply_appearance()


## Drop any action the player was holding when the overlay appeared.
##
## A TouchScreenButton hidden mid-press never emits its release, and the stick
## stops receiving drags the moment it is hidden, so without this the player
## resumes still running in whatever direction they were holding.
func _release_gameplay_actions() -> void:
	stick.release()
	for action: StringName in GAMEPLAY_ACTIONS:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)


## Convert each authored position into a distance from its own corner.
##
## Read from the scene rather than duplicated as constants here, so the .tscn
## stays the single place the layout is designed.
func _capture_insets() -> void:
	for child: Node in buttons.get_children():
		var control := child as Node2D
		if control == null:
			continue
		var from_right: bool = RIGHT_ANCHORED.has(control.name)
		var from_top: bool = TOP_ANCHORED.has(control.name)
		_insets[control] = Vector2(
			REFERENCE_SIZE.x - control.position.x if from_right else control.position.x,
			control.position.y if from_top else REFERENCE_SIZE.y - control.position.y)


## Where a control sits for a given screen, inset and scale.
##
## Static and pure so the anchoring maths can be tested without a viewport.
## Insets scale with the control, so enlarging the buttons grows them inward
## from the corner instead of pushing them off the screen.
static func anchored_position(inset: Vector2, viewport: Vector2, scale_factor: float,
		from_right: bool, from_top: bool) -> Vector2:
	var scaled: Vector2 = inset * scale_factor
	return Vector2(
		viewport.x - scaled.x if from_right else scaled.x,
		scaled.y if from_top else viewport.y - scaled.y)


func _apply_appearance() -> void:
	if not is_inside_tree() or buttons == null:
		return
	visible = controls_visible
	buttons.modulate.a = control_opacity

	# The parent stays at unit scale. Scaling it would scale the child
	# *positions* too, dragging every control away from the corner it is
	# supposed to be pinned to.
	buttons.scale = Vector2.ONE

	var viewport: Vector2 = get_viewport().get_visible_rect().size
	for control: Node2D in _insets:
		if not is_instance_valid(control):
			continue
		# A hidden control receives no input, which is exactly what should happen
		# to the stick and attack buttons over a frozen world.
		control.visible = not _overlay_open or LIVE_WHILE_PAUSED.has(control.name)
		control.scale = Vector2.ONE * control_scale
		control.position = anchored_position(
			_insets[control], viewport, control_scale,
			RIGHT_ANCHORED.has(control.name), TOP_ANCHORED.has(control.name))


func _exit_tree() -> void:
	# Never leave an action stuck down if the layer is torn down mid-press.
	for action: StringName in [
		&"move_left", &"move_right", &"move_up", &"move_down",
		&"jump", &"attack", &"subweapon", &"dash", UP_ALSO_PRESSES,
	]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)
