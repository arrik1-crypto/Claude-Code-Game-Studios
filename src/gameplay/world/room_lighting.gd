class_name RoomLighting
extends CanvasModulate

## Per-room ambient darkness, which is what makes 2D lights visible at all.
##
## Without a [CanvasModulate] in the canvas, every `PointLight2D` in the scene is
## a no-op: the canvas is already at full brightness so there is nothing for a
## light to add. The torches, the relic pedestals and the player lantern were all
## rendering nothing until this node existed.
##
## The ambient colour multiplies the whole 2D canvas. UI lives on separate
## `CanvasLayer`s and is unaffected, so the HUD stays fully legible however dark
## the castle gets.
##
## Mobile budget: ambient darkening itself is free — it is one modulate on the
## canvas. The cost is in the lights, so light count and shadow casting are
## governed by [LightingQuality] rather than by this node.

## Ambient tint applied when a room does not specify its own.
## A desaturated blue-violet at roughly half brightness: dark enough that torch
## light reads as light, bright enough to stay playable on a phone screen in
## daylight, which is the actual constraint on a mobile game.
const DEFAULT_AMBIENT: Color = Color(0.50, 0.47, 0.62, 1.0)

## Ambient used by rooms flagged as pitch dark (the boss throne room).
const DARK_AMBIENT: Color = Color(0.30, 0.27, 0.42, 1.0)

## Ambient for rooms that are notionally outdoors under the crimson moon.
const MOONLIT_AMBIENT: Color = Color(0.58, 0.50, 0.66, 1.0)

## Named presets a room file can select with its `ambient` key.
const PRESETS: Dictionary = {
	"default": DEFAULT_AMBIENT,
	"dark": DARK_AMBIENT,
	"moonlit": MOONLIT_AMBIENT,
}


func _ready() -> void:
	# Draw beneath everything so nothing accidentally sorts above the ambient.
	z_index = -100


## Apply a named preset, or a literal colour if the name is unknown.
func apply_preset(preset_name: String) -> void:
	if preset_name == "":
		color = DEFAULT_AMBIENT
		return
	if PRESETS.has(preset_name):
		color = PRESETS[preset_name]
		return
	# Allow a room to specify a raw hex colour for a one-off.
	if preset_name.begins_with("#"):
		color = Color.from_string(preset_name, DEFAULT_AMBIENT)
		return
	push_warning("RoomLighting: unknown ambient preset '%s'" % preset_name)
	color = DEFAULT_AMBIENT


## Fade the ambient towards a target, used for boss-phase transitions.
func tween_to(target: Color, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "color", target, duration)
