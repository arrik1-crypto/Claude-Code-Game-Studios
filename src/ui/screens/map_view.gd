class_name MapView
extends Control

## Draws the castle map from [GameState.discovered_rooms].
##
## Rendered with `_draw()` rather than a node per cell: the map is redrawn only
## when it is opened, and a custom draw pass keeps it to a handful of rects no
## matter how large the castle grows.
##
## Only rooms the player has actually entered appear. Undiscovered rooms are not
## hinted at — working out where the gaps are is the point of a Metroidvania map.

const CELL_SIZE: Vector2 = Vector2(22, 16)
const CELL_GAP: Vector2 = Vector2(3, 3)

const COLOR_VISITED := Color(0.27, 0.40, 0.59, 1.0)
const COLOR_VISITED_EDGE := Color(0.44, 0.66, 0.92, 1.0)
const COLOR_CURRENT := Color(0.83, 0.20, 0.29, 1.0)
const COLOR_SAVE := Color(0.94, 0.80, 0.45, 1.0)
const COLOR_UNKNOWN := Color(0.13, 0.11, 0.20, 0.55)

## Rooms containing a save coffin get a marker so the player can plan a run back.
const SAVE_ROOMS: PackedStringArray = ["chapel_landing", "boss_approach"]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	var rooms: Dictionary = RoomIndex.all()
	if rooms.is_empty():
		return

	var bounds: Rect2i = RoomIndex.grid_bounds()
	var span := Vector2(
		float(bounds.size.x) * (CELL_SIZE.x + CELL_GAP.x),
		float(bounds.size.y) * (CELL_SIZE.y + CELL_GAP.y))
	# Centre the whole grid inside the control.
	var origin: Vector2 = (size - span) * 0.5

	for room_id: String in rooms:
		if not GameState.is_room_discovered(room_id):
			continue

		var cell: Rect2i = rooms[room_id]["cell"]
		var local := Vector2(
			float(cell.position.x - bounds.position.x) * (CELL_SIZE.x + CELL_GAP.x),
			float(cell.position.y - bounds.position.y) * (CELL_SIZE.y + CELL_GAP.y))
		var rect := Rect2(
			origin + local,
			Vector2(float(cell.size.x) * CELL_SIZE.x + float(cell.size.x - 1) * CELL_GAP.x,
					float(cell.size.y) * CELL_SIZE.y + float(cell.size.y - 1) * CELL_GAP.y))

		var is_current: bool = room_id == GameState.current_room
		draw_rect(rect, COLOR_CURRENT if is_current else COLOR_VISITED, true)
		draw_rect(rect, COLOR_VISITED_EDGE, false, 1.0)

		if SAVE_ROOMS.has(room_id):
			var marker := Rect2(rect.position + rect.size * 0.5 - Vector2(3, 3), Vector2(6, 6))
			draw_rect(marker, COLOR_SAVE, true)


## Human-readable summary shown beneath the grid.
func exploration_summary() -> String:
	var total: int = RoomIndex.all().size()
	var found: int = GameState.discovered_rooms.size()
	if total <= 0:
		return ""
	return "%d / %d rooms   %d%%" % [found, total, int(round(float(found) / float(total) * 100.0))]
