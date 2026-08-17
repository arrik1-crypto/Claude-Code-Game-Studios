extends Node

## Automated screenshot + smoke-test harness.
##
## Boots straight into gameplay, drives the player with synthetic input, and
## writes PNGs of the running game. Used two ways:
##
##   * CI smoke test — proves the game boots, builds rooms, spawns entities and
##     survives a scripted play session without an error.
##   * Visual evidence — the screenshots are the artefact the QA standards ask
##     for on Visual/Feel and UI stories.
##
## Run it with a virtual display, since the game must actually render:
##
##     xvfb-run -a godot --path . res://tools/debug/capture_scene.tscn -- \
##         --out=/tmp/shots
##
## User arguments (all optional, all after the bare `--`):
##
##   --out=DIR     where the PNGs are written (default `user://captures`)
##   --room=ID     start the scripted run in this room (default the castle gate)
##   --door=ID     spawn at this door within that room (default `start`)
##   --title       photograph the title screen instead of running the script
##
## This is a development tool. It is excluded from release exports via the
## `tools/` filter in the export preset.

const WORLD_SCENE: String = "res://src/gameplay/world/world.tscn"
const TITLE_SCENE: String = "res://src/ui/screens/title_screen.tscn"

## Room the scripted run starts in, unless `--room=` overrides it.
const DEFAULT_ROOM: String = "outer_ward_gate"

## One scripted beat: hold these actions for this many frames, then screenshot.
const SCRIPT: Array[Dictionary] = [
	{"name": "01_spawn", "hold": [], "frames": 30},
	{"name": "02_run_right", "hold": ["move_right"], "frames": 40},
	{"name": "03_whip", "hold": ["attack"], "frames": 8},
	{"name": "04_whip_active", "hold": ["attack"], "frames": 6},
	{"name": "05_jump", "hold": ["move_right", "jump"], "frames": 14},
	{"name": "06_airborne", "hold": ["move_right"], "frames": 10},
	{"name": "07_land_and_fight", "hold": ["move_right"], "frames": 45},
	{"name": "08_attack_enemy", "hold": ["attack"], "frames": 10},
	{"name": "09_crouch", "hold": ["move_down"], "frames": 12},
	{"name": "10_backdash", "hold": ["dash"], "frames": 10},
	{"name": "11_travel_east", "hold": ["move_right"], "frames": 120},
	{"name": "12_fight_through", "hold": ["attack"], "frames": 20},
	{"name": "13_travel_on", "hold": ["move_right"], "frames": 200},
	{"name": "14_next_room", "hold": ["move_right"], "frames": 180},
]

var _out_dir: String = "user://captures"
var _errors: PackedStringArray = []
var _shots: int = 0

## The live World node. Held directly rather than read back through
## `current_scene`, which is not reliable while scenes are being swapped.
var _world: Node = null


func _ready() -> void:
	_out_dir = _parse_out_dir()
	DirAccess.make_dir_recursive_absolute(_out_dir)
	print("[capture] writing to %s" % _out_dir)

	# Surface anything the game complains about as a test failure.
	get_tree().node_added.connect(_noop)

	await _run()


func _noop(_n: Node) -> void:
	pass


func _parse_out_dir() -> String:
	return _arg("--out=", "user://captures")


