extends Control

## Title screen: new game, continue, and the controls reference.
##
## "Continue" is only offered when a save actually exists, so a first-time player
## is never presented with a dead option.

@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var save_info: Label = %SaveInfo


func _ready() -> void:
	AudioDirector.play_music("title")

	var has_save: bool = GameState.has_save(0)
	continue_button.visible = has_save
	continue_button.disabled = not has_save

	if has_save:
		_describe_save()
		continue_button.grab_focus()
	else:
		save_info.text = ""
		new_game_button.grab_focus()

	new_game_button.pressed.connect(_on_new_game)
	continue_button.pressed.connect(_on_continue)


## Peek at the save without loading it into the live GameState.
func _describe_save() -> void:
	var path: String = GameState.save_path(0)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		save_info.text = ""
		return
	var text: String = file.get_as_text()
	file.close()

	var parser: JSON = JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		save_info.text = "Saved game (unreadable)"
		return

	var d: Dictionary = parser.data
	var seconds: int = int(float(d.get("playtimeSeconds", 0.0)))
	var room: String = RoomIndex.display_name(String(d.get("respawnRoom", "")))
	save_info.text = "Level %d   %d:%02d   %s" % [
		int(d.get("level", 1)), seconds / 60, seconds % 60, room]


func _on_new_game() -> void:
	AudioDirector.play_sfx("ui_select")
	SceneDirector.start_new_game()


func _on_continue() -> void:
	AudioDirector.play_sfx("ui_select")
	SceneDirector.continue_game(0)
