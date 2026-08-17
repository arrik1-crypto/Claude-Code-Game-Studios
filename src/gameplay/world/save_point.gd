class_name SavePoint
extends Area2D

## A coffin the player rests in to save, heal and set their respawn point.
##
## Saving is explicit rather than automatic. In a Metroidvania the save room is a
## pacing beat — the moment you decide whether to push on with half health or
## walk back — and an autosave would erase that decision.

const PROP_SHEET: String = "res://assets/art/props/props.png"

## Identifier of the door players respawn at when they die.
@export var respawn_door: String = "save"

## Save slot written to.
@export var slot: int = 0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var prompt: Label = $Prompt

var _player_inside: bool = false
var _room_id: String = ""


func _ready() -> void:
	add_to_group(&"save_points")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if SpriteSheetLoader.apply(sprite, PROP_SHEET, "save_coffin"):
		sprite.play("save_coffin")

	prompt.visible = false
	prompt.text = "REST"


## The room builder tells the save point which room it lives in.
func set_room(room_id: String) -> void:
	_room_id = room_id


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if not event.is_action_pressed(&"interact"):
		return
	get_viewport().set_input_as_handled()
	_perform_save()


func _perform_save() -> void:
	if _room_id == "":
		_room_id = GameState.current_room

	GameState.set_respawn(_room_id, respawn_door)
	GameState.set_hp(GameState.max_hp)
	GameState.set_mp(GameState.max_mp)

	if GameState.save_to_slot(slot):
		EventBus.toast_requested.emit("Saved. Rest well.")
		SceneDirector.flash_fade()
	else:
		EventBus.toast_requested.emit("Could not save.")


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_inside = true
		prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_inside = false
		prompt.visible = false
