class_name LightingQuality
extends RefCounted

## Central budget for 2D lighting, so mobile performance is a decision made once
## rather than re-litigated at every call site.
##
## `PointLight2D` is cheap; `PointLight2D` with shadows is not — each shadow-
## casting light forces an extra pass over every `LightOccluder2D` in range. On a
## mid-range 2022 Android part that is the difference between a comfortable 60fps
## and a variable one, so shadows are off by default and only the player's lantern
## is allowed to cast them at the highest tier.
##
## Tiers are chosen at runtime from the renderer and platform, and can be
## overridden by the player in settings.

enum Tier {
	## No dynamic lights at all. Ambient stays fully bright.
	OFF,
	## Lights, no shadows. The mobile default.
	SIMPLE,
	## Lights plus shadows from the player's lantern only.
	SHADOWS,
}

## Maximum simultaneous lights per room, by tier. Torches beyond the cap are
## created without a light rather than being culled, so the room still looks
## populated.
const MAX_LIGHTS: Dictionary = {
	Tier.OFF: 0,
	Tier.SIMPLE: 10,
	Tier.SHADOWS: 16,
}

## Texture scale for point lights. Larger looks softer but costs fill rate.
const LIGHT_TEXTURE_SCALE: float = 2.6

## Radius in pixels of the generated radial falloff gradient.
const LIGHT_GRADIENT_SIZE: int = 128

static var _tier: Tier = Tier.SIMPLE
static var _resolved: bool = false
static var _gradient: GradientTexture2D = null


## The active tier, resolved from the platform on first use.
static func tier() -> Tier:
	if not _resolved:
		_resolved = true
		_tier = _detect_tier()
	return _tier


## Override the tier, e.g. from a settings menu.
static func set_tier(value: Tier) -> void:
	_tier = value
	_resolved = true


static func _detect_tier() -> Tier:
	# The compatibility renderer is used on low-end devices and in CI capture;
	# keep it on the cheapest tier that still shows the art.
	var method: String = String(ProjectSettings.get_setting(
		"rendering/renderer/rendering_method", "mobile"))
	if method == "gl_compatibility":
		return Tier.SIMPLE
	if OS.has_feature("mobile"):
		return Tier.SIMPLE
	return Tier.SHADOWS


static func lights_enabled() -> bool:
	return tier() != Tier.OFF


static func max_lights() -> int:
	return int(MAX_LIGHTS.get(tier(), 8))


static func shadows_enabled() -> bool:
	return tier() == Tier.SHADOWS


## Shared radial falloff texture for every point light.
##
## Built once and reused: a `GradientTexture2D` per light would allocate an
## identical texture for every torch in the castle.
static func light_texture() -> GradientTexture2D:
	if _gradient != null:
		return _gradient

	var gradient := Gradient.new()
	# A soft shoulder rather than a linear ramp — linear falloff reads as a hard
	# disc against flat pixel-art tiles.
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1),
		Color(1, 1, 1, 0.62),
		Color(1, 1, 1, 0.18),
		Color(1, 1, 1, 0),
	])

	_gradient = GradientTexture2D.new()
	_gradient.gradient = gradient
	_gradient.width = LIGHT_GRADIENT_SIZE
	_gradient.height = LIGHT_GRADIENT_SIZE
	_gradient.fill = GradientTexture2D.FILL_RADIAL
	_gradient.fill_from = Vector2(0.5, 0.5)
	_gradient.fill_to = Vector2(1.0, 0.5)
	return _gradient


## Build a configured point light. Returns null when lighting is disabled.
##
## [param casts_shadow] is only honoured at the highest tier.
static func make_light(
	color: Color,
	energy: float,
	scale: float = LIGHT_TEXTURE_SCALE,
	casts_shadow: bool = false
) -> PointLight2D:
	if not lights_enabled():
		return null

	var light := PointLight2D.new()
	light.texture = light_texture()
	light.color = color
	light.energy = energy
	light.texture_scale = scale
	light.shadow_enabled = casts_shadow and shadows_enabled()
	if light.shadow_enabled:
		light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		light.shadow_filter_smooth = 2.0
	return light


## Reset cached state. Tests use this to exercise each tier.
static func clear_cache() -> void:
	_resolved = false
	_gradient = null
