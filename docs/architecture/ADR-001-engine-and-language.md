# ADR-001 — Godot 4.6 with GDScript

**Status:** Accepted
**Date:** 2026-08-17
**Deciders:** technical-director

## Context

Crimson Vespers is a 2D pixel-art Metroidvania targeting mobile first, built by a
small team with a heavy emphasis on iteration speed. The engine choice
constrains everything downstream: the asset pipeline, the build system, the
testing story and the export targets.

The project template ships specialist agents for Godot, Unity and Unreal, and
pins an engine reference library for each.

## Decision

**Godot 4.6, with GDScript as the sole gameplay language.**

Rendering method is `mobile` (Vulkan on Android/iOS, with the OpenGL3
compatibility renderer available as a fallback and used for CI screenshots).

## Rationale

- **2D is a first-class citizen.** Godot's 2D renderer, `TileMapLayer`,
  `CharacterBody2D` and `AnimatedSprite2D` are exactly the primitives this genre
  needs, with no 3D overhead dragged along into the export.
- **Export size.** A 2D-only Godot export is tens of megabytes. Mobile install
  size is a real conversion factor.
- **Iteration speed.** GDScript needs no compile step. For a game whose
  difficulty is tuned by repeatedly playing it, the edit-to-play loop dominates
  raw execution speed.
- **Headless testing.** `godot --headless` runs the full engine including
  autoloads, so gameplay logic can be unit-tested in CI without a display. This
  is what makes the balance model verifiable rather than aspirational.
- **Licensing.** MIT, no royalties, no seat costs.

### Why GDScript rather than C#

The performance ceiling is irrelevant at this scale — the frame budget is spent
on a dozen entities and two tilemap layers. GDScript buys faster iteration,
smaller exports (no .NET runtime), and simpler mobile export configuration.
C# remains available per-file if a genuine hot path appears; none has.

### Why not Unity or Unreal

Unity's 2D toolchain is capable but the export size and licensing overhead are
poor fits for a small mobile title. Unreal is built around 3D and its mobile 2D
story is weak.

## Consequences

**Positive**
- Sub-second iteration on gameplay tuning.
- Full logic test coverage runs headless in CI.
- Small mobile export.

**Negative**
- GDScript is dynamically typed by default. Mitigated by mandating static type
  hints throughout — see the control manifest.
- The team must track post-4.3 API changes. Mitigated by the pinned reference
  library in `docs/engine-reference/godot/`.
- No compile-time checking. Mitigated by the headless test suite gating CI.

## Engine Compatibility

Pinned to **Godot 4.6** (`docs/engine-reference/godot/VERSION.md`). Relevant
post-cutoff features actually used:

| Feature | Version | Used for |
|---|---|---|
| `@abstract` | 4.5 | `PlayerState`, `EnemyBase` |
| `TileMapLayer` | 4.3 | All room geometry (replaces `TileMap`) |
| Dedicated 2D navigation server | 4.5 | Smaller export (not otherwise used) |
| `FileAccess.store_*` returning `bool` | 4.4 | Save writes check the return value |
| Dual-focus UI system | 4.6 | Touch vs keyboard focus in menus |

Jolt physics (4.6 default) is 3D-only and does not affect this project; 2D
physics is unchanged.

## GDD Requirements Addressed

`TR-ENG-001` (mobile export target), `TR-ENG-002` (headless-testable gameplay
logic), `TR-ENG-003` (sub-second iteration on balance changes).
