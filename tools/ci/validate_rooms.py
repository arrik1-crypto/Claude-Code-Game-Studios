#!/usr/bin/env python3
"""Validate every room definition in assets/data/rooms/.

Room files are hand-authored ASCII, which is exactly the kind of data where a
one-character mistake produces a soft-lock rather than a crash. This checker runs
in CI and catches the failure modes that playtesting would otherwise have to:

  * ragged rows (a grid that is not rectangular)
  * glyphs missing from the legend, or legend entries naming unknown tiles
  * doors pointing at rooms or door ids that do not exist
  * doors that are not reciprocal (A->B without B->A)
  * spawn points and door anchors embedded inside solid tile
  * entity types the room builder cannot instantiate
  * rooms unreachable from the starting room

    python3 tools/ci/validate_rooms.py

Exits non-zero if any error is found. Warnings do not fail the build.
"""

from __future__ import annotations

import json
import sys
from collections import deque
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ROOMS_DIR = REPO_ROOT / "assets" / "data" / "rooms"
TILESET_MANIFEST = REPO_ROOT / "assets" / "art" / "tiles" / "castle_tileset.json"

START_ROOM = "outer_ward_gate"

# --- Character and traversal contract --------------------------------------
# These mirror the numbers in assets/data/game_balance.json and
# design/gdd/traversal-moveset.md. They are duplicated here deliberately: this
# checker runs before the engine, so it cannot read the engine's view of them.
# The in-engine suite asserts the same contract against the real balance data,
# which is what stops the two copies drifting apart.

TILE = 16
ROOM_WIDTH = 40
ROOM_HEIGHT = 24

## Character is 38x56px. Collision is 14x44px, so it occupies 3 tiles of height
## and needs a fourth for headroom when walking under anything.
CHARACTER_TILES_TALL = 4

## Tallest ledge the player must clear with no relic (single jump apex 101px).
MAX_UNGATED_CLIMB_PX = 96

## The Twin Step gate, which a single jump must fail and a double must clear.
TWIN_STEP_GATE_PX = 130
TWIN_STEP_GATE_TOLERANCE_PX = 4
TWIN_STEP_GATE_ROOM = "entrance_hall"

# Must stay in step with Room.ENTITY_SCENES in src/gameplay/world/room.gd.
KNOWN_ENTITIES = {
    "bone_sentry", "nightwing", "gravewalker", "medusa_head", "cellar_slime",
    "sanguine_knight", "save_point", "relic", "mist_gate", "pickup", "door",
    "prop", "medusa_spawner",
}

errors: list[str] = []
warnings: list[str] = []


