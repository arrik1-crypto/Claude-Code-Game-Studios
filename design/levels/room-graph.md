# Level Design — Outer Ward Room Graph

**Status:** Implemented (vertical slice)
**Owner:** level-designer
**Data:** `assets/data/rooms/room_*.json`
**Validated by:** `tools/ci/validate_rooms.py`, `tests/unit/world/world_room_data_test.gd`

## Overview

Eleven rooms forming the Outer Ward and the Clocktower approach. The wing is
built around a single backtrack: the ground floor runs east to a dead-end vault
holding the Twin Step, and the only use for the Twin Step is a ledge back in the
Entrance Hall, two rooms west. That loop is the smallest complete expression of
the Metroidvania structure, and everything else in the slice hangs off it.

## The graph

```
                       ┌──────────────┐   ┌──────────────┐   ┌───────────────┐   ┌──────────────┐
   upper floor         │ clock_stair  │──▶│  vault_mist  │──▶│medusa_gauntlet│──▶│boss_approach │
                       │    (2,2)     │   │    (3,2)     │   │     (4,2)     │   │    (5,2)  ⛨  │
                       └──────▲───────┘   │  ⟡ Mist Dash │   │   ▓ mist gate │   └──────┬───────┘
                              │           └──────────────┘   └───────────────┘          │
                     Twin Step gate                                                      ▼
                        (80 px climb)                                            ┌───────────────┐
                              │                                                  │ throne_of_ash │
   ground floor  ┌────────────┴──┐   ┌──────────────┐   ┌──────────────┐         │     (6,2)     │
   ┌───────────┐ │ entrance_hall │   │west_corridor │   │chapel_landing│         │  ☠ boss       │
   │outer_ward │─│    (1,3)      │──▶│    (2,3)     │──▶│   (3,3)  ⛨   │         │  ⟡ Chain Whip │
   │ gate (0,3)│ └───────────────┘   └──────────────┘   │ ⟡ Dagger     │         └───────▲───────┘
   └───────────┘                                        └──────┬───────┘                 │
                                                               ▼                         │
                                              ┌──────────────┐   ┌────────────────┐      │
                                              │ bat_gallery  │──▶│vault_twin_step │      │
                                              │    (4,3)     │   │     (5,3)      │      │
                                              └──────────────┘   │  ⟡ Twin Step   │      │
                                                                 └────────────────┘      │
                                                                                          │
   ⛨ save coffin   ⟡ relic   ▓ ability gate   ☠ boss        boss_approach ────────────────┘
```

Coordinates are map-screen grid cells. Every link is bidirectional and asserted
reciprocal by both validators.

## Intended route

| # | Beat | Room | What the player learns |
|---|---|---|---|
| 1 | Arrival | outer_ward_gate | Move, jump, whip. One Bone Sentry, lots of space. |
| 2 | The hub | entrance_hall | A ledge they cannot reach. Registered, not solved. |
| 3 | Pressure | west_corridor | Gravewalkers + spike pits: backing up is not free. |
| 4 | Relief | chapel_landing | Save coffin, Silver Dagger. First safe beat. |
| 5 | Air | bat_gallery | Nightwings over a spike floor; drop-through planks. |
| 6 | **Reward** | vault_twin_step | Twin Step. Dead end — the only way out is back. |
| 7 | **Backtrack** | entrance_hall | The ledge from beat 2 is now reachable. |
| 8 | New wing | clock_stair | A climb built entirely from double-jump gaps. |
| 9 | **Reward** | vault_mist | Mist Dash. |
| 10 | Gauntlet | medusa_gauntlet | Medusa Heads over spikes; a mist gate at the far end. |
| 11 | Preparation | boss_approach | Second coffin, hearts, healing. |
| 12 | Boss | throne_of_ash | Sanguine Knight. Chain Whip on the far side. |

Target completion: **15–20 minutes** for a player who does not already know the
route; ~6 minutes for one who does.

