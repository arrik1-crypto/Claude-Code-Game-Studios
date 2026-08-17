extends TestCase

## Integration test: the player spawns cleanly into a live world.
##
## Regression cover for a spawn-order bug that ran on every single boot. The
## [StateMachine] is a child of [Player], and Godot readies children *before*
## their parent, so the machine's `_ready` entered the Idle state while the
## player's own `@onready` references were all still null. Idle's `enter()` calls
## `play_animation()`, which reached through the unset `sprite` and threw
## "Invalid access to property 'sprite_frames' on a base object of type 'Nil'".
##
## Nothing caught it. The engine logs a script error and carries on, the test
## suite never instantiated a Player, and the screenshot harness reported PASS
## because the player *looked* right — the next state transition set an
## animation a few frames later and covered the gap.
##
## The machine is now started explicitly by the player, last thing in its
## `_ready`. These tests assert the observable consequences of that ordering.

const PLAYER_SCENE: String = "res://src/gameplay/player/player.tscn"

var _host: Node2D


func before_each() -> void:
	_host = Node2D.new()
	Engine.get_main_loop().root.add_child(_host)
	GameState.new_game()


func after_each() -> void:
	if is_instance_valid(_host):
		_host.queue_free()


func _spawn_player() -> Player:
	var scene: PackedScene = load(PLAYER_SCENE) as PackedScene
	if scene == null:
		return null
	var player: Player = scene.instantiate() as Player
	if player == null:
		return null
	_host.add_child(player)
	return player


func test_the_player_scene_instantiates() -> void:
	var player: Player = _spawn_player()
	assert_not_null(player, "the player scene must load and instantiate")


func test_onready_references_are_live_after_spawn() -> void:
	# If any of these is null the state machine would have been driving a
	# half-built player.
	var player: Player = _spawn_player()
	assert_not_null(player, "the player must spawn")
	if player == null:
		return
	assert_not_null(player.sprite, "sprite must be resolved")
	assert_not_null(player.state_machine, "state_machine must be resolved")


func test_the_state_machine_is_running_after_spawn() -> void:
	var player: Player = _spawn_player()
	assert_not_null(player, "the player must spawn")
	if player == null:
		return
	assert_not_null(player.state_machine.current_state,
		"the machine must have a current state once the player is ready")
	assert_true(player.state_machine.is_state(&"Idle"),
		"a freshly spawned player stands idle")


func test_the_spawn_animation_actually_played() -> void:
	# This is the assertion that fails if the machine self-starts again: with a
	# null `sprite` the Idle state's `play_animation` throws and no animation is
	# ever set, so the player renders whatever frame the scene happened to save.
	var player: Player = _spawn_player()
	assert_not_null(player, "the player must spawn")
	if player == null:
		return
	assert_not_null(player.sprite.sprite_frames,
		"the player's frames must be built during spawn")
	assert_eq(String(player.sprite.animation), "idle",
		"entering Idle must have set the idle animation on the sprite")


func test_starting_the_machine_twice_is_harmless() -> void:
	# `start()` is called by the player, but a room reload or a respawn path
	# calling it again must not re-enter the state and reset the player.
	var player: Player = _spawn_player()
	assert_not_null(player, "the player must spawn")
	if player == null:
		return
	player.state_machine.transition_to(&"Fall", {})
	# Transitions are queued and applied at the end of an update, not inline.
	player.state_machine.physics_update(1.0 / 60.0)
	assert_true(player.state_machine.is_state(&"Fall"), "the transition must apply")

	player.state_machine.start()
	assert_true(player.state_machine.is_state(&"Fall"),
		"a second start() must not yank the player back to Idle")
