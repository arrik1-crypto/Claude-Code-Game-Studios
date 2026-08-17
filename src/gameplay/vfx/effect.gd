class_name Effect
extends AnimatedSprite2D

## A one-shot visual effect from the generated VFX atlas.
##
## Plays a single non-looping animation and frees itself. Callers do not need to
## track the node, which is what makes `player.spawn_vfx()` a fire-and-forget
## one-liner at every call site.

const VFX_SHEET: String = "res://assets/art/vfx/vfx.png"

## Safety net: free the node even if the animation never reports finishing
## (a mis-authored manifest with a looping flag, for instance).
const MAX_LIFETIME: float = 2.0

var _elapsed: float = 0.0


func _ready() -> void:
	z_index = 40
	animation_finished.connect(queue_free)


## Start the named effect, e.g. "hit_spark", "blood", "mist", "soul".
func play_effect(effect_name: String, flip: bool = false) -> void:
	if not SpriteSheetLoader.apply(self, VFX_SHEET):
		queue_free()
		return
	if sprite_frames == null or not sprite_frames.has_animation(effect_name):
		push_warning("Effect: no VFX animation named '%s'" % effect_name)
		queue_free()
		return
	flip_h = flip
	play(effect_name)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > MAX_LIFETIME:
		queue_free()
