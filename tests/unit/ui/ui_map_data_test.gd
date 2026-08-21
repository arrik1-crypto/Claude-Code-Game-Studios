extends TestCase

## The map must be able to see the castle it is drawing.
##
## Reported from a device as "map has no detail". The drawing code was only half
## the problem: [RoomIndex] deliberately kept just a display name and a grid cell
## per room and discarded everything else, so the map screen *physically could
## not* show doors, relics or save points however it was written.
##
## These tests pin the widened index — and, more importantly, pin the landmarks
## to the room data rather than to a hand-maintained list. `MapView` used to
## carry `SAVE_ROOMS = ["chapel_landing", "boss_approach"]`, which was correct
## only by coincidence and would have gone stale the first time a coffin moved.

const EXPECTED_ROOM_COUNT: int = 11


func before_each() -> void:
	GameState.new_game()


func test_every_room_is_indexed() -> void:
	assert_eq(RoomIndex.all().size(), EXPECTED_ROOM_COUNT,
		"the index must cover the whole castle")


func test_rooms_know_what_they_connect_to() -> void:
	# Without this the map cannot draw a single line between two chips.
	var total_links: int = 0
	for room_id: String in RoomIndex.all():
		total_links += RoomIndex.links(room_id).size()
	assert_gt(float(total_links), 0.0, "no room reported any connection")


func test_connections_are_reciprocal_in_the_index() -> void:
	# The room data is validated as reciprocal; the index must not lose that, or
	# the map would draw one-way corridors that do not exist.
	for room_id: String in RoomIndex.all():
		for link: Dictionary in RoomIndex.links(room_id):
			var target: String = String(link.get("to", ""))
			var back: bool = false
			for reverse: Dictionary in RoomIndex.links(target):
				if String(reverse.get("to", "")) == room_id:
					back = true
					break
			assert_true(back, "%s links to %s but not the other way" % [room_id, target])


func test_the_two_corridors_are_actually_connected() -> void:
	# The specific gap that made the old map confusing: nothing showed that the
	# upper row is reached from the lower one. entrance_hall is the junction.
	var targets: PackedStringArray = []
	for link: Dictionary in RoomIndex.links("entrance_hall"):
		targets.append(String(link.get("to", "")))
	assert_has(targets, "clock_stair",
		"entrance_hall must link up to the clocktower, or the map shows two "
		+ "unrelated corridors")


func test_save_rooms_come_from_the_room_data() -> void:
	# Exactly the two coffins the castle actually contains — derived, not typed
	# out. If a coffin is added or moved, this follows it automatically.
	var save_rooms: PackedStringArray = []
	for room_id: String in RoomIndex.all():
		if RoomIndex.has_save_point(room_id):
			save_rooms.append(room_id)
	save_rooms.sort()
	assert_eq(save_rooms.size(), 2, "the slice has two save coffins")
	assert_has(save_rooms, "chapel_landing", "the chapel coffin")
	assert_has(save_rooms, "boss_approach", "the antechamber coffin")


func test_relic_rooms_are_marked_with_their_flags() -> void:
	# The flag is what lets the map distinguish a relic still on its plinth from
	# one already taken.
	var flagged: int = 0
	for room_id: String in RoomIndex.all():
		var marks: Dictionary = RoomIndex.entry(room_id).get("marks", {}) as Dictionary
		for flag: String in (marks.get("relicFlags", []) as Array):
			assert_true(flag != "", "%s has a relic with no flag" % room_id)
			flagged += 1
	assert_eq(flagged, 4, "the slice places four relics")


func test_the_boss_room_is_marked() -> void:
	var marks: Dictionary = RoomIndex.entry("throne_of_ash").get("marks", {}) as Dictionary
	assert_true(bool(marks.get("boss", false)), "the throne room holds the boss")
	assert_false(bool((RoomIndex.entry("west_corridor").get("marks", {}) as Dictionary)
		.get("boss", false)), "an ordinary corridor is not a boss room")


func test_the_ability_gate_is_marked() -> void:
	var marks: Dictionary = RoomIndex.entry("medusa_gauntlet").get("marks", {}) as Dictionary
	assert_true(bool(marks.get("gate", false)),
		"the mist gate should be visible on the map — it is the reason the "
		+ "player cannot get through yet")


func test_the_index_still_does_not_hold_tile_grids() -> void:
	# The whole point of RoomIndex is that opening the map does not drag every
	# room's 40x24 grid into memory. Widening it must not have cost that.
	for room_id: String in RoomIndex.all():
		var entry: Dictionary = RoomIndex.entry(room_id)
		assert_false(entry.has("fg"), "%s: the index must not keep tile grids" % room_id)
		assert_false(entry.has("legend"), "%s: the index must not keep legends" % room_id)
