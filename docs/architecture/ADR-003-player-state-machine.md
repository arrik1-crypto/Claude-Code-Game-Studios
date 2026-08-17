# ADR-003 — Node-based finite state machine for the player

**Status:** Accepted
**Date:** 2026-08-17
**Deciders:** lead-programmer, gameplay-programmer

## Context

The player has eleven behaviours — idle, run, crouch, jump, fall, two attacks,
two dashes, hurt, dead — with non-trivial transition rules (coyote time, input
buffering, combo chaining, ability gating). A single `_physics_process` with
boolean flags becomes unmaintainable at roughly five behaviours.

## Decision

A `StateMachine` node whose children are `PlayerState` nodes. Exactly one is
current; the machine forwards physics and input to it.

- States are **thin**: they read input, set velocity on the shared `Player`
  context, and request transitions.
- States hold **no persistent data**. Anything that survives a transition
  (facing, combo step, timers, double-jump availability) lives on `Player`.
- Transitions are **queued and applied at the end of the physics step**, so a
  state always finishes its own frame before being replaced.
- Shared transition rules (`try_jump`, `try_attack`, `try_dash`) live on the
  base class so they cannot drift apart between states.

## Alternatives considered

- **Enum + `match`** in one script. Fewer files, but every state's logic shares
  one scope and the transition rules get duplicated. Rejected on maintainability.
- **`AnimationTree` state machine.** Couples gameplay state to animation state;
  a hurt animation finishing should not decide when control returns.

## Consequences

**Positive**
- Adding a state is one file plus one node; no existing state changes.
- The transition table is documented and enforceable — see
  `design/gdd/traversal-moveset.md` §3.1.
- Deferred transitions eliminate the "enter() runs against half-updated velocity"
  class of bug.

**Negative**
- Twelve small files instead of one large one.
- A transition loop is possible; the machine guards with an 8-iteration cap that
  logs an error rather than hanging.

## Engine Compatibility

Uses `@abstract` (Godot 4.5+) on `PlayerState` so an incomplete state fails at
parse time rather than silently doing nothing. See
`docs/engine-reference/godot/current-best-practices.md`.

## GDD Requirements Addressed

`TR-MOV-001`…`TR-MOV-011` (one per state), `TR-MOV-020` (ability gating).
