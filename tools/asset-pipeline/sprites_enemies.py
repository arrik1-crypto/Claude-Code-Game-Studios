"""Castle Vhorn bestiary — enemy placeholder sprites.

All poses face RIGHT; the engine flips for left-facing. Each builder returns an
Atlas so the runtime loader can construct SpriteFrames from a single manifest.
"""

from __future__ import annotations

from pixelart import Atlas, Canvas, frame

E_W = 32
E_H = 32


def _place(rows: list[str], w: int = E_W, h: int = E_H, dx: int = 0, dy: int = 0) -> Canvas:
    """Centre a pose horizontally in the frame with feet near the bottom."""
    art = Canvas.from_ascii(rows)
    x = (w - art.w) // 2 + dx
    y = h - art.h - 1 + dy
    return frame(w, h, [(art, x, y)])


# ---------------------------------------------------------------------------
# Bone Sentry — patrolling skeleton, throws bones at range.
# ---------------------------------------------------------------------------

SENTRY_IDLE = [
    "....WWWWWW....",
    "...WWWWWWWW...",
    "..WWKKWWKKWW..",
    "..WWKKWWKKWW..",
    "..WWWWWWWWWW..",
    "...WKWKWKWW...",
    "....WWWWWW....",
    ".....wWWw.....",
    "..mMWWWWWMm...",
    ".mMMWWWWWMMm..",
    ".mMWWwwwwWMm..",
    "..wWWwwwwWWw..",
    "..wWw.WW.wWw..",
    "...W..WW..W...",
    "......WW......",
    ".....WWWW.....",
    ".....W..W.....",
    ".....W..W.....",
    "....WW..WW....",
    "....Ww..wW....",
    "...WWw..wWW...",
    "...ww....ww...",
]

SENTRY_WALK = [
    "....WWWWWW....",
    "...WWWWWWWW...",
    "..WWKKWWKKWW..",
    "..WWKKWWKKWW..",
    "..WWWWWWWWWW..",
    "...WKWKWKWW...",
    "....WWWWWW....",
    ".....wWWw.....",
    "..mMWWWWWMm...",
    ".mMMWWWWWMMm..",
    ".mMWWwwwwWMm..",
    "..wWWwwwwWWw..",
    "..wWw.WW.wWw..",
    "...W..WW..W...",
    "......WW......",
    ".....WWWW.....",
    "....WW..WW....",
    "...WW....WW...",
    "..WW......WW..",
    "..Ww......wW..",
    ".WWw......wWW.",
    ".ww........ww.",
]

SENTRY_THROW = [
    "....WWWWWW....",
    "...WWWWWWWW...",
    "..WWKKWWKKWW..",
    "..WWKKWWKKWW..",
    "..WWWWWWWWWW..",
    "...WKWKWKWW...",
    "....WWWWWW....",
    ".....wWWw..W..",
    "..mMWWWWWMWW..",
    ".mMMWWWWWMWm..",
    ".mMWWwwwwWMm..",
    "..wWWwwwwWWw..",
    "..wWw.WW.wWw..",
    "...W..WW......",
    "......WW......",
    ".....WWWW.....",
    ".....W..W.....",
    ".....W..W.....",
    "....WW..WW....",
    "....Ww..wW....",
    "...WWw..wWW...",
    "...ww....ww...",
]

SENTRY_BREAK = [
    "..............",
    "..............",
    "..............",
    "...W..WW..W...",
    "..WWKKWWKKW...",
    "...WWWWWWW....",
    "....wWWWw.....",
    "..W..wWw..W...",
    ".WWw.....wWW..",
    "..wW.WWW.Ww...",
    "...w.WWW.w....",
    "....wwwww.....",
    "..w...w...w...",
    ".ww..www..ww..",
    "..............",
    "..............",
    "..............",
    "..............",
    "..............",
    "..............",
    "..............",
    "..............",
]


