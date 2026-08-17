# Crimson Vespers — Game Concept

**Status:** Approved (vertical slice built)
**Stage:** Production — vertical slice
**Last updated:** 2026-08-17

## One-line pitch

A gothic action-exploration Metroidvania for phones: whip, leap and dissolve into
mist through a cursed castle whose locked doors are opened by the abilities you
find, not the keys you carry.

## The hook

Castlevania's Symphony-of-the-Night structure with a control scheme designed for
thumbs from the first line of code, rather than a console layout with a
touchscreen bolted on afterwards. Two things follow from that:

- **Short loops, permanent progress.** Every trip out from a save coffin is a
  five-to-ten minute arc. Death costs you the trip, never the run.
- **Few verbs, deep verbs.** Move, jump, whip, sub-weapon, dash. Five buttons,
  no menus during combat, and every ability you find changes the *map* rather
  than adding another button.

## Setting

**Castle Vhorn**, under a crimson moon that has not set in nine days. The Blood
Marquis **Vhorn Drakhaus** has drawn the castle out of its usual century of
sleep, and the countryside has started to disappear one hamlet at a time.

The vertical slice covers the **Outer Ward** and the approach to the
**Clocktower** — the castle's threshold, before the interior proper.

## Protagonist

**Seraphine Valcourt** (she/her), last initiate of a monster-hunting order that
no longer exists to induct anyone. She carries the order's leather whip and none
of its authority. She is not chosen, prophesied or possessed; she is simply the
only one who came.

Her arc across the full game is about inheriting a duty she never agreed to.
In the slice, that is expressed entirely mechanically: she starts with the
weakest whip in the game and every relic she finds is something the order left
behind.

## Core loop

```
explore a room  ->  fight what lives there  ->  gain exp / hearts / gold
      ^                                                    |
      |                                                    v
 new route opens  <-  find a relic  <-  reach a gated door / dead end
```

The loop is closed by **backtracking**: the Twin Step relic at the far east of
the ground floor is what lets you reach the upper door back in the Entrance
Hall. The player must return through rooms they have already cleared, and see
them differently.

## Pillars

1. **Weight over speed.** The whip commits you. Attacks root you in place, the
   recovery is real, and enemies telegraph. Winning a fight means having chosen
   your position two seconds ago.
2. **The map is the puzzle.** Combat is the texture; the actual problem the
   player is solving is "where can I not yet go, and what would let me".
3. **Legible on a small screen.** One saturated crimson in an otherwise
   desaturated violet palette. If something is red, it matters — the player's
   sash, blood, the boss, the moon.
4. **Never lose progress.** Relics, levels, gold and map knowledge are permanent
   from the moment you touch them. Only position is lost on death.

## Scope — vertical slice

| Element | Shipped |
|---|---|
| Rooms | 11, fully interconnected |
| Traversal abilities | 2 (Twin Step, Mist Dash) |
| Sub-weapons | 3 defined, 1 placed (Silver Dagger) |
| Weapons | 2 (Leather Whip, Chain Whip) |
| Enemy types | 4 + 1 three-phase boss |
| Save points | 2 |
| Session length | ~15–20 minutes to the boss |

## Out of scope for the slice

Explicitly deferred, with the reasoning recorded so it is not re-litigated:

- **Equipment and inventory.** The stat model supports it; the UI does not. A
  menu-driven inventory is at odds with pillar 4 (legible on a small screen) and
  needs its own design pass.
- **Familiars, spells, alternate forms.** Second-wing content.
- **Shops and an economy sink.** Gold accumulates but has nothing to buy yet.
  It is tracked because retro-fitting a currency is worse than banking one.
- **Narrative delivery.** No dialogue, no cutscenes. Environmental only.

## Comparables and what we take from each

| Game | What we take | What we deliberately do not |
|---|---|---|
| *Castlevania: Symphony of the Night* | Interconnected castle, ability gates, sub-weapons on hearts | RPG equipment depth, 100+ rooms |
| *Castlevania: Rondo of Blood* | Committed whip timing, enemy telegraphs | Stage-based linearity |
| *Hollow Knight* | Map-as-reward, generous checkpointing | Punishing death cost |
| *Dead Cells* (mobile) | Touch layout conventions | Roguelike structure |

## Risks

| Risk | Mitigation |
|---|---|
| Touch controls make committed combat feel unfair | Generous coyote time, input buffering, and long enemy telegraphs; controls are scalable and repositionable |
| Backtracking reads as padding | The slice's backtrack is one room long and opens a visibly new route |
| Placeholder art misread as final | Every asset is generated from `tools/asset-pipeline/`; specs for replacement live in `design/art-bible.md` |
| Small screen hides enemy tells | Boss wind-ups are 0.45–0.6s and animation-distinct; the palette reserves crimson for threats |

## Related documents

- Mechanics: `design/gdd/`
- Level layout and gating: `design/levels/room-graph.md`
- Visual direction: `design/art-bible.md`
- Technical decisions: `docs/architecture/`
