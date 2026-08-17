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
| Unit + integration | `godot --headless --path . res://tests/test_runner.tscn` | 120 tests / 1377 assertions, all pass |
| Runtime smoke + screenshots | `xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/debug/capture_scene.tscn -- --out=/tmp/shots` | PASS, 17 screenshots, zero engine errors |
| Title screen | same, with `-- --title` | PASS |
| Save room | same, with `-- --room=chapel_landing --door=save` | PASS |

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


## Correctness pass (post-capture)

Reviewing the captured evidence turned up four defects that every green gate had
missed. Each is fixed, and each now has a test that fails without the fix.

| Defect | Consequence | Caught by |
|---|---|---|
| `parallax_backdrop.gd` assigned `modulate` on a `ParallaxBackground` (a `CanvasLayer`, which has none) | The script never compiled, and took `world.gd` down with it. The backdrop had **never rendered** — the room's background tile layer was standing in for it. Shipped in `b7395da`. | `tests/unit/core/source_compilation_test.gd` |
| `StateMachine` entered its first state during its own `_ready` | Godot readies children before parents, so `Player.sprite` was still null. Threw on **every spawn**; the idle animation never played until the next transition covered it. | `tests/integration/player_spawn_test.gd` |
| `RelicPedestal` wrote `monitoring = false` from inside `body_entered` | Refused by the physics server while flushing queries, so a collected relic kept its collision live. | `test_taking_a_relic_at_runtime_...` |
| `enemy_base._spawn_drops` added an `Area2D` pickup to the tree from inside the death callback | Same refusal; also configured the node *after* `add_child`, which this project forbids. | capture run is now error-free |

Two gates were themselves at fault and were hardened:

- **The test runner** silently skipped suites that failed to load and still
  reported PASS with a *lower* test count.
- **The capture harness** reported PASS while `world.gd` was failing to compile,
  because a script error is an engine error, not a harness error. It now asserts
  the World has a script and the backdrop resolved.

The harness also gained `--title` and `--room=`/`--door=`, without which the
title screen and both save rooms could not be photographed at all.

## Art corrections

- `save_point.png` recoloured on import from magenta (sat 0.73) to the castle
  violet (sat 0.19–0.33), and pushed to `z_index = -1` so it stops swallowing the
  player from the knees down.
- `medusa_gauntlet` ambient `default` → `dark`; it was a brightness pop between
  two dark rooms on the descent to the boss.
- Orphans removed: `assets/art/ui/logo.png` (the pack's own wordmark, already
  rejected from the title screen) and `assets/art/vfx/weapon_smears.png`.

## Known gaps

Unchanged from the graphics pass and tracked in `design/art-bible.md` §4.4: 22
doors are still invisible triggers (highest-value remaining art task), and the
extra vertical room space from the 40x18 → 40x24 regrow is unused headroom rather
than designed layout.
