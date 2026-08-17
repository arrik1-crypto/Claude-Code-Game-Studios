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

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var light: PointLight2D = $Light

var _taken: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	if flag == "":
		push_error("RelicPedestal '%s' has no flag; it would be collectable forever" % relic_id)

	if SpriteSheetLoader.apply(sprite, PROP_SHEET, "relic"):
		sprite.play("relic")

	if GameState.get_flag(flag):
		_show_as_taken()


func _show_as_taken() -> void:
	_taken = true
	# Keep the pedestal, lose the relic: the empty plinth is a landmark the
	# player can use to orient themselves on a return visit.
	sprite.frame = 0
	sprite.stop()
	sprite.modulate = Color(0.55, 0.55, 0.62, 1.0)
	light.enabled = false
	monitoring = false


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
	_show_as_taken()
