# ADR-005 — Balance and level content live in data, not code

**Status:** Accepted
**Date:** 2026-08-17
**Deciders:** technical-director, game-designer, level-designer

## Context

The project's coding standards forbid hardcoded gameplay values. Beyond
compliance, a Metroidvania's difficulty is tuned by playing it repeatedly, and
every value that lives in code adds a step between "that felt wrong" and
"try it again".

## Decision

**All tuning** lives in `assets/data/game_balance.json`, read through the
`Balance` autoload. **All level content** lives in `assets/data/rooms/room_*.json`
as ASCII tile grids plus entity placements, built at runtime by `Room`.

Presentation constants (sprite offsets, tween durations, z-indices) may remain in
code as named `const` — they are not gameplay.

### Why ASCII rooms rather than editor-authored scenes

- A room layout is **reviewable in a pull request**. A `.tscn` diff is not.
- A designer can add a room by writing one text file, with no engine session.
- Tile routing (solid / one-way / decorative) is decided by the tileset manifest,
  so "is this a platform?" is answered in exactly one place.

## Consequences

**Positive**
- Re-tuning the jump is a JSON edit, and the level-design contract it affects is
  asserted by a test that fails CI if the gates break.
- Adding a fourth sub-weapon is a data change, not a code change.
- Room layouts are diffable and greppable.

**Negative**
- Errors move from compile time to load time. Mitigated by two validators:
  `tools/ci/validate_rooms.py` (pre-engine) and the in-engine data test suites.
- JSON has no comments. Mitigated by `_comment` / `_design_note` keys, which the
  loader ignores.

**Evidence this pays for itself:** the room validator caught a ragged grid row, a
stray Unicode ellipsis, four doors embedded in wall tiles and a spawn point
inside the floor — all before the engine was ever launched.

## Engine Compatibility

Godot 4.6 `JSON` + `FileAccess`. Note that `FileAccess.store_*` returns `bool`
since 4.4 and the save path checks it.

## GDD Requirements Addressed

`TR-DATA-001` (no hardcoded gameplay values), `TR-DATA-002` (reviewable level
content), `TR-DATA-003` (validated content pipeline).