def build_bone_sentry() -> Atlas:
    atlas = Atlas(E_W, E_H)
    atlas.add_anim("idle", [_place(SENTRY_IDLE), _place(SENTRY_IDLE, dy=-1)], fps=3.0)
    atlas.add_anim(
        "walk",
        [_place(SENTRY_WALK), _place(SENTRY_IDLE), _place(SENTRY_WALK, dy=-1), _place(SENTRY_IDLE)],
        fps=7.0,
    )
    atlas.add_anim("attack", [_place(SENTRY_THROW)] * 2 + [_place(SENTRY_IDLE)], fps=8.0, loop=False)
    atlas.add_anim("hurt", [_place(SENTRY_IDLE, dx=-1)], fps=1.0, loop=False)
    atlas.add_anim("death", [_place(SENTRY_BREAK), _place(SENTRY_BREAK, dy=2)], fps=6.0, loop=False)
    return atlas


# ---------------------------------------------------------------------------
# Nightwing — swooping bat.
# ---------------------------------------------------------------------------

BAT_WINGS_UP = [
    "..pp........pp..",
    ".pPPp......pPPp.",
    "pPPPPp....pPPPPp",
    "pPPPPPp..pPPPPPp",
    ".pPPPPPppPPPPPp.",
    "..pPPPuPPuPPPp..",
    "....pPRPPRPp....",
    ".....pPPPPp.....",
    "......pupu......",
    ".......pp.......",
    "................",
    "................",
]

BAT_WINGS_MID = [
    "................",
    "................",
    "pp............pp",
    "pPPp........pPPp",
    "pPPPPpp..ppPPPPp",
    ".pPPPPPuPPPPPPp.",
    "..pPPPuPPuPPPp..",
    "....pPRPPRPp....",
    ".....pPPPPp.....",
    "......pupu......",
    ".......pp.......",
    "................",
]

BAT_WINGS_DOWN = [
    "................",
    "................",
    "................",
    "......pupu......",
    "....pPPPPPPp....",
    "...pPRPPPPRPp...",
    "..pPPPPuuPPPPp..",
    ".pPPPPPPPPPPPPp.",
    "pPPPPp....pPPPPp",
    "pPPp........pPPp",
    "pp............pp",
    "................",
]

BAT_HANG = [
    ".......pp.......",
    "......pupu......",
    ".....pPPPPp.....",
    "....pPRPPRPp....",
    "..pPPPuPPuPPPp..",
    ".pPPPPPppPPPPPp.",
    "pPPPPPp..pPPPPPp",
    "pPPPPp....pPPPPp",
    ".pPPp......pPPp.",
    "..pp........pp..",
    "................",
    "................",
]


def build_nightwing() -> Atlas:
    atlas = Atlas(E_W, E_H)
    flap = [
        _place(BAT_WINGS_UP, dy=-10),
        _place(BAT_WINGS_MID, dy=-10),
        _place(BAT_WINGS_DOWN, dy=-10),
        _place(BAT_WINGS_MID, dy=-10),
    ]
    atlas.add_anim("fly", flap, fps=14.0)
    atlas.add_anim("idle", [_place(BAT_HANG, dy=-10)], fps=1.0)
    atlas.add_anim("attack", flap, fps=20.0)
    atlas.add_anim("hurt", [_place(BAT_WINGS_MID, dy=-10, dx=-1)], fps=1.0, loop=False)
    atlas.add_anim(
        "death",
        [_place(BAT_WINGS_DOWN, dy=-8), _place(BAT_WINGS_DOWN, dy=-4)],
        fps=8.0,
        loop=False,
    )
    return atlas


# ---------------------------------------------------------------------------
# Gravewalker — slow, tanky shambling corpse.
# ---------------------------------------------------------------------------

