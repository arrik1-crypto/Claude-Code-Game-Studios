# GDD — Progression & Stats

**Status:** Implemented (vertical slice)
**Owner:** economy-designer
**Implements:** `src/core/combat_math.gd`, `src/core/game_state.gd`
**Tuning data:** `assets/data/game_balance.json` → `player`, `economy`, `pickups`
**Tests:** `tests/unit/progression/progression_curve_test.gd`

## 1. Overview

Two progression tracks run in parallel and are deliberately unequal in weight.
**Levels** are the incremental track: they accrue from ordinary play, soften
difficulty spikes, and never gate anything. **Relics** are the real track: they
are hand-placed, permanent, and each one changes which rooms exist for you. A
player who grinds becomes slightly stronger; a player who explores becomes able
to go somewhere new.

## 2. Player Fantasy

Growing into the role rather than being handed it. Levels arrive quietly — a
chime, a full heal, one more point in each stat — and their job is to make the
room you just struggled through feel routine on the way back. The relics are the
memorable beats, and they are memorable precisely because the levels are not.

## 3. Detailed Rules

### 3.1 Stats

| Stat | Effect |
|---|---|
| **STR** | Adds directly to attack power for whip and sub-weapons |
| **CON** | Adds to maximum HP |
| **INT** | Adds to maximum MP (reserved for spells; not consumed in the slice) |
| **LCK** | Adds to critical hit chance, capped at 50% |

All four increase by 1 per level. There is no allocation choice: a build system
would be a menu, and menus are against pillar 3 (legible on a small screen).

### 3.2 Levelling

- Experience is awarded on kill and applied immediately.
- Multiple levels can be gained from a single kill; each is applied in turn so
  every level-up emits its own event and grants its own stat increase.
- A level-up **restores exactly the HP it granted** and refills MP. It is a
  reward for pushing one room further, not a full heal.
- Level cap is 99. Reaching it is far outside the slice's content.

### 3.3 Resources

| Resource | Gained from | Spent on | Persists on death |
|---|---|---|---|
| **HP** | Level-up, HP orbs, save coffins | Taking damage | Restored at the coffin |
| **MP** | Regenerates passively, level-up | Reserved for spells | Yes |
| **Hearts** | Enemy drops, candles, placed pickups | Sub-weapon throws | Yes |
| **Gold** | Enemy drops, placed pickups | Nothing yet (banked for shops) | Yes |
| **EXP** | Kills | Levels, automatically | Yes |

### 3.4 Relics

| Relic | Type | Grants | Located |
|---|---|---|---|
| Silver Dagger | Sub-weapon | Cheap ranged option | Chapel Landing |
| Twin Step | Ability | Double jump | Vault of the Twin Step |
| Mist Dash | Ability | Dash + i-frames + gate passage | Vault of Mist |
| Chain Whip | Weapon | +5 attack, +8 reach | Throne of Ash |

Each is guarded by a unique world flag, so a taken relic stays taken across
save/load and across room re-entry. The empty pedestal remains as a landmark.

### 3.5 Death and persistence

- On death: return to the last save coffin at `respawnHpFraction` of max HP.
- Nothing is lost. `economy.deathGoldPenaltyFraction` is 0 and is expected to
  stay 0 — it exists as a knob so that the decision is explicit rather than
  accidental.

### 3.6 Saving

- Explicit, at a coffin. Saving also fully heals and sets the respawn point.
- One slot. Written as plain JSON under `user://`, unencrypted — this is a
  single-player game with no leaderboard, so tamper protection would buy nothing.

## 4. Formulas

```
exp_to_next(level)   = round(24 × level^1.6)
total_exp(level)     = Σ exp_to_next(n) for n in [1, level)

max_hp(level, CON)   = 60 + CON × 4 + (level − 1) × 8
max_mp(level, INT)   = 20 + INT × 3 + (level − 1) × 4

exp_reward(base, enemy_level, player_level):
    gap   = enemy_level − player_level
    scale = clamp(1 + gap × 0.15, 0.1, 2.0)
    = max(1, round(base × scale))
```

