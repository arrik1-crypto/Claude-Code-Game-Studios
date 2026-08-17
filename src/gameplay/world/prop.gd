class_name Prop
extends AnimatedSprite2D

## Purely decorative animated scenery — torches, candles, wall fittings.
##
## Props carry no collision and no gameplay behaviour. They exist so rooms can
## place a flickering torch without every room file needing to know about the
## prop atlas layout.
##
## A torch that emits light also drives a subtle flicker on its own light, which
## is what stops a lit room from looking like it is under a fluorescent tube.

const PROP_SHEET: String = "res://assets/art/props/props.png"

## Warm flame colour for torch and candle light.
const FLAME_LIGHT_COLOR: Color = Color(1.0, 0.72, 0.38)

## Flicker depth as a fraction of base energy, and its speed in Hz.
const FLICKER_DEPTH: float = 0.16
const FLICKER_SPEED: float = 7.0

## Animation name from assets/art/props/props.json.
@export var prop_animation: String = "torch"

## Optional warm light cast by flame props. The room grants this from its
## lighting budget; see `Room._claim_light`.
@export var emits_light: bool = false

var _light: PointLight2D = null
var _base_energy: float = 0.0
var _flicker_phase: float = 0.0


func _ready() -> void:
	z_index = -2
	if not SpriteSheetLoader.apply(self, PROP_SHEET):
		queue_free()
		return
	if sprite_frames.has_animation(prop_animation):
		# Randomise the starting frame so a row of torches does not flicker in
		# perfect unison.
		play(prop_animation)
		frame = randi() % maxi(1, sprite_frames.get_frame_count(prop_animation))
	else:
		push_warning("Prop: no animation named '%s'" % prop_animation)

	if emits_light:
		_add_light()
	else:
		# Nothing to animate; skip the per-frame callback entirely.
		set_process(false)


func _add_light() -> void:
	_base_energy = 1.05 if prop_animation == "torch" else 0.7
	var scale: float = 3.0 if prop_animation == "torch" else 1.8

	_light = LightingQuality.make_light(FLAME_LIGHT_COLOR, _base_energy, scale)
	if _light == null:
		set_process(false)
		return

	# Offset to the flame rather than the sprite origin, so the pool of light
	# sits where the fire is drawn.
	_light.position = Vector2(0, -4)
	_flicker_phase = randf() * TAU
	add_child(_light)


func _process(delta: float) -> void:
	if _light == null:
		return
	# Two out-of-phase sines rather than one: a single sine reads as a pulse,
	# two at different rates read as a flame.
	_flicker_phase += delta * FLICKER_SPEED
	var flicker: float = sin(_flicker_phase) * 0.6 + sin(_flicker_phase * 2.37) * 0.4
	_light.energy = _base_energy * (1.0 + flicker * FLICKER_DEPTH)
