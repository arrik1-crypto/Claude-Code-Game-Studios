class_name Prop
extends AnimatedSprite2D

## Purely decorative animated scenery — torches, candles, wall fittings.
##
## Props carry no collision and no gameplay behaviour. They exist so rooms can
## place a flickering torch without every room file needing to know about the
## prop atlas layout.

const PROP_SHEET: String = "res://assets/art/props/props.png"

## Animation name from assets/art/props/props.json.
@export var prop_animation: String = "torch"

## Optional warm light cast by flame props.
@export var emits_light: bool = false


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


func _add_light() -> void:
	var light := PointLight2D.new()
	light.color = Color(1.0, 0.78, 0.42)
	light.energy = 0.75
	light.texture_scale = 2.5
	var gradient := GradientTexture2D.new()
	gradient.width = 128
	gradient.height = 128
	gradient.fill = GradientTexture2D.FILL_RADIAL
	gradient.fill_from = Vector2(0.5, 0.5)
	gradient.fill_to = Vector2(1.0, 0.5)
	light.texture = gradient
	add_child(light)
