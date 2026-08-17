class_name World
extends Node2D

## The gameplay container: one room at a time, the player, the camera and the UI.
##
## [SceneDirector] owns *when* rooms change; this node owns *how*. Keeping the
## two separate means the fade and the room build can be sequenced correctly
## without either one knowing the other's internals.

const PLAYER_SCENE: String = "res://src/gameplay/player/player.tscn"

## Extra margin beyond the room bounds for the camera limits, so a room narrower
## than the viewport still centres nicely.
const CAMERA_MARGIN: float = 0.0

## Camera lead, in pixels. Scaled for the 56px character: the camera should show
## roughly half a body ahead of where the player is facing.
const LOOK_AHEAD_X: float = 28.0
const LOOK_AHEAD_Y: float = -28.0

## Per-frame lerp weight towards the look-ahead target.
const CAMERA_FOLLOW_WEIGHT: float = 0.14

@onready var room_host: Node2D = $RoomHost
@onready var camera: Camera2D = $Camera2D
@onready var backdrop: ParallaxBackdrop = $Backdrop

var player: Player = null
var current_room: Room = null

var _shake_strength: float = 0.0
var _shake_decay: float = 0.0
var _hit_stop_active: bool = false


func _ready() -> void:
	SceneDirector.world = self

	EventBus.screen_shake_requested.connect(_on_shake_requested)
	EventBus.hit_stop_requested.connect(_on_hit_stop_requested)

	_spawn_player()

	var start_room: String = GameState.current_room
	if start_room == "":
		start_room = "outer_ward_gate"
		GameState.current_room = start_room
	build_room(start_room, GameState.spawn_door)


func _exit_tree() -> void:
	if SceneDirector.world == self:
		SceneDirector.world = null
	# Never leave the engine paused or slowed if the scene is torn down mid-effect.
	Engine.time_scale = 1.0


func _spawn_player() -> void:
	var scene: PackedScene = load(PLAYER_SCENE) as PackedScene
	if scene == null:
		push_error("World: could not load %s" % PLAYER_SCENE)
		return
	player = scene.instantiate() as Player
	add_child(player)


## Tear down the current room and build [param room_id], placing the player at
## [param door_id]. Called by [SceneDirector] while the screen is faded out.
func build_room(room_id: String, door_id: String) -> void:
	if current_room != null and is_instance_valid(current_room):
		# free() rather than queue_free(): the new room is built this same frame
		# and two rooms must never share the physics space.
		room_host.remove_child(current_room)
		current_room.free()
		current_room = null

	var room := Room.new()
	room.name = "Room"
	room_host.add_child(room)

	if not room.build(room_id):
		push_error("World: failed to build room '%s'" % room_id)
		return

	current_room = room
	_place_player(room, door_id)
	_apply_camera_limits(room)
	_apply_backdrop(room)

	AudioDirector.play_music(room.music_track)
	EventBus.room_entered.emit(room_id)


func _place_player(room: Room, door_id: String) -> void:
	if player == null or not is_instance_valid(player):
		_spawn_player()
	if player == null:
		return

	player.global_position = room.spawn_point_for(door_id)
	player.velocity = Vector2.ZERO
	player.set_facing(room.entry_facing_for(door_id))
	# Snap the camera so the new room does not smear past during the fade-in.
	camera.global_position = player.global_position
	camera.reset_smoothing()


## Show the skyline only in rooms that declare themselves open to the sky.
##
## An interior room fills its background with masonry, which would hide the
## backdrop entirely; drawing it there would be pure cost for no pixels.
func _apply_backdrop(room: Room) -> void:
	if backdrop == null:
		return
	backdrop.set_active(room.shows_sky)
	if room.shows_sky and room.lighting != null:
		backdrop.match_ambient(room.lighting.color)


func _apply_camera_limits(room: Room) -> void:
	var rect: Rect2 = room.bounds
	camera.limit_left = int(rect.position.x - CAMERA_MARGIN)
	camera.limit_top = int(rect.position.y - CAMERA_MARGIN)
	camera.limit_right = int(rect.end.x + CAMERA_MARGIN)
	camera.limit_bottom = int(rect.end.y + CAMERA_MARGIN)


func _process(delta: float) -> void:
	_follow_player()
	_update_shake(delta)


func _follow_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	# Lead the camera towards a look-ahead point rather than locking to the
	# player, which keeps more of the room ahead of them on screen.
	#
	# This is the ONLY smoothing in play. The Camera2D's own
	# `position_smoothing` used to be enabled as well, and the two compounded
	# into a camera that lagged noticeably behind fast movement.
	var target: Vector2 = player.global_position \
		+ Vector2(float(player.facing) * LOOK_AHEAD_X, LOOK_AHEAD_Y)
	camera.global_position = camera.global_position.lerp(target, CAMERA_FOLLOW_WEIGHT)


func _on_shake_requested(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_decay = maxf(_shake_decay, strength / maxf(0.01, duration))


func _update_shake(delta: float) -> void:
	if _shake_strength <= 0.0:
		camera.offset = Vector2.ZERO
		return
	_shake_strength = maxf(0.0, _shake_strength - _shake_decay * delta)
	camera.offset = Vector2(
		randf_range(-_shake_strength, _shake_strength),
		randf_range(-_shake_strength, _shake_strength))


## Brief time freeze on impact. Uses an unscaled timer so the freeze cannot
## extend itself.
func _on_hit_stop_requested(duration: float) -> void:
	if _hit_stop_active:
		return
	_hit_stop_active = true
	Engine.time_scale = 0.03
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stop_active = false
