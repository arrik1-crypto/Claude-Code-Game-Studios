class_name MedusaSpawner
extends Node2D

## Emits a steady stream of [MedusaHead]s across a corridor.
##
## Medusa Heads are placed as a *hazard field*, not as individual enemies: the
## room designer drops a spawner at one end of a gauntlet and the stream becomes
## the obstacle. The alive cap keeps the pressure constant without letting the
## room fill up if the player waits.

const MEDUSA_SCENE: String = "res://src/gameplay/enemies/medusa_head.tscn"

## Direction the heads travel: -1 for leftwards, 1 for rightwards.
@export var direction: int = -1

## Vertical spread of spawn points, in pixels either side of the spawner.
@export var vertical_spread: float = 34.0

## Only spawn while the player is within this distance, so off-screen spawners
## are not quietly filling the room.
@export var activation_range: float = 260.0

var _config: Dictionary = {}
var _timer: float = 0.0
var _alive: Array[Node] = []


func _ready() -> void:
	_config = Balance.entry("enemies", "medusa_head")
	_timer = randf_range(0.0, _interval())


func _interval() -> float:
	return float(_config.get("spawnerInterval", 2.4))


func _max_alive() -> int:
	return int(_config.get("spawnerMaxAlive", 3))


func _process(delta: float) -> void:
	_alive = _alive.filter(func(n: Node) -> bool: return is_instance_valid(n))

	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null or global_position.distance_to(player.global_position) > activation_range:
		return

	_timer -= delta
	if _timer > 0.0:
		return
	_timer = _interval()

	if _alive.size() >= _max_alive():
		return
	_spawn()


func _spawn() -> void:
	var scene: PackedScene = load(MEDUSA_SCENE) as PackedScene
	if scene == null:
		push_error("MedusaSpawner: missing scene %s" % MEDUSA_SCENE)
		return

	var head: Node = scene.instantiate()
	# Set the travel direction before the node enters the tree so `_ready` on the
	# head sees the final value.
	head.set("travel_direction", direction)
	get_parent().add_child(head)
	if head is Node2D:
		(head as Node2D).global_position = global_position + Vector2(
			0.0, randf_range(-vertical_spread, vertical_spread))
	_alive.append(head)
