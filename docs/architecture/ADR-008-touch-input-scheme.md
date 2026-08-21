# ADR-008 — Touch input scheme

**Status:** Accepted
**Date:** 2026-08-17
**Supersedes:** the d-pad decision in `design/gdd/mobile-controls.md` §3.2
**Related:** ADR-002 (autoload service layer), ADR-003 (player state machine)

## Context

Touch is the primary input method for this game, but until now there was no ADR
covering it — the layout lived only in a GDD section, and the architectural rule
that makes it work (everything goes through the `InputMap`) was written down
nowhere.

The first build to reach a real Android phone produced immediate feedback: the
controls were unusable. Measuring rather than guessing:

At the 480×270 reference viewport, a 2340×1080 phone scales exactly 4×. At a
typical ~400 ppi:

| Control | Canvas units | Physical | vs ~9 mm minimum |
|---|---|---|---|
| d-pad arrows, pause, map | 24 | **6.1 mm** | 68% — fail |
| dash, subweapon | 32 | **8.1 mm** | 90% — fail |
| attack, jump | 40 | 10.2 mm | pass |

Eight of ten controls were under the minimum, including every movement input —
the one held down continuously. Worse, the four d-pad arrows tiled edge-to-edge
around a **dead centre cell**: a thumb resting in the middle of what looked like
a d-pad registered nothing.

The GDD contained the correct sizing formula but applied it only to the largest
button, and against a 7 mm bar rather than the ~9 mm / 48 dp standard.

## Decision

**1. All touch input drives the same `InputMap` actions as keyboard and gamepad.**

No gameplay code branches on input method. This is already a project Forbidden
Pattern; this ADR records *why* it is load-bearing rather than stylistic. It is
the reason replacing the entire movement control required no changes to the
player controller at all.

**2. Movement uses a hand-built circular `VirtualStick`, not a d-pad.**

This reverses the original design. The stated objection to a stick — "an analogue
stick under a thumb produces accidental diagonals" — was legitimate, and is
answered directly rather than ignored:

- a deadzone below which the stick reads as centred, so a resting thumb does not
  creep the character sideways;
- an axis-dominance rule: vertical input is ignored unless it clearly beats
  horizontal, so pushing diagonally while running never crouches you;
- a high vertical threshold, because up and down are discrete actions (crouch,
  drop-through, interact) while left and right are continuous.

**3. Horizontal movement is analog; vertical is digital.**

`Input.action_press()` accepts a strength, and the player already read movement
through `Input.get_axis`. So a partial tilt yields a partial axis and the
character walks rather than sprints — gained for free, with no gameplay change.
Vertical stays digital because the actions behind it are on/off.

**4. No touch target ships under ~9 mm on a 1080p phone.**

That is 40 canvas units at the 480×270 reference. Enforced by
`tests/unit/ui/ui_touch_anchoring_test.gd`, which converts authored sizes to
millimetres and fails below the floor — so "too small" is a test failure rather
than a matter of taste.

**5. Controls anchor to screen corners, never to fixed viewport coordinates.**

The project stretches with `expand`, so a 19.5:9 phone gets a ~585×270 canvas.
Fixed coordinates put the right-hand cluster at ~60% across, out of thumb reach.

## Alternatives considered

**Keep the d-pad, just make it bigger.** Rejected: it fixes the size but not the
dead centre, and a four-button cross large enough to clear 9 mm per arrow would
occupy substantially more screen than a stick with the same effective target.

**Use Godot's built-in virtual joystick.** Not available. The `VirtualJoystick`
node landed in **4.7**; this project is pinned to 4.6.

**Use a third-party joystick addon.** Rejected by `.claude/docs/technical-preferences.md`
— the project runs no third-party Godot addons. The stick is ~180 lines built on
`InputEventScreenTouch` and `InputEventScreenDrag`.

**Expose `control_scale` and let players size their own controls.** Not a
substitute for a sane default: the setting exists (0.6–2.0) but there is no
settings screen, so on a device it is permanently 1.0. Shipping targets that are
only usable *after* the player finds an options menu is not accessibility.

## Consequences

**Good.** Movement is a single ~18 mm target with no dead zone. Analog movement
arrives free. Every control clears the accessibility floor, and a test keeps it
that way. The stick claims a touch index, so a second finger on attack cannot
steal or cancel movement.

**Costs.** The stick is bespoke code the project now maintains, and will want
revisiting if the project ever moves to Godot 4.7 and could adopt the engine
node. Its geometry is drawn procedurally rather than from art, so it does not
match the pixel-art buttons stylistically — `dpad_base.png` remains unused.

**Untested.** Everything above is verified by unit tests and by screenshots at
2340×1080. Whether it *feels* right under an actual thumb cannot be verified
from a headless container and needs a device playtest — which is exactly how the
original d-pad's problems were found.
