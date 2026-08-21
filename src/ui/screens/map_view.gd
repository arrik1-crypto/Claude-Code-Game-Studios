class_name MapView
extends Control

## Draws the castle map from [GameState.discovered_rooms].
##
## Rendered with `_draw()` rather than a node per cell: the map is redrawn only
## when it is opened, and a custom draw pass keeps it to a handful of primitives
## no matter how large the castle grows.
##
## Reported from a real device as "map has no detail", and the numbers agreed:
## every room is a 1x1 cell in a two-row ribbon, so the whole castle drew as a
## 175x38 strip floating in a 400x162 panel — about a tenth of the space it was
## given — using three draw calls per room and no relationship between them. The
## worst part was that nothing indicated the upper corridor connects to the lower
## one at all, which is the single fact a Metroidvania map exists to convey.
##
## It now draws, from data that was already in the room files and simply thrown
## away at index time: the links between rooms, save coffins, uncollected relics,
## the ability gate, the boss, and the rooms you know exist but have not entered.
##
## Undiscovered rooms are shown only when they are adjacent to somewhere you have
## been — working out how to reach them is the point; not knowing they exist is
## just a blank screen.

## Cell geometry. Larger than the old 22x16 so the grid fills its panel and the
## markers inside a room are legible rather than a 6px dot.
const CELL_SIZE: Vector2 = Vector2(34, 26)
const CELL_GAP: Vector2 = Vector2(10, 10)

const COLOR_VISITED := Color(0.27, 0.40, 0.59, 1.0)
const COLOR_VISITED_EDGE := Color(0.44, 0.66, 0.92, 1.0)
const COLOR_CURRENT := Color(0.83, 0.20, 0.29, 1.0)
const COLOR_CURRENT_EDGE := Color(1.0, 0.51, 0.55, 1.0)
const COLOR_SAVE := Color(0.94, 0.80, 0.45, 1.0)
const COLOR_RELIC := Color(0.62, 0.86, 1.0, 1.0)
const COLOR_BOSS := Color(0.90, 0.24, 0.32, 1.0)
const COLOR_GATE := Color(0.42, 0.66, 0.92, 1.0)
const COLOR_LINK := Color(0.44, 0.66, 0.92, 0.75)
const COLOR_UNKNOWN := Color(0.13, 0.11, 0.20, 0.55)
const COLOR_UNKNOWN_EDGE := Color(0.30, 0.28, 0.42, 0.7)

const LINK_WIDTH: float = 2.0
const MARKER_RADIUS: float = 3.5


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	queue_redraw()


## Top-left corner of a room's chip, in local coordinates.
func _rect_for(cell: Rect2i, bounds: Rect2i, origin: Vector2) -> Rect2:
	var local := Vector2(
		float(cell.position.x - bounds.position.x) * (CELL_SIZE.x + CELL_GAP.x),
		float(cell.position.y - bounds.position.y) * (CELL_SIZE.y + CELL_GAP.y))
	return Rect2(
		origin + local,
		Vector2(float(cell.size.x) * CELL_SIZE.x + float(cell.size.x - 1) * CELL_GAP.x,
				float(cell.size.y) * CELL_SIZE.y + float(cell.size.y - 1) * CELL_GAP.y))


## Rooms adjacent to somewhere the player has been, but not yet entered.
##
## These are the leads. Showing them is what turns a record of where you have
## been into a map of where you could go next.
func _frontier(rooms: Dictionary) -> Dictionary:
	var frontier: Dictionary = {}
	for room_id: String in rooms:
		if not GameState.is_room_discovered(room_id):
			continue
		for link: Dictionary in RoomIndex.links(room_id):
			var target: String = String(link.get("to", ""))
			if target != "" and rooms.has(target) and not GameState.is_room_discovered(target):
				frontier[target] = true
	return frontier


