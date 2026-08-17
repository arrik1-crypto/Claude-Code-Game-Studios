# GDD — Traversal & Moveset

**Status:** Implemented (vertical slice)
**Owner:** game-designer
**Implements:** `src/gameplay/player/player.gd`, `src/gameplay/player/states/`
**Tuning data:** `assets/data/game_balance.json` → `movement`
**Tests:** `tests/unit/data/data_balance_test.gd` (gate-height assertions)

## 1. Overview

Seraphine's movement is a compact state machine: eleven states, one active at a
time, all sharing a single physics context. Two of the states — Jump's double
variant and the Mist Dash — are gated behind relics, and those two gates are what
turn a set of rooms into a Metroidvania. The numbers are chosen so that the
*reachable height* of each movement tier maps cleanly onto tile counts a level
designer can count on a grid.

## 2. Player Fantasy

Heavy but precise. Seraphine is not agile — she has no wall-jump, no air-dash
chain, no momentum tricks — but she goes exactly where you point her. The two
relics do not make her faster; they make the castle smaller. The Twin Step is the
moment a ledge you have walked past four times stops being scenery.

## 3. Detailed Rules

### 3.1 State machine

| State | Enter from | Exits to | Control |
|---|---|---|---|
| Idle | Run, Fall, Attack, Hurt, Backdash, MistDash | Run, Crouch, Jump, Fall, Attack, Backdash, MistDash | Full |
| Run | Idle, Fall, Hurt | Idle, Crouch, Jump, Fall, Attack, dashes | Full |
| Crouch | Idle, Run | Idle, Fall, Jump, Attack, dashes | Locked in place |
| Jump | Idle, Run, Crouch, Fall (coyote), Jump (double) | Fall, Attack, AirAttack, MistDash | Air control |
| Fall | Jump, ledge walk-off, Crouch drop-through, AirAttack | Idle, Run, Jump (double), AirAttack, MistDash | Air control |
| Attack | Idle, Run, Crouch, Backdash | Attack (next step), Idle, Run, Fall | Rooted |
| AirAttack | Jump, Fall | Fall, Idle | Air control |
| Backdash | any grounded state | Idle, Fall, Attack | Scripted |
| MistDash | any state, if unlocked | Idle, Fall | Scripted, intangible |
| Hurt | any state, on damage | Idle, Run, Fall | None |
| Dead | on HP reaching 0 | — (terminal) | None |

Transitions are queued and applied at the end of the physics step, so a state
always finishes its own frame before being replaced.

### 3.2 Jumping

- **Variable height.** Releasing the jump button while still rising multiplies
  the remaining upward velocity by `jumpCutMultiplier`. A tap is a short hop; a
  hold is a full leap.
- **Coyote time.** A grounded jump remains available for `coyoteTime` seconds
  after walking off a ledge.
- **Input buffering.** A jump pressed up to `jumpBufferTime` before landing fires
  on the first grounded frame.
- **Twin Step (double jump).** Once unlocked, one extra mid-air jump per airborne
  period. It is restored on touching the ground, and also when walking off a
  ledge (so a ledge walk-off does not silently cost the double jump).

### 3.3 Crouching and drop-through

- Crouching halves the hurtbox height, letting Medusa Heads pass overhead.
- The body collider is deliberately **not** resized: changing it mid-frame pops
  the character through floors.
- Crouch + jump on a one-way platform drops through it. The player's one-way
  collision mask is disabled for `0.28 s`, long enough to clear the plank.

### 3.4 Backdash (starting move)

- Fixed-duration hop backwards, eased out.
- Reduced gravity during the dash so it reads as a glide, not a fall.
- **No invulnerability.** It repositions; it does not save you.
- Cancellable into an attack — the intended spacing tool.

### 3.5 Mist Dash (relic)

Grants three things at once, which is what makes it feel like a real upgrade:

1. **Distance** — faster and flatter than the backdash; gravity is suspended.
2. **Invulnerability** — the hurtbox is disabled for the whole dash.
3. **Passage** — every `MistGate` in the room becomes permeable while dashing.

Works grounded and airborne, does not consume the double jump, and dashes in the
held direction (or facing, if no direction is held).

### 3.6 Hazards and death

- Spike tiles are solid — the player lands on them and then takes damage, rather
  than falling through.
- Death is not a run-ender: relics, level, gold and map knowledge persist. Only
  position is lost, and the player restarts at the last save coffin.

## 4. Formulas

Projectile motion under constant gravity, all values from `movement`:

```
jump_apex_height        = jumpVelocity²  / (2 × gravity)
double_jump_extra       = doubleJumpVelocity² / (2 × gravity)
total_reachable_height  = jump_apex_height + double_jump_extra

horizontal_accel        = grounded ? groundAcceleration : airAcceleration
horizontal_target       = input_axis × (grounded ? runSpeed : airControlSpeed)
velocity.x              = move_toward(velocity.x, horizontal_target, accel × Δt)

velocity.y              = min(velocity.y + gravity × Δt, maxFallSpeed)
jump_cut                : if released while velocity.y < 0 → velocity.y ×= jumpCutMultiplier

backdash_velocity.x     = −facing × backdashSpeed × ease(t_remaining / duration, 0.4)
mist_velocity           = (direction × mistDashSpeed, 0)
```

With the shipped values (`gravity 900`, `jumpVelocity −330`, `doubleJumpVelocity −300`):

| Capability | Height | In 16 px tiles |
|---|---|---|
| Single jump | 60.5 px | ~3.8 |
| Twin Step total | 110.5 px | ~6.9 |

**This is the contract the level design depends on.** Ledges at ≤ 48 px are open
to everyone; the 80 px climb in the Entrance Hall is the Twin Step gate. Both
bounds are asserted in `data_balance_test.gd`, so re-tuning the jump without
re-checking the level design fails CI.

## 5. Edge Cases

| Case | Behaviour |
|---|---|
| Jump pressed the frame before landing | Buffered and fires on landing. |
| Jump pressed just after walking off a ledge | Coyote time makes it a ground jump, not a double jump. |
| Double jump used, then the player lands | Restored on the first grounded frame. |
| Walking off a ledge without jumping | Fall state restores the double jump so it is not silently lost. |
| Mist Dash into a wall | Player stops at the wall; the dash timer still expires normally. |
| Mist Dash ends inside a mist gate | Gate collision is re-enabled; the player is pushed out by physics. Gates are one tile wide so this cannot trap. |
| Drop-through pressed on solid ground | Treated as a normal jump; the one-way mask is untouched. |
| Drop-through while the platform is destroyed mid-fall | Mask is restored by a scene-tree timer, which survives the state change. |
| Attack pressed while airborne | Routes to AirAttack, never the grounded combo. |
| Hurt while airborne | Knockback applies; the player lands into Fall → Idle/Run. |
| Crouching under a low ceiling, then standing | The body collider never shrank, so there is nothing to un-shrink. No ceiling check needed. |
| Room transition mid-dash | `set_control_enabled(false)` zeroes horizontal velocity; the dash state is discarded with the room. |

## 6. Dependencies

- **Combat** (`combat-system.md`) — Attack/AirAttack states and i-frames.
- **Level design** (`../levels/room-graph.md`) — consumes the height table above.
- **Mobile controls** (`mobile-controls.md`) — buffering and coyote windows are
  sized for touch latency.
- **Progression** — the relic flags that gate Twin Step and Mist Dash.

## 7. Tuning Knobs

| Knob | Effect if raised |
|---|---|
| `runSpeed` | Pace of exploration; too high makes rooms feel small |
| `airControlSpeed` | Mid-air correction; too high removes jump commitment |
| `groundAcceleration` / `groundFriction` | Snappiness vs. weight |
| `gravity` / `maxFallSpeed` | Overall heaviness; changes every gate height |
| `jumpVelocity` / `doubleJumpVelocity` | **Re-check the gate table in §4** |
| `jumpCutMultiplier` | Precision of short hops |
| `coyoteTime` / `jumpBufferTime` | Forgiveness — raise for touch, not for feel |
| `backdashSpeed` / `backdashDuration` | Spacing tool range |
| `mistDashSpeed` / `mistDashDuration` | Gap-crossing distance and i-frame length |
| `mistDashCooldown` | How spammable the invulnerability is |
| `hurtLockout` / `invulnerabilityTime` | Weight and crowd-safety of taking a hit |

## 8. Acceptance Criteria

- [x] A single jump clears a 3-tile ledge and fails a 5-tile one.
- [x] Twin Step clears the 5-tile Entrance Hall gate.
- [x] Releasing jump early produces a measurably shorter hop.
- [x] Coyote time allows a ground jump shortly after leaving a ledge.
- [x] A jump buffered before landing fires on touchdown.
- [x] The double jump is restored on landing and on ledge walk-off.
- [x] Crouch + jump drops through a one-way platform and not through solid floor.
- [x] Crouching shrinks the hurtbox but not the body collider.
- [x] Mist Dash passes through mist gates; the backdash does not.
- [x] Mist Dash grants invulnerability for its full duration.
- [x] Mist Dash does not consume the double jump.
- [x] Being hit cancels attacks and applies knockback away from the source.
- [x] The gate-height contract is enforced by an automated test.
