#!/usr/bin/env python3
"""Generate the Android launcher icons from the 64x64 game icon.

    python3 tools/asset-pipeline/make_android_icons.py

Android wants three separate images and Godot will silently substitute its own
robot logo for any one left unset — which is how the first APK out of this
project shipped the Godot mascot as its launcher icon.

What gets produced, and why each is shaped the way it is:

* **main_192x192** — the legacy square icon, used on Android 7 and older. The
  source is 64x64 pixel art and 192 is exactly 3x, so this is a clean
  nearest-neighbour upscale with no resampling blur.

* **adaptive_foreground_432x432** — Android 8+ composites a foreground over a
  background and then masks the pair to whatever shape the launcher wants
  (circle, squircle, rounded square). Only the centre 288x288 of the 432 canvas
  is guaranteed to survive that mask, so the motif is upscaled 4x to 256x256 and
  centred, leaving 88px of bleed on every side. The icon's own flat background
  is made transparent here: if it were left in, the mask would cut a circle out
  of a dark *square* sitting on the background layer, and the seam would show.

* **adaptive_background_432x432** — a flat fill in the icon's own background
  colour, so the transparent areas of the foreground land on exactly the shade
  the artwork was drawn against.

* **adaptive_monochrome_432x432** — Android 13+ themed icons. The launcher tints
  this by the user's wallpaper palette, so it must be a single-colour silhouette
  on transparency; any colour in it is discarded.

Nearest-neighbour throughout. Pixel art upscaled with any smoothing filter turns
to mush, which is the whole reason the project renders at integer scale.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[2]
UI = REPO_ROOT / "assets" / "art" / "ui"
SOURCE = UI / "icon.png"

## Android's adaptive-icon canvas, and the centre square guaranteed to survive
## the launcher's mask (72dp visible out of 108dp total).
ADAPTIVE_CANVAS = 432
ADAPTIVE_SAFE = 288

## Legacy square icon. Exactly 3x the 64px source.
LEGACY_SIZE = 192

## Upscale for the motif inside the adaptive canvas: 64 * 4 = 256, comfortably
## inside the 288 safe zone.
ADAPTIVE_SCALE = 4

## Flat colours in the source that are background rather than motif. Both are
## dropped from the foreground layer and reproduced by the background layer.
BACKGROUND_COLORS = {(23, 19, 38, 255), (20, 16, 31, 255)}

## The fill for the background layer — the icon's dominant background shade.
BACKGROUND_FILL = (23, 19, 38, 255)


def _nearest(image: Image.Image, size: int) -> Image.Image:
    return image.resize((size, size), Image.NEAREST)


def _centred(sprite: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (ADAPTIVE_CANVAS, ADAPTIVE_CANVAS), (0, 0, 0, 0))
    offset = (ADAPTIVE_CANVAS - sprite.width) // 2
    canvas.paste(sprite, (offset, offset), sprite)
    return canvas


def _drop_background(image: Image.Image) -> Image.Image:
    out = image.copy()
    out.putdata([
        (0, 0, 0, 0) if px in BACKGROUND_COLORS else px
        for px in out.get_flattened_data()
    ])
    return out


def _silhouette(image: Image.Image) -> Image.Image:
    # Themed icons are tinted by the launcher, so only the alpha channel
    # survives. White keeps it legible if a launcher skips tinting entirely.
    out = image.copy()
    out.putdata([
        (255, 255, 255, px[3]) if px[3] > 0 else (0, 0, 0, 0)
        for px in out.get_flattened_data()
    ])
    return out


def main() -> int:
    if not SOURCE.exists():
        print(f"error: {SOURCE} not found", file=sys.stderr)
        return 1

    icon = Image.open(SOURCE).convert("RGBA")
    if icon.size != (64, 64):
        print(f"error: expected a 64x64 source icon, got {icon.size}", file=sys.stderr)
        return 1

    written: list[tuple[Path, str]] = []

    legacy = _nearest(icon, LEGACY_SIZE)
    legacy_path = UI / "android_icon_192.png"
    legacy.save(legacy_path)
    written.append((legacy_path, f"{LEGACY_SIZE}x{LEGACY_SIZE} legacy square"))

    motif = _drop_background(_nearest(icon, 64 * ADAPTIVE_SCALE))
    foreground = _centred(motif)
    fg_path = UI / "android_icon_foreground_432.png"
    foreground.save(fg_path)
    written.append((fg_path, f"{ADAPTIVE_CANVAS}px adaptive foreground "
                             f"(motif {motif.width}px, safe zone {ADAPTIVE_SAFE}px)"))

    background = Image.new("RGBA", (ADAPTIVE_CANVAS, ADAPTIVE_CANVAS), BACKGROUND_FILL)
    bg_path = UI / "android_icon_background_432.png"
    background.save(bg_path)
    written.append((bg_path, f"{ADAPTIVE_CANVAS}px adaptive background (flat "
                             f"#{BACKGROUND_FILL[0]:02x}{BACKGROUND_FILL[1]:02x}"
                             f"{BACKGROUND_FILL[2]:02x})"))

    monochrome = _silhouette(foreground)
    mono_path = UI / "android_icon_monochrome_432.png"
    monochrome.save(mono_path)
    written.append((mono_path, f"{ADAPTIVE_CANVAS}px themed monochrome silhouette"))

    print("Android launcher icons:")
    for path, note in written:
        print(f"  {path.relative_to(REPO_ROOT)}  — {note}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
