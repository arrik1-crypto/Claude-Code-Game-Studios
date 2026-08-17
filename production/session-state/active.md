# Session State — Crimson Vespers

**Updated:** 2026-08-17
**Stage:** Production — vertical slice + graphics upgrade

<!-- STATUS -->
Epic: Vertical Slice
Feature: Graphics upgrade
Task: Complete — awaiting playtest
<!-- /STATUS -->

## What exists

A playable Godot 4.6 mobile Metroidvania: 11 interconnected rooms, 6 enemy types
plus a 3-phase boss, 2 ability gates, 2 save points, full touch/keyboard/gamepad
input, HUD, map and pause screens — now rendered at the art's native fidelity
with dynamic lighting, parallax and a full VFX layer.

## Verification status

| Check | Command | Result |
|---|---|---|
| Room data | `python3 tools/ci/validate_rooms.py` | 11 rooms, 0 errors |
| Unit + integration | `godot --headless --path . res://tests/test_runner.tscn` | 109 tests / 1173 assertions, all pass |
| Runtime smoke + screenshots | `xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/debug/capture_scene.tscn -- --out=/tmp/shots` | PASS, 17 screenshots |

Evidence: `production/qa/evidence/2026-08-17-graphics-upgrade/`.

## The graphics upgrade

**Hero restored to native resolution.** Was being imported at a 2:1 downscale,
making the character 28px — half the size the genre calls for. Now native 80x80
art, 56px character, 20.7% of viewport height (SOTN's Alucard is 21.4%).

That cascaded, deliberately:
- Rooms regrown 40x18 → 40x24; doorways 2 → 4 tiles
- Jump retuned: apex 60px → 101px, double-jump total 110px → 181px
- Twin Step gate moved 80px → 128px, still inside the single/double window
- Player, enemy and boss collision, hurtboxes, whip reach and probes all rescaled
- Bestiary EPX-doubled on export so a 22px skeleton no longer stands next to a
  56px hero

**Lighting now exists at all.** The torches and relic pedestals had been creating
`PointLight2D` nodes with no `CanvasModulate` in the scene, so every one rendered
zero pixels. Added per-room ambient with named presets, a central
`LightingQuality` budget with mobile tiers, tile occluders for lantern shadows,
and a flickering flame light per torch.

**Sprite shader** replacing the `modulate` hit-flash hack: silhouette flash,
death dissolve against procedural noise, and a real mist form for the dash.

**Parallax skyline** behind rooms that declare `showsSky`, dimmed so it never
competes with platforms the player can actually stand on.

**VFX library** wiring the previously-unused pack sheets: whip arc smears per
combo step, jump/land/run dust, impact rings, mist trails, blood.

## Key decisions

- ADR-001..006 as before; **ADR-007** added for the rendering and lighting stack
- Characters render `unshaded` — a torch was blowing out any sprite beside it
- No 2D `WorldEnvironment` glow: Godot 4.6 changed glow to pre-tonemap, and the
  art plus light falloff gives the bloom for free on mobile
- Kept the generated castle tileset over the pack's forest one (theme fit)

## Bugs found and fixed

1. **TileSet had no collision** — atlas source populated before being attached.
   Every floor was walk-through. Guarded by `world_tileset_collision_test.gd`.
2. **Relics could never render as taken** — `Room` set exports after `add_child`.
3. **Boss charge resolved into a slash** — shared wind-up state never branched.
4. **All 2D lights were no-ops** — no `CanvasModulate`. Guarded by
   `world_lighting_test.gd`, which asserts the conditions that make a light
   visible rather than merely that a light node exists.
5. Room authoring errors caught by the validator throughout.

## Known gaps

- The pack's hero sheet has no crouch or airborne poses; substitutes in use.
- Gold accumulates with nothing to spend it on.
- MP regenerates but is never consumed.
- The smoke run covers the first room, map and pause — not the full route to the
  boss.
- Unused pack art remaining: `nega_pink_box` boss sprite, `forgotten_forest`
  tileset, `props_destructible`, `door_and_switch`, `light_stream` god-rays.
- Style split between the imported hero and the generated bestiary is reduced by
  the EPX doubling but not eliminated. Tracked in `design/art-bible.md` 4.3.

## Suggested next steps

1. Playtest the full route and tune encounter density for the new movement speed.
2. Extend the capture harness to walk the whole critical path.
3. Wire `light_stream.jpg` as god-rays through the window tiles.
4. Add the shop to give gold a sink.
