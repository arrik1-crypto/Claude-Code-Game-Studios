# ADR-007 — 2D lighting, parallax and the sprite effects stack

**Status:** Accepted
**Date:** 2026-08-17
**Deciders:** technical-director, technical-artist, art-director
**Supersedes:** nothing. **Amends:** ADR-006 (adds the shader and lighting layers).

## Context

The first pass shipped a game that was *readable* but flat. Three specific gaps:

1. **The lights did nothing.** Torches and relic pedestals created `PointLight2D`
   nodes, but the scene had no `CanvasModulate`. With the canvas already at full
   brightness there is nothing for a light to add, so every one of them rendered
   exactly zero pixels. This was invisible in code review and invisible in the
   screenshots — it only showed up when someone asked why the castle looked flat.
2. **Effects were faked with `modulate`.** The hit flash multiplied the sprite
   colour, which brightens a sprite but preserves its shading, so a dark enemy
   barely registered as hit. The mist form was an alpha value. Neither could
   express a silhouette flash or a dissolve.
3. **Nothing behind the playfield.** Every room was masonry to the edge of the
   screen, including the ones notionally outdoors.

Meanwhile the supplied art pack contained a weapon-smear sheet, a dust sheet and
an animated heart that were imported but never wired to anything.

## Decision

Four layers, each independently disable-able:

### 1. Ambient + point lighting

A `CanvasModulate` (`RoomLighting`) is created per room and tinted by a named
preset declared in the room's JSON (`default`, `dark`, `moonlit`). That is what
makes every existing `PointLight2D` visible.

Light cost is governed centrally by `LightingQuality`, which resolves a tier from
the platform:

| Tier | Lights | Shadows | Used on |
|---|---:|---|---|
| `OFF` | 0 | no | fallback / accessibility |
| `SIMPLE` | 10 | no | mobile, compatibility renderer |
| `SHADOWS` | 16 | player lantern only | desktop |

Rooms hand out lights from a budget; a torch past the cap is still placed, it
just does not light. The room stays dressed and the fill-rate cost stays bounded.

Solid tiles carry an occluder polygon on a dedicated `TileSet` occlusion layer,
so the player's lantern casts real shadows at the top tier. Building the occluders
is nearly free; they cost nothing until a shadow-casting light exists.

### 2. Sprite effects shader

One `canvas_item` shader (`assets/shaders/sprite_fx.gdshader`) shared by every
character, with a **per-entity `ShaderMaterial` instance** — a shared material
would flash the whole bestiary whenever one skeleton was hit.

It provides hit flash (mix to a flat colour, so the whole silhouette reads),
death dissolve (threshold burn against procedural value noise with a hot rim,
requiring no noise texture asset) and the mist form (tint plus a vertical alpha
gradient).

`SpriteFx` wraps it and **falls back to `modulate`** when the shader is
unavailable, so a build where it fails to compile still shows hits.

### 3. Parallax backdrop

Three `ParallaxLayer`s on the World, not inside a Room, so the scroll does not
reset at every door. Visibility is **opt-in per room** (`showsSky`), because an
interior room fills its background with masonry that would hide it entirely.

`ParallaxBackground` is a `CanvasLayer`, so the world's `CanvasModulate` does not
reach it; the ambient tint is applied to the node directly, **darkened** rather
than brightened. Scenery the player can never touch must never compete with
platforms they can.

### 4. VFX library

`Vfx` is a static, fire-and-forget façade over the effect atlases. It owns the
tints, so "what colour is an impact" is decided once rather than in each of the
six places something can be hit — gold for the player's whip, steel for the boss,
crimson for damage, moonlight for magic, desaturated stone for dust.

## Consequences

**Positive**
- Torchlit rooms, moving shadows, and a castle skyline behind the outdoor areas.
- Every hit, landing, dash and swing has a visual.
- Adding an effect is one line at the call site.
- Quality tiers make the mobile budget an explicit decision, in one file.

**Negative**
- Characters are `unshaded`, so they do not receive 2D light. This is deliberate:
  a torch was blowing out any sprite standing beside it, and the lantern plus
  ambient already places the character in the scene. It does mean a character
  cannot be lit dramatically by a scene light without revisiting this.
- The value-noise dissolve is cheaper but slightly coarser than a texture-based
  one. Acceptable at 80x80 during a death animation.
- More draw calls from effects. Bounded by the fact that effects are short-lived
  and free themselves.

## Engine Compatibility

Godot 4.6. Notes verified against `docs/engine-reference/godot/`:

- `CanvasModulate` affects only its own canvas, so `CanvasLayer`-based UI is
  unaffected however dark the world gets — which is what keeps the HUD legible.
- Godot 4.6 processes **glow before tonemapping** (changed in 4.6). No 2D
  `WorldEnvironment` glow is used here; the moon and torches get their bloom from
  the art and the light falloff instead, which avoids the change entirely and
  costs nothing on mobile.
- `TileSet.add_occlusion_layer` and `TileData.set_occluder` are the 4.x
  occlusion API; the pre-4.0 `LightOccluder2D`-per-tile approach is not used.
- `Parallax2D` exists since 4.3 but `ParallaxBackground`/`ParallaxLayer` remain
  supported and are used here for their `motion_mirroring` tiling.

## GDD Requirements Addressed

`TR-ART-003` (readable depth), `TR-ART-004` (combat and movement feedback),
`TR-ART-005` (mobile-bounded rendering cost).
