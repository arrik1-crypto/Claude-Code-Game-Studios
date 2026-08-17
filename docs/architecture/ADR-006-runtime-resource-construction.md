# ADR-006 — Build SpriteFrames and TileSet at runtime from manifests

**Status:** Accepted
**Date:** 2026-08-17
**Deciders:** technical-director, technical-artist

## Context

Godot's normal workflow is to author `SpriteFrames` and `TileSet` resources in
the editor and commit them as `.tres`. Those files are large, machine-generated,
and merge-conflict constantly. Worse, they duplicate information that already
exists in the atlas: if the art pipeline adds two frames, the `.tres` silently
goes stale.

This project generates most of its art from a Python pipeline and imports the
rest from a third-party pack, so the atlas layout changes often.

## Decision

- Every sprite atlas ships a **JSON manifest** beside the PNG, paired by
  basename. `SpriteSheetLoader` builds `SpriteFrames` from it at load time and
  caches per-path.
- The tile atlas ships a manifest declaring each tile's coordinate and role
  (solid / one-way / hazard / decor). `TileSetBuilder` constructs the `TileSet`
  and its collision polygons from that.
- No `SpriteFrames` or `TileSet` `.tres` is committed.

Manifests support both a single horizontal strip (generated art) and a grid via
a `columns` field (imported pack sheets), so one loader covers both sources.

## Consequences

**Positive**
- Regenerating art never produces a merge conflict.
- The animation table cannot drift out of sync with the image — they are
  produced by the same script.
- Every Nightwing in a room shares one cached `SpriteFrames` and one set of
  `AtlasTexture`s.

**Negative**
- No in-editor preview of animations. Accepted; the capture harness renders real
  frames instead.
- Construction cost at load. Measured in single-digit milliseconds per atlas,
  and cached thereafter.

**Sharp edge, learned the hard way:** a `TileSetAtlasSource` must be added to its
`TileSet` **before** any tile is created. Building tiles first produces a TileSet
that looks correct and has *no collision polygons at all* — Godot logs an error
and continues. Every floor in the castle was walk-through until
`tests/unit/world/world_tileset_collision_test.gd` was written to assert on
polygon counts rather than tile counts.

## Engine Compatibility

Godot 4.6. Uses `TileSetAtlasSource`, `TileData.add_collision_polygon`,
`set_collision_polygon_one_way`, and custom data layers. `AtlasTexture.filter_clip`
is set so sub-images do not bleed at non-integer viewport scales.

## GDD Requirements Addressed

`TR-ART-001` (regenerable art pipeline), `TR-ART-002` (mixed generated and
imported asset sources), `TR-DATA-003` (validated content pipeline).
