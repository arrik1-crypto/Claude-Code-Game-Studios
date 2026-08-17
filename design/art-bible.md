# Art Bible — Crimson Vespers

**Status:** Living document
**Owner:** art-director
**Last updated:** 2026-08-17

## 1. Visual pillars

1. **Moonlit, not black.** The castle is lit by a crimson moon through lancet
   windows. Shadows are deep violet, never neutral black — pure black is reserved
   for silhouettes and outlines.
2. **Crimson is information.** One saturated red in an otherwise desaturated
   palette. If something is crimson it matters: the player's sash, blood, the
   boss, the moon, the HP bar. Nothing decorative is allowed to be red.
3. **Silhouette first.** At 480×270 on a phone held at arm's length, a shape is
   read before its detail. Every character must be identifiable in solid black.
4. **Readable over ornate.** Masonry is regular and low-contrast so that
   characters, pickups and hazards pop against it.

## 2. Technical specification

| Property | Value |
|---|---|
| Reference viewport | 480 × 270 (16:9) |
| Tile size | 16 × 16 px |
| Player frame | 40 × 40 px (character ≈ 28 px tall) |
| Standard enemy frame | 32 × 32 px |
| Boss frame | 64 × 64 px |
| Texture filtering | Nearest, no mipmaps |
| Stretch mode | `canvas_items`, `expand` |
| Colour depth | Indexed palette, see §3 |

Characters are authored facing **right**; the engine flips for left. Never author
a mirrored pose.

Sprite origin convention: the character's feet sit on the last row of the frame,
and the `AnimatedSprite2D.offset` places that row at the node origin.

## 3. Palette

The full palette lives in `tools/asset-pipeline/palette.py` and is the single
source of truth for generated art.

| Ramp | Light | Mid | Dark | Used for |
|---|---|---|---|---|
| Outline | — | `#241d33` | `#14101f` | All silhouettes |
| Castle brick | `#4a4265` | `#372f4d` | `#251f38` | Walls, floors |
| Stone | `#7f869a` | `#5a6072` | `#3b4050` | Pillars, flagstones |
| Crimson | `#d33449` | `#8e1b2c` | `#54101c` | **Reserved — see pillar 2** |
| Gold | `#f0cd72` | `#a67c2c` | — | Trim, relics, the whip lash |
| Moonlight | `#bfe6ff` | `#6f9fd8` | `#3d5f96` | Windows, mist, magic |
| Flame | `#ffe9a8` | `#f2a63c` | `#c25320` | Torches, hit sparks |
| Bone | `#ece7d6` | `#b3ac96` | `#7a7460` | Skeletons |
| Undead flesh | `#7d9560` | `#55663f` | `#39452a` | Gravewalkers |

## 4. Asset sources — current state

The slice mixes two sources, and that is a known, tracked inconsistency.

### 4.1 Imported (Metroidvania asset pack)

Raw pack lives unmodified in `Game-Assets-And-Resources/metroidvania-pack/`.
Game-ready copies are produced by
`tools/asset-pipeline/import_pack_assets.py`.

| Asset | Use |
|---|---|
| `hero.png` | Player character — all animations |
| `slime.png` | Cellar Slime |
| `alagard.ttf` | Project-wide UI font |
| `metroidvania_logo.png` | Title screen |
| `dust_effects`, `weapon_smears`, `pink_box_effects` | VFX library (partially wired) |
| SFX + 3 music tracks | All game audio |

**Hero downscale.** The pack's hero is 80 × 80 with a ~56 px character, authored
for a larger tile scale. The import downscales 2:1 to 40 × 40 (≈ 28 px character)
because the level geometry, collision capsules, doorway heights and camera
framing were all built around a ~28 px protagonist on a 16 px grid. This is a
deliberate trade: adopting the native size is a level-geometry pass, not an
import flag.

**Known gaps in the pack's hero sheet.** No dedicated crouch or airborne poses.
The import substitutes a low sword-guard frame for the crouch and mid-stride run
frames for jump and fall. These read acceptably but are the first thing to
replace if the character gets a bespoke animation pass.

### 4.2 Generated placeholders

Everything else is generated deterministically by
`tools/asset-pipeline/generate_assets.py` from hand-authored ASCII glyph grids.
Re-running produces byte-identical output, so regeneration never churns the diff.

| Asset | Status |
|---|---|
| `castle_tileset.png` | Generated — **keep**. Thematically correct (gothic masonry) and fully wired to the room builder's role system. The pack's forest tileset does not fit Castle Vhorn. |
| Bone Sentry, Nightwing, Gravewalker, Medusa Head | Generated placeholders |
| Sanguine Knight | Generated placeholder |
| Props, pickups, UI plates, touch controls | Generated placeholders |

### 4.3 Style inconsistency — tracked

The imported hero is a higher-fidelity, warmer-palette character than the
generated gothic bestiary around it. This is visible and is accepted for the
slice. Resolution options, in preference order:

1. Commission or source a bestiary in the hero's style (preferred).
2. Recolour the hero into the castle palette via a pipeline step.
3. Replace the hero with bespoke art matching the generated set.

Do not resolve this by degrading the hero.

## 5. Animation standards

| Animation | Frames | FPS | Loop |
|---|---:|---:|---|
| idle | 8–12 | 3–8 | yes |
| run | 6–8 | 12 | yes |
| jump / fall | 1–2 | — | no |
| attack (per combo step) | 4–5 | 14–16 | no |
| hurt | 1 | — | no |
| death | 6–12 | 5–12 | no |

Enemy telegraphs must be **at least 0.35 s** and visually distinct from the idle
pose — on a small screen a subtle wind-up is not a tell, it is a surprise. Boss
wind-ups are 0.45–0.6 s.

## 6. VFX

- Hit sparks are warm (flame ramp); blood is crimson; mist and soul effects are
  moonlight. The colour tells the player what happened before the shape does.
- Screen shake is capped and short — 2.5–8 strength, 0.15–0.8 s. It punctuates;
  it never obscures.
- Hit-stop is 0.06 s on player damage. Any longer reads as a frame drop.

## 7. UI

- Font: **Alagard** (`assets/fonts/alagard.ttf`), set project-wide via
  `gui/theme/custom_font`.
- HUD occupies the top-left only, clear of both thumb zones.
- Bars: 1 px outline in outline-dark, 1 px inner edge, flat fill, 1 px highlight
  along the top of the fill.
- Touch controls are tinted to the coat ramp and default to 65% opacity so they
  read as an overlay rather than as part of the world.

## 8. Asset request checklist

Before commissioning or generating any new asset:

- [ ] Frame size matches the table in §2
- [ ] Authored facing right
- [ ] Feet on the last row of the frame
- [ ] Palette drawn from §3, crimson used only per pillar 2
- [ ] Silhouette test passed (identifiable in solid black)
- [ ] Telegraph frames visually distinct from idle
- [ ] Legible at 1× on a 5-inch screen
