extends CanvasLayer

## Autoload: screen flow and room streaming.
##
## Two responsibilities, deliberately kept together because they share the fade
## overlay:
##
## 1. Top-level screens — title, gameplay, game over.
## 2. Room-to-room transitions inside the castle. Rooms are streamed one at a
##    time: the outgoing room is freed before the incoming one is built, so
##    memory stays flat no matter how large the castle grows.
##
## The fade overlay lives on this CanvasLayer at a high layer index so it always
## covers the HUD and the touch controls.

const TITLE_SCENE: String = "res://src/ui/screens/title_screen.tscn"
const WORLD_SCENE: String = "res://src/gameplay/world/world.tscn"
const GAME_OVER_SCENE: String = "res://src/ui/screens/game_over_screen.tscn"

const FADE_OUT_TIME: float = 0.28
const FADE_IN_TIME: float = 0.34

signal transition_started(room_id: String)
signal transition_finished(room_id: String)

var _fade: ColorRect
var _busy: bool = false

## The active World node, when gameplay is running.
var world: Node = null


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS

	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.015, 0.03, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_fade.visible = false
	add_child(_fade)


## True while a transition is in flight. Input handlers should ignore actions.
## Route the Android Back button.
##
## With `quit_on_go_back` left at its default, Android's Back button tears the
## app down instantly. This game only writes a save at a coffin, so one stray
## back-swipe on a gesture-navigation phone discards the entire run. Back is
## handed to the pause menu when gameplay is running; on the title and game-over
## screens there is nothing to go back *to*, so it quits, which is what the
## platform convention expects of a root screen.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	for menu: Node in get_tree().get_nodes_in_group(&"pause_menu"):
		if menu.has_method("handle_back_request") and menu.handle_back_request():
			return
	get_tree().quit()


func is_busy() -> bool:
	return _busy


# -- Screen flow -------------------------------------------------------------


func go_to_title() -> void:
	world = null
	await _fade_out()
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
	await get_tree().process_frame
	AudioDirector.play_music("title")
	await _fade_in()


## Start a fresh run from the castle entrance.
func start_new_game(entry_room: String = "outer_ward_gate", entry_door: String = "start") -> void:
	GameState.new_game()
	GameState.current_room = entry_room
	GameState.spawn_door = entry_door
	GameState.set_respawn(entry_room, entry_door)
	await _enter_world()


## Resume a saved run.
func continue_game(slot: int = 0) -> void:
	if not GameState.load_from_slot(slot):
		push_error("SceneDirector: no save in slot %d" % slot)
		return
	await _enter_world()


func _enter_world() -> void:
	await _fade_out()
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_SCENE)
	# Wait for the new scene tree to be built before the World node registers.
	await get_tree().process_frame
	await get_tree().process_frame
	AudioDirector.play_music("explore")
	await _fade_in()


## Player death flow: fade, show the game-over screen, keep the save intact.
func game_over() -> void:
	if _busy:
		return
	_busy = true
	AudioDirector.stop_music()
	await _fade_out()
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_OVER_SCENE)
	await get_tree().process_frame
	await _fade_in()
	_busy = false


## Respawn at the last save point, restoring HP per balance.json.
func respawn_at_save() -> void:
	if GameState.respawn_room == "":
		await go_to_title()
		return
	var fraction: float = Balance.get_float("economy", "respawnHpFraction", 1.0)
	GameState.current_hp = maxi(1, int(round(float(GameState.max_hp) * fraction)))
	GameState.current_room = GameState.respawn_room
	GameState.spawn_door = GameState.respawn_door
	await _enter_world()


# -- Room streaming ----------------------------------------------------------


## Move the player to another room, entering from [param door_id].
##
## Safe to call from a door's body_entered handler: re-entrant calls while a
## transition is running are ignored.
func travel_to_room(room_id: String, door_id: String) -> void:
	if _busy:
		return
	if world == null or not is_instance_valid(world):
		push_error("SceneDirector: travel_to_room called with no active world")
		return

	_busy = true
	var previous: String = GameState.current_room
	transition_started.emit(room_id)
	EventBus.room_exited.emit(previous)

	await _fade_out()

	GameState.current_room = room_id
	GameState.spawn_door = door_id
	if world.has_method("build_room"):
		world.build_room(room_id, door_id)
	# Give the freshly built room one frame to settle physics before revealing it.
	await get_tree().physics_frame

	await _fade_in()

	_busy = false
	transition_finished.emit(room_id)


# -- Fade helpers ------------------------------------------------------------


func _fade_out(duration: float = FADE_OUT_TIME) -> void:
	_fade.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, duration)
	await tween.finished


func _fade_in(duration: float = FADE_IN_TIME) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "modulate:a", 0.0, duration)
	await tween.finished
	_fade.visible = false


## Fade to black and back without changing scenes — used for save confirmations.
func flash_fade() -> void:
	await _fade_out(0.15)
	await _fade_in(0.25)
