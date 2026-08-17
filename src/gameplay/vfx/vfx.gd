class_name Vfx
extends RefCounted

## Fire-and-forget visual effects.
##
## Every call site is one line and never has to track the node it spawned. The
## library owns the atlas paths, the tints and the motion, so the *look* of an
## impact lives here rather than being re-decided in each of the six places
## something can be hit.
##
## Palette discipline (design/art-bible.md pillar 2): the tint tells the player
## what happened before the shape does. Gold is the player's whip, crimson is
## damage, moonlight is magic and traversal, dust is desaturated stone.

const SHEET_VFX: String = "res://assets/art/vfx/vfx.png"
const SHEET_DUST: String = "res://assets/art/vfx/dust.png"
const SHEET_SMEARS: String = "res://assets/art/vfx/smears.png"
const EFFECT_SCENE: String = "res://src/gameplay/vfx/effect.tscn"

## Whip arcs are gold; the lash and its smear must read as the same object.
const TINT_WHIP: Color = Color(0.94, 0.80, 0.45, 0.92)
## Boss steel is cold.
const TINT_STEEL: Color = Color(0.86, 0.88, 0.95, 0.85)
## Stone dust, desaturated so it never competes with crimson.
const TINT_DUST: Color = Color(0.72, 0.70, 0.80, 0.75)
## Mist form and magic.
const TINT_MIST: Color = Color(0.62, 0.86, 1.0, 0.85)

## Which smear variant each combo step uses. Chosen so the three swings read as
## a rising sequence rather than the same arc three times.
const SMEAR_BY_COMBO: PackedStringArray = ["smear_0", "smear_4", "smear_1"]


## Spawn a one-shot effect and return it, or null if it could not be created.
##
## [param options] accepts: `tint`, `scale`, `flip`, `rotation`, `z_index`,
## `fade`, `grow`, `lifetime`.
static func spawn(
	host: Node,
	sheet: String,
	animation: String,
	at: Vector2,
	options: Dictionary = {}
) -> Node2D:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return null

	var scene: PackedScene = load(EFFECT_SCENE) as PackedScene
	if scene == null:
		return null

	var effect: Node = scene.instantiate()
	host.add_child(effect)

	var effect_2d := effect as Node2D
	if effect_2d != null:
		effect_2d.global_position = at
		effect_2d.rotation = float(options.get("rotation", 0.0))
		var s: float = float(options.get("scale", 1.0))
		effect_2d.scale = Vector2(s, s)
		effect_2d.modulate = options.get("tint", Color.WHITE)
		effect_2d.z_index = int(options.get("z_index", 40))

	if effect.has_method("play_effect"):
		effect.play_effect(sheet, animation, bool(options.get("flip", false)))
	if effect.has_method("set_motion"):
		effect.set_motion(
			float(options.get("fade", 0.0)),
			float(options.get("grow", 0.0)),
			float(options.get("lifetime", 0.0)))

	return effect_2d


# -- Combat ------------------------------------------------------------------


## Whip arc, drawn in front of the player during a swing's active frames.
##
## [param combo_step] is 0-based and selects the arc variant.
static func whip_smear(host: Node, at: Vector2, facing: int, combo_step: int = 0,
		reach: float = 44.0) -> void:
	var variant: String = SMEAR_BY_COMBO[clampi(combo_step, 0, SMEAR_BY_COMBO.size() - 1)]
	# The 128px source art is scaled to the weapon's actual reach, so a longer
	# whip visibly sweeps further rather than just doing more damage.
	var arc_scale: float = clampf(reach / 128.0 * 2.0, 0.35, 1.1)
	spawn(host, SHEET_SMEARS, variant, at, {
		"tint": TINT_WHIP,
		"scale": arc_scale,
		"flip": facing < 0,
		"fade": 14.0,
		"grow": 1.6,
		"lifetime": 0.14,
	})


## Heavy weapon arc for the boss, cold and larger.
static func boss_smear(host: Node, at: Vector2, facing: int, reach: float = 46.0) -> void:
	spawn(host, SHEET_SMEARS, "smear_3", at, {
		"tint": TINT_STEEL,
		"scale": clampf(reach / 128.0 * 3.0, 0.5, 1.6),
		"flip": facing < 0,
		"fade": 9.0,
		"grow": 1.2,
		"lifetime": 0.2,
	})


## Expanding ring at the point of contact, on top of the existing spark.
static func impact(host: Node, at: Vector2, tint: Color = TINT_WHIP) -> void:
	spawn(host, SHEET_DUST, "impact", at, {
		"tint": tint,
		"scale": 0.8,
		"z_index": 45,
	})


static func hit_spark(host: Node, at: Vector2) -> void:
	spawn(host, SHEET_VFX, "hit_spark", at, {"z_index": 45})


static func blood(host: Node, at: Vector2) -> void:
	spawn(host, SHEET_VFX, "blood", at, {"z_index": 45})


static func soul(host: Node, at: Vector2) -> void:
	spawn(host, SHEET_VFX, "soul", at, {"z_index": 45})


# -- Movement ----------------------------------------------------------------


## Puff kicked up on take-off. Placed at the feet, not the body origin.
static func jump_dust(host: Node, at: Vector2) -> void:
	spawn(host, SHEET_DUST, "jump", at, {"tint": TINT_DUST, "scale": 0.9, "z_index": 15})


## Wider, flatter puff on touchdown. Scales with impact speed so a long fall
## lands harder than a hop.
static func land_dust(host: Node, at: Vector2, impact_speed: float = 0.0) -> void:
	var weight: float = clampf(impact_speed / 420.0, 0.0, 1.0)
	spawn(host, SHEET_DUST, "land", at, {
		"tint": TINT_DUST,
		"scale": lerpf(0.7, 1.35, weight),
		"z_index": 15,
	})


## Small scuff behind a running character.
static func run_dust(host: Node, at: Vector2, facing: int) -> void:
	spawn(host, SHEET_DUST, "run", at, {
		"tint": Color(TINT_DUST.r, TINT_DUST.g, TINT_DUST.b, 0.5),
		"scale": 0.6,
		"flip": facing > 0,
		"z_index": 15,
	})


## Trailing after-image for the Mist Dash.
static func mist_trail(host: Node, at: Vector2) -> void:
	spawn(host, SHEET_DUST, "jump", at, {
		"tint": TINT_MIST,
		"scale": 1.0,
		"fade": 8.0,
		"z_index": 18,
	})
