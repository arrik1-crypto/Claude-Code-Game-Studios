"""Seraphine Valcourt — player character placeholder sprites.

Poses are hand-authored facing RIGHT at 20x28 inside a 32x32 frame. The engine
flips horizontally for the left-facing case, so never author a mirrored pose.

Frame origin convention: the character's feet sit on y=30 and the body is
centred on x=16, which lines up with the CharacterBody2D collision capsule
defined in src/gameplay/player/player.tscn.
"""

from __future__ import annotations

from pixelart import Atlas, Canvas, frame

# The frame is wider than the character so the whip has room to extend. The
# character stays centred on the frame so horizontal flipping is symmetric.
FRAME_W = 48
FRAME_H = 32
# Where the 20x28 pose art is placed inside the frame.
POSE_X = 14
POSE_Y = 2


IDLE = [
    "........HHHH........",
    "......HHHHHHH.......",
    ".....HHhhhhhHH......",
    "....HHhSSSSSSh......",
    "....HhhSSKSSSs......",
    "....Hh.SSSSSSs......",
    "....Hn.SSSSSs.......",
    ".....n..SSss........",
    "......ssssss........",
    ".....dCCCCCCd.......",
    "....cCCCCCCCCd......",
    "...cCCCCCCCCCCd.....",
    "...cCCRRRRRRCCd.....",
    "...cCCRRRRRRCCd.....",
    "...cCCCCCCCCCCd.....",
    "...cCcCCCCCCcCd.....",
    "...cCcCCCCCCcCd.....",
    "...GCcCCCCCCcCd.....",
    "....dcCCCCCCcd......",
    "....BB.dCCd.BB......",
    ".....d.CC.CC.d......",
    "......CC..CC........",
    "......CC..CC........",
    "......CC..CC........",
    "......BB..BB........",
    "......BB..BB........",
    "......bB..Bb........",
    ".....bbb..bbb.......",
]

# Run contact — lead leg forward and planted, trailing leg back.
RUN_A = [
    "........HHHH........",
    "......HHHHHHH.......",
    ".....HHhhhhhHH......",
    "....HHhSSSSSSh......",
    "....HhhSSKSSSs......",
    "....Hh.SSSSSSs......",
    "....Hn.SSSSSs.......",
    ".....n..SSss........",
    "......ssssss........",
    ".....dCCCCCCd.......",
    "....cCCCCCCCCd......",
    "...cCCCCCCCCCCd.....",
    "..cCCRRRRRRCCCd.....",
    "..cCCRRRRRRCCCd.....",
    "..cCCCCCCCCCCCd.....",
    "..BCcCCCCCCcCCd.....",
    "..BBcCCCCCCcCBB.....",
    "...GcCCCCCCCcBB.....",
    "....dCCCCCCCd.......",
    "....dCCd..dCCd......",
    "...dCCd....dCCd.....",
    "...CCC......CCC.....",
    "..BBB........BBB....",
    "..BBB........BBB....",
    "..bbb........bbb....",
    ".bbbb........bbbb...",
    "....................",
    "....................",
]

# Run passing — legs together under the body, torso lifted one pixel.
RUN_B = [
    "....................",
    "........HHHH........",
    "......HHHHHHH.......",
    ".....HHhhhhhHH......",
    "....HHhSSSSSSh......",
    "....HhhSSKSSSs......",
    "....Hh.SSSSSSs......",
    "....Hn.SSSSSs.......",
    ".....n..SSss........",
    "......ssssss........",
    ".....dCCCCCCd.......",
    "....cCCCCCCCCd......",
    "...cCCCCCCCCCCd.....",
    "...cCCRRRRRRCCd.....",
    "...cCCRRRRRRCCd.....",
    "...cCCCCCCCCCCd.....",
    "...BCcCCCCCCcCd.....",
    "...BBcCCCCCCcBB.....",
    "....GCCCCCCCCBB.....",
    "....dCCCCCCCCd......",
    ".....dCCCCCCd.......",
    "......CCCCCC........",
    "......CC.CCC........",
    "......CC..CC........",
    "......BB..BB........",
    "......BB..BB........",
    ".....bbb..bb........",
    "....................",
]