WALKER_A = [
    "....EEEEEE....",
    "...EEeeeeEE...",
    "..EEKEEEKEE...",
    "..EEEEEEEEE...",
    "..EEeEEEeEE...",
    "...EEeeeeE....",
    "....EEEEE.....",
    "...FeeeeeF....",
    "..FddEEEddF...",
    ".FdddEEEdddF..",
    ".FddEEEEEddF..",
    ".EddEEEEEddE..",
    ".Ee.dEEEd.eE..",
    "....dEEEd.....",
    "....EE.EE.....",
    "....EE.EE.....",
    "....ee.ee.....",
    "...FEe.eEF....",
    "...bbb.bbb....",
    "..bbbb.bbbb...",
]

WALKER_B = [
    "....EEEEEE....",
    "...EEeeeeEE...",
    "..EEKEEEKEE...",
    "..EEEEEEEEE...",
    "..EEeEEEeEE...",
    "...EEeeeeE....",
    "....EEEEE.....",
    "...FeeeeeF....",
    "..FddEEEddF...",
    ".FdddEEEdddF..",
    ".FddEEEEEddF..",
    ".EddEEEEEddE..",
    ".Ee.dEEEd.eE..",
    "....dEEEd.....",
    "...EE...EE....",
    "..EE.....EE...",
    "..ee.....ee...",
    ".FEe.....eEF..",
    ".bbb.....bbb..",
    "bbbb.....bbbb.",
]

WALKER_DEATH = [
    "..............",
    "..............",
    "..............",
    "..............",
    "..............",
    "..............",
    "..............",
    "..............",
    "..EEEEE.......",
    ".EEKEEKE......",
    ".EEeeeeE..FF..",
    "..EEEEE.FddF..",
    "...eeeFdddddF.",
    "..FddddEEEddF.",
    ".FdddEEEEEdddF",
    ".FddEEEEEEEddF",
    "..FeeEEEEEeeF.",
    "...bb.....bb..",
    "..............",
    "..............",
]


def build_gravewalker() -> Atlas:
    atlas = Atlas(E_W, E_H)
    atlas.add_anim("idle", [_place(WALKER_A), _place(WALKER_A, dy=-1)], fps=2.0)
    atlas.add_anim(
        "walk",
        [_place(WALKER_A), _place(WALKER_B), _place(WALKER_A, dy=-1), _place(WALKER_B)],
        fps=4.0,
    )
    atlas.add_anim("attack", [_place(WALKER_B, dx=1)], fps=4.0, loop=False)
    atlas.add_anim("hurt", [_place(WALKER_A, dx=-1)], fps=1.0, loop=False)
    atlas.add_anim("death", [_place(WALKER_DEATH), _place(WALKER_DEATH, dy=1)], fps=5.0, loop=False)
    return atlas


# ---------------------------------------------------------------------------
# Medusa Head — sine-wave drifting stone head. The classic knock-you-off-a-ledge
# hazard; deliberately fragile but relentless.
# ---------------------------------------------------------------------------

MEDUSA_A = [
    "..a..a..a.a...",
    ".aAa.aAa.aAa..",
    "..aAaaAaaAa...",
    "...aAAAAAa....",
    "..aAAAAAAAa...",
    ".aAAKAAAKAAa..",
    ".aAAAAAAAAAa..",
    ".aAAAaaaAAAa..",
    "..aAAAAAAAa...",
    "...aaAAAaa....",
    "....aaaaa.....",
    "..............",
]

MEDUSA_B = [
    "...a..a..a.a..",
    "..aAa.aAa.aAa.",
    "...aAaaAaaAa..",
    "...aAAAAAa....",
    "..aAAAAAAAa...",
    ".aAAKAAAKAAa..",
    ".aAAAAAAAAAa..",
    ".aAAAaaaAAAa..",
    "..aAAAAAAAa...",
    "...aaAAAaa....",
    "....aaaaa.....",
    "..............",
]

MEDUSA_BREAK = [
    "..............",
    "....a...a.....",
    "..aAa..aaA....",
    "...a.aa..a....",
    "..aAa..aAa....",
    "...a.aaa.a....",
    "..a..aAa..a...",
    "...aa...aa....",
    "....a.a.a.....",
    "..............",
    "..............",
    "..............",
]


