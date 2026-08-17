#!/usr/bin/env python3
"""Crimson Vespers — placeholder asset generator.

Regenerates every sprite atlas, tileset and UI image under `assets/`, plus the
JSON manifests the engine reads at runtime.

    python3 tools/asset-pipeline/generate_assets.py

Output is fully deterministic: running it twice produces identical bytes, so it
is safe to re-run before every commit. These are *placeholders* — see
`design/art-bible.md` and `design/asset-specs/` for the specifications that
final art must satisfy when it replaces them.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

# Allow running from the repository root without installing anything.
sys.path.insert(0, str(Path(__file__).resolve().parent))

import sprites_enemies  # noqa: E402
import sprites_player  # noqa: E402
import sprites_world  # noqa: E402
from pixelart import save_png, scale_atlas_2x  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parents[2]
ART = REPO_ROOT / "assets" / "art"


def _report(path: Path) -> None:
    print(f"  wrote {path.relative_to(REPO_ROOT)}")


def generate_characters() -> None:
    print("characters:")
    player = sprites_player.build()
    player.save(ART / "characters" / "player.png", ART / "characters" / "player.json")
    _report(ART / "characters" / "player.png")

    # The bestiary is authored at half scale and EPX-doubled on export. The
    # imported hero is 56px tall; a 22px skeleton beside it reads as a different
    # game. Doubling with edge interpolation (rather than nearest-neighbour)
    # keeps the art crisp at 16px-tile resolution instead of turning every pixel
    # into a 2x2 block. See design/art-bible.md 4.2.
    bestiary = {
        "bone_sentry": scale_atlas_2x(sprites_enemies.build_bone_sentry()),
        "nightwing": scale_atlas_2x(sprites_enemies.build_nightwing()),
        "gravewalker": scale_atlas_2x(sprites_enemies.build_gravewalker()),
        "medusa_head": scale_atlas_2x(sprites_enemies.build_medusa_head()),
        "sanguine_knight": scale_atlas_2x(sprites_enemies.build_sanguine_knight()),
    }
    for name, atlas in bestiary.items():
        atlas.save(ART / "characters" / f"{name}.png", ART / "characters" / f"{name}.json")
        _report(ART / "characters" / f"{name}.png")


def generate_world() -> None:
    print("world:")
    sheet, index = sprites_world.build_tileset()
    save_png(sheet, ART / "tiles" / "castle_tileset.png")
    _report(ART / "tiles" / "castle_tileset.png")

    manifest = {
        "tileSize": sprites_world.TILE,
        "columns": sprites_world.TILES_PER_ROW,
        "tiles": {name: {"x": c[0], "y": c[1]} for name, c in index.items()},
        # Tiles the physics layer should treat as solid ground.
        "solid": [
            "brick_solid", "brick_top", "brick_top_left", "brick_top_right",
            "brick_left", "brick_right", "brick_bottom", "brick_cracked",
            "floor_stone", "pillar_top", "pillar_mid", "pillar_base",
        ],
        # Tiles that only collide from above (drop-through platforms).
        "oneWay": ["platform"],
        # Tiles that damage the player on contact.
        "hazard": ["spikes"],
        # Purely decorative — no collision at all.
        "decor": [
            "bg_brick", "bg_arch", "bg_window", "bg_curtain", "bg_dark",
            "stair_right", "stair_left", "rubble", "mist_gate", "iron_rail",
        ],
    }
    tile_json = ART / "tiles" / "castle_tileset.json"
    tile_json.write_text(json.dumps(manifest, indent=2) + "\n")
    _report(tile_json)

    props = sprites_world.build_props()
    props.save(ART / "props" / "props.png", ART / "props" / "props.json")
    _report(ART / "props" / "props.png")

    vfx = sprites_world.build_vfx()
    vfx.save(ART / "vfx" / "vfx.png", ART / "vfx" / "vfx.json")
    _report(ART / "vfx" / "vfx.png")

    for name, builder in (
        ("sky", sprites_world.build_parallax_sky),
        ("far", sprites_world.build_parallax_far),
        ("near", sprites_world.build_parallax_near),
    ):
        path = ART / "parallax" / f"{name}.png"
        save_png(builder(), path)
        _report(path)


def generate_ui() -> None:
    print("ui:")
    for name, canvas in sprites_world.build_ui().items():
        save_png(canvas, ART / "ui" / f"{name}.png")
        _report(ART / "ui" / f"{name}.png")
    save_png(sprites_world.build_title_banner(), ART / "ui" / "title_backdrop.png")
    _report(ART / "ui" / "title_backdrop.png")


def main() -> int:
    print(f"Crimson Vespers asset generation -> {ART.relative_to(REPO_ROOT)}")
    generate_characters()
    generate_world()
    generate_ui()
    print("done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