# Run stride — opposite leg forward.
RUN_C = [
    "........HHHH........",
    "......HHHHHHH.......",
    ".....HHhhhhhHH......",
    "....HHhSSSSSSh......",
    "....HhhSSKSSSs......",
    "....Hh.SSSSSSs......",
    "....Hn.SSSSSs.......",
    ".....n..SSss........",
    "......ssssss........",
    ".....dCCCCCCd.......",
    "....cCCCCCCCCd......",
    "...cCCCCCCCCCCd.....",
    "...cCCRRRRRRCCCd....",
    "...cCCRRRRRRCCCd....",
    "...cCCCCCCCCCCCd....",
    "..BBcCCCCCCcCCCd....",
    "..BBcCCCCCCcCCBB....",
    "...GcCCCCCCCcCBB....",
    "....dCCCCCCCCd......",
    "....dCCd..dCCd......",
    "...dCCd....dCCd.....",
    "..dCCd......CCC.....",
    "..BBB........BBB....",
    "..BBB........BBB....",
    "..bbb........bbb....",
    ".bbbb........bbbb...",
    "....................",
    "....................",
]

JUMP = [
    "....................",
    "........HHHH........",
    "......HHHHHHH.......",
    ".....HHhhhhhHH......",
    "....HHhSSSSSSh......",
    "....HhhSSKSSSs......",
    "....Hh.SSSSSSs......",
    "....Hn.SSSSSs.......",
    ".....n..SSss........",
    "..BB..ssssss........",
    "..BBcCCCCCCd........",
    "...cCCCCCCCCd.......",
    "...cCCRRRRRCCd......",
    "...cCCRRRRRCCd..BB..",
    "...cCCCCCCCCCd..BB..",
    "...cCCCCCCCCCcd.....",
    "....GCCCCCCCcd......",
    "....dCCCCCCCd.......",
    ".....dCCCCCd........",
    "....dCCd.dCCd.......",
    "...dCCd...dCCd......",
    "...CCC.....CCC......",
    "..BBB.......BB......",
    "..BBB.......BB......",
    "..bbb.......bb......",
    "....................",
    "....................",
    "....................",
]

FALL = [
    "....................",
    "........HHHH........",
    ".....HHHHHHHH.......",
    "...HHHhhhhhhHH......",
    "..HHhhSSSSSSh.......",
    "..HhhSSSKSSSs.......",
    "...h.SSSSSSSs.......",
    "...n..SSSSSs........",
    "......SSss..........",
    ".BB...ssssss........",
    ".BBcCCCCCCCd........",
    "..cCCCCCCCCCd.......",
    "..cCCRRRRRRCCd......",
    "..cCCRRRRRRCCd...BB.",
    "..cCCCCCCCCCCd...BB.",
    "..cCCCCCCCCCcd......",
    "...GCCCCCCCCcd......",
    "...dCCCCCCCCd.......",
    "....dCCCCCCd........",
    "....dCCd.dCCd.......",
    "....CCC...dCCd......",
    "...BBB.....CCC......",
    "...BBB......BBB.....",
    "...bbb......BBB.....",
    "............bbb.....",
    "....................",
    "....................",
    "....................",
]

CROUCH = [
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "........HHHH........",
    "......HHHHHHH.......",
    ".....HHhhhhhHH......",
    "....HHhSSSSSSh......",
    "....HhhSSKSSSs......",
    "....Hh.SSSSSSs......",
    ".....n.SSSSSs.......",
    "......ssssss........",
    ".....dCCCCCCd.......",
    "....cCCCCCCCCd......",
    "...cCCRRRRRRCCd.....",
    "...cCCRRRRRRCCd.....",
    "...cCcCCCCCCcCd.....",
    "...GCcCCCCCCcCd.....",
    "...BBcCCCCCCcBB.....",
    "...BB.dCCCCd.BB.....",
    "....dCCd..dCCd......",
    "...dCCd....dCCd.....",
    "...CCC......CCC.....",
    "..BBBB......BBBB....",
    "..bbbb......bbbb....",
    "....................",
    "....................",
]

