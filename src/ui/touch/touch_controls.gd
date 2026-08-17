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

## Pressing the d-pad up also fires `interact`, so a save coffin can be used
## without a separate button competing for thumb space.
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
## but to force-quit and lose the run. Keeping the layer alive means the d-pad
## and attack buttons would otherwise still be pressable over a stopped world.
const LIVE_WHILE_PAUSED: PackedStringArray = ["BtnPause", "BtnMap"]

## Actions to release when the gameplay buttons are taken away, so nothing is
## left latched down across the pause.
const GAMEPLAY_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"jump", &"attack", &"subweapon", &"dash",
]

@onready var buttons: Node2D = $Buttons
@onready var dpad_up: TouchScreenButton = $Buttons/DpadUp

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


## Authored corner insets, captured once from the scene: button -> inset.
var _insets: Dictionary[TouchScreenButton, Vector2] = {}


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

	dpad_up.pressed.connect(_on_up_pressed)
	dpad_up.released.connect(_on_up_released)
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
## A TouchScreenButton that is hidden mid-press never emits its release, so
## without this the player resumes with the d-pad still held down.
func _release_gameplay_actions() -> void:
	for action: StringName in GAMEPLAY_ACTIONS:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)


## Convert each authored position into a distance from its own corner.
##
## Read from the scene rather than duplicated as constants here, so the .tscn
## stays the single place the layout is designed.
func _capture_insets() -> void:
	for child: Node in buttons.get_children():
		var button := child as TouchScreenButton
		if button == null:
			continue
		var from_right: bool = RIGHT_ANCHORED.has(button.name)
		var from_top: bool = TOP_ANCHORED.has(button.name)
		_insets[button] = Vector2(
			REFERENCE_SIZE.x - button.position.x if from_right else button.position.x,
			button.position.y if from_top else REFERENCE_SIZE.y - button.position.y)


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
	for button: TouchScreenButton in _insets:
		if not is_instance_valid(button):
			continue
		# A hidden TouchScreenButton receives no input, which is exactly what
		# should happen to the d-pad and attack buttons over a frozen world.
		button.visible = not _overlay_open or LIVE_WHILE_PAUSED.has(button.name)
		button.scale = Vector2.ONE * control_scale
		button.position = anchored_position(
			_insets[button], viewport, control_scale,
			RIGHT_ANCHORED.has(button.name), TOP_ANCHORED.has(button.name))


## The up button doubles as "interact" so pressing up at a coffin rests there.
func _on_up_pressed() -> void:
	Input.action_press(UP_ALSO_PRESSES)


func _on_up_released() -> void:
	Input.action_release(UP_ALSO_PRESSES)


func _exit_tree() -> void:
	# Never leave an action stuck down if the layer is torn down mid-press.
	for action: StringName in [
		&"move_left", &"move_right", &"move_up", &"move_down",
		&"jump", &"attack", &"subweapon", &"dash", UP_ALSO_PRESSES,
	]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)