def build_medusa_head() -> Atlas:
    atlas = Atlas(E_W, E_H)
    drift = [_place(MEDUSA_A, dy=-10), _place(MEDUSA_B, dy=-10)]
    atlas.add_anim("idle", drift, fps=6.0)
    atlas.add_anim("fly", drift, fps=8.0)
    atlas.add_anim("attack", drift, fps=8.0)
    atlas.add_anim("hurt", [_place(MEDUSA_B, dy=-10, dx=-1)], fps=1.0, loop=False)
    atlas.add_anim(
        "death",
        [_place(MEDUSA_BREAK, dy=-10), _place(MEDUSA_BREAK, dy=-7)],
        fps=8.0,
        loop=False,
    )
    return atlas


# ---------------------------------------------------------------------------
# Sanguine Knight, Sir Kaelis — wing boss. Larger 64x64 frame.
# ---------------------------------------------------------------------------

B_W = 64
B_H = 64

KNIGHT_IDLE = [
    "..............GG................",
    ".............GGGG...............",
    ".............gGGg...............",
    "..........MMMMMMMM........MM....",
    ".........MMMMMMMMMM.......MM....",
    "........MMMGGGGGGMMM......MM....",
    "........MMG......GMM......Mm....",
    "........MMG.RRRR.GMM......MM....",
    "........MMGG....GGMM......Mm....",
    "........MMMGGGGGGMMM......MM....",
    ".........MMMMMMMMMM.......MM....",
    "..........MMMMMMMM........Mm....",
    "...........MMMMMM.........MM....",
    "......MMMMMMMMMMMMMMMM....MM....",
    ".....MMMMMMMMMMMMMMMMMM...MM....",
    "....MMMmMMMMMMMMMMMMmMMMGGGGGG..",
    "....MMm..MMMMMMMMMM..mMMGGGGGG..",
    "....MMm.MMRRRRRRRRMM.mMM.BBB....",
    "....MMm.MMRRGGGGRRMM.mMM.BBB....",
    ".....M..MMRRGGGGRRMM..M..BBB....",
    "........MMRRGGGGRRMM......G.....",
    "........MMRRGGGGRRMM............",
    "........MMRRRRRRRRMM............",
    "........MMRRRRRRRRMM............",
    "........qMRRRRRRRRMq............",
    ".......qqMMRRRRRRMMqq...........",
    "......qqqMMMRRRRMMMqqq..........",
    "......qqqMMMMMMMMMMqqq..........",
    "......qqq.MMMMMMMM.qqq..........",
    "......qq..MMM..MMM..qq..........",
    "..........MMM..MMM..............",
    "..........MMM..MMM..............",
    ".........MMMM..MMMM.............",
    ".........MMMM..MMMM.............",
    "........mMMMM..MMMMm............",
    "........bbbbb..bbbbb............",
    ".......bbbbbb..bbbbbb...........",
    "................................",
]

# Greatsword raised overhead, weight shifted onto the back foot.
KNIGHT_WINDUP = [
    "...GGGGGG.....GG................",
    "...GGGGGG....GGGG...............",
    "....BBB......gGGg...............",
    "....BBB...MMMMMMMM..............",
    "....BBB..MMMMMMMMMM.............",
    "MMMMMMMMMMMGGGGGGMMM............",
    "MMMMMMMMMG......GMM.............",
    "........MMG.RRRR.GMM............",
    "........MMGG....GGMM............",
    "........MMMGGGGGGMMM............",
    ".........MMMMMMMMMM.............",
    "..........MMMMMMMM..............",
    "...........MMMMMM...............",
    "......MMMMMMMMMMMMMMMM..........",
    ".....MMMMMMMMMMMMMMMMMM.........",
    "....MMMmMMMMMMMMMMMMmMMM........",
    "....MMm..MMMMMMMMMM..mMM........",
    "....MMm.MMRRRRRRRRMM.mMM........",
    "....MMm.MMRRGGGGRRMM.mMM........",
    ".....M..MMRRGGGGRRMM..M.........",
    "........MMRRGGGGRRMM............",
    "........MMRRGGGGRRMM............",
    "........MMRRRRRRRRMM............",
    "........MMRRRRRRRRMM............",
    "........qMRRRRRRRRMq............",
    ".......qqMMRRRRRRMMqq...........",
    "......qqqMMMRRRRMMMqqq..........",
    "......qqqMMMMMMMMMMqqq..........",
    "......qqq.MMMMMMMM.qqq..........",
    "......qq..MMM..MMM..qq..........",
    "..........MMM..MMM..............",
    ".........MMMM..MMMM.............",
    ".........MMMM..MMMM.............",
    "........MMMMM..MMMMM............",
    "........mMMMM..MMMMm............",
    ".......bbbbbb..bbbbbb...........",
    "......bbbbbbb..bbbbbbb..........",
    "................................",
]