# Whip wind-up: arm drawn back behind the head.
ATTACK_WIND = [
    "........HHHH........",
    "......HHHHHHH.......",
    ".....HHhhhhhHH......",
    "....HHhSSSSSSh......",
    "....HhhSSKSSSs......",
    "....Hh.SSSSSSs......",
    "....Hn.SSSSSs.......",
    ".....n..SSss........",
    "..BB..ssssss........",
    "..BBcdCCCCCCd.......",
    "...ccCCCCCCCCd......",
    "...cCCCCCCCCCCd.....",
    "...cCCRRRRRRCCd.....",
    "...cCCRRRRRRCCd.....",
    "...cCCCCCCCCCCd.....",
    "...cCcCCCCCCcCd.....",
    "...GCcCCCCCCcCd.....",
    "....dcCCCCCCcd......",
    ".....dCCCCCCd.......",
    ".....dCCd.CCd.......",
    "......CC..CCd.......",
    "......CC..CC........",
    "......CC..CC........",
    "......BB..BB........",
    "......BB..BB........",
    ".....bbB..Bbb.......",
    "....bbbb..bbbb......",
    "....................",
]

# Whip strike: arm extended forward, body leaning into the swing.
ATTACK_STRIKE = [
    "........HHHH........",
    "......HHHHHHH.......",
    ".....HHhhhhhHH......",
    "....HHhSSSSSSh......",
    "....HhhSSKSSSs......",
    "....Hh.SSSSSSs......",
    "....Hn.SSSSSs.......",
    ".....n..SSss........",
    "......ssssss........",
    ".....dCCCCCCd.......",
    "....cCCCCCCCCdBB....",
    "...cCCCCCCCCCCBB....",
    "...cCCRRRRRRCCd.....",
    "...cCCRRRRRRCCd.....",
    "...cCCCCCCCCCCd.....",
    "...cCcCCCCCCcCd.....",
    "...GCcCCCCCCcCd.....",
    "....dcCCCCCCcd......",
    "....BBCCCCCCd.......",
    "....BBdCCd.CCd......",
    ".....dCCd..dCCd.....",
    ".....CCC....CCC.....",
    "....BBB......BBB....",
    "....BBB......BBB....",
    "....bbb......bbb....",
    "...bbbb......bbbb...",
    "....................",
    "....................",
]

DASH = [
    "....................",
    "....................",
    "....................",
    "..........HHHH......",
    ".....HHHHHHHHH......",
    "...HHhhhhSSSSSh.....",
    "..Hhh.SSSKSSSSs.....",
    "...n..SSSSSSSs......",
    ".......Sssss........",
    "..BBBcCCCCCCd.......",
    "..BBcCCCCCCCCd......",
    "..ccCCRRRRRRCCd.....",
    "...cCCRRRRRRCCCd....",
    "...cCCCCCCCCCCCd....",
    "....GCCCCCCCCCd.....",
    "....dCCCCCCCCd......",
    "...dCCd..dCCd.......",
    "..dCCd....CCC.......",
    "..CCC......BBB......",
    ".BBB.......BBB......",
    ".bbb.......bbb......",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
]

HURT = [
    "....................",
    ".........HHHH.......",
    ".......HHHHHHH......",
    "......HHhhhhhHH.....",
    ".....HHhSSSSSSh.....",
    ".....HhhSSKSSSs.....",
    ".....Hh.SSSSSSs.....",
    "......n.SSSSSs......",
    ".......ssssss.......",
    "..BB..dCCCCCCd......",
    "..BB.cCCCCCCCCd.....",
    "....cCCCCCCCCCCd..BB",
    "....cCCRRRRRRCCd..BB",
    "....cCCRRRRRRCCd....",
    "....cCCCCCCCCCCd....",
    "....cCcCCCCCCcCd....",
    ".....GCCCCCCCCd.....",
    ".....dCCCCCCCd......",
    "....dCCd...dCCd.....",
    "...dCCd.....dCCd....",
    "...CCC.......CCC....",
    "..BBB.........BBB...",
    "..BBB.........BBB...",
    "..bbb.........bbb...",
    "....................",
    "....................",
    "....................",
    "....................",
]

DEAD = [
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "...HHHHH............",
    "..HHhhhhH...........",
    ".HHhSSSSSh..........",
    ".HhSSSSSSs..dCCd....",
    "..hsssssz.dCCCCCCd..",
    "...ccCCCCCCRRRRCCd..",
    "..cCCCCCCCCRRRRCCd..",
    "..cCCCCCCCCCCCCCCd..",
    "...dCCCCCCCCCCCCd...",
    "....BB..dCCd..BB....",
    "....bb........bb....",
    "....................",
]


def _pose(rows: list[str], dx: int = 0, dy: int = 0) -> Canvas:
    """Place a 20x28 pose inside the 32x32 frame."""
    return frame(FRAME_W, FRAME_H, [(Canvas.from_ascii(rows), POSE_X + dx, POSE_Y + dy)])


