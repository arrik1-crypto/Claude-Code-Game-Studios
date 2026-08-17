# GDD — Combat System

**Status:** Implemented (vertical slice)
**Owner:** systems-designer
**Implements:** `src/core/combat_math.gd`, `src/gameplay/combat/`, `src/gameplay/player/states/attack_state.gd`
**Tuning data:** `assets/data/game_balance.json` → `combo`, `weapons`, `subweapons`
**Tests:** `tests/unit/combat/combat_damage_test.gd`, `tests/unit/combat/combat_health_test.gd`

## 1. Overview

Combat is a committed, positional melee exchange built on one weapon — the whip —
supported by a heart-costed thrown sub-weapon. The player roots in place for the
duration of a swing, so every attack is a decision made in advance about spacing
rather than a reaction. Damage is deterministic apart from a luck-driven critical
roll, which keeps the balance model verifiable and lets enemy health totals be
expressed honestly in "number of whip hits".

## 2. Player Fantasy

You are holding an old, heavy weapon that you know how to use and that does not
forgive being used carelessly. The whip is slow to start and long when it lands.
The feeling to protect is the half-second *before* the crack, when you have
already chosen and cannot take it back — and the satisfaction of having chosen
correctly. Missing should feel like your mistake, never the game's.

## 3. Detailed Rules

### 3.1 The whip

- Three-hit ground combo. Each hit runs **wind-up → active → recovery**.
- The player's horizontal velocity decays to zero during a swing; they cannot
  walk, turn, or jump out of it. Facing is locked at the moment the swing starts.
- Pressing attack during the **active** or **recovery** phase queues the next
  combo step. The queue is consumed when the current step's recovery ends.
- The combo resets to step 1 if the chain window lapses without a queued input.
- The whip hitbox is a rectangle extending forward from the player, `reach`
  pixels long and 14 px tall, centred 10 px above the player's feet. It clips
  crouching and grounded enemies but not enemies directly overhead.
- One activation can hit each enemy at most once. Piercing multiple enemies in
  a line is intended.

### 3.2 Air attack

- Single hit, no combo, no chain.
- Full air control is retained: the swing never costs the player a landing.
- Landing during any phase cancels the attack immediately.

### 3.3 Sub-weapons

- Thrown with a dedicated button, usable from almost every state including
  mid-combo and mid-air.
- Costs hearts, not MP. Hearts drop from enemies and candles, so sub-weapon use
  is paced by aggression rather than by a regenerating pool.
- Each sub-weapon has an on-screen cap. Exceeding it silently refuses the throw
  and costs nothing.
- **Silver Dagger** — straight, fast, cheap, single-target.
- **Throwing Axe** — arcs upward then falls; pierces; the answer to fliers.
- **Holy Water** — lobs short, shatters on the floor into a pool that ticks
  damage on an interval for its duration.

### 3.4 Taking damage

- Contact with an enemy body, an enemy projectile, or a hazard deals damage.
- On being hit the player enters **Hurt**: control is removed, and a knockback
  impulse is applied away from the damage source and upward.
- Invulnerability frames begin on the hit and outlast the control lockout, so
  the player is never combo-locked by a crowd.
- The whip hitbox is deactivated on being hit; a swing does not survive a stagger.

### 3.5 Critical hits

- Rolled per swing, not per enemy hit — every enemy struck by one crack shares
  its crit state, so a critical multi-hit reads clearly.

## 4. Formulas

All defined in `CombatMath`; constants come from `game_balance.json`.

```
attack_power      = max(0, (STR + weapon.attack) × combo.multiplier)

damage            = max(1, round( (attack_power − DEF × 0.5)
                                  × element_multiplier
                                  × (critical ? critical_multiplier : 1) ))

critical_chance   = clamp(base_crit_chance + LUCK × 0.005, 0, 0.5)

knockback         = ( sign(direction) × horizontal_force , −|vertical_force| )

subweapon_damage  = max(1, round( (STR + weapon.attack) × subweapon.damageMultiplier ))
```

Where:

| Symbol | Source |
|---|---|
| `STR` | `GameState.strength` |
| `weapon.attack` | `weapons.<equipped>.attack` |
| `combo.multiplier` | `combo.steps[n].multiplier` — 1.0 / 1.15 / 1.45 |
| `DEF` | the target's `defense` stat |
| `element_multiplier` | reserved; always 1.0 in the slice |
| `base_crit_chance` | `player.baseCritChance` (0.02) |
| `critical_multiplier` | `player.criticalMultiplier` (2.0) |

