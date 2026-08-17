class_name Pickup
extends Area2D

## A collectable dropped by enemies or placed in a room.
##
## What the item *does* comes from the `pickups` block in balance.json, so adding
## a new drop type is a data change plus one atlas animation — no new scene and
## no new script.
##
## Dropped pickups fall to the ground before settling, which keeps candle drops
## from hanging in mid-air over a pit.

const PROP_SHEET: String = "res://assets/art/props/props.png"

## Hearts are the most-seen pickup in the game, so they use the pack's
## ten-frame spin rather than the two-frame generated bob.
const HEART_SHEET: String = "res://assets/art/props/heart_pickup.png"

## Seconds before an uncollected pickup despawns. Zero means it never expires;
## placed pickups (as opposed to drops) use that.
@export var lifetime: float = 9.0

## Seconds of flashing before despawn, warning the player it is about to go.
@export var warn_time: float = 2.5

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var ground_probe: RayCast2D = $GroundProbe

var item_id: String = "heart"

var _config: Dictionary = {}
var _fall_speed: float = 0.0
var _grounded: bool = false
var _age: float = 0.0
var _bob_phase: float = 0.0
var _rest_y: float = 0.0
var _collected: bool = false


func _ready() -> void:
	_bob_phase = randf() * TAU
	if item_id != "":
		configure(item_id)


## Set which pickup this is. Safe to call before or after the node enters the tree.
func configure(id: String) -> void:
	item_id = id
	if not is_inside_tree():
		return

	_config = Balance.entry("pickups", id)
	if _config.is_empty():
		push_error("Pickup: no balance entry for pickups.%s" % id)

	if id == "heart" or id == "heart_large":
		if SpriteSheetLoader.apply(sprite, HEART_SHEET, "spin"):
			# Large hearts are the same art, scaled and slightly gilded.
			if id == "heart_large":
				sprite.scale = Vector2(1.45, 1.45)
				sprite.modulate = Color(1.0, 0.86, 0.6)
			return
	if SpriteSheetLoader.apply(sprite, PROP_SHEET):
		var anim: String = _animation_for(id)
		if sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)


## Map an item id to its atlas animation. Large variants share the base art.
func _animation_for(id: String) -> String:
	match id:
		"heart", "heart_large":
			return "heart"
		"gold", "gold_large":
			return "gold"
		"hp_orb":
			return "hp_orb"
		_:
			return "heart"


func _physics_process(delta: float) -> void:
	if _collected:
		return

	if not _grounded:
		_fall_speed = minf(_fall_speed + 700.0 * delta, 260.0)
		position.y += _fall_speed * delta
		ground_probe.force_raycast_update()
		if ground_probe.is_colliding():
			_grounded = true
			_rest_y = position.y
	else:
		# Gentle bob so pickups catch the eye against a busy tile background.
		_bob_phase += delta * 4.0
		position.y = _rest_y + sin(_bob_phase) * 1.5

	if lifetime <= 0.0:
		return
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	if _age >= lifetime - warn_time:
		sprite.visible = fmod(_age, 0.2) < 0.12


## Called by the player's pickup collector.
func collect(_by: Node) -> void:
	if _collected:
		return
	_collected = true

	var hearts: int = int(_config.get("hearts", 0))
	var hp: int = int(_config.get("hp", 0))
	var gold: int = int(_config.get("gold", 0))

	if hearts > 0:
		GameState.add_hearts(hearts)
		AudioDirector.play_sfx("heart")
	if hp > 0:
		GameState.heal(hp)
		AudioDirector.play_sfx("pickup")
	if gold > 0:
		GameState.add_gold(gold)
		AudioDirector.play_sfx("pickup", -4.0)

	if hearts <= 0 and hp <= 0 and gold <= 0:
		push_warning("Pickup '%s' granted nothing — check balance.json" % item_id)

	queue_free()