def error(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def load_tile_roles() -> dict[str, str]:
    """Map tile name -> role from the generated tileset manifest."""
    if not TILESET_MANIFEST.exists():
        error(f"missing tileset manifest {TILESET_MANIFEST.relative_to(REPO_ROOT)} "
              "— run tools/asset-pipeline/generate_assets.py first")
        return {}
    manifest = json.loads(TILESET_MANIFEST.read_text())
    roles: dict[str, str] = {}
    for role in ("solid", "oneWay", "hazard", "decor"):
        for name in manifest.get(role, []):
            roles[name] = role
    for name in manifest.get("tiles", {}):
        roles.setdefault(name, "decor")
    return roles


def load_rooms() -> dict[str, dict]:
    rooms: dict[str, dict] = {}
    if not ROOMS_DIR.is_dir():
        error(f"no room directory at {ROOMS_DIR.relative_to(REPO_ROOT)}")
        return rooms
    for path in sorted(ROOMS_DIR.glob("room_*.json")):
        try:
            data = json.loads(path.read_text())
        except json.JSONDecodeError as exc:
            error(f"{path.name}: invalid JSON — {exc}")
            continue
        # Data files follow `[system]_[name].json`, so the room id is the stem
        # minus the `room_` prefix.
        stem = path.stem.removeprefix("room_")
        room_id = data.get("id", "")
        if room_id != stem:
            error(f"{path.name}: id is '{room_id}' but the filename says '{stem}'")
        rooms[stem] = data

    stray = [p.name for p in ROOMS_DIR.glob("*.json") if not p.name.startswith("room_")]
    for name in stray:
        error(f"{name}: room data files must be named room_<id>.json")
    return rooms


def check_grid(room_id: str, data: dict, tile_roles: dict[str, str]) -> set[tuple[int, int]]:
    """Validate the tile grid and return the set of solid (x, y) cells."""
    solid_cells: set[tuple[int, int]] = set()
    legend: dict[str, str] = data.get("legend", {})

    for tile_name in legend.values():
        if tile_name not in tile_roles:
            error(f"{room_id}: legend names unknown tile '{tile_name}'")

    fill = data.get("bgFill", "")
    if fill and fill not in tile_roles:
        error(f"{room_id}: bgFill names unknown tile '{fill}'")

    for layer in ("fg", "bg"):
        grid = data.get(layer, [])
        if not grid:
            if layer == "fg":
                error(f"{room_id}: has no 'fg' grid")
            continue

        widths = {len(row) for row in grid}
        if len(widths) != 1:
            error(f"{room_id}: '{layer}' rows have differing widths {sorted(widths)}")

        for y, row in enumerate(grid):
            for x, glyph in enumerate(row):
                if glyph in (".", " "):
                    continue
                if glyph not in legend:
                    error(f"{room_id}: '{layer}' glyph '{glyph}' at ({x},{y}) "
                          "is not in the legend")
                    continue
                if layer == "fg" and tile_roles.get(legend[glyph]) in ("solid", "hazard"):
                    solid_cells.add((x, y))

    # Rooms deliberately share one legend template, so unused entries are
    # expected and are not reported.
    return solid_cells


def check_standing_spot(room_id: str, label: str, x: int, y: int,
                        solid: set[tuple[int, int]], height: int) -> None:
    """A spawn or door anchor must be clear, and have ground beneath it."""
    for dy in range(height):
        if (x, y - dy) in solid:
            error(f"{room_id}: {label} at ({x},{y}) is inside solid tile "
                  f"({x},{y - dy})")
            return
    if (x, y + 1) not in solid:
        warn(f"{room_id}: {label} at ({x},{y}) has no floor directly beneath it")


def check_room_dimensions(room_id: str, data: dict) -> None:
    """Rooms are a fixed grid so the camera and level vocabulary stay consistent."""
    grid = data.get("fg", [])
    if not grid:
        return
    if len(grid) != ROOM_HEIGHT:
        error(f"{room_id}: room is {len(grid)} tiles tall, expected {ROOM_HEIGHT}")
    width = len(grid[0]) if grid else 0
    if width != ROOM_WIDTH:
        error(f"{room_id}: room is {width} tiles wide, expected {ROOM_WIDTH}")


def check_character_clearance(room_id: str, data: dict,
                              solid: set[tuple[int, int]]) -> None:
    """Every doorway must admit a character that is CHARACTER_TILES_TALL."""
    for door in data.get("doors", []):
        did = door.get("id", "")
        x, y = int(door.get("x", 0)), int(door.get("y", 0))
        blocked = [
            (x, y - dy) for dy in range(CHARACTER_TILES_TALL)
            if (x, y - dy) in solid
        ]
        if blocked:
            error(f"{room_id}: doorway '{did}' at ({x},{y}) gives less than "
                  f"{CHARACTER_TILES_TALL} tiles of clearance — blocked at {blocked}")

        # The tile the player is nudged towards on arrival must be clear too, or
        # they materialise inside the wall beside the door.
        inward = x + (1 if int(door.get("dir", 1)) > 0 else -1)
        inward_blocked = [
            (inward, y - dy) for dy in range(CHARACTER_TILES_TALL)
            if (inward, y - dy) in solid
        ]
        if inward_blocked:
            error(f"{room_id}: doorway '{did}' has no clearance one tile inward "
                  f"at x={inward} — blocked at {inward_blocked}")


def surface_heights(solid: set[tuple[int, int]], width: int, height: int) -> dict[int, list[int]]:
    """For each column, the row indices of every standable surface top."""
    surfaces: dict[int, list[int]] = {}
    for x in range(width):
        tops: list[int] = []
        for y in range(height):
            if (x, y) in solid and (x, y - 1) not in solid:
                tops.append(y)
        surfaces[x] = tops
    return surfaces


def check_twin_step_gate(rooms: dict[str, dict],
                         solids: dict[str, set[tuple[int, int]]]) -> None:
    """The ability gate is pure geometry, so its height is a hard contract.

    Verifies the gate room contains a climb inside the window that a single jump
    fails and a double jump clears. Without this, a level edit can silently open
    a sequence break that no other check would notice.
    """
    data = rooms.get(TWIN_STEP_GATE_ROOM)
    if data is None:
        error(f"gate room '{TWIN_STEP_GATE_ROOM}' does not exist")
        return

    declared = data.get("_gateClimbPx")
    if declared is None:
        error(f"{TWIN_STEP_GATE_ROOM}: must declare '_gateClimbPx' recording the "
              "designed Twin Step climb height")
        return

    if abs(int(declared) - TWIN_STEP_GATE_PX) > TWIN_STEP_GATE_TOLERANCE_PX:
        error(f"{TWIN_STEP_GATE_ROOM}: declared gate climb {declared}px is outside "
              f"{TWIN_STEP_GATE_PX}+/-{TWIN_STEP_GATE_TOLERANCE_PX}px")

    if int(declared) <= MAX_UNGATED_CLIMB_PX:
        error(f"{TWIN_STEP_GATE_ROOM}: gate climb {declared}px is within single-jump "
              f"range ({MAX_UNGATED_CLIMB_PX}px) — the relic would be skippable")


def check_entities(room_id: str, data: dict) -> None:
    for spec in data.get("entities", []):
        etype = spec.get("type", "")
        if etype not in KNOWN_ENTITIES:
            error(f"{room_id}: unknown entity type '{etype}'")
        if etype == "relic" and not spec.get("flag"):
            error(f"{room_id}: relic '{spec.get('relic_id')}' has no flag "
                  "and would be collectable forever")


def check_doors(rooms: dict[str, dict], solids: dict[str, set[tuple[int, int]]]) -> None:
    door_index: dict[str, set[str]] = {
        rid: {d.get("id", "") for d in data.get("doors", [])}
        for rid, data in rooms.items()
    }

    for room_id, data in rooms.items():
        for door in data.get("doors", []):
            did = door.get("id", "")
            target = door.get("to", "")
            target_door = door.get("toDoor", "")

            check_standing_spot(room_id, f"door '{did}'",
                                int(door.get("x", 0)), int(door.get("y", 0)),
                                solids.get(room_id, set()),
                                int(door.get("height", 2)))

            # An empty target marks an anchor-only door, such as a save respawn
            # point. Those are intentional and are not links.
            if target == "":
                continue

            if target not in rooms:
                error(f"{room_id}.{did} -> unknown room '{target}'")
                continue
            if target_door not in door_index[target]:
                error(f"{room_id}.{did} -> '{target}' has no door '{target_door}'")
                continue

            back = next((d for d in rooms[target].get("doors", [])
                         if d.get("id") == target_door), None)
            if back is not None and (back.get("to") != room_id or back.get("toDoor") != did):
                error(f"{room_id}.{did} <-> {target}.{target_door} is not reciprocal "
                      f"(the far side points at "
                      f"{back.get('to')}.{back.get('toDoor')})")


def check_reachability(rooms: dict[str, dict]) -> None:
    if START_ROOM not in rooms:
        error(f"start room '{START_ROOM}' does not exist")
        return
    seen = {START_ROOM}
    queue = deque([START_ROOM])
    while queue:
        current = queue.popleft()
        for door in rooms[current].get("doors", []):
            target = door.get("to", "")
            if target and target in rooms and target not in seen:
                seen.add(target)
                queue.append(target)
    for room_id in sorted(set(rooms) - seen):
        error(f"{room_id}: unreachable from '{START_ROOM}'")


def check_map_cells(rooms: dict[str, dict]) -> None:
    occupied: dict[tuple[int, int], str] = {}
    for room_id, data in rooms.items():
        cell = data.get("map", {})
        key = (int(cell.get("x", 0)), int(cell.get("y", 0)))
        if key in occupied:
            error(f"{room_id}: map cell {key} is already used by '{occupied[key]}'")
        occupied[key] = room_id


def main() -> int:
    tile_roles = load_tile_roles()
    rooms = load_rooms()
    if not rooms:
        error("no room files found")

    solids: dict[str, set[tuple[int, int]]] = {}
    for room_id, data in rooms.items():
        solids[room_id] = check_grid(room_id, data, tile_roles)
        check_room_dimensions(room_id, data)
        check_entities(room_id, data)
        check_character_clearance(room_id, data, solids[room_id])
        spawn = data.get("spawn", {})
        if spawn:
            check_standing_spot(room_id, "spawn", int(spawn.get("x", 0)),
                                int(spawn.get("y", 0)), solids[room_id],
                                CHARACTER_TILES_TALL)

    check_doors(rooms, solids)
    check_twin_step_gate(rooms, solids)
    check_reachability(rooms)
    check_map_cells(rooms)

    for message in warnings:
        print(f"WARN  {message}")
    for message in errors:
        print(f"ERROR {message}")

    print(f"\n{len(rooms)} room(s) checked: "
          f"{len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
