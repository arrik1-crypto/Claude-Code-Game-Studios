"""Castle Vhorn environment art — tileset, props, pickups, projectiles, VFX, UI.

Tiles are generated procedurally rather than hand-authored: masonry is regular
by nature, so a deterministic brick-course function produces cleaner and more
consistent results than ASCII would, and it makes the tile count cheap to grow.

Tile atlas layout is a 8-column grid of 16x16 tiles. The column/row of each tile
is recorded in TILE_INDEX and consumed by the TileSet builder in
src/core/tileset_builder.gd, so the two never drift apart.
"""

from __future__ import annotations

from pixelart import Atlas, Canvas, frame

TILE = 16
TILES_PER_ROW = 8

# Logical tile name -> atlas coordinate. Also exported to JSON for the engine.
TILE_INDEX: dict[str, tuple[int, int]] = {
    "brick_solid": (0, 0),
    "brick_top": (1, 0),
    "brick_top_left": (2, 0),
    "brick_top_right": (3, 0),
    "brick_left": (4, 0),
    "brick_right": (5, 0),
    "brick_bottom": (6, 0),
    "floor_stone": (7, 0),
    "platform": (0, 1),
    "pillar_top": (1, 1),
    "pillar_mid": (2, 1),
    "pillar_base": (3, 1),
    "bg_brick": (4, 1),
    "bg_arch": (5, 1),
    "bg_window": (6, 1),
    "spikes": (7, 1),
    "stair_right": (0, 2),
    "stair_left": (1, 2),
    "rubble": (2, 2),
    "bg_curtain": (3, 2),
    "mist_gate": (4, 2),
    "brick_cracked": (5, 2),
    "bg_dark": (6, 2),
    "iron_rail": (7, 2),
}


def _brick_course(c: Canvas, x0: int, y0: int, light: str, mid: str, dark: str,
                  mortar: str) -> None:
    """Fill a 16x16 tile with a two-course running-bond brick pattern."""
    c.rect(x0, y0, x0 + TILE - 1, y0 + TILE - 1, mid)
    for row in range(4):
        by = y0 + row * 4
        # Mortar line between courses.
        c.rect(x0, by + 3, x0 + TILE - 1, by + 3, mortar)
        # Alternate the vertical joint offset per course (running bond).
        offset = 0 if row % 2 == 0 else 8
        for j in (offset, offset + 8):
            jx = x0 + (j % TILE)
            c.rect(jx, by, jx, by + 2, mortar)
        # Top highlight and bottom shading on each brick face.
        c.rect(x0, by, x0 + TILE - 1, by, light)
        c.rect(x0, by + 2, x0 + TILE - 1, by + 2, dark)


def _tile_brick(variant: str = "solid") -> Canvas:
    c = Canvas(TILE, TILE)
    _brick_course(c, 0, 0, "L", "l", "j", "J")
    if variant in ("top", "top_left", "top_right"):
        # Lit upper lip where moonlight catches the ledge.
        c.rect(0, 0, TILE - 1, 0, "A")
        c.rect(0, 1, TILE - 1, 1, "L")
    if variant in ("top_left", "left"):
        c.rect(0, 0, 0, TILE - 1, "j")
        c.rect(1, 2, 1, TILE - 1, "l")
    if variant in ("top_right", "right"):
        c.rect(TILE - 1, 0, TILE - 1, TILE - 1, "j")
        c.rect(TILE - 2, 2, TILE - 2, TILE - 1, "l")
    if variant == "bottom":
        c.rect(0, TILE - 1, TILE - 1, TILE - 1, "J")
    if variant == "cracked":
        c.line(3, 1, 6, 7, "J")
        c.line(6, 7, 4, 13, "J")
        c.line(6, 7, 11, 10, "J")
        c.set(9, 3, (0, 0, 0, 255))
    return c


def _tile_floor_stone() -> Canvas:
    c = Canvas(TILE, TILE)
    c.rect(0, 0, TILE - 1, TILE - 1, "a")
    c.rect(0, 0, TILE - 1, 1, "A")
    c.rect(0, 2, TILE - 1, 2, "a")
    c.rect(0, TILE - 2, TILE - 1, TILE - 1, "o")
    for x in (0, 7, 15):
        c.rect(x, 3, x, TILE - 1, "o")
    c.rect(3, 6, 4, 6, "o")
    c.rect(11, 10, 12, 10, "o")
    return c


