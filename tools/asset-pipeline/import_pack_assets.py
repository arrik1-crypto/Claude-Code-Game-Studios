#!/usr/bin/env python3
"""Import third-party art and audio from the Metroidvania asset pack.

The raw pack is kept unmodified in the `Game-Assets-And-Resources` repository;
this script produces the game-ready copies under `assets/`. Keeping the two
separate means the pack can be re-imported after an update without hand-editing
anything in the game repo.

    python3 tools/asset-pipeline/import_pack_assets.py --pack ../Game-Assets-And-Resources/metroidvania-pack

Transformations applied, and why:

* **Hero sprite is downscaled 2:1** (80x80 -> 40x40 frames). The pack's hero is
  authored for a larger tile scale than this project's 16px grid; at native size
  the character is 56px tall and does not fit the doorways, corridors or camera
  framing the levels were built around. A 2:1 box downscale is a clean integer
  ratio and keeps the art readable. Moving to native-size art is a real option,
  but it is a level-geometry pass, not an import setting — see
  design/art-bible.md.
* **Grid sheets keep their grid.** The manifest records `columns`, and
  `SpriteSheetLoader` computes row/column regions, so no repacking is needed.
* **Audio is copied verbatim.** No resampling; Godot handles the source formats.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[2]
ART = REPO_ROOT / "assets" / "art"
AUDIO = REPO_ROOT / "assets" / "audio"
FONTS = REPO_ROOT / "assets" / "fonts"

# Hero sheet geometry in the source pack.
HERO_SRC_FRAME = 80
HERO_SCALE = 2  # 80 -> 40

# Animation ranges within the hero grid, verified frame-by-frame against the
# source sheet. Format: name -> (start, count, fps, loop).
HERO_ANIMATIONS: dict[str, tuple[int, int, float, bool]] = {
    "idle": (0, 12, 8.0, True),
    "run": (16, 8, 12.0, True),
    # The pack ships no dedicated crouch or airborne poses. Mid-stride run
    # frames read better in the air than a standing pose, and the low
    # sword-guard frame stands in for the crouch. Flagged in the art bible.
    "crouch": (33, 1, 1.0, False),
    "jump": (20, 1, 1.0, False),
    "fall": (22, 1, 1.0, False),
    "attack_1": (32, 4, 16.0, False),
    "attack_2": (36, 4, 16.0, False),
    "attack_3": (40, 4, 14.0, False),
    "air_attack": (32, 4, 16.0, False),
    # The pack's morph-ball frames stand in for the Mist Dash: the player
    # dissolving into a spinning form reads exactly right for the ability.
    "dash": (44, 3, 16.0, True),
    "hurt": (47, 1, 1.0, False),
    "dead": (48, 10, 10.0, False),
}

# Slime sheet: 288x96 at 48x32 -> 6 columns, 3 rows.
#   row 0 (0-5)   squash-and-stretch hop cycle
#   row 1 (6-11)  burst and dissipate
#   row 2 (12-17) reform from a puddle
SLIME_FRAME = (48, 32)
SLIME_ANIMATIONS: dict[str, tuple[int, int, float, bool]] = {
    "idle": (0, 6, 5.0, True),
    "walk": (0, 6, 9.0, True),
    "attack": (0, 6, 12.0, True),
    "hurt": (0, 1, 1.0, False),
    "death": (6, 6, 12.0, False),
    "spawn": (12, 6, 12.0, False),
}

# Straight file copies: (source path within pack, destination).
AUDIO_MAP: dict[str, str] = {
    "ch_04_player_abilities/audio/attack.wav": "sfx/whip.wav",
    "ch_04_player_abilities/audio/hit.wav": "sfx/hit.wav",
    "ch_04_player_abilities/audio/jump.wav": "sfx/jump.wav",
    "ch_04_player_abilities/audio/land.wav": "sfx/land.wav",
    "ch_04_player_abilities/audio/dash.wav": "sfx/dash.wav",
    "ch_04_player_abilities/audio/death.wav": "sfx/player_death.wav",
    "ch_04_player_abilities/audio/aargh.wav": "sfx/player_hurt.wav",
    "ch_04_player_abilities/audio/boom.wav": "sfx/boss_hit.wav",
    "ch_04_player_abilities/audio/break_wood.wav": "sfx/enemy_death.wav",
    "ch_04_player_abilities/audio/ability_acquire.wav": "sfx/level_up.wav",
    "ch_04_player_abilities/audio/ability_crack.wav": "sfx/subweapon.wav",
    "ch_05_enemies/slime/slime_hit.wav": "sfx/enemy_hit.wav",
    "ch_05_enemies/audio/health_up.wav": "sfx/pickup.wav",
    "ch_03_game_systems/audio/ui_bloop_audio.wav": "sfx/heart.wav",
    "ch_03_game_systems/audio/ui_select_audio.wav": "sfx/ui_select.wav",
    "ch_03_game_systems/audio/ui_success_audio.wav": "sfx/save.wav",
    "ch_03_game_systems/music/title_01.ogg": "music/title.ogg",
    "ch_03_game_systems/music/dungeon_01.ogg": "music/explore.ogg",
    "ch_06_boss_battles/audio/nega_pink_box_boss.wav": "music/boss.wav",
}

SPRITE_COPIES: dict[str, str] = {
    "ch_03_game_systems/sprites/metroidvania_logo.png": "ui/logo.png",
    "ch_03_game_systems/sprites/health_bar_frame.png": "ui/health_bar_frame.png",
    "ch_03_game_systems/sprites/input_icons.png": "ui/input_icons.png",
    "ch_03_game_systems/sprites/save_point.png": "props/save_point.png",
    "ch_05_enemies/sprites/heart.png": "props/heart_pickup.png",
    "ch_04_player_abilities/sprites/dust_effects.png": "vfx/dust.png",
    "ch_04_player_abilities/sprites/weapon_smears.png": "vfx/weapon_smears.png",
    "ch_04_player_abilities/sprites/abilities.png": "ui/ability_icons.png",
    "ch_06_boss_battles/sprites/pink_box_effects.png": "vfx/boss_effects.png",
}

FONT_COPIES: dict[str, str] = {
    "ch_03_game_systems/fonts/alagard.ttf": "alagard.ttf",
}


def _write_manifest(path: Path, frame_w: int, frame_h: int, columns: int,
                    frame_count: int,
                    animations: dict[str, tuple[int, int, float, bool]]) -> None:
    manifest = {
        "frameWidth": frame_w,
        "frameHeight": frame_h,
        "frameCount": frame_count,
        "columns": columns,
        "animations": {
            name: {"start": start, "count": count, "fps": fps, "loop": loop}
            for name, (start, count, fps, loop) in animations.items()
        },
    }
    path.write_text(json.dumps(manifest, indent=2) + "\n")


def import_hero(pack: Path) -> None:
    src = pack / "ch_01_player_foundations/hero.png"
    image = Image.open(src).convert("RGBA")
    columns = image.width // HERO_SRC_FRAME
    rows = image.height // HERO_SRC_FRAME

    out_frame = HERO_SRC_FRAME // HERO_SCALE
    # BOX averaging over an exact 2:1 ratio: each output pixel is the mean of a
    # 2x2 block, which keeps edges coherent instead of dropping alternate rows.
    scaled = image.resize(
        (image.width // HERO_SCALE, image.height // HERO_SCALE), Image.BOX)

    dest = ART / "characters" / "hero.png"
    dest.parent.mkdir(parents=True, exist_ok=True)
    scaled.save(dest)
    _write_manifest(
        ART / "characters" / "hero.json",
        out_frame, out_frame, columns, columns * rows, HERO_ANIMATIONS)
    print(f"  hero.png  {image.size} -> {scaled.size} "
          f"({out_frame}x{out_frame} frames, {columns}x{rows} grid)")


def import_slime(pack: Path) -> None:
    src = pack / "ch_05_enemies/slime/slime.png"
    image = Image.open(src).convert("RGBA")
    fw, fh = SLIME_FRAME
    columns = image.width // fw
    rows = image.height // fh

    dest = ART / "characters" / "slime.png"
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    _write_manifest(
        ART / "characters" / "slime.json",
        fw, fh, columns, columns * rows, SLIME_ANIMATIONS)
    print(f"  slime.png {image.size} ({fw}x{fh} frames, {columns}x{rows} grid)")


def copy_files(pack: Path, mapping: dict[str, str], root: Path, label: str) -> None:
    print(f"{label}:")
    for src_rel, dest_rel in mapping.items():
        src = pack / src_rel
        if not src.exists():
            print(f"  MISSING {src_rel}")
            continue
        dest = root / dest_rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)
        print(f"  {dest.relative_to(REPO_ROOT)}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--pack",
        default=str(REPO_ROOT.parent / "Game-Assets-And-Resources" / "metroidvania-pack"),
        help="path to the extracted asset pack")
    args = parser.parse_args()

    pack = Path(args.pack)
    if not pack.is_dir():
        print(f"error: asset pack not found at {pack}", file=sys.stderr)
        return 1

    print(f"Importing pack assets from {pack}")
    print("characters:")
    import_hero(pack)
    import_slime(pack)
    copy_files(pack, SPRITE_COPIES, ART, "sprites")
    copy_files(pack, AUDIO_MAP, AUDIO, "audio")
    copy_files(pack, FONT_COPIES, FONTS, "fonts")
    print("done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
