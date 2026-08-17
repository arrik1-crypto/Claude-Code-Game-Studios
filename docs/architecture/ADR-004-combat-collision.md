# ADR-004 — Area2D hitbox/hurtbox pairs with an explicit layer matrix

**Status:** Accepted
**Date:** 2026-08-17
**Deciders:** lead-programmer, systems-designer

## Context

Damage must flow between the player, four enemy types, a boss, projectiles and
hazards, in both directions, with per-source knockback and invulnerability
behaviour. Ad-hoc `body_entered` handlers on each entity would duplicate the
same registry and mitigation logic six times.

## Decision

Two reusable components and a value object:

- **`Hitbox`** (Area2D) — deals damage. Normally disabled; switched on for a few
  frames. Tracks which hurtboxes it has already hit this activation.
- **`Hurtbox`** (Area2D) — receives damage. Owns no health; forwards to a
  `Health` node.
- **`DamageInfo`** — carries amount, source kind, crit state, knockback and
  provenance together.

Damage always flows `Hitbox → DamageInfo → Hurtbox → Health`. Calling
`Health.take_damage()` directly from an attack is forbidden.

### Layer matrix

| Layer | Bit | Set by | Masked by |
|---|---:|---|---|
| `world` | 1 | Tiles, mist gates | Bodies, projectiles |
| `player` | 2 | Player body + hurtbox | Enemy hitboxes |
| `enemy` | 4 | Enemy bodies + hurtboxes | Player hitboxes |
| `player_hitbox` | 8 | Whip, player projectiles | — |
| `enemy_hitbox` | 16 | Contact damage, enemy projectiles | — |
| `pickup` | 32 | Collectables | Player's collector |
| `interactable` | 64 | Doors, coffins, pedestals | — |
| `one_way` | 128 | Drop-through platforms | Player body |

Hurtboxes set a **layer** and no mask; hitboxes set a **mask**. This single rule
is what makes the matrix readable.

## Consequences

**Positive**
- A new enemy needs no combat code — it inherits the pair from `EnemyBase`.
- The "one swing hits each enemy once" rule exists in exactly one place.
- Continuous damage (contact, holy-water pools) is a flag, not a second system.

**Negative**
- Every entity carries two extra Area2D nodes. Negligible at this entity count.
- Layer bits are easy to mis-set. Mitigated by documenting them in the control
  manifest and naming them in `project.godot`.

**Guardrail:** a hitbox never damages its own `attacker`, so a projectile
spawned inside its owner cannot hit it on frame one.

## Engine Compatibility

Godot 4.6 Area2D. Collision shapes are toggled with `set_deferred` — changing
them inside a physics callback is an error in 4.x.

## GDD Requirements Addressed

`TR-CMB-001` (whip damage), `TR-CMB-004` (multi-hit), `TR-CMB-007` (knockback),
`TR-CMB-010` (i-frames), `TR-CMB-012` (hazard damage).
