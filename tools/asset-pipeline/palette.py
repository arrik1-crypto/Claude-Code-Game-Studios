"""Crimson Vespers — master colour palette.

Single source of truth for every generated placeholder sprite. Each glyph maps
to an RGBA tuple; '.' is always fully transparent.

The palette is deliberately small and moonlit: desaturated violets for stone and
cloth, a narrow warm ramp for skin and gold, and one saturated crimson reserved
for the player's sash, blood VFX and the boss. Keeping crimson scarce is what
makes it read as "important" on a small mobile screen.

See design/art-bible.md for the reasoning behind each ramp.
"""

T = (0, 0, 0, 0)


def _c(hex_str: str, alpha: int = 255) -> tuple[int, int, int, int]:
    """Convert '#rrggbb' to an RGBA tuple."""
    h = hex_str.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), alpha)


PALETTE: dict[str, tuple[int, int, int, int]] = {
    ".": T,
    # --- Universal outline -------------------------------------------------
    "K": _c("#14101f"),   # outline / darkest
    "k": _c("#241d33"),   # soft outline, used inside silhouettes
    # --- Skin --------------------------------------------------------------
    "S": _c("#f0cfa8"),   # skin light
    "s": _c("#c69670"),   # skin mid
    "z": _c("#8d6249"),   # skin shadow
    # --- Hair (silver-white) ----------------------------------------------
    "H": _c("#f2f4fb"),
    "h": _c("#c3cadd"),
    "n": _c("#8e97b3"),
    # --- Coat (violet) -----------------------------------------------------
    "c": _c("#5b477f"),   # coat light
    "C": _c("#3d2d5c"),   # coat mid
    "d": _c("#261a3c"),   # coat dark
    # --- Crimson -----------------------------------------------------------
    "R": _c("#d33449"),
    "r": _c("#8e1b2c"),
    "q": _c("#54101c"),
    # --- Leather / boots ---------------------------------------------------
    "B": _c("#4a3626"),
    "b": _c("#2a1d14"),
    # --- Metal / steel -----------------------------------------------------
    "M": _c("#dbe1ec"),
    "m": _c("#98a2b8"),
    "N": _c("#5f6880"),
    # --- Gold --------------------------------------------------------------
    "G": _c("#f0cd72"),
    "g": _c("#a67c2c"),
    # --- Bone --------------------------------------------------------------
    "W": _c("#ece7d6"),
    "w": _c("#b3ac96"),
    "v": _c("#7a7460"),
    # --- Undead flesh (green) ---------------------------------------------
    "E": _c("#7d9560"),
    "e": _c("#55663f"),
    "F": _c("#39452a"),
    # --- Bat / shadow creature --------------------------------------------
    "P": _c("#5d3b68"),
    "p": _c("#3a2343"),
    "u": _c("#221328"),
    # --- Stone (tiles, medusa) --------------------------------------------
    "A": _c("#7f869a"),
    "a": _c("#5a6072"),
    "o": _c("#3b4050"),
    # --- Castle brick ------------------------------------------------------
    "L": _c("#4a4265"),   # brick light
    "l": _c("#372f4d"),   # brick mid
    "j": _c("#251f38"),   # brick dark
    "J": _c("#171326"),   # mortar / deep shadow
    # --- Flame / light -----------------------------------------------------
    "Y": _c("#ffe9a8"),
    "y": _c("#f2a63c"),
    "x": _c("#c25320"),
    # --- Moonlight / magic -------------------------------------------------
    "I": _c("#bfe6ff"),
    "i": _c("#6f9fd8"),
    "U": _c("#3d5f96"),
    # --- Pure white / UI ---------------------------------------------------
    "#": _c("#ffffff"),
    "-": _c("#9aa0b5"),
    "_": _c("#000000"),
}


def rgba(glyph: str) -> tuple[int, int, int, int]:
    """Look up a palette glyph, raising a helpful error for typos."""
    if glyph not in PALETTE:
        raise KeyError(
            f"Unknown palette glyph {glyph!r}. Add it to palette.PALETTE first."
        )
    return PALETTE[glyph]
