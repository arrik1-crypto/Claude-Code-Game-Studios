# ADR-002 — Autoload service layer with a signal-only EventBus

**Status:** Accepted
**Date:** 2026-08-17
**Deciders:** technical-director, lead-programmer

## Context

Systems that must not know about each other still need to communicate: the HUD
must react to damage, the map to room entry, audio to almost everything. The
naive solutions are direct node references (brittle across room rebuilds) or a
god object (untestable).

The player node is destroyed and recreated on every death and respawn, and the
room node is freed on every transition, so any design that relies on stable node
paths between systems is guaranteed to break.

## Decision

Five autoloads, each with one job:

| Autoload | Owns |
|---|---|
| `EventBus` | Global signals. **No state, no methods.** |
| `Balance` | Read-only access to `game_balance.json` |
| `GameState` | All persistent run state + save/load |
| `AudioDirector` | Music and SFX playback |
| `SceneDirector` | Screen flow and room streaming |

`EventBus` carries **notifications only** — past-tense signals, no return values,
no commands. Anything that must be remembered lives in `GameState`.

## Consequences

**Positive**
- The HUD binds to `EventBus` once and survives every player and room rebuild.
- Adding a sound to an event is one line in `AudioDirector._connect_events()`.
- Systems are independently testable — the combat tests never construct a HUD.

**Negative**
- Signal flow is not statically traceable; finding "who reacts to this" needs a
  search. Mitigated by keeping every signal declared in one file with doc
  comments.
- Autoloads are global state. Bounded by the rule that only *services* qualify —
  gameplay logic never becomes an autoload.

**Guardrail:** `CombatMath` is deliberately **not** an autoload. It is a static
class with no dependencies, which is what lets the balance model be unit-tested
without booting the game.

## Engine Compatibility

Godot 4.6. Autoloads are instantiated before the main scene, so `_ready` in any
gameplay node can rely on them. Signal connections use the 4.x
`signal.connect(callable)` form; the string-based API is forbidden.

## GDD Requirements Addressed

`TR-ARCH-001` (systems decoupled across room rebuilds), `TR-ARCH-002` (HUD
reactive to gameplay without polling).
