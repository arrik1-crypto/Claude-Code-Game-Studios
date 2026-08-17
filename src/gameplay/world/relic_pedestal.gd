class_name RelicPedestal
extends Area2D

## A pedestal holding a traversal relic — the Metroidvania unlock beat.
##
## Taking a relic sets a world flag, so the pedestal stays empty on every
## subsequent visit and across save/load. What the relic *grants* is either a
## traversal ability or a sub-weapon, chosen by [member relic_type].

const PROP_SHEET: String = "res://assets/art/props/props.png"

enum RelicType {
	## Unlocks a traversal ability from GameState's ability constants.
	ABILITY,
	## Equips a sub-weapon from the `subweapons` block of balance.json.
	SUBWEAPON,
	## Swaps the equipped weapon.
	WEAPON,
}

@export var relic_type: RelicType = RelicType.ABILITY

## Ability id, sub-weapon id or weapon id, depending on [member relic_type].
@export var relic_id: String = ""

## Name shown in the pickup toast.
@export var display_name: String = "Relic"

## World flag recording that this relic has been taken. Must be unique.
@export var flag: String = ""

## Cool magical glow marking an uncollected relic.
const RELIC_LIGHT_COLOR: Color = Color(0.62, 0.86, 1.0)

@onready var sprite: AnimatedSprite2D = $Sprite

var light: PointLight2D = null
var _taken: bool = false
var _pulse: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	if flag == "":
		push_error("RelicPedestal '%s' has no flag; it would be collectable forever" % relic_id)

	if SpriteSheetLoader.apply(sprite, PROP_SHEET, "relic"):
		sprite.play("relic")

	# An uncollected relic is a landmark the player should notice from across a
	# dark room, so it always gets a light regardless of the room's budget.
	light = LightingQuality.make_light(RELIC_LIGHT_COLOR, 1.15, 2.2)
	if light != null:
		light.position = Vector2(0, -14)
		add_child(light)

	if GameState.get_flag(flag):
		_show_as_taken()


## Render the plinth as already looted.
##
## [param during_collision] must be true when this is reached from
## `body_entered`. Area2D refuses a direct `monitoring` write while the physics
## server is flushing queries — it logs "Can't change this state while flushing
## queries" and drops the assignment — so the relic the player just picked up
## would keep its collision active for the rest of the room's life.
func _show_as_taken(during_collision: bool = false) -> void:
	_taken = true
	# Keep the pedestal, lose the relic: the empty plinth is a landmark the
	# player can use to orient themselves on a return visit.
	sprite.frame = 0
	sprite.stop()
	sprite.modulate = Color(0.55, 0.55, 0.62, 1.0)
	if light != null:
		light.queue_free()
		light = null
	set_process(false)
	if during_collision:
		set_deferred("monitoring", false)
	else:
		monitoring = false


## Slow breathing pulse on the relic glow, so it reads as alive rather than
## as a static lamp.
func _process(delta: float) -> void:
	if light == null:
		return
	_pulse += delta * 1.7
	light.energy = 1.15 + sin(_pulse) * 0.28


func _on_body_entered(body: Node2D) -> void:
	if _taken or not (body is Player):
		return
	_take(body as Player)


func _take(player: Player) -> void:
	_taken = true
	GameState.set_flag(flag, true)

	match relic_type:
		RelicType.ABILITY:
			GameState.unlock_ability(relic_id)
		RelicType.SUBWEAPON:
			GameState.equip_subweapon(relic_id)
		RelicType.WEAPON:
			GameState.equipped_weapon = relic_id

	AudioDirector.play_sfx("level_up")
	EventBus.toast_requested.emit("%s acquired" % display_name)
	player.spawn_vfx("soul", global_position + Vector2(0, -12))
	_show_as_taken(true)
