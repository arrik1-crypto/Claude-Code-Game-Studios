class_name SpriteFx
extends RefCounted

## Drives the shared character sprite shader.
##
## Every character — player, enemies, boss — gets its own `ShaderMaterial`
## instance from here, because shader parameters are per-material and a shared
## material would flash the whole bestiary whenever one skeleton was hit.
##
## Callers never touch parameter names; they ask for an effect.

const SHADER_PATH: String = "res://assets/shaders/sprite_fx.gdshader"

const PARAM_FLASH: StringName = &"flash_amount"
const PARAM_FLASH_COLOR: StringName = &"flash_color"
const PARAM_DISSOLVE: StringName = &"dissolve"
const PARAM_MIST: StringName = &"mist_amount"

## Seconds a hit flash stays at full intensity before it decays.
const FLASH_HOLD: float = 0.05
const FLASH_DECAY: float = 0.14

static var _shader: Shader = null


static func _shader_resource() -> Shader:
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
		if _shader == null:
			push_error("SpriteFx: could not load %s" % SHADER_PATH)
	return _shader


## Attach a fresh material to a sprite. Returns false if the shader is missing,
## in which case the sprite simply renders unmodified.
static func attach(sprite: CanvasItem) -> bool:
	var shader: Shader = _shader_resource()
	if shader == null or sprite == null:
		return false
	var material := ShaderMaterial.new()
	material.shader = shader
	sprite.material = material
	return true


static func _material(sprite: CanvasItem) -> ShaderMaterial:
	if sprite == null:
		return null
	return sprite.material as ShaderMaterial


## Flash the sprite to a flat colour and decay back.
##
## Falls back to modulating when the shader is unavailable, so the hit still
## reads on a build where the shader failed to compile.
static func flash(sprite: CanvasItem, color: Color = Color.WHITE,
		hold: float = FLASH_HOLD, decay: float = FLASH_DECAY) -> void:
	var material: ShaderMaterial = _material(sprite)
	if material == null:
		if sprite != null:
			var fallback: Tween = sprite.create_tween()
			sprite.modulate = Color(2.2, 2.2, 2.2, sprite.modulate.a)
			fallback.tween_property(sprite, "modulate", Color.WHITE, decay)
		return

	material.set_shader_parameter(PARAM_FLASH_COLOR, color)
	material.set_shader_parameter(PARAM_FLASH, 1.0)

	var tween: Tween = sprite.create_tween()
	tween.tween_interval(hold)
	tween.tween_method(
		func(v: float) -> void: material.set_shader_parameter(PARAM_FLASH, v),
		1.0, 0.0, decay)


## Burn the sprite away over [param duration] seconds.
static func dissolve(sprite: CanvasItem, duration: float) -> void:
	var material: ShaderMaterial = _material(sprite)
	if material == null:
		if sprite != null:
			var fallback: Tween = sprite.create_tween()
			fallback.tween_property(sprite, "modulate:a", 0.0, duration)
		return
	material.set_shader_parameter(PARAM_DISSOLVE, 0.0)
	var tween: Tween = sprite.create_tween()
	tween.tween_method(
		func(v: float) -> void: material.set_shader_parameter(PARAM_DISSOLVE, v),
		0.0, 1.0, duration)


## Set the mist-form intensity directly. Driven per-frame by the dash state.
static func set_mist(sprite: CanvasItem, amount: float) -> void:
	var material: ShaderMaterial = _material(sprite)
	if material == null:
		if sprite != null:
			sprite.modulate.a = lerpf(1.0, 0.55, clampf(amount, 0.0, 1.0))
		return
	material.set_shader_parameter(PARAM_MIST, clampf(amount, 0.0, 1.0))


## Clear every effect back to neutral, e.g. when an entity is reused.
static func reset(sprite: CanvasItem) -> void:
	var material: ShaderMaterial = _material(sprite)
	if material == null:
		return
	material.set_shader_parameter(PARAM_FLASH, 0.0)
	material.set_shader_parameter(PARAM_DISSOLVE, 0.0)
	material.set_shader_parameter(PARAM_MIST, 0.0)
