#!/usr/bin/env python3
"""Import third-party art and audio from the Metroidvania asset pack.

The raw pack is kept unmodified in the `Game-Assets-And-Resources` repository;
this script produces the game-ready copies under `assets/`. Keeping the two
separate means the pack can be re-imported after an update without hand-editing
anything in the game repo.

    python3 tools/asset-pipeline/import_pack_assets.py --pack ../Game-Assets-And-Resources/metroidvania-pack

Transformations applied, and why:

* **Hero sprite is imported at NATIVE 80x80.** The character is 56px tall, which
  is 20.7% of the 270px viewport — almost exactly the proportion Symphony of the
  Night gives Alucard (21.4%). An earlier revision downscaled 2:1 to fit level
  geometry authored for a 28px character; that made the protagonist half the size
  the genre calls for, so the geometry was rebuilt instead. `HERO_SCALE` is kept
  as a knob but should stay at 1.
* **Grid sheets keep their grid.** The manifest records `columns`, and
  `SpriteSheetLoader` computes row/column regions, so no repacking is needed.
* **Audio is copied verbatim, with one exception.** SFX stay as WAV so they fire
  without a decode delay. The boss theme arrives as 24-bit PCM — 9.8 MB for 39
  seconds — and is transcoded to Vorbis to match the pack's other music tracks;
  see `MUSIC_TRANSCODE`. Requires `ffmpeg` on PATH.
* **The save point is recoloured on import.** It ships bright magenta, which is
  off-palette for the castle; see `import_save_point`.
"""

from __future__ import annotations

import argparse
import colorsys
import json
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[2]
ART = REPO_ROOT / "assets" / "art"
AUDIO = REPO_ROOT / "assets" / "audio"
FONTS = REPO_ROOT / "assets" / "fonts"

# Hero sheet geometry in the source pack.
HERO_SRC_FRAME = 80
HERO_SCALE = 1  # native 80x80 — see design/art-bible.md 4.1

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
}

# The pack ships the boss theme as 24-bit stereo PCM: 39 seconds for 9.8 MB,
# which was 70% of the entire APK's asset payload and would also have sat
# uncompressed in memory against a 256 MB budget. The other two music tracks
# already arrive as Vorbis at ~140 kbps, so the boss theme is transcoded to
# match rather than shipped raw. Music is streamed, not a latency-sensitive
# one-shot, so Vorbis costs nothing that matters here — unlike the SFX, which
# stay as WAV precisely because they must fire without a decode delay.
MUSIC_TRANSCODE: dict[str, tuple[str, str]] = {
    "ch_06_boss_battles/audio/nega_pink_box_boss.wav": ("music/boss.ogg", "140k"),
}

# Dust: 256x96 at 32x32 -> 8 columns, 3 rows.
#   row 0 (0-7)   tall puff, dissipating   — jump / double jump
#   row 1 (8-15)  low wide puff            — landing and running
#   row 2 (16-23) expanding ring           — impacts
DUST_FRAME = (32, 32)
DUST_ANIMATIONS: dict[str, tuple[int, int, float, bool]] = {
    "jump": (0, 8, 22.0, False),
    "land": (8, 8, 24.0, False),
    "run": (8, 6, 26.0, False),
    "impact": (16, 8, 26.0, False),
}

# Weapon smears: 1024x128 at 128x128 -> 8 columns, 1 row. These are eight
# distinct arc SHAPES, not a dissipation sequence, so each is exposed as its own
# single-frame animation and the fade/scale is driven in code.
SMEAR_FRAME = (128, 128)
SMEAR_COUNT = 8

# Heart pickup: 320x32 at 32x32 -> 10 frames, one row. A full spin cycle.
HEART_FRAME = (32, 32)
HEART_ANIMATIONS: dict[str, tuple[int, int, float, bool]] = {
    "spin": (0, 10, 12.0, True),
}

# Ability icons: 160x160 at 32x32 -> a 5x5 grid of 25 icons.
ABILITY_ICON_FRAME = (32, 32)

