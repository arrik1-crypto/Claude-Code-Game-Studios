class_name ParallaxBackdrop
extends ParallaxBackground

## Three-layer scrolling castle skyline behind the playfield.
##
## Lives on the World rather than inside a Room, so it survives room transitions
## and does not restart its scroll every time the player walks through a door.
##
## Visibility is per-room and opt-in. Interior rooms fill their background with
## masonry, which would completely hide this; only rooms that declare themselves
## open to the sky show it. That keeps the backdrop meaningful — seeing the
## crimson moon should tell the player they are outdoors.
##
## Note that `ParallaxBackground` is a `CanvasLayer`, so the world's
## `CanvasModulate` does not reach it. The ambient tint is therefore applied to
## this node directly by [method match_ambient], or the sky would stay brightly
## lit inside a pitch-dark castle.

## Scroll rates per layer. Small values read as distant.
const SKY_SCALE: Vector2 = Vector2(0.06, 0.03)
const FAR_SCALE: Vector2 = Vector2(0.22, 0.09)
const NEAR_SCALE: Vector2 = Vector2(0.46, 0.18)

## Width of the generated layer art, used for horizontal tiling.
const LAYER_WIDTH: float = 480.0

@onready var sky_layer: ParallaxLayer = $SkyLayer
@onready var far_layer: ParallaxLayer = $FarLayer
@onready var near_layer: ParallaxLayer = $NearLayer

var _drift: float = 0.0


func _ready() -> void:
	# Behind the world canvas, which itself sits above the default layer.
	layer = -100
	visible = false


## Show or hide the backdrop for the room being entered.
func set_active(active: bool) -> void:
	visible = active
	set_process(active)


## Tint the backdrop to sit behind the room's ambient light.
##
## Deliberately DARKER than the room ambient. The backdrop is scenery the player
## can never touch, so it must never compete with the platforms they can. Aerial
## perspective in this palette is low contrast, not high brightness.
const BACKDROP_DIM: float = 0.62

func match_ambient(ambient: Color) -> void:
	modulate = Color(
		ambient.r * BACKDROP_DIM,
		ambient.g * BACKDROP_DIM,
		ambient.b * BACKDROP_DIM * 1.08,
		1.0)


func _process(delta: float) -> void:
	# A very slow independent drift on the far layers, so the sky is never
	# completely static while the player stands still.
	_drift += delta
	far_layer.motion_offset.x = sin(_drift * 0.05) * 6.0
	near_layer.motion_offset.x = sin(_drift * 0.08 + 1.3) * 3.0
