# Session State — Crimson Vespers

**Updated:** 2026-08-17
**Stage:** Production — vertical slice complete

<!-- STATUS -->
Epic: Vertical Slice
Feature: Outer Ward wing
Task: Slice complete — awaiting playtest
<!-- /STATUS -->

## What exists

A playable Godot 4.6 mobile Metroidvania: 11 interconnected rooms, 5 enemy types
plus a 3-phase boss, 2 ability gates, 2 save points, full touch/keyboard/gamepad
input, HUD, map and pause screens.

## Verification status

| Check | Command | Result |
|---|---|---|
| Room data | `python3 tools/ci/validate_rooms.py` | 11 rooms, 0 errors |
| Unit + integration | `godot --headless --path . res://tests/test_runner.tscn` | 95 tests / 1067 assertions, all pass |
| Runtime smoke + screenshots | `xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/debug/capture_scene.tscn -- --out=/tmp/shots` | PASS, 17 screenshots |

Screenshots are committed under `production/qa/evidence/2026-08-17-vertical-slice/`.

## Key decisions made

- Godot 4.6 + GDScript (ADR-001)
- Autoload services + signal-only EventBus (ADR-002)
- Node-based player FSM (ADR-003)
- Area2D hitbox/hurtbox with an explicit layer matrix (ADR-004)
- All tuning and level content in JSON (ADR-005)
- SpriteFrames and TileSet built at runtime from manifests (ADR-006)
- Data files renamed to `[system]_[name].json` with camelCase keys, per
  `.claude/rules/data-files.md`
- Hero art imported from the supplied asset pack and downscaled 2:1 to fit the
  16px tile grid (see `design/art-bible.md` §4.1)

## Bugs found and fixed during the build

1. **TileSet had no collision.** `TileSetAtlasSource` was populated before being
   attached to its `TileSet`; Godot logged an error and produced tiles with no
   collision polygons. Every floor was walk-through. Fixed, and guarded by
   `world_tileset_collision_test.gd`.
2. **Relics could never render as taken.** `Room` set exported properties after
   `add_child()`, so `RelicPedestal._ready` read an empty flag. Fixed by
   configuring before tree entry.
3. **Boss charge resolved into a slash.** The shared wind-up state always routed
   to `_begin_strike()`. Fixed to branch on the queued move.
4. Room authoring errors caught by the validator: ragged grid row, stray Unicode
   ellipsis, four doors embedded in wall tiles, one spawn point inside the floor.

## Known gaps

- The imported hero is stylistically warmer/higher-fidelity than the generated
  gothic bestiary. Tracked in `design/art-bible.md` §4.3.
- The pack's hero sheet has no crouch or airborne poses; substitutes are in use.
- Gold accumulates with nothing to spend it on (no shop yet).
- MP regenerates but is never consumed (spells not implemented).
- The scripted smoke run does not reach the boss; it verifies the first room's
  combat loop, the map and the pause screen.
- Breakable-wall tile art exists but nothing consumes it.

## Suggested next steps

1. Playtest the full route to the boss and tune encounter density.
2. Extend the capture harness to walk the full critical path as a regression test.
3. Resolve the art style split (commission a bestiary in the hero's style).
4. Add the shop to give gold a sink.
