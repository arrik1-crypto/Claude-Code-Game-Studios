extends Control

## Shown after the player dies.
##
## Death is not punishing in this game: progress, gold and relics are kept, and
## the player restarts at the last coffin. The screen exists to mark the failure,
## not to take anything away.

@onready var retry_button: Button = %RetryButton
@onready var title_button: Button = %TitleButton
@onready var detail: Label = %Detail


func _ready() -> void:
	# Every other always-on screen in the game declares this; this one inherited
	# PAUSABLE and worked only because SceneDirector happens to unpause on the
	# line before it swaps the scene in. Reorder those two statements and the
	# Retry button silently stops responding — on the one screen the player
	# absolutely must be able to press.
	process_mode = Node.PROCESS_MODE_ALWAYS

	AudioDirector.stop_music(false)

	var has_respawn: bool = GameState.respawn_room != ""
	retry_button.visible = has_respawn
	retry_button.disabled = not has_respawn

	if has_respawn:
		detail.text = "You wake at %s." % RoomIndex.display_name(GameState.respawn_room)
		retry_button.grab_focus()
	else:
		detail.text = "No coffin claimed you. The run ends here."
		title_button.grab_focus()

	retry_button.pressed.connect(_on_retry)
	title_button.pressed.connect(_on_title)


func _on_retry() -> void:
	AudioDirector.play_sfx("ui_select")
	SceneDirector.respawn_at_save()


func _on_title() -> void:
	AudioDirector.play_sfx("ui_select")
	SceneDirector.go_to_title()
