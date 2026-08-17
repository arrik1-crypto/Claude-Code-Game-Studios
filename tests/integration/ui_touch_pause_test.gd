extends TestCase

## A touch-only player must be able to get back out of the pause menu.
##
## Regression cover for a soft-lock that made the APK unfinishable by touch —
## the only input method the game actually targets.
##
## The chain: `PauseMenu._show()` sets `get_tree().paused = true`. `TouchControls`
## was `PROCESS_MODE_PAUSABLE`, so the moment the pause button did its job, the
## entire touch layer — including the pause button itself — stopped processing
## input. There is no `Button` node anywhere in `pause_menu.tscn`, and the
## fallback `ui_confirm` action is bound to Enter and Space with no touch or
## gamepad binding. So on a phone: tap pause, and the only way out is to
## force-quit the app, losing everything since the last coffin.
##
## None of the desktop tests or screenshots could catch it, because a keyboard
## always had Escape.

const TOUCH_SCENE: String = "res://src/ui/touch/touch_controls.tscn"
const PAUSE_SCENE: String = "res://src/ui/screens/pause_menu.tscn"

var _host: Node


func before_each() -> void:
	_host = Node.new()
	Engine.get_main_loop().root.add_child(_host)


func after_each() -> void:
	# Never leave the tree paused for the suites that run after this one.
	Engine.get_main_loop().root.get_tree().paused = false
	if is_instance_valid(_host):
		_host.queue_free()


func _touch_controls() -> TouchControls:
	var scene: PackedScene = load(TOUCH_SCENE) as PackedScene
	var node: TouchControls = scene.instantiate() as TouchControls
	_host.add_child(node)
	# Force them on: the scene hides itself on a device with no touchscreen,
	# which is every machine this suite runs on.
	node.controls_visible = true
	return node


func _button(controls: TouchControls, name: String) -> TouchScreenButton:
	return controls.get_node_or_null("Buttons/%s" % name) as TouchScreenButton


func test_the_touch_layer_keeps_running_while_the_game_is_paused() -> void:
	# The heart of it. PAUSABLE here is the soft-lock.
	var controls: TouchControls = _touch_controls()
	assert_eq(controls.process_mode, Node.PROCESS_MODE_ALWAYS,
		"the touch layer must keep processing while paused, or its own pause "
		+ "button freezes the instant it is used")


func test_a_pause_button_exists_for_touch_players() -> void:
	var controls: TouchControls = _touch_controls()
	assert_not_null(_button(controls, "BtnPause"),
		"there must be a touch route to the pause menu")


func test_a_map_button_exists_for_touch_players() -> void:
	# The map action was keyboard-and-gamepad only: Tab, or joypad button 4.
	# A touch player could never open the map at all.
	var controls: TouchControls = _touch_controls()
	var button: TouchScreenButton = _button(controls, "BtnMap")
	assert_not_null(button, "there must be a touch route to the map screen")
	if button != null:
		assert_eq(String(button.action), "map_screen", "BtnMap must fire map_screen")


func test_the_pause_and_map_buttons_survive_an_open_overlay() -> void:
	var controls: TouchControls = _touch_controls()
	EventBus.overlay_toggled.emit(true)

	for name: String in ["BtnPause", "BtnMap"]:
		var button: TouchScreenButton = _button(controls, name)
		assert_not_null(button, "%s must exist" % name)
		if button != null:
			assert_true(button.visible,
				"%s must stay visible while an overlay is up — it is the way out" % name)


func test_gameplay_buttons_are_withdrawn_while_an_overlay_is_up() -> void:
	# The flip side: keeping the layer alive must not leave a live d-pad
	# hovering over a frozen world.
	var controls: TouchControls = _touch_controls()
	EventBus.overlay_toggled.emit(true)

	for name: String in ["DpadLeft", "DpadRight", "BtnJump", "BtnAttack"]:
		var button: TouchScreenButton = _button(controls, name)
		if button != null:
			assert_false(button.visible,
				"%s must be withdrawn while the game is paused" % name)


func test_gameplay_buttons_come_back_when_the_overlay_closes() -> void:
	var controls: TouchControls = _touch_controls()
	EventBus.overlay_toggled.emit(true)
	EventBus.overlay_toggled.emit(false)

	for name: String in ["DpadLeft", "BtnJump", "BtnAttack"]:
		var button: TouchScreenButton = _button(controls, name)
		if button != null:
			assert_true(button.visible, "%s must return after resuming" % name)


func test_no_action_is_left_latched_down_across_a_pause() -> void:
	# A TouchScreenButton hidden mid-press never emits its release, so without
	# an explicit sweep the player resumes still running left.
	var controls: TouchControls = _touch_controls()
	Input.action_press(&"move_left")
	assert_true(Input.is_action_pressed(&"move_left"), "arrange: the action is held")

	EventBus.overlay_toggled.emit(true)
	assert_false(Input.is_action_pressed(&"move_left"),
		"opening an overlay must release whatever the player was holding")


func test_the_back_button_closes_an_overlay_instead_of_quitting() -> void:
	# Android's Back would otherwise tear the app down and discard the run.
	var scene: PackedScene = load(PAUSE_SCENE) as PackedScene
	var menu: PauseMenu = scene.instantiate() as PauseMenu
	_host.add_child(menu)

	assert_true(menu.handle_back_request(), "back must be consumed, not passed to quit")
	assert_true(menu.is_in_group(&"pause_menu"),
		"SceneDirector finds the menu by group to route the back button")


func test_quit_on_go_back_is_disabled() -> void:
	assert_false(bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)),
		"a stray back-swipe must not kill the app and lose the run")
