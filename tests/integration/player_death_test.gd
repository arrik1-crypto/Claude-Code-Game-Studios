extends TestCase

## Dying must actually reach the game-over screen.
##
## Regression cover for a freeze reported from a real phone: the player died and
## the game simply stopped. Not crashed — enemies, camera and music kept running
## and the death sound played, the character just stood there, invulnerable,
## forever. The only way out was force-quitting the app and losing the run.
##
## The cause was an ordering bug with a long fuse. `Player._on_died` cleared
## `_control_enabled` and *then* called `state_machine.transition_to(&"Dead")`.
## That call only queues; the queue is drained inside `physics_update`, and
## `physics_update` was itself gated on `_control_enabled`. So the Dead state was
## never entered, and `SceneDirector.game_over()` — which DeadState is the only
## caller of — was unreachable.
##
## Nothing caught it because no test in the project referenced `game_over`,
## `player_died` or `dead_state`. `combat_health_test.gd` tests `Health` in
## isolation and never touches the Player/StateMachine wiring, which is exactly
## where the break was.

const PLAYER_SCENE: String = "res://src/gameplay/player/player.tscn"

## Physics steps to pump. The transition is queued, so it needs at least one
## step to apply; a handful more proves the Dead state then keeps ticking.
const STEPS: int = 8
const STEP_DELTA: float = 1.0 / 60.0

var _host: Node2D


func before_each() -> void:
	_host = Node2D.new()
	Engine.get_main_loop().root.add_child(_host)
	GameState.new_game()


func after_each() -> void:
	Engine.get_main_loop().root.get_tree().paused = false
	if is_instance_valid(_host):
		_host.queue_free()


func _spawn_player() -> Player:
	var scene: PackedScene = load(PLAYER_SCENE) as PackedScene
	var player: Player = scene.instantiate() as Player
	_host.add_child(player)
	return player


## Kill the player the way the game does — through Health, not by poking flags.
func _kill(player: Player) -> void:
	player.health.take_damage(player.health.max_hp * 4, null)


func _pump(player: Player, steps: int = STEPS) -> void:
	for i: int in range(steps):
		player.state_machine.physics_update(STEP_DELTA)


func test_taking_fatal_damage_marks_the_player_dead() -> void:
	var player: Player = _spawn_player()
	assert_false(player.is_dead(), "arrange: the player starts alive")
	_kill(player)
	assert_true(player.is_dead(), "fatal damage must mark the player dead")


func test_the_dead_state_is_actually_entered() -> void:
	# THE assertion that fails without the fix. Before it, `_pending` stayed
	# &"Dead" forever and `current_state` never changed.
	var player: Player = _spawn_player()
	_kill(player)
	_pump(player)
	assert_true(player.state_machine.is_state(&"Dead"),
		"the Dead state must be entered; it is the only thing that calls "
		+ "SceneDirector.game_over(), so a stuck transition freezes the game")


func test_the_state_machine_keeps_running_once_control_is_disabled() -> void:
	# `_control_enabled` means "the player may act", not "stop simulating".
	# Gating the machine on it is what stranded the death sequence.
	var player: Player = _spawn_player()
	player.set_control_enabled(false)
	player.state_machine.transition_to(&"Fall", {})
	_pump(player, 2)
	assert_true(player.state_machine.is_state(&"Fall"),
		"a queued transition must still apply while control is disabled")


func test_disabling_control_suppresses_input_rather_than_simulation() -> void:
	# The other half of that contract: states must stop *reading* input.
	var player: Player = _spawn_player()
	Input.action_press(&"move_right")

	assert_gt(player.move_axis(), 0.0, "arrange: input registers while in control")
	player.set_control_enabled(false)
	assert_eq(player.move_axis(), 0.0, "movement input must be ignored")
	assert_false(player.wants(&"move_right"), "held actions must read as unheld")
	Input.action_release(&"move_right")


func test_the_death_sequence_hands_off_rather_than_stalling() -> void:
	# DeadState counts down and then emits `death_finished` on its way to calling
	# SceneDirector.game_over(). Pump past the hold and assert the hand-off fires
	# — that signal is the last thing under this test's control before the scene
	# swap, so it is the honest boundary to assert on.
	var player: Player = _spawn_player()
	var fired: Array[bool] = [false]
	player.death_finished.connect(func() -> void: fired[0] = true)

	_kill(player)
	# DeadState holds for 1.1s after the animation; 3 seconds is comfortably past.
	_pump(player, 180)

	assert_true(fired[0],
		"the death sequence must hand off; if it never does, the player is stuck "
		+ "alive-but-dead with no way to reach the game-over screen")


func test_a_dead_player_cannot_be_killed_again() -> void:
	var player: Player = _spawn_player()
	_kill(player)
	_pump(player)
	assert_false(player.hurtbox.active, "a corpse must not keep taking hits")


func test_the_watchdog_timeout_outlasts_a_healthy_death() -> void:
	# The watchdog only exists to catch a broken death path. If it were shorter
	# than a normal death it would fire during ordinary play and yank the player
	# to the game-over screen early.
	assert_gt(SceneDirector.DEATH_WATCHDOG_TIMEOUT, 2.0,
		"the watchdog must not pre-empt a healthy death sequence")
