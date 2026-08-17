class_name PauseMenu
extends CanvasLayer

## Pause overlay and map screen.
##
## Both live here because they are the same interaction: the game stops, an
## overlay appears, and one button dismisses it. Opening the map from a paused
## game — and pausing from the map — therefore needs no state juggling.
##
## Runs with `PROCESS_MODE_ALWAYS` so it can still respond while the tree is
## paused; everything else in the game is `PAUSABLE` and freezes.

enum Screen { NONE, PAUSED, MAP }

@onready var dim: ColorRect = %Dim
@onready var pause_panel: Control = %PausePanel
@onready var map_panel: Control = %MapPanel
@onready var map_view: MapView = %MapView
@onready var map_title: Label = %MapTitle
@onready var map_summary: Label = %MapSummary
@onready var stats_text: Label = %StatsText
@onready var hint: Label = %Hint

var _screen: Screen = Screen.NONE


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"pause_menu")
	_show(Screen.NONE)


## Handle the Android hardware/gesture Back button.
##
## `application/config/quit_on_go_back` is disabled in project.godot, so this is
## the only thing standing between a stray back-swipe and the player losing
## every minute since their last coffin. Back closes an overlay if one is up,
## and otherwise opens the pause menu — the Android convention of "go up one
## level", not "exit".
##
## Returns true when the press was consumed.
func handle_back_request() -> bool:
	if SceneDirector.is_busy():
		return true
	if _screen != Screen.NONE:
		_show(Screen.NONE)
	else:
		_show(Screen.PAUSED)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if SceneDirector.is_busy():
		return

	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_show(Screen.NONE if _screen == Screen.PAUSED else Screen.PAUSED)
		return

	if event.is_action_pressed(&"map_screen"):
		get_viewport().set_input_as_handled()
		_show(Screen.NONE if _screen == Screen.MAP else Screen.MAP)
		return

	# While an overlay is up, the confirm button closes it. Without this a touch
	# player with no Escape key could open the map and never get out.
	if _screen != Screen.NONE and event.is_action_pressed(&"ui_confirm"):
		get_viewport().set_input_as_handled()
		_show(Screen.NONE)


func _show(screen: Screen) -> void:
	_screen = screen

	var showing: bool = screen != Screen.NONE
	dim.visible = showing
	pause_panel.visible = screen == Screen.PAUSED
	map_panel.visible = screen == Screen.MAP
	get_tree().paused = showing
	# The touch layer needs this: it stays alive while paused so its pause and
	# map buttons still work, and hides the gameplay buttons in response.
	EventBus.overlay_toggled.emit(showing)

	if screen == Screen.PAUSED:
		_refresh_stats()
		AudioDirector.play_sfx("ui_select", -6.0)
	elif screen == Screen.MAP:
		_refresh_map()
		AudioDirector.play_sfx("ui_select", -6.0)


func _refresh_stats() -> void:
	var minutes: int = int(GameState.playtime_seconds) / 60
	var seconds: int = int(GameState.playtime_seconds) % 60
	stats_text.text = "\n".join([
		"Seraphine Valcourt",
		"",
		"Level        %d" % GameState.level,
		"HP           %d / %d" % [GameState.current_hp, GameState.max_hp],
		"MP           %d / %d" % [int(GameState.current_mp), int(GameState.max_mp)],
		"Hearts       %d" % GameState.hearts,
		"Gold         %d" % GameState.gold,
		"",
		"STR %d   CON %d   INT %d   LCK %d" % [
			GameState.strength, GameState.constitution,
			GameState.intelligence, GameState.luck],
		"",
		"Next level   %d exp" % GameState.exp_to_next_level(),
		"Playtime     %d:%02d" % [minutes, seconds],
	])
	hint.text = _dismiss_hint()


## What to tell the player about getting out of here.
##
## Branching on input method is forbidden in gameplay code, but this is the one
## place it is the whole point: naming a key that a phone does not have is not a
## hint, it is a dead end. The touch wording matches the two buttons left live
## in the corner while the overlay is up.
func _dismiss_hint() -> String:
	if DisplayServer.is_touchscreen_available():
		return "tap  ▮▮  resume     tap  ▤  map"
	return "ESC resume    TAB map"


func _refresh_map() -> void:
	map_title.text = RoomIndex.display_name(GameState.current_room)
	map_view.refresh()
	map_summary.text = map_view.exploration_summary()


## Close any overlay and unpause. Called by [SceneDirector] before a transition.
func close() -> void:
	if _screen != Screen.NONE:
		_show(Screen.NONE)