SPRITE_COPIES: dict[str, str] = {
    "ch_03_game_systems/sprites/health_bar_frame.png": "ui/health_bar_frame.png",
    "ch_03_game_systems/sprites/input_icons.png": "ui/input_icons.png",
    "ch_05_enemies/sprites/heart.png": "props/heart_pickup.png",
    "ch_04_player_abilities/sprites/dust_effects.png": "vfx/dust.png",
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


def import_dust(pack: Path) -> None:
    src = pack / "ch_04_player_abilities/sprites/dust_effects.png"
    image = Image.open(src).convert("RGBA")
    fw, fh = DUST_FRAME
    columns = image.width // fw
    rows = image.height // fh

    dest = ART / "vfx" / "dust.png"
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    _write_manifest(ART / "vfx" / "dust.json", fw, fh, columns,
                    columns * rows, DUST_ANIMATIONS)
    print(f"  dust.png  {image.size} ({fw}x{fh} frames, {columns}x{rows} grid)")


def import_smears(pack: Path) -> None:
    src = pack / "ch_04_player_abilities/sprites/weapon_smears.png"
    image = Image.open(src).convert("RGBA")
    fw, fh = SMEAR_FRAME
    columns = image.width // fw

    animations = {
        f"smear_{i}": (i, 1, 1.0, False) for i in range(min(SMEAR_COUNT, columns))
    }

    dest = ART / "vfx" / "smears.png"
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    _write_manifest(ART / "vfx" / "smears.json", fw, fh, columns,
                    columns, animations)
    print(f"  smears.png {image.size} ({len(animations)} arc variants)")


def import_heart(pack: Path) -> None:
    src = pack / "ch_05_enemies/sprites/heart.png"
    image = Image.open(src).convert("RGBA")
    fw, fh = HEART_FRAME
    columns = image.width // fw

    dest = ART / "props" / "heart_pickup.png"
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    _write_manifest(ART / "props" / "heart_pickup.json", fw, fh, columns,
                    columns, HEART_ANIMATIONS)
    print(f"  heart_pickup.png {image.size} ({columns} spin frames)")


def import_ability_icons(pack: Path) -> None:
    src = pack / "ch_04_player_abilities/sprites/abilities.png"
    image = Image.open(src).convert("RGBA")
    fw, fh = ABILITY_ICON_FRAME
    columns = image.width // fw
    rows = image.height // fh
    animations = {
        f"icon_{i}": (i, 1, 1.0, False) for i in range(columns * rows)
    }

    dest = ART / "ui" / "ability_icons.png"
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    _write_manifest(ART / "ui" / "ability_icons.json", fw, fh, columns,
                    columns * rows, animations)
    print(f"  ability_icons.png {image.size} ({columns * rows} icons)")


# The pack's save point is a bright magenta pod. Its silhouette works as a
# sarcophagus, but the hue is from a different game — dropped into Castle Vhorn
# it is the single most saturated thing on screen and reads as a power-up, not a
# place to rest. Only the pink family is moved; the stone greys and the specular
# highlight are the parts that already fit and are left exactly as they are.
SAVE_POINT_SRC = "ch_03_game_systems/sprites/save_point.png"
SAVE_POINT_DEST = "props/save_point.png"

## Hue window treated as "pink/magenta", in degrees. Wraps through 360.
PINK_HUE_RANGE = (280.0, 20.0)
## Colours below this saturation are structural greys and are never touched.
PINK_MIN_SATURATION = 0.20
## Everything in the window collapses onto this hue — the castle's deep violet.
GOTHIC_HUE = 270.0
GOTHIC_SATURATION_SCALE = 0.45
GOTHIC_VALUE_SCALE = 0.82


def _is_pink(hue: float, saturation: float) -> bool:
    if saturation < PINK_MIN_SATURATION:
        return False
    low, high = PINK_HUE_RANGE
    return hue >= low or hue <= high


def import_save_point(pack: Path) -> None:
    """Copy the save point, recoloured from magenta into the gothic palette."""
    src = pack / SAVE_POINT_SRC
    if not src.exists():
        print(f"  MISSING {SAVE_POINT_SRC}")
        return

    image = Image.open(src).convert("RGBA")
    pixels = list(image.getdata())
    out: list[tuple[int, int, int, int]] = []
    moved = 0
    for r, g, b, a in pixels:
        if a == 0:
            out.append((r, g, b, a))
            continue
        h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        if not _is_pink(h * 360.0, s):
            out.append((r, g, b, a))
            continue
        nr, ng, nb = colorsys.hsv_to_rgb(
            GOTHIC_HUE / 360.0,
            min(1.0, s * GOTHIC_SATURATION_SCALE),
            min(1.0, v * GOTHIC_VALUE_SCALE))
        out.append((round(nr * 255), round(ng * 255), round(nb * 255), a))
        moved += 1

    image.putdata(out)
    dest = ART / SAVE_POINT_DEST
    dest.parent.mkdir(parents=True, exist_ok=True)
    image.save(dest)
    print(f"  {dest.relative_to(REPO_ROOT)}  ({moved} px recoloured)")


def transcode_music(pack: Path) -> None:
    """Encode oversized PCM music to Vorbis at the pack's own music bitrate."""
    print("music (transcoded):")
    for src_rel, (dest_rel, bitrate) in MUSIC_TRANSCODE.items():
        src = pack / src_rel
        if not src.exists():
            print(f"  MISSING {src_rel}")
            continue
        dest = AUDIO / dest_rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        result = subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(src),
             "-c:a", "libvorbis", "-b:a", bitrate, str(dest)],
            capture_output=True, text=True)
        if result.returncode != 0:
            print(f"  FAILED {dest_rel}: {result.stderr.strip()[:200]}")
            continue
        before = src.stat().st_size / 1048576
        after = dest.stat().st_size / 1048576
        print(f"  {dest.relative_to(REPO_ROOT)}  {before:.1f} MB -> {after:.1f} MB")


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
    import_heart(pack)
    import_ability_icons(pack)
    print("vfx:")
    import_dust(pack)
    import_smears(pack)
    copy_files(pack, SPRITE_COPIES, ART, "sprites")
    print("props:")
    import_save_point(pack)
    copy_files(pack, AUDIO_MAP, AUDIO, "audio")
    transcode_music(pack)
    copy_files(pack, FONT_COPIES, FONTS, "fonts")
    print("done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