# Blade swept forward and level — the active-hitbox frame.
KNIGHT_SLASH = [
    "..............GG................",
    ".............GGGG...............",
    ".............gGGg...............",
    "..........MMMMMMMM..............",
    ".........MMMMMMMMMM.............",
    "........MMMGGGGGGMMM............",
    "........MMG......GMM............",
    "........MMG.RRRR.GMM............",
    "........MMGG....GGMM............",
    "........MMMGGGGGGMMM............",
    ".........MMMMMMMMMM.............",
    "..........MMMMMMMM..............",
    "...........MMMMMM...............",
    "......MMMMMMMMMMMMMMMM..........",
    ".....MMMMMMMMMMMMMMMMMM.........",
    "....MMMmMMMMMMMMMMMMmMMM........",
    "....MMm..MMMMMMMMMM..mMM.G......",
    "....MMm.MMRRRRRRRRMM.mMMBGMMMMMM",
    "....MMm.MMRRGGGGRRMM.mMMBGMMMMMM",
    ".....M..MMRRGGGGRRMM..MMBG......",
    "........MMRRGGGGRRMM.....G......",
    "........MMRRGGGGRRMM............",
    "........MMRRRRRRRRMM............",
    "........MMRRRRRRRRMM............",
    "........qMRRRRRRRRMq............",
    ".......qqMMRRRRRRMMqq...........",
    "......qqqMMMRRRRMMMqqq..........",
    "......qqqMMMMMMMMMMqqq..........",
    "......qqq.MMMMMMMM.qqq..........",
    "......qq..MMM..MMM..qq..........",
    ".........MMMM..MMMM.............",
    ".........MMMM..MMMM.............",
    "........MMMMM..MMMMM............",
    "........MMMMM..MMMMM............",
    ".......mMMMMM..MMMMMm...........",
    ".......bbbbbb..bbbbbb...........",
    "......bbbbbbb..bbbbbbb..........",
    "................................",
]

KNIGHT_HURT = [
    "..............GG................",
    ".............GGGG...............",
    ".............gGGg...............",
    "..........MMMMMMMM.........MM...",
    ".........MMMMMMMMMM........MM...",
    "........MMMGGGGGGMMM.......MM...",
    "........MMG......GMM.......Mm...",
    "........MMG.YYYY.GMM.......MM...",
    "........MMGG....GGMM.......Mm...",
    "........MMMGGGGGGMMM.......MM...",
    ".........MMMMMMMMMM........MM...",
    "..........MMMMMMMM.........Mm...",
    "...........MMMMMM..........MM...",
    "......MMMMMMMMMMMMMMMM.....MM...",
    ".....MMMMMMMMMMMMMMMMMM....MM...",
    "....MMMmMMMMMMMMMMMMmMMM.GGGGGG.",
    "....MMm..MMMMMMMMMM..mMM.GGGGGG.",
    "....MMm.MMYYRRRRYYMM.mMM..BBB...",
    "....MMm.MMRRGGGGRRMM.mMM..BBB...",
    ".....M..MMRRGGGGRRMM..M...BBB...",
    "........MMRRGGGGRRMM.......G....",
    "........MMRRGGGGRRMM............",
    "........MMRRRRRRRRMM............",
    "........MMRRRRRRRRMM............",
    "........qMRRRRRRRRMq............",
    ".......qqMMRRRRRRMMqq...........",
    "......qqqMMMRRRRMMMqqq..........",
    "......qqqMMMMMMMMMMqqq..........",
    "......qqq.MMMMMMMM.qqq..........",
    "......qq..MMM..MMM..qq..........",
    "..........MMM..MMM..............",
    "..........MMM..MMM..............",
    ".........MMMM..MMMM.............",
    ".........MMMM..MMMM.............",
    "........mMMMM..MMMMm............",
    "........bbbbb..bbbbb............",
    ".......bbbbbb..bbbbbb...........",
    "................................",
]

