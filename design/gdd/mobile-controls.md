# GDD — Mobile Controls

**Status:** Implemented (vertical slice)
**Owner:** ux-designer
**Implements:** `src/ui/touch/touch_controls.gd`, `project.godot` → `[input]`
**Tuning data:** `assets/data/game_balance.json` → `movement` (buffer and coyote windows)

## 1. Overview

The game is designed for thumbs first. Every action is an entry in Godot's
`InputMap`, and the touch layer does nothing but press and release those same
actions — so no gameplay code branches on input method, and a phone, a keyboard
and a gamepad are all first-class without a single conditional in the player
controller.

## 2. Player Fantasy

The controls should disappear. A player should never think about the buttons,
only about the castle. That means: nothing important under the palm, no gesture
that competes with a tap, and enough input forgiveness that a mistimed press
reads as the game being generous rather than the screen being unresponsive.

## 3. Detailed Rules

### 3.1 Action set

| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| `move_left` / `move_right` | ← → / A D | Left stick X | D-pad left/right |
| `move_up` / `move_down` | ↑ ↓ / W S | Left stick Y | D-pad up/down |
| `jump` | Space, C | A | Large button, bottom-right |
| `attack` | X | X | Large button, left of jump |
| `subweapon` | Z | Y | Small button, upper right |
| `dash` | Shift | B | Small button, upper right |
| `interact` | ↑ | Y | D-pad up (doubles) |
| `pause` | Esc | Start | Small button, top-right corner |
| `map_screen` | Tab | L1 | — (via pause) |

### 3.2 Layout

Landscape, 480×270 reference viewport:

```
 ┌──────────────────────────────────────────────[pause]─┐
 │  HP ▬▬▬▬▬▬▬▬  60/60                                  │
 │  MP ▬▬▬▬▬                                            │
 │  ♥ 10   Silver Dagger (1♥)                           │
 │  LV 1  EXP 24  0 G                                   │
 │                                                      │
 │                                          [dash][sub] │
 │            ▲                                         │
 │         ◀  ●  ▶                            [atk][JMP]│
 │            ▼                                         │
 └──────────────────────────────────────────────────────┘
```

- **Left thumb**: four-way d-pad. Discrete buttons rather than a virtual stick —
  a platformer needs unambiguous left/right, and an analogue stick under a thumb
  produces accidental diagonals.
- **Right thumb**: attack and jump are the largest targets and sit closest to the
  corner where the thumb rests. Dash and sub-weapon are smaller and higher, since
  they are used deliberately rather than reflexively.
- **`passby_press`** is enabled on the d-pad, so sliding a thumb from left to
  right registers without lifting.
- The HUD occupies the top-left, away from both thumbs.

### 3.3 Input forgiveness

Touch input carries more latency and less precision than a keyboard, so the
windows in `movement` are sized for the worst case and simply feel generous on
a keyboard:

- `jumpBufferTime` (0.12 s) — a jump pressed before landing still fires.
- `coyoteTime` (0.10 s) — a jump pressed after leaving a ledge still fires.
- `combo.chainWindow` (0.36 s) — combo chaining does not demand frame precision.

### 3.4 Accessibility

- `control_scale` (0.6–2.0) resizes every touch target together, re-anchored so
  the layout never overlaps at any scale.
- `control_opacity` (0.15–1.0) for players who find the overlay distracting.
- `controls_visible` hides the layer entirely for gamepad play.
- The controls auto-hide when no touchscreen is present, so desktop playtests are
  not cluttered — `DisplayServer.is_touchscreen_available()`.
- No gesture is required anywhere. Every action has a discrete button.
- The up button doubles as `interact` so resting at a coffin does not need a
  dedicated target competing for thumb space.

## 4. Formulas

```
effective_touch_target_px = base_size × control_scale × (screen_height / 270)
```

On a 1080p phone the 40 px jump button becomes 160 physical pixels ≈ 9 mm at
typical DPI — comfortably above the ~7 mm minimum for reliable thumb targets.
At `control_scale` 2.0 it reaches ~18 mm.

## 5. Edge Cases

| Case | Behaviour |
|---|---|
| Layer removed while a button is held | `_exit_tree` releases every action it owns, so nothing sticks down. |
| Two buttons pressed simultaneously | Independent `TouchScreenButton`s; both actions register. |
| Thumb slides off a d-pad button | `passby_press` keeps directional input alive across the pad. |
| Thumb slides off an action button | Released — action buttons deliberately do not pass-by, so a slide is a cancel. |
| Device has both touch and keyboard | Controls hidden by default; `controls_visible` forces them on. |
| Pause opened mid-movement | Tree pauses; held actions remain held and resume correctly. |
| Very small screen | `control_scale` and the anchored layout keep targets separated. |

## 6. Dependencies

- **Traversal** — consumes the buffering and coyote windows.
- **Combat** — consumes the chain window.
- **HUD** — shares screen real estate; occupies the opposite corner.
- **Pause menu** — reachable from the on-screen pause button, since a phone has
  no Escape key.

## 7. Tuning Knobs

| Knob | Location | Effect |
|---|---|---|
| `control_scale` | TouchControls export | Target size |
| `control_opacity` | TouchControls export | Overlay prominence |
| `controls_visible` | TouchControls export | Show/hide the layer |
| Button positions | `touch_controls.tscn` | Layout for different hand sizes |
| `movement.jumpBufferTime` | balance data | Pre-landing jump forgiveness |
| `movement.coyoteTime` | balance data | Post-ledge jump forgiveness |
| `combo.chainWindow` | balance data | Combo timing forgiveness |

## 8. Acceptance Criteria

- [x] Every gameplay action is reachable by touch alone, with no gestures.
- [x] Touch, keyboard and gamepad drive identical `InputMap` actions.
- [x] No gameplay code branches on input method.
- [x] Controls auto-hide when no touchscreen is present.
- [x] Scale and opacity are adjustable at runtime.
- [x] Sliding across the d-pad changes direction without lifting.
- [x] No action remains stuck down when the layer is removed.
- [x] Attack and jump are the two largest targets.
- [x] The HUD never sits under either thumb.
- [x] The pause menu is reachable without a hardware key.
