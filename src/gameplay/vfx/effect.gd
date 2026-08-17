class_name Effect
extends AnimatedSprite2D

## A one-shot visual effect from any generated or imported atlas.
##
## Plays a single non-looping animation and frees itself. Callers do not need to
## track the node, which is what makes every [Vfx] helper a fire-and-forget
## one-liner.
##
## Effects can optionally fade and grow over their lifetime. That is used for the
## single-frame weapon smears, which have no dissipation frames of their own —
## the motion has to come from code or the arc just pops in and out.

const DEFAULT_SHEET: String = "res://assets/art/vfx/vfx.png"

## Safety net: free the node even if the animation never reports finishing
## (a mis-authored manifest with a looping flag, for instance).
const MAX_LIFETIME: float = 2.0

var _elapsed: float = 0.0
var _lifetime: float = 0.0
var _fade_rate: float = 0.0
var _grow_rate: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _base_alpha: float = 1.0


func _ready() -> void:
	z_index = 40
	animation_finished.connect(queue_free)


## Start an effect.
##
## [param sheet_or_name] accepts either a full `res://` atlas path or, for
## backwards compatibility, a bare animation name on the default VFX sheet.
func play_effect(sheet_or_name: String, animation: String = "", flip: bool = false) -> void:
	var sheet: String = sheet_or_name
	var anim: String = animation

	# Legacy single-argument form: play_effect("hit_spark").
	if not sheet_or_name.begins_with("res://"):
		sheet = DEFAULT_SHEET
		anim = sheet_or_name

	if not SpriteSheetLoader.apply(self, sheet):
		queue_free()
		return
	if sprite_frames == null or not sprite_frames.has_animation(anim):
		push_warning("Effect: '%s' has no animation named '%s'" % [sheet, anim])
		queue_free()
		return

	flip_h = flip
	_base_scale = scale
	_base_alpha = modulate.a
	play(anim)


## Configure code-driven motion, for effects whose art is a single frame.
##
## [param fade] is alpha lost per second, [param grow] is scale gained per
## second, and [param lifetime] force-frees the node after that many seconds
## (0 means "when the animation ends").
func set_motion(fade: float, grow: float, lifetime: float) -> void:
	_fade_rate = fade
	_grow_rate = grow
	_lifetime = lifetime
	_base_scale = scale
	_base_alpha = modulate.a


func _process(delta: float) -> void:
	_elapsed += delta

	if _fade_rate > 0.0:
		modulate.a = maxf(0.0, modulate.a - _fade_rate * delta * _base_alpha)
	if _grow_rate > 0.0:
		scale = _base_scale * (1.0 + _grow_rate * _elapsed)

	if _lifetime > 0.0 and _elapsed >= _lifetime:
		queue_free()
		return
	if _elapsed > MAX_LIFETIME:
		queue_free()