def _tile_platform() -> Canvas:
    """One-way platform: a timber plank on iron brackets."""
    c = Canvas(TILE, TILE)
    c.rect(0, 0, TILE - 1, 0, "B")
    c.rect(0, 1, TILE - 1, 3, "b")
    c.rect(0, 1, TILE - 1, 1, "B")
    for x in (2, 9):
        c.rect(x, 0, x, 3, "b")
    c.rect(1, 4, 2, 6, "N")
    c.rect(13, 4, 14, 6, "N")
    return c


def _tile_pillar(part: str) -> Canvas:
    c = Canvas(TILE, TILE)
    c.rect(3, 0, 12, TILE - 1, "a")
    c.rect(4, 0, 5, TILE - 1, "A")
    c.rect(10, 0, 12, TILE - 1, "o")
    if part == "top":
        c.rect(1, 0, 14, 3, "A")
        c.rect(1, 4, 14, 4, "o")
        c.rect(2, 1, 13, 1, "a")
    if part == "base":
        c.rect(1, TILE - 4, 14, TILE - 1, "A")
        c.rect(1, TILE - 4, 14, TILE - 4, "o")
        c.rect(2, TILE - 2, 13, TILE - 1, "a")
    return c


def _tile_bg(kind: str) -> Canvas:
    c = Canvas(TILE, TILE)
    if kind == "dark":
        c.rect(0, 0, TILE - 1, TILE - 1, "J")
        return c
    _brick_course(c, 0, 0, "l", "j", "J", "J")
    if kind == "arch":
        # Recessed gothic arch cut into the wall.
        c.rect(3, 4, 12, TILE - 1, "J")
        for i in range(5):
            c.rect(3 + i, 4 - 0 + (4 - i) // 2, 3 + i, 4, "J")
        c.line(3, 6, 7, 2, "j")
        c.line(8, 2, 12, 6, "j")
        c.rect(4, 5, 11, TILE - 1, "J")
    if kind == "window":
        # Moonlit lancet window — the main light source in the castle.
        c.rect(4, 2, 11, TILE - 1, "U")
        c.rect(5, 3, 10, TILE - 1, "i")
        c.rect(6, 5, 9, TILE - 1, "I")
        c.line(4, 4, 7, 1, "j")
        c.line(8, 1, 11, 4, "j")
        c.rect(7, 2, 8, TILE - 1, "U")
        c.rect(4, 8, 11, 8, "U")
    if kind == "curtain":
        c.rect(0, 0, TILE - 1, TILE - 1, "q")
        for x in range(0, TILE, 4):
            c.rect(x, 0, x, TILE - 1, "r")
            c.rect(x + 2, 0, x + 2, TILE - 1, "q")
        c.rect(0, 0, TILE - 1, 1, "R")
    return c


def _tile_spikes() -> Canvas:
    c = Canvas(TILE, TILE)
    for base in (0, 5, 10):
        for i in range(5):
            c.rect(base + i, TILE - 1 - (4 - abs(i - 2) * 2), base + i, TILE - 1, "m")
        c.rect(base + 2, TILE - 6, base + 2, TILE - 1, "M")
    c.rect(0, TILE - 2, TILE - 1, TILE - 1, "N")
    return c


def _tile_stair(direction: str) -> Canvas:
    """Diagonal stair block. Castlevania-style stairs are traversal, not collision."""
    c = Canvas(TILE, TILE)
    for step in range(4):
        sy = TILE - 4 * (step + 1)
        sx = step * 4 if direction == "right" else TILE - 4 * (step + 1)
        c.rect(sx, sy, sx + 3, sy + 3, "a")
        c.rect(sx, sy, sx + 3, sy, "A")
        c.rect(sx, sy + 3, sx + 3, sy + 3, "o")
    return c


def _tile_rubble() -> Canvas:
    c = Canvas(TILE, TILE)
    c.rect(0, TILE - 5, TILE - 1, TILE - 1, "j")
    for x, y, w in ((1, 10, 3), (6, 9, 4), (12, 11, 3), (3, 12, 5)):
        c.rect(x, y, x + w, y + 2, "l")
        c.rect(x, y, x + w, y, "L")
    return c


def _tile_mist_gate() -> Canvas:
    """Visual marker for a mist-dash-only passage."""
    c = Canvas(TILE, TILE)
    c.rect(0, 0, TILE - 1, TILE - 1, "U")
    for y in range(0, TILE, 2):
        c.rect(0, y, TILE - 1, y, "i")
    for x in (2, 7, 12):
        c.rect(x, 0, x, TILE - 1, "I")
    return c


def _tile_iron_rail() -> Canvas:
    c = Canvas(TILE, TILE)
    c.rect(0, 2, TILE - 1, 3, "N")
    c.rect(0, 2, TILE - 1, 2, "m")
    for x in (2, 8, 14):
        c.rect(x, 4, x, TILE - 1, "N")
    return c


def build_tileset() -> tuple[Canvas, dict[str, tuple[int, int]]]:
    """Render every tile into one atlas image."""
    builders = {
        "brick_solid": lambda: _tile_brick("solid"),
        "brick_top": lambda: _tile_brick("top"),
        "brick_top_left": lambda: _tile_brick("top_left"),
        "brick_top_right": lambda: _tile_brick("top_right"),
        "brick_left": lambda: _tile_brick("left"),
        "brick_right": lambda: _tile_brick("right"),
        "brick_bottom": lambda: _tile_brick("bottom"),
        "brick_cracked": lambda: _tile_brick("cracked"),
        "floor_stone": _tile_floor_stone,
        "platform": _tile_platform,
        "pillar_top": lambda: _tile_pillar("top"),
        "pillar_mid": lambda: _tile_pillar("mid"),
        "pillar_base": lambda: _tile_pillar("base"),
        "bg_brick": lambda: _tile_bg("brick"),
        "bg_arch": lambda: _tile_bg("arch"),
        "bg_window": lambda: _tile_bg("window"),
        "bg_curtain": lambda: _tile_bg("curtain"),
        "bg_dark": lambda: _tile_bg("dark"),
        "spikes": _tile_spikes,
        "stair_right": lambda: _tile_stair("right"),
        "stair_left": lambda: _tile_stair("left"),
        "rubble": _tile_rubble,
        "mist_gate": _tile_mist_gate,
        "iron_rail": _tile_iron_rail,
    }
    rows = max(coord[1] for coord in TILE_INDEX.values()) + 1
    sheet = Canvas(TILE * TILES_PER_ROW, TILE * rows)
    for name, (cx, cy) in TILE_INDEX.items():
        if name not in builders:
            raise KeyError(f"TILE_INDEX lists '{name}' but no builder exists for it")
        sheet.blit(builders[name](), cx * TILE, cy * TILE)
    return sheet, TILE_INDEX


# ---------------------------------------------------------------------------
# Props, pickups and projectiles — all 16x16 unless noted.
# ---------------------------------------------------------------------------

TORCH = [
    "......yY........",
    ".....yYYx.......",
    "....xYYYYy......",
    "....xyYYYx......",
    ".....xyyx.......",
    "......xx........",
    ".....GGGG.......",
    ".....gGGg.......",
    ".....gGGg.......",
    "......gg........",
    "......NN........",
    "......Nm........",
    "................",
    "................",
    "................",
    "................",
]

CANDLE = [
    "................",
    "................",
    "......yY........",
    ".....xYYy.......",
    ".....xyyx.......",
    "......xx........",
    "......##........",
    "......##........",
    ".....####.......",
    ".....#--#.......",
    "......--........",
    "................",
    "................",
    "................",
    "................",
    "................",
]

HEART_PICKUP = [
    "................",
    "................",
    "....RR..RR......",
    "...RRRRRRRR.....",
    "..RRRRRRRRRR....",
    "..RRRRRRRRRR....",
    "..rRRRRRRRRr....",
    "...rRRRRRRr.....",
    "....rRRRRr......",
    ".....rRRr.......",
    "......rr........",
    "................",
    "................",
    "................",
    "................",
    "................",
]

HP_ORB = [
    "................",
    ".....IIII.......",
    "....IIIIII......",
    "...III##III.....",
    "...II####II.....",
    "...II####II.....",
    "...IIIIIIII.....",
    "....IIIIII......",
    ".....IIII.......",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]

GOLD_PICKUP = [
    "................",
    "................",
    ".....GGGG.......",
    "....GGggGG......",
    "....GgGGgG......",
    "....GgGGgG......",
    "....GGggGG......",
    ".....GGGG.......",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]

DAGGER = [
    "................",
    "................",
    "................",
    "................",
    "..B..MMMMMMMM...",
    ".BBBBMMMMMMMMM..",
    "..B..MMMMMMMM...",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]

AXE = [
    "................",
    "................",
    "....MMMM........",
    "...MMMMMM.......",
    "..MMMmmMMM......",
    "..MMm..mMM......",
    "..MMm..mMM..B...",
    "..MMMmmMMMBB....",
    "...MMMMMMB......",
    "....MMMMB.......",
    "......BB........",
    ".....BB.........",
    "................",
    "................",
    "................",
    "................",
]

HOLY_WATER = [
    "................",
    "................",
    "................",
    "......II........",
    ".....IIII.......",
    "....IIiiII......",
    "....IiUUiI......",
    "....IiUUiI......",
    "....IIiiII......",
    ".....IIII.......",
    "......II........",
    "................",
    "................",
    "................",
    "................",
    "................",
]

BONE_PROJECTILE = [
    "................",
    "................",
    "................",
    "................",
    "....WW....WW....",
    "...WwwWWWWwwW...",
    "...WwwWWWWwwW...",
    "....WW....WW....",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]

SAVE_COFFIN = [
    "................",
    "......GGGG......",
    ".....GddddG.....",
    "....GdddddddG...",
    "....GdCCCCCdG...",
    "....GdCRRRCdG...",
    "....GdCRRRCdG...",
    "....GdCRRRCdG...",
    "....GdCCCCCdG...",
    "....GdddddddG...",
    "....GdddddddG...",
    ".....GddddG.....",
    "......GGGG......",
    "................",
    "................",
    "................",
]

RELIC_PEDESTAL = [
    "................",
    "................",
    "................",
    "......II........",
    ".....IIII.......",
    "....II##II......",
    "....I####I......",
    ".....IIII.......",
    "......II........",
    "....AAAAAA......",
    "...AaaaaaaA.....",
    "...Aa....aA.....",
    "..AAAAAAAAAA....",
    "..AaaaaaaaaA....",
    "..oooooooooo....",
    "................",
]


def _prop(rows: list[str]) -> Canvas:
    return Canvas.from_ascii(rows)


def build_props() -> Atlas:
    """16x16 world props and pickups, each with a gentle idle animation."""
    atlas = Atlas(16, 16)
    torch = _prop(TORCH)
    atlas.add_anim(
        "torch",
        [torch, torch.shifted(0, -1), torch, _prop(TORCH).shifted(1, 0)],
        fps=8.0,
    )
    candle = _prop(CANDLE)
    atlas.add_anim("candle", [candle, candle.shifted(0, -1)], fps=6.0)
    heart = _prop(HEART_PICKUP)
    atlas.add_anim("heart", [heart, heart.shifted(0, -1)], fps=4.0)
    orb = _prop(HP_ORB)
    atlas.add_anim("hp_orb", [orb, orb.shifted(0, -1)], fps=4.0)
    gold = _prop(GOLD_PICKUP)
    atlas.add_anim("gold", [gold, gold.shifted(0, -1)], fps=4.0)
    atlas.add_anim("dagger", [_prop(DAGGER)], fps=1.0)
    axe = _prop(AXE)
    atlas.add_anim("axe", [axe, axe.flipped_h()], fps=12.0)
    water = _prop(HOLY_WATER)
    atlas.add_anim("holy_water", [water, water.shifted(0, -1)], fps=10.0)
    bone = _prop(BONE_PROJECTILE)
    atlas.add_anim("bone", [bone, bone.flipped_h()], fps=12.0)
    coffin = _prop(SAVE_COFFIN)
    atlas.add_anim("save_coffin", [coffin, coffin.shifted(0, -1)], fps=2.0)
    pedestal = _prop(RELIC_PEDESTAL)
    atlas.add_anim("relic", [pedestal, pedestal.shifted(0, -1)], fps=3.0)
    return atlas


# ---------------------------------------------------------------------------
# VFX — impact sparks, mist trail, flame burst, soul wisp.
# ---------------------------------------------------------------------------


def _spark(radius: int, glyph_outer: str, glyph_inner: str) -> Canvas:
    """A four-point star burst, drawn analytically so it scales cleanly."""
    c = Canvas(24, 24)
    cx = cy = 12
    for i in range(radius):
        t = i / max(1, radius - 1)
        g = glyph_inner if t < 0.45 else glyph_outer
        c.rect(cx + i, cy, cx + i, cy, g)
        c.rect(cx - i, cy, cx - i, cy, g)
        c.rect(cx, cy + i, cx, cy + i, g)
        c.rect(cx, cy - i, cx, cy - i, g)
        d = int(i * 0.7)
        if d:
            c.rect(cx + d, cy + d, cx + d, cy + d, g)
            c.rect(cx - d, cy + d, cx - d, cy + d, g)
            c.rect(cx + d, cy - d, cx + d, cy - d, g)
            c.rect(cx - d, cy - d, cx - d, cy - d, g)
    return c


def build_vfx() -> Atlas:
    atlas = Atlas(24, 24)
    atlas.add_anim(
        "hit_spark",
        [_spark(3, "Y", "#"), _spark(6, "y", "Y"), _spark(9, "x", "y"), _spark(11, "q", "x")],
        fps=24.0,
        loop=False,
    )
    atlas.add_anim(
        "blood",
        [_spark(3, "R", "#"), _spark(6, "R", "R"), _spark(9, "r", "R"), _spark(11, "q", "r")],
        fps=22.0,
        loop=False,
    )
    atlas.add_anim(
        "mist",
        [_spark(4, "U", "I"), _spark(7, "U", "i"), _spark(10, "U", "U"), _spark(12, "U", "U")],
        fps=20.0,
        loop=False,
    )
    atlas.add_anim(
        "soul",
        [_spark(2, "I", "#"), _spark(5, "i", "I"), _spark(8, "U", "i"), _spark(10, "U", "U")],
        fps=14.0,
        loop=False,
    )
    return atlas


# ---------------------------------------------------------------------------
# UI — touch controls, HUD frames, icons.
# ---------------------------------------------------------------------------


def _round_button(size: int, fill: str, edge: str, glyph_rows: list[str] | None = None) -> Canvas:
    """A soft-cornered circular button plate for the on-screen controls."""
    c = Canvas(size, size)
    r = size // 2
    cx = cy = r
    for y in range(size):
        for x in range(size):
            d2 = (x - cx + 0.5) ** 2 + (y - cy + 0.5) ** 2
            if d2 <= (r - 0.5) ** 2:
                c.rect(x, y, x, y, edge if d2 > (r - 2.5) ** 2 else fill)
    if glyph_rows:
        art = Canvas.from_ascii(glyph_rows)
        c.blit(art, (size - art.w) // 2, (size - art.h) // 2)
    return c


ICON_SWORD = [
    "....MM..",
    "...MMM..",
    "..MMM...",
    ".MMM.G..",
    "MMM.GG..",
    "MM.GGG..",
    "M.G..B..",
    "....BB..",
]

ICON_JUMP = [
    "...##...",
    "..####..",
    ".##..##.",
    "##....##",
    "...##...",
    "...##...",
    "...##...",
    "...##...",
]

ICON_FLASK = [
    "..####..",
    "...##...",
    "...##...",
    "..####..",
    ".##II##.",
    "##IIII##",
    "##IIII##",
    ".######.",
]

ICON_DASH = [
    "........",
    ".#...##.",
    "..#..##.",
    "...#.##.",
    "####.##.",
    "...#.##.",
    "..#..##.",
    ".#...##.",
]

ICON_PAUSE = [
    "........",
    ".##..##.",
    ".##..##.",
    ".##..##.",
    ".##..##.",
    ".##..##.",
    ".##..##.",
    "........",
]

ICON_MAP = [
    "........",
    ".######.",
    ".#--#-#.",
    ".#-##-#.",
    ".#-##-#.",
    ".#--#-#.",
    ".######.",
    "........",
]

ARROW_GLYPH = [
    "...##...",
    "..####..",
    ".##..##.",
    "##....##",
    "..####..",
    "..####..",
    "..####..",
    "..####..",
]


def build_ui() -> dict[str, Canvas]:
    """Discrete UI images, saved as individual PNGs rather than an atlas."""
    out: dict[str, Canvas] = {}

    out["btn_attack"] = _round_button(40, "C", "c", ICON_SWORD)
    out["btn_jump"] = _round_button(40, "C", "c", ICON_JUMP)
    out["btn_subweapon"] = _round_button(32, "d", "C", ICON_FLASK)
    out["btn_dash"] = _round_button(32, "d", "C", ICON_DASH)
    out["btn_pause"] = _round_button(24, "d", "C", ICON_PAUSE)
    out["btn_map"] = _round_button(24, "d", "C", ICON_MAP)

    # D-pad: a rounded plate plus a directional arrow per face.
    pad = _round_button(56, "d", "C")
    for i, (name, rot) in enumerate(
        (("up", 0), ("right", 1), ("down", 2), ("left", 3))
    ):
        arrow = Canvas.from_ascii(ARROW_GLYPH)
        for _ in range(rot):
            # Rotate 90° clockwise by transposing then flipping.
            rotated = Canvas(arrow.h, arrow.w)
            for y in range(arrow.h):
                for x in range(arrow.w):
                    rotated.px[x][arrow.h - 1 - y] = arrow.px[y][x]
            arrow = rotated
        plate = _round_button(24, "C", "c")
        plate.blit(arrow, (24 - arrow.w) // 2, (24 - arrow.h) // 2)
        out[f"dpad_{name}"] = plate
    out["dpad_base"] = pad

    # HUD bar frames — 9-patch friendly: 3px border, flat centre.
    for name, fill, edge in (
        ("bar_hp", "R", "q"),
        ("bar_mp", "i", "U"),
        ("bar_boss", "r", "q"),
    ):
        bar = Canvas(64, 8)
        bar.rect(0, 0, 63, 7, "K")
        bar.rect(1, 1, 62, 6, edge)
        bar.rect(2, 2, 61, 5, fill)
        bar.rect(2, 2, 61, 2, "#")
        out[name] = bar

    frame_bg = Canvas(64, 8)
    frame_bg.rect(0, 0, 63, 7, "K")
    frame_bg.rect(1, 1, 62, 6, "j")
    out["bar_frame"] = frame_bg

    # Map cell art: an explored room chip and the "you are here" marker.
    cell = Canvas(12, 10)
    cell.rect(0, 0, 11, 9, "U")
    cell.rect(1, 1, 10, 8, "i")
    out["map_cell"] = cell

    unknown = Canvas(12, 10)
    unknown.rect(0, 0, 11, 9, "j")
    out["map_unknown"] = unknown

    here = Canvas(12, 10)
    here.rect(0, 0, 11, 9, "R")
    here.rect(2, 2, 9, 7, "#")
    out["map_here"] = here

    save_cell = Canvas(12, 10)
    save_cell.rect(0, 0, 11, 9, "U")
    save_cell.rect(1, 1, 10, 8, "i")
    save_cell.rect(4, 3, 7, 6, "G")
    out["map_save"] = save_cell

    # Application icon — the crimson moon over a castle silhouette.
    icon = Canvas(64, 64)
    icon.rect(0, 0, 63, 63, "J")
    for y in range(64):
        for x in range(64):
            if (x - 40) ** 2 + (y - 20) ** 2 <= 13 * 13:
                icon.rect(x, y, x, y, "R")
            elif (x - 40) ** 2 + (y - 20) ** 2 <= 15 * 15:
                icon.rect(x, y, x, y, "r")
    for x0, top in ((6, 40), (14, 32), (24, 44), (34, 36), (46, 30), (56, 42)):
        icon.rect(x0, top, x0 + 7, 63, "d")
        icon.rect(x0, top, x0 + 7, top, "C")
    icon.rect(0, 60, 63, 63, "K")
    out["icon"] = icon

    return out


def _tower(c: Canvas, x0: int, top: int, width: int, bottom: int, body: str,
           trim: str, lit_windows: bool) -> None:
    """Draw one crenellated tower silhouette."""
    c.rect(x0, top, x0 + width, bottom, body)
    # Merlons along the top.
    for m in range(0, width + 1, 8):
        c.rect(x0 + m, top - 6, x0 + min(m + 4, width), top, body)
    c.rect(x0, top, x0 + width, top, trim)
    if not lit_windows:
        return
    # Sparse and dim on purpose: a distant window that reads as brightly as a
    # platform the player can stand on turns the backdrop into visual noise.
    for i, wy in enumerate(range(top + 18, bottom, 44)):
        if i % 2:
            continue
        c.rect(x0 + 5, wy, x0 + 7, wy + 5, "x")


def build_parallax_sky(width: int = 480, height: int = 270) -> Canvas:
    """Farthest layer: banded night sky and the crimson moon.

    Deliberately not tileable — it is drawn with `mirroring` disabled and a very
    low scroll scale, so it behaves as a fixed backdrop.
    """
    c = Canvas(width, height)
    bands = ["J", "j", "d", "C", "d", "j"]
    band_h = height // len(bands) + 1
    for i, glyph in enumerate(bands):
        c.rect(0, i * band_h, width - 1, min((i + 1) * band_h - 1, height - 1), glyph)

    moon_x, moon_y = int(width * 0.74), int(height * 0.24)
    for y in range(height):
        for x in range(width):
            d2 = (x - moon_x) ** 2 + (y - moon_y) ** 2
            if d2 <= 30 * 30:
                c.rect(x, y, x, y, "R")
            elif d2 <= 36 * 36:
                c.rect(x, y, x, y, "r")
            elif d2 <= 44 * 44:
                c.rect(x, y, x, y, "q")

    # Sparse stars, placed on a deterministic lattice so regeneration is stable.
    for i in range(34):
        sx = (i * 97 + 31) % width
        sy = (i * 53 + 17) % (height // 2)
        if (sx - moon_x) ** 2 + (sy - moon_y) ** 2 < 60 * 60:
            continue
        c.rect(sx, sy, sx, sy, "n" if i % 3 else "-")
    return c


def build_parallax_far(width: int = 480, height: int = 270) -> Canvas:
    """Middle layer: distant castle skyline, horizontally tileable.

    The first and last towers are placed so the seam falls in open sky, which is
    what lets the layer repeat without a visible join.
    """
    c = Canvas(width, height)
    towers = [
        (14, 150, 30), (58, 118, 26), (100, 162, 34), (150, 96, 30),
        (200, 138, 26), (244, 88, 34), (300, 142, 30), (348, 112, 26),
        (392, 158, 34), (444, 130, 24),
    ]
    for x0, top, w in towers:
        _tower(c, x0, top, w, height - 1, "j", "d", True)
    # Curtain wall tying the towers together along the bottom.
    c.rect(0, 208, width - 1, height - 1, "j")
    c.rect(0, 208, width - 1, 209, "d")
    return c


def build_parallax_near(width: int = 480, height: int = 270) -> Canvas:
    """Nearest layer: dark foreground spires and a fog band."""
    c = Canvas(width, height)
    for x0, top, w in ((-6, 176, 34), (86, 196, 28), (196, 168, 36),
                       (300, 200, 30), (410, 182, 38)):
        _tower(c, max(0, x0), top, w, height - 1, "J", "j", False)
    c.rect(0, 236, width - 1, height - 1, "J")
    # Banded fog, lightest at the top so it reads as depth rather than a wall.
    for i, y in enumerate(range(220, height, 5)):
        c.rect(0, y, width - 1, y + 1, "j" if i % 2 else "d")
    return c


def build_title_banner() -> Canvas:
    """Title-screen backdrop: moon, castle silhouette, fog bands."""
    c = Canvas(480, 270)
    # Night sky gradient, banded to stay in palette.
    bands = ["J", "j", "d", "C"]
    for i, g in enumerate(bands):
        c.rect(0, i * 34, 479, (i + 1) * 34 - 1, g)
    c.rect(0, 136, 479, 269, "J")
    # Crimson moon.
    for y in range(270):
        for x in range(480):
            d2 = (x - 360) ** 2 + (y - 70) ** 2
            if d2 <= 34 * 34:
                c.rect(x, y, x, y, "R")
            elif d2 <= 40 * 40:
                c.rect(x, y, x, y, "r")
            elif d2 <= 46 * 46:
                c.rect(x, y, x, y, "q")
    # Castle silhouette.
    towers = [
        (20, 150), (60, 120), (110, 165), (150, 100), (205, 135),
        (250, 90), (300, 140), (350, 115), (400, 160), (440, 130),
    ]
    for x0, top in towers:
        c.rect(x0, top, x0 + 34, 269, "K")
        for merlon in range(0, 35, 8):
            c.rect(x0 + merlon, top - 6, x0 + merlon + 4, top, "K")
    c.rect(0, 200, 479, 269, "K")
    # Lit windows.
    for x0, top in towers:
        for wy in range(top + 16, 260, 26):
            c.rect(x0 + 10, wy, x0 + 13, wy + 6, "y")
            c.rect(x0 + 22, wy + 10, x0 + 25, wy + 16, "y")
    # Fog bands.
    for y in range(230, 270, 6):
        c.rect(0, y, 479, y + 1, "d")
    return c