## Gating

| Gate | Location | Key | Enforced by |
|---|---|---|---|
| 80 px climb | entrance_hall → clock_stair | Twin Step | Geometry (jump physics) |
| Mist barrier | medusa_gauntlet x=33 | Mist Dash | `MistGate` collision |

Only two gates, deliberately. A slice with more locks than the player has keys
reads as a demo of a gating system rather than a place.

### Why the geometry gate is safe

The gate is a pure height check, so it depends on the jump numbers staying put.
That contract is asserted in `tests/unit/data/data_balance_test.gd`:

- a single jump must reach **less than 80 px** (it reaches 60.5)
- a double jump must reach **more than 80 px** (it reaches 110.5)
- a single jump must still clear the ordinary 48 px ledges

Re-tuning the jump without re-checking the level design therefore fails CI
rather than silently opening a sequence break.

## Room format

Rooms are ASCII grids in JSON, 40 × 18 tiles at 16 px — 640 × 288 px, slightly
larger than the 480 × 270 viewport, so every room scrolls a little.

```json
{
  "id": "entrance_hall",
  "map": { "x": 1, "y": 3, "w": 1, "h": 1 },
  "bgFill": "bg_brick",
  "legend": { "#": "brick_solid", "T": "brick_top", "=": "platform" },
  "fg": [ "########################################", "..." ],
  "doors": [ { "id": "east", "x": 38, "y": 14, "to": "west_corridor",
               "toDoor": "west", "dir": -1, "height": 2 } ],
  "entities": [ { "type": "bone_sentry", "x": 24, "y": 14 } ]
}
```

The choice of ASCII over an editor-authored scene is deliberate: a room layout
is reviewable in a pull request diff, and a level designer can add a room without
opening the engine. Tiles route themselves to the solid, one-way or decorative
layer based on the tileset manifest, so "is this a platform?" is answered in
exactly one place.

## Encounter composition

| Room | Bone Sentry | Nightwing | Gravewalker | Medusa | Notes |
|---|---:|---:|---:|---:|---|
| outer_ward_gate | 1 | — | — | — | Tutorial pacing |
| entrance_hall | 1 | 1 | — | — | Introduces fliers |
| west_corridor | 1 | — | 2 | — | Spike pits constrain retreat |
| chapel_landing | — | — | — | — | Deliberately empty |
| bat_gallery | — | 3 | — | — | Vertical, over spikes |
| vault_twin_step | 2 | — | 1 | — | Guarded reward |
| clock_stair | 1 | 2 | — | — | Vertical climb |
| vault_mist | 2 | — | — | — | Guarded reward |
| medusa_gauntlet | — | 1 | — | stream | Two spawners, capped at 3 alive each |
| boss_approach | — | — | — | — | Deliberately empty |
| throne_of_ash | — | — | — | — | Boss only |

The two empty rooms are load-bearing. A save point that also has enemies is not
a rest beat, and the rhythm of the wing depends on the player being allowed to
exhale twice.

## Validation

`tools/ci/validate_rooms.py` runs in CI and fails the build on:

- ragged grids, unknown glyphs, unknown tile names
- doors pointing at missing rooms or missing doors
- non-reciprocal door pairs
- spawn points or door anchors embedded in solid tile
- unknown entity types
- rooms unreachable from `outer_ward_gate`
- duplicate map cells

The in-engine suite additionally checks that every legend tile exists in the
generated atlas and that every entity type resolves to a real scene.

These checks are not theoretical: they caught a ragged row, a stray Unicode
ellipsis, four doors embedded in wall tiles and a spawn point inside the floor
during authoring of this very document's rooms.

## Known gaps

- **No secret rooms.** Breakable walls exist as a tile (`brick_cracked`) but
  nothing consumes them yet.
- **Gold has no sink.** Banked for a future shop.
- **One boss, one wing.** The graph is built to extend north from
  `clock_stair` and east from `throne_of_ash`.