def _with_whip(rows: list[str], extent: int, dy: int = 0, droop: int = 5) -> Canvas:
    """Draw the whip lash in front of a pose.

    `extent` is how far the lash reaches past the hand in pixels; `droop` is how
    far the midpoint of the arc rises above the hand. The lash is sampled from a
    quadratic Bezier and drawn two pixels thick with a gold highlight along the
    upper edge, which is what makes it read as a crack rather than a stray line.
    """
    c = _pose(rows, dy=dy)
    hand_x, hand_y = POSE_X + 16, POSE_Y + 11 + dy
    tip_x, tip_y = min(hand_x + extent, FRAME_W - 1), hand_y + 3
    ctrl_x, ctrl_y = hand_x + extent // 2, hand_y - droop

    steps = max(8, extent * 2)
    points: list[tuple[int, int]] = []
    for i in range(steps + 1):
        t = i / steps
        inv = 1.0 - t
        x = inv * inv * hand_x + 2 * inv * t * ctrl_x + t * t * tip_x
        y = inv * inv * hand_y + 2 * inv * t * ctrl_y + t * t * tip_y
        p = (int(round(x)), int(round(y)))
        if not points or p != points[-1]:
            points.append(p)

    # Body of the lash: two pixels thick so it survives at 1x zoom.
    for x, y in points:
        c.rect(x, y, x, y + 1, "B")
    # Gold highlight riding the upper edge.
    for x, y in points:
        c.rect(x, y - 1, x, y - 1, "G")
    # A brighter tip sells the snap.
    if points:
        tx, ty = points[-1]
        c.rect(tx, ty - 1, tx, ty + 1, "Y")
    return c


def build() -> Atlas:
    """Assemble the full player animation atlas."""
    atlas = Atlas(FRAME_W, FRAME_H)

    atlas.add_anim("idle", [_pose(IDLE), _pose(IDLE, dy=1)], fps=3.0)
    atlas.add_anim(
        "run",
        [_pose(RUN_A), _pose(RUN_B), _pose(RUN_C), _pose(RUN_B, dy=1)],
        fps=12.0,
    )
    atlas.add_anim("jump", [_pose(JUMP)], fps=1.0, loop=False)
    atlas.add_anim("fall", [_pose(FALL)], fps=1.0, loop=False)
    atlas.add_anim("crouch", [_pose(CROUCH)], fps=1.0, loop=False)
    atlas.add_anim("dash", [_pose(DASH), _pose(DASH, dy=1)], fps=14.0)
    atlas.add_anim("hurt", [_pose(HURT)], fps=1.0, loop=False)
    atlas.add_anim("dead", [_pose(DEAD)], fps=1.0, loop=False)

    # Three-hit whip combo. Each swing is wind-up -> strike -> recover so the
    # active-frame window in player_attack.gd lines up with the visible lash.
    atlas.add_anim(
        "attack_1",
        [
            _pose(ATTACK_WIND),
            _with_whip(ATTACK_STRIKE, 10, droop=6),
            _with_whip(ATTACK_STRIKE, 16, droop=4),
            _pose(ATTACK_STRIKE),
        ],
        fps=16.0,
        loop=False,
    )
    atlas.add_anim(
        "attack_2",
        [
            _pose(ATTACK_WIND, dy=1),
            _with_whip(ATTACK_STRIKE, 12, droop=7),
            _with_whip(ATTACK_STRIKE, 17, droop=3),
            _pose(ATTACK_STRIKE),
        ],
        fps=16.0,
        loop=False,
    )
    atlas.add_anim(
        "attack_3",
        [
            _pose(ATTACK_WIND),
            _with_whip(ATTACK_STRIKE, 13, droop=8),
            _with_whip(ATTACK_STRIKE, 18, droop=4),
            _with_whip(ATTACK_STRIKE, 15, droop=2),
            _pose(ATTACK_STRIKE),
        ],
        fps=15.0,
        loop=False,
    )
    atlas.add_anim(
        "air_attack",
        [
            _pose(JUMP),
            _with_whip(JUMP, 12, droop=6),
            _with_whip(JUMP, 17, droop=3),
            _pose(FALL),
        ],
        fps=16.0,
        loop=False,
    )
    return atlas
