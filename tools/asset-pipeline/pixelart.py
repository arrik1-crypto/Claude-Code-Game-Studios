"""Crimson Vespers — tiny pixel-art composition library.

The placeholder art is *hand-authored* as ASCII glyph grids (see `sprites_*.py`)
and then composed procedurally into animation frames. That split is deliberate:

* Hand-authored parts give silhouettes that actually read as a character.
* Procedural composition gives us cheap animation (bob, stride, squash) without
  authoring every frame by hand.

Everything here is deterministic — no RNG — so regenerating the atlas produces
byte-identical output and never churns the repo diff.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

from palette import T, rgba


class Canvas:
    """A mutable RGBA pixel buffer with pixel-art friendly helpers."""

    def __init__(self, width: int, height: int) -> None:
        self.w = width
        self.h = height
        self.px: list[list[tuple[int, int, int, int]]] = [
            [T for _ in range(width)] for _ in range(height)
        ]

    # -- construction ------------------------------------------------------

    @classmethod
    def from_ascii(cls, rows: list[str]) -> "Canvas":
        """Build a canvas from a list of equal-length glyph strings."""
        rows = [r for r in rows if r != ""]
        if not rows:
            return cls(1, 1)
        width = max(len(r) for r in rows)
        c = cls(width, len(rows))
        for y, row in enumerate(rows):
            for x, glyph in enumerate(row):
                if glyph != ".":
                    c.px[y][x] = rgba(glyph)
        return c

    # -- drawing -----------------------------------------------------------

    def set(self, x: int, y: int, color: tuple[int, int, int, int]) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = color

    def get(self, x: int, y: int) -> tuple[int, int, int, int]:
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return T

    def blit(self, other: "Canvas", ox: int, oy: int) -> None:
        """Alpha-aware paste: fully transparent source pixels are skipped."""
        for y in range(other.h):
            for x in range(other.w):
                c = other.px[y][x]
                if c[3] == 0:
                    continue
                self.set(x + ox, y + oy, c)

    def rect(self, x0: int, y0: int, x1: int, y1: int, glyph: str) -> None:
        col = rgba(glyph)
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, col)

    def line(self, x0: int, y0: int, x1: int, y1: int, glyph: str) -> None:
        """Integer Bresenham line — keeps edges crisp."""
        col = rgba(glyph)
        dx, dy = abs(x1 - x0), abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy
        while True:
            self.set(x0, y0, col)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                x0 += sx
            if e2 < dx:
                err += dx
                y0 += sy

    # -- transforms --------------------------------------------------------

    def flipped_h(self) -> "Canvas":
        out = Canvas(self.w, self.h)
        for y in range(self.h):
            for x in range(self.w):
                out.px[y][self.w - 1 - x] = self.px[y][x]
        return out

    def recolored(self, mapping: dict[str, str]) -> "Canvas":
        """Swap palette entries, e.g. to tint an enemy variant."""
        lut = {rgba(k): rgba(v) for k, v in mapping.items()}
        out = Canvas(self.w, self.h)
        for y in range(self.h):
            for x in range(self.w):
                c = self.px[y][x]
                out.px[y][x] = lut.get(c, c)
        return out

    def outlined(self, glyph: str = "K") -> "Canvas":
        """Add a 4-neighbour outline around every opaque pixel."""
        col = rgba(glyph)
        out = Canvas(self.w, self.h)
        out.px = [row[:] for row in self.px]
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x][3] != 0:
                    continue
                touching = any(
                    self.get(x + dx, y + dy)[3] != 0
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                )
                if touching:
                    out.px[y][x] = col
        return out

    def shifted(self, dx: int, dy: int) -> "Canvas":
        out = Canvas(self.w, self.h)
        out.blit(self, dx, dy)
        return out

    def to_image(self) -> Image.Image:
        img = Image.new("RGBA", (self.w, self.h))
        img.putdata([self.px[y][x] for y in range(self.h) for x in range(self.w)])
        return img


def frame(width: int, height: int, parts: list[tuple[Canvas, int, int]]) -> Canvas:
    """Compose an animation frame from (part, x, y) placements, back to front."""
    c = Canvas(width, height)
    for part, x, y in parts:
        c.blit(part, x, y)
    return c


class Atlas:
    """Packs equal-sized frames into a horizontal strip plus a JSON manifest.

    Godot builds `SpriteFrames` from the manifest at runtime (see
    `src/core/sprite_sheet_loader.gd`), so no giant hand-written .tres files
    need to live in the repo.
    """

    def __init__(self, frame_w: int, frame_h: int) -> None:
        self.fw = frame_w
        self.fh = frame_h
        self.frames: list[Canvas] = []
        self.anims: dict[str, dict] = {}

    def add_anim(
        self,
        name: str,
        frames: list[Canvas],
        fps: float = 10.0,
        loop: bool = True,
    ) -> None:
        start = len(self.frames)
        for f in frames:
            if f.w != self.fw or f.h != self.fh:
                raise ValueError(
                    f"anim '{name}': frame is {f.w}x{f.h}, atlas expects "
                    f"{self.fw}x{self.fh}"
                )
            self.frames.append(f)
        self.anims[name] = {
            "start": start,
            "count": len(frames),
            "fps": fps,
            "loop": loop,
        }

    def save(self, png_path: Path, json_path: Path) -> None:
        png_path.parent.mkdir(parents=True, exist_ok=True)
        json_path.parent.mkdir(parents=True, exist_ok=True)
        sheet = Image.new("RGBA", (self.fw * max(1, len(self.frames)), self.fh))
        for i, f in enumerate(self.frames):
            sheet.paste(f.to_image(), (i * self.fw, 0))
        sheet.save(png_path)
        manifest = {
            "frameWidth": self.fw,
            "frameHeight": self.fh,
            "frameCount": len(self.frames),
            "animations": self.anims,
        }
        json_path.write_text(json.dumps(manifest, indent=2) + "\n")


def save_png(canvas: Canvas, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.to_image().save(path)
