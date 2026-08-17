class_name RoomDoor
extends Area2D

## A doorway linking two rooms.
##
## Doors are bidirectional by convention: room A's `east` door points at room B's
## `west` door and vice versa. The room builder reads both ends from
## `assets/data/rooms/*.json`, so a mismatched link shows up as a validation
## error at build time rather than as a soft-lock during play.
##
## The same node serves two purposes — a trigger to travel, and an anchor the
## arriving player is placed at.

## Identifier within this room, e.g. "east", "upper_west".
@export var door_id: String = ""

## Room this door leads to.
@export var target_room: String = ""

## Door in the target room the player emerges from.
@export var target_door: String = ""

## Which way the player faces and is nudged when arriving here.
@export var entry_direction: int = 1

## How far inside the room the arriving player is placed, so they are never
## standing inside the trigger that would send them straight back.
@export var entry_offset: float = 14.0

var _armed: bool = false


func _ready() -> void:
	add_to_group(&"room_doors")
	body_entered.connect(_on_body_entered)
	# Doors arm after a beat so the player spawning on top of one does not
	# immediately re-trigger it.
	get_tree().create_timer(0.25).timeout.connect(func() -> void: _armed = true)


## World position an arriving player should be placed at.
func spawn_position() -> Vector2:
	return global_position + Vector2(float(entry_direction) * entry_offset, 0.0)


func _on_body_entered(body: Node2D) -> void:
	if not _armed or not (body is Player):
		return
	if target_room == "":
		push_error("RoomDoor '%s' has no target_room" % door_id)
		return
	if SceneDirector.is_busy():
		return
	SceneDirector.travel_to_room(target_room, target_door)