func _draw() -> void:
	var rooms: Dictionary = RoomIndex.all()
	if rooms.is_empty():
		return

	var bounds: Rect2i = RoomIndex.grid_bounds()
	var span := Vector2(
		float(bounds.size.x) * (CELL_SIZE.x + CELL_GAP.x) - CELL_GAP.x,
		float(bounds.size.y) * (CELL_SIZE.y + CELL_GAP.y) - CELL_GAP.y)
	# Centre the whole grid inside the control.
	var origin: Vector2 = (size - span) * 0.5

	var frontier: Dictionary = _frontier(rooms)

	# Links first, so the chips draw over the ends of the lines.
	_draw_links(rooms, bounds, origin, frontier)

	for room_id: String in rooms:
		var known: bool = GameState.is_room_discovered(room_id)
		if not known and not frontier.has(room_id):
			continue
		var rect: Rect2 = _rect_for(rooms[room_id]["cell"], bounds, origin)
		if known:
			_draw_room(room_id, rect)
		else:
			_draw_unknown(rect)


## Connections between rooms, drawn centre-to-centre.
##
## This is the detail the map most obviously lacked: the castle is two corridors,
## and nothing showed that the upper one is reached from the lower.
func _draw_links(rooms: Dictionary, bounds: Rect2i, origin: Vector2,
		frontier: Dictionary) -> void:
	var drawn: Dictionary = {}
	for room_id: String in rooms:
		if not GameState.is_room_discovered(room_id):
			continue
		var from_rect: Rect2 = _rect_for(rooms[room_id]["cell"], bounds, origin)

		for link: Dictionary in RoomIndex.links(room_id):
			var target: String = String(link.get("to", ""))
			if target == "" or not rooms.has(target):
				continue
			if not GameState.is_room_discovered(target) and not frontier.has(target):
				continue

			# One line per pair, whichever end is walked first.
			var key: String = room_id + "|" + target if room_id < target else target + "|" + room_id
			if drawn.has(key):
				continue
			drawn[key] = true

			var to_rect: Rect2 = _rect_for(rooms[target]["cell"], bounds, origin)
			draw_line(from_rect.get_center(), to_rect.get_center(), COLOR_LINK, LINK_WIDTH)


func _draw_room(room_id: String, rect: Rect2) -> void:
	var is_current: bool = room_id == GameState.current_room
	draw_rect(rect, COLOR_CURRENT if is_current else COLOR_VISITED, true)
	draw_rect(rect, COLOR_CURRENT_EDGE if is_current else COLOR_VISITED_EDGE, false, 1.0)

	var marks: Dictionary = RoomIndex.entry(room_id).get("marks", {}) as Dictionary
	var centre: Vector2 = rect.get_center()

	# Landmarks sit in a row across the middle of the chip so several can coexist.
	var icons: Array[Color] = []
	if bool(marks.get("save", false)):
		icons.append(COLOR_SAVE)
	if bool(marks.get("boss", false)):
		icons.append(COLOR_BOSS)
	if bool(marks.get("gate", false)):
		icons.append(COLOR_GATE)
	# Only relics still on their plinth — a collected one is no longer a lead.
	for flag: String in (marks.get("relicFlags", []) as Array):
		if flag != "" and not GameState.get_flag(flag):
			icons.append(COLOR_RELIC)

	if icons.is_empty():
		return
	var step: float = MARKER_RADIUS * 2.6
	var start_x: float = centre.x - step * float(icons.size() - 1) * 0.5
	for i: int in range(icons.size()):
		draw_circle(Vector2(start_x + step * float(i), centre.y), MARKER_RADIUS, icons[i])


## A room the player knows is there but has not entered.
func _draw_unknown(rect: Rect2) -> void:
	draw_rect(rect, COLOR_UNKNOWN, true)
	draw_rect(rect, COLOR_UNKNOWN_EDGE, false, 1.0)


## Human-readable summary shown beneath the grid.
func exploration_summary() -> String:
	var total: int = RoomIndex.all().size()
	var found: int = GameState.discovered_rooms.size()
	if total <= 0:
		return ""
	return "%d / %d rooms   %d%%" % [found, total, int(round(float(found) / float(total) * 100.0))]