**Worked example** — a level-1 player (STR 6) with the Leather Whip (attack 4)
landing combo step 3 (×1.45) on a Gravewalker (DEF 6):

```
attack_power = (6 + 4) × 1.45   = 14.5
damage       = 14.5 − 6 × 0.5   = 11.5  → 12
```

A Gravewalker has 40 HP, so it survives a full three-hit combo (10 + 11 + 12 = 33)
and needs a fourth swing. That is the intended pacing: the Gravewalker is the
enemy that teaches the player to disengage and re-space.

## 5. Edge Cases

| Case | Behaviour |
|---|---|
| Damage would be ≤ 0 after mitigation | Floors at `MIN_DAMAGE` (1). A hit always registers. |
| Attacker has negative effective STR | `attack_power` clamps to 0; damage still floors at 1. |
| Whip activates while already overlapping an enemy | The hitbox sweeps existing overlaps on activation, so point-blank swings connect. |
| Two enemies inside one swing | Both are hit once; the already-hit registry prevents double ticks. |
| Player is hit mid-combo | Whip deactivates, combo state is discarded, Hurt takes over. |
| Player dies mid-combo | Whip deactivates; hurtbox is disabled; Dead state is terminal. |
| Sub-weapon thrown with insufficient hearts | Refused. No hearts spent, no projectile, no cooldown. |
| Sub-weapon cap reached | Refused before hearts are spent. |
| Projectile spawned overlapping its owner | The hitbox refuses to damage its own `attacker`. |
| Holy water lands on a hazard tile | Becomes a pool normally; the pool stops colliding with world geometry. |
| Enemy dies to the first hit of a combo | Later steps find no target; the combo still completes its animation. |
| Crit rolled on a 1-damage hit | 1 × 2 = 2. Crits are always a strict improvement. |

## 6. Dependencies

- **Progression** (`progression-and-stats.md`) — supplies STR, LUCK and DEF.
- **Traversal** (`traversal-moveset.md`) — owns the states combat transitions
  into and out of; the Mist Dash's i-frames interact with damage.
- **Enemies** (`enemies-and-bestiary.md`) — supplies DEF, contact damage and
  telegraph timings.
- **Hitbox/Hurtbox layer matrix** — `docs/architecture/ADR-004-combat-collision.md`.

## 7. Tuning Knobs

All in `assets/data/game_balance.json`:

| Knob | Effect if raised |
|---|---|
| `combo.steps[].multiplier` | Back-loads combo damage; rewards completing the chain |
| `combo.steps[].windup` | Makes the whip feel heavier and less reactive |
| `combo.steps[].active` | Widens the timing window; more forgiving |
| `combo.steps[].recovery` | Increases the punishment for a whiff |
| `combo.chainWindow` | Makes chaining easier on a laggy touchscreen |
| `weapons.*.attack` / `.reach` | Weapon power curve and effective spacing |
| `subweapons.*.heartCost` | Pacing of sub-weapon use |
| `subweapons.*.damageMultiplier` | Sub-weapon vs melee opportunity cost |
| `player.baseCritChance` | Damage variance floor |
| `movement.invulnerabilityTime` | How punishing crowds are |
| `movement.hurtLockout` | Weight of taking a hit |
| `CombatMath.DEFENSE_SCALE` | Armour's value across the whole game (code constant, deliberately not data — changing it re-balances everything) |

## 8. Acceptance Criteria

- [x] A three-hit combo can be chained by pressing attack once per swing.
- [x] The combo resets after the chain window lapses.
- [x] The player cannot move or turn during a grounded swing.
- [x] Air attacks retain full air control and cancel on landing.
- [x] One swing damages each overlapping enemy exactly once.
- [x] Damage never drops below 1 regardless of defence.
- [x] Critical hits apply exactly `criticalMultiplier`.
- [x] Crit chance is capped at 50% however high LUCK goes.
- [x] Sub-weapons refuse to fire without sufficient hearts, spending nothing.
- [x] Holy water forms a damage-over-time pool on landing.
- [x] Taking damage cancels an in-progress swing.
- [x] Knockback always pushes away from the source and upward.
- [x] All formulas covered by unit tests that run headless in CI.
