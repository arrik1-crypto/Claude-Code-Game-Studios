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
## Accessibility: scale and opacity are adjustable, and the whole layer can be
## hidden for players using a gamepad. See design/gdd/mobile-controls.md.

## Pressing the d-pad up also fires `interact`, so a save coffin can be used
## without a separate button competing for thumb space.
const UP_ALSO_PRESSES: StringName = &"interact"

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


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# Default to showing the controls only where they are useful. A desktop
	# playtest can force them on via `controls_visible`.
	if not DisplayServer.is_touchscreen_available():
		controls_visible = false

	dpad_up.pressed.connect(_on_up_pressed)
	dpad_up.released.connect(_on_up_released)

	_apply_appearance()


func _apply_appearance() -> void:
	if not is_inside_tree() or buttons == null:
		return
	visible = controls_visible
	buttons.scale = Vector2.ONE * control_scale
	buttons.modulate.a = control_opacity


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
