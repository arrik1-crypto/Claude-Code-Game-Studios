class_name StateMachine
extends Node

## A minimal hierarchical-free finite state machine driven by child nodes.
##
## Each child is a [PlayerState]. Exactly one is current; the machine forwards
## physics and input to it and performs transitions requested via
## [method transition_to].
##
## Transitions are queued rather than applied mid-update: a state that requests a
## transition finishes its own frame first, which avoids the classic bug where
## `enter()` runs against a half-updated velocity.

signal state_changed(from: StringName, to: StringName)

## Name of the state entered on ready.
@export var initial_state: StringName = &"Idle"

var current_state: PlayerState = null
var previous_state_name: StringName = &""

var _states: Dictionary = {}
var _pending: StringName = &""
var _pending_payload: Dictionary = {}
var _started: bool = false


func _ready() -> void:
	for child: Node in get_children():
		var state := child as PlayerState
		if state == null:
			push_warning("StateMachine: child '%s' is not a PlayerState and will be ignored"
				% child.name)
			continue
		_states[StringName(child.name)] = state
		state.state_machine = self

	if _states.is_empty():
		push_error("StateMachine on %s has no states" % get_parent().name)
		set_physics_process(false)
		return

	if not _states.has(initial_state):
		push_error("StateMachine: initial state '%s' does not exist" % initial_state)
		initial_state = _states.keys()[0]

	current_state = _states[initial_state]


## Enter the initial state and begin running.
##
## Deliberately NOT done in `_ready`. Godot readies children before their parent,
## so this node is ready while the [Player] that owns it still has every
## `@onready` reference unset — and `enter()` immediately calls back into the
## player to set an animation. Letting the machine self-start threw
## "Invalid access to property 'sprite_frames' on a base object of type 'Nil'"
## on every single spawn. The owner starts it once it is genuinely ready.
func start() -> void:
	if current_state == null or _started:
		return
	_started = true
	current_state.enter({})


## Request a transition. Applied at the end of the current physics step, or
## immediately if called from outside the update loop.
func transition_to(state_name: StringName, payload: Dictionary = {}) -> void:
	if not _states.has(state_name):
		push_error("StateMachine: no state named '%s'" % state_name)
		return
	_pending = state_name
	_pending_payload = payload


## True when [param state_name] is the running state.
func is_state(state_name: StringName) -> bool:
	return current_state != null and StringName(current_state.name) == state_name


func state_name() -> StringName:
	return StringName(current_state.name) if current_state != null else &""


func physics_update(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)
	_apply_pending()


func handle_input(event: InputEvent) -> void:
	if current_state != null:
		current_state.handle_input(event)
	_apply_pending()


func _apply_pending() -> void:
	# Loop so a state whose enter() immediately redirects (e.g. Land -> Run)
	# resolves within the same frame instead of showing a one-frame flicker.
	var guard: int = 0
	while _pending != &"":
		guard += 1
		if guard > 8:
			push_error("StateMachine: transition loop detected around '%s'" % _pending)
			break

		var next: PlayerState = _states[_pending]
		var payload: Dictionary = _pending_payload
		_pending = &""
		_pending_payload = {}

		var from: StringName = state_name()
		if current_state != null:
			current_state.exit()
		previous_state_name = from
		current_state = next
		current_state.enter(payload)
		state_changed.emit(from, StringName(next.name))
