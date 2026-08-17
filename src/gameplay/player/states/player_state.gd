@abstract
class_name PlayerState
extends Node

## Base class for every player state.
##
## States are thin: they read input, set velocity on the shared [Player] context
## and request transitions. They never own persistent data — anything that has to
## survive a transition (combo step, coyote timer, facing) lives on the Player.
##
## `@abstract` is a Godot 4.5+ feature; see
## docs/engine-reference/godot/current-best-practices.md.

## Set by [StateMachine] during its `_ready`.
var state_machine: StateMachine

## The character this state drives. Resolved lazily so states work regardless of
## where they sit under the Player node.
@onready var player: Player = _find_player()


func _find_player() -> Player:
	var node: Node = get_parent()
	while node != null:
		var candidate := node as Player
		if candidate != null:
			return candidate
		node = node.get_parent()
	push_error("PlayerState '%s' is not a descendant of a Player node" % name)
	return null


## Called when the state becomes current. [param payload] carries data from the
## previous state, e.g. the combo step being chained into.
@abstract
func enter(payload: Dictionary) -> void


## Called when the state stops being current.
func exit() -> void:
	pass


## Per physics frame, while current.
func physics_update(_delta: float) -> void:
	pass


## Unhandled input, while current.
func handle_input(_event: InputEvent) -> void:
	pass


# -- Shared transition helpers ----------------------------------------------
# These encode rules that several states need identically, so the rules cannot
# drift apart between states.


## Route to the correct airborne state, or return false if still grounded.
func try_fall_off_ledge() -> bool:
	if player.is_on_floor():
		return false
	state_machine.transition_to(&"Fall", {"from_ledge": true})
	return true


## Consume a buffered or fresh jump if one is available. Returns true if a jump
## state was entered.
func try_jump() -> bool:
	if not player.wants_jump():
		return false
	if player.can_ground_jump():
		player.consume_jump_input()
		state_machine.transition_to(&"Jump", {"double": false})
		return true
	if player.can_double_jump():
		player.consume_jump_input()
		state_machine.transition_to(&"Jump", {"double": true})
		return true
	return false


## Start an attack if the button was pressed. Returns true on transition.
func try_attack() -> bool:
	if not Input.is_action_just_pressed(&"attack"):
		return false
	if player.is_on_floor():
		state_machine.transition_to(&"Attack", {"step": 0})
	else:
		state_machine.transition_to(&"AirAttack", {})
	return true


## Throw the equipped sub-weapon if the button was pressed and hearts allow.
## Does not change state — sub-weapons are usable from most states.
func try_subweapon() -> bool:
	if not Input.is_action_just_pressed(&"subweapon"):
		return false
	return player.throw_subweapon()


## Start a dash: mist dash if unlocked, backdash otherwise.
func try_dash() -> bool:
	if not Input.is_action_just_pressed(&"dash"):
		return false
	if GameState.has_ability(GameState.ABILITY_MIST_DASH) and player.can_mist_dash():
		state_machine.transition_to(&"MistDash", {})
		return true
	if player.is_on_floor() and player.can_backdash():
		state_machine.transition_to(&"Backdash", {})
		return true
	return false