### Curve shape

| Level | EXP for next | Cumulative | Max HP (CON = 7 + level) |
|---:|---:|---:|---:|
| 1 | 24 | 0 | 92 |
| 2 | 73 | 24 | 104 |
| 3 | 143 | 97 | 116 |
| 5 | 336 | 466 | 140 |
| 10 | 956 | 2 621 | 200 |

The exponent of 1.6 is the load-bearing choice. Level 2 arrives after roughly two
Bone Sentries — inside the first two rooms — which teaches the player that
levelling exists. By level 10 a single level is a deliberate session's work.

### Level-gap scaling

`exp_reward` is what stops the first room being a grinding spot. A level-1
Bone Sentry killed by a level-20 player pays 10% of its listed value; killing
something four levels above you pays 160%.

## 5. Edge Cases

| Case | Behaviour |
|---|---|
| A single kill grants several levels | Each level applied separately; one event per level. |
| Level-up while at full HP | HP ceiling rises and current HP rises by the same amount, so the player stays full. |
| Level-up while nearly dead | Grants only the *increase*, not a full heal. A level-up cannot save you mid-fight. |
| EXP total is 0 or negative | Clamped; player is level 1. |
| EXP beyond the level cap | Level stops at `maxLevel`; surplus is retained but inert. |
| CON raised, lowering nothing | `current_hp` is clamped to the new max, never inflated. |
| Hearts spent below zero | `try_spend_hearts` refuses and returns false; nothing is deducted. |
| Picking up hearts at the cap | Clamped to `maxHearts`; the pickup is still consumed. |
| Relic re-entered after collection | World flag suppresses it; the pedestal renders as taken. |
| Save file from an older version | Loaded with a warning; missing keys fall back to defaults. |
| Corrupt save file | Load is refused entirely and the in-memory run is left untouched. |
| Death with no save point set | Falls back to the title screen rather than an invalid respawn. |

## 6. Dependencies

- **Combat** — consumes STR, LCK, and enemy DEF.
- **Traversal** — consumes the ability flags this system unlocks.
- **Level design** — relic placement defines the critical path.
- **HUD** — subscribes to level, HP, MP, heart and gold events.

## 7. Tuning Knobs

| Knob | Effect if raised |
|---|---|
| `player.expCurveBase` | Slows the whole curve uniformly |
| `player.expCurveExponent` | Steepens late levels specifically — the single most impactful knob |
| `player.hpBase` / `hpPerConstitution` / `hpPerLevel` | Survivability floor and growth |
| `player.mpRegenPerSecond` | Pace of the reserved spell economy |
| `player.startingHearts` / `maxHearts` | Sub-weapon availability |
| `player.baseCritChance` | Damage variance |
| `enemies.*.exp` / `.gold` | Reward density per room |
| `economy.respawnHpFraction` | Death severity |
| `economy.deathGoldPenaltyFraction` | Death severity (intentionally 0) |

## 8. Acceptance Criteria

- [x] EXP requirements increase monotonically with level.
- [x] The curve is super-linear: doubling the level more than doubles the cost.
- [x] Level 2 costs ≤ 30 exp, reachable in the first two rooms.
- [x] `level_for_exp` round-trips exactly against `total_exp_for_level`.
- [x] Levelling stops at the configured cap.
- [x] A level-up grants exactly the HP it added, not a full heal.
- [x] Killing far-below-level enemies pays under half value.
- [x] Killing above-level enemies pays a bonus.
- [x] Every kill awards at least 1 exp.
- [x] Relics cannot be collected twice, across reload or re-entry.
- [x] Death preserves level, gold, hearts, relics and map knowledge.
- [x] A corrupt save never destroys the in-memory run.