# Collapsed: helm split, blade fallen, cape pooling on the flagstones.
KNIGHT_DEATH = [
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "..........MM....MM..............",
    ".........MMMGGGGMMM.............",
    "........MMG......GMM............",
    "........MMGG....GGMM............",
    ".........MMMMMMMMMM.............",
    "...MMMMMMMMMMMMMMMMMMMM.........",
    "..MMMMMMMMMMMMMMMMMMMMMM........",
    "..MMmMMRRRRRRRRRRRRMMmMM........",
    "..MM..MMRRGGGGGGRRMM..MM........",
    "..M...qMRRGGGGGGRRMq...M........",
    ".....qqMMRRRRRRRRMMqq...........",
    "....qqqMMMMMMMMMMMMqqq..........",
    "...qqqqqMMMMMMMMMMqqqqq.........",
    "..qqqqq..MMM..MMM..qqqqq........",
    "..qqq....MMM..MMM....qqq........",
    "....GGGGGGGGGGGGGGGGGG..........",
    "....MMMMMMMMMMMMMMMMMM..........",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
]


def _boss(rows: list[str], dx: int = 0, dy: int = 0) -> Canvas:
    art = Canvas.from_ascii(rows)
    x = (B_W - art.w) // 2 + dx
    y = B_H - art.h - 1 + dy
    return frame(B_W, B_H, [(art, x, y)])


def build_sanguine_knight() -> Atlas:
    atlas = Atlas(B_W, B_H)
    atlas.add_anim("idle", [_boss(KNIGHT_IDLE), _boss(KNIGHT_IDLE, dy=-1)], fps=2.5)
    atlas.add_anim(
        "walk",
        [_boss(KNIGHT_IDLE), _boss(KNIGHT_IDLE, dy=-1), _boss(KNIGHT_IDLE), _boss(KNIGHT_IDLE, dy=1)],
        fps=5.0,
    )
    atlas.add_anim(
        "attack",
        [_boss(KNIGHT_WINDUP), _boss(KNIGHT_WINDUP), _boss(KNIGHT_SLASH), _boss(KNIGHT_SLASH), _boss(KNIGHT_IDLE)],
        fps=9.0,
        loop=False,
    )
    atlas.add_anim(
        "charge",
        [_boss(KNIGHT_SLASH), _boss(KNIGHT_SLASH, dy=-1)],
        fps=12.0,
    )
    atlas.add_anim(
        "summon",
        [_boss(KNIGHT_WINDUP), _boss(KNIGHT_WINDUP, dy=-2), _boss(KNIGHT_WINDUP)],
        fps=5.0,
        loop=False,
    )
    atlas.add_anim("hurt", [_boss(KNIGHT_HURT, dx=-1)], fps=1.0, loop=False)
    atlas.add_anim(
        "death",
        [_boss(KNIGHT_HURT), _boss(KNIGHT_DEATH), _boss(KNIGHT_DEATH, dy=2)],
        fps=3.0,
        loop=False,
    )
    return atlas