## Read a `--key=value` user argument, or [param fallback] when absent.
func _arg(prefix: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return fallback


func _has_flag(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag)


func _run() -> void:
	# Wait one frame before touching the tree: `_ready` runs while the parent is
	# still setting up its children, and `root.add_child()` is rejected there.
	await get_tree().process_frame

	# The title screen is a separate scene the scripted run never reaches, so it
	# needs its own mode to produce evidence at all.
	if _has_flag("--title"):
		await _run_title()
		return

	# Start a fresh run at the castle entrance, or wherever `--room=` points.
	# Save rooms in particular are deep in the castle and unreachable inside a
	# short scripted run, so their artwork can only be photographed directly.
	var start_room: String = _arg("--room=", DEFAULT_ROOM)
	var start_door: String = _arg("--door=", "start")
	GameState.new_game()
	GameState.current_room = start_room
	GameState.spawn_door = start_door
	GameState.set_respawn(start_room, start_door)

	# Deliberately NOT change_scene_to_file(): this harness *is* the current
	# scene, so swapping it out would free the node whose coroutine is driving
	# the capture and the run would silently hang. Instead the world is added
	# alongside and promoted to current scene, leaving the harness alive.
	var world_scene: PackedScene = load(WORLD_SCENE) as PackedScene
	if world_scene == null:
		_errors.append("could not load %s" % WORLD_SCENE)
		_report()
		get_tree().quit(1)
		return

	_world = world_scene.instantiate()
	get_tree().root.add_child(_world)
	get_tree().current_scene = _world
	await get_tree().process_frame
	await get_tree().process_frame

	var world: Node = _world

	# A script that fails to compile is an *engine* error, not a harness error,
	# so the run would otherwise photograph a half-built world and report PASS.
	# That is exactly how a broken `parallax_backdrop.gd` survived a green
	# capture: the room's background tile layer stood in for the missing sky.
	if world.get_script() == null:
		_errors.append("world.gd did not compile — the World node has no script")
	if not (world.get_node_or_null("Backdrop") is ParallaxBackdrop):
		_errors.append("the parallax backdrop is missing or its script did not compile")

	# Force the touch controls on so the screenshots show the real mobile layout.
	var touch: Node = world.get_node_or_null("TouchControls")
	if touch != null:
		touch.set("controls_visible", true)
	else:
		_errors.append("world scene has no TouchControls node")

	await _capture("00_title_of_world")

	for beat: Dictionary in SCRIPT:
		var actions: Array = beat["hold"]
		for action: Variant in actions:
			Input.action_press(StringName(String(action)))
		await _wait_frames(int(beat["frames"]))
		for action: Variant in actions:
			Input.action_release(StringName(String(action)))
		await _capture(String(beat["name"]))

	await _capture_map()
	_report()
	get_tree().quit(1 if not _errors.is_empty() else 0)


## Photograph the title screen on its own.
##
## The scripted run boots straight into the world, so the title is the one
## screen no gameplay capture can ever reach.
func _run_title() -> void:
	var scene: PackedScene = load(TITLE_SCENE) as PackedScene
	if scene == null:
		_errors.append("could not load %s" % TITLE_SCENE)
		_report()
		get_tree().quit(1)
		return

	var title: Node = scene.instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	# Two frames: one to enter the tree, one for the layout to settle.
	await _wait_frames(2)

	await _capture("00_title_screen")
	_report()
	get_tree().quit(1 if not _errors.is_empty() else 0)


func _wait_frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


func _capture(label: String) -> void:
	# Wait for the frame to finish drawing before reading the framebuffer.
	await RenderingServer.frame_post_draw

	var viewport: Viewport = get_tree().root
	var image: Image = viewport.get_texture().get_image()
	if image == null:
		_errors.append("could not read the viewport for '%s'" % label)
		return

	var path: String = "%s/%s.png" % [_out_dir, label]
	var err: int = image.save_png(path)
	if err != OK:
		_errors.append("failed writing %s (error %d)" % [path, err])
		return

	_shots += 1
	print("[capture] %-22s room=%-18s hp=%-8s enemies=%d"
		% [
			label,
			GameState.current_room,
			"%d/%d" % [GameState.current_hp, GameState.max_hp],
			get_tree().get_nodes_in_group(&"enemies").size(),
		])


## Open the map screen and capture it too.
func _capture_map() -> void:
	var pause_menu: Node = _world.get_node_or_null("PauseMenu") if _world != null else null
	if pause_menu == null:
		_errors.append("world scene has no PauseMenu node")
		return

	await _tap(&"map_screen")
	await _capture("15_map_screen")

	# Close the map, then open the pause panel.
	await _tap(&"map_screen")
	await _tap(&"pause")
	await _capture("16_pause_menu")

	await _tap(&"pause")
	get_tree().paused = false


## Synthesise a real button press.
##
## `Input.action_press` only sets the polled state — it does not generate an
## InputEvent, so `_unhandled_input` handlers (the pause menu, the map) never
## see it. Feeding an InputEventAction through `parse_input_event` exercises the
## same path a physical button does.
func _tap(action: StringName) -> void:
	var pressed := InputEventAction.new()
	pressed.action = action
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await _wait_frames(3)

	var released := InputEventAction.new()
	released.action = action
	released.pressed = false
	Input.parse_input_event(released)
	await _wait_frames(3)


func _report() -> void:
	print("\n[capture] %d screenshot(s) written" % _shots)
	if _errors.is_empty():
		print("[capture] RESULT: PASS")
		return
	for e: String in _errors:
		printerr("[capture] ERROR %s" % e)
	print("[capture] RESULT: FAIL (%d problem(s))" % _errors.size())
