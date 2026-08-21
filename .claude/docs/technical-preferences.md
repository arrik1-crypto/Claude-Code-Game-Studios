# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6 (pinned — `docs/engine-reference/godot/VERSION.md`)
- **Language**: GDScript, statically typed
- **Rendering**: `mobile` renderer; OpenGL3 compatibility fallback for CI capture
- **Physics**: Godot Physics 2D (Jolt is 3D-only and does not apply here)

## Input & Platform

- **Target Platforms**: Android and iOS phones/tablets; desktop for development
- **Input Methods**: Touch, keyboard, gamepad — all driving the same `InputMap`
- **Primary Input**: Touch (landscape, two thumbs)
- **Gamepad Support**: Full
- **Touch Support**: Full — scalable, adjustable-opacity, hideable overlay
- **Platform Notes**: 480×270 reference viewport, `canvas_items` stretch with
  `expand`. HUD is confined to the top-left, clear of both thumb zones. No
  gesture input anywhere.

## Naming Conventions

- **Classes**: `PascalCase` (`CombatMath`, `RelicPedestal`)
- **Variables / functions**: `snake_case`; private members prefixed `_`
- **Signals**: `snake_case`, past tense (`damage_dealt`, `room_entered`)
- **Files**: `snake_case.gd` / `snake_case.tscn`
- **Scenes**: named after their root node
- **Constants**: `SCREAMING_SNAKE_CASE`
- **Data files**: `[system]_[name].json`; keys `camelCase`, except identifier
  keys shared with asset filenames (`bone_sentry`, `brick_solid`)

## Performance Budgets

- **Target Framerate**: 60 fps on a mid-range 2022 Android device
- **Frame Budget**: 16.6 ms
- **Draw Calls**: < 120 per frame (one room, ≤ 12 entities)
- **Memory Ceiling**: 256 MB resident; one room streamed at a time
- **Export Size**: < 80 MB

## Testing

- **Framework**: Bespoke headless runner — `tests/test_runner.tscn`, base class
  `tests/test_case.gd`. No third-party addon.
- **Minimum Coverage**: 100% of `CombatMath`; every balance and room data file
  under assertion; every room built in an integration test.
- **Required Tests**: Balance formulas, progression curve, health component,
  room graph integrity, tileset collision.
- **Current status**: 167 tests / 1532 assertions, all passing.

## Forbidden Patterns

- Hardcoded gameplay values (all tuning lives in `assets/data/game_balance.json`)
- `TileMap` (removed 4.3 — use `TileMapLayer`)
- String-based `connect()` (use `signal.connect(callable)`)
- `$NodePath` lookups inside `_process` / `_physics_process`
- Untyped `Array` / `Dictionary` in new code
- Static singletons for mutable gameplay state
- Configuring exported properties *after* `add_child()`
- Branching on input method in gameplay code
- Writing `monitoring` / `monitorable`, or adding an `Area2D` to the tree, from
  inside a collision callback — the physics server is flushing queries there and
  drops the change with "Can't change this state while flushing queries". Use
  `set_deferred` / `add_child.call_deferred`.
- A child node calling back into its parent during its own `_ready`. Godot
  readies children first, so every `@onready` on the parent is still null.
- `FileAccess.file_exists()` on an imported resource (`.png`, `.ogg`, `.wav`).
  An exported build ships only the imported form under `.godot/imported/`, so
  this is always false in an export and always true in the editor. Use
  `ResourceLoader.exists()`. `FileAccess` is correct only for files Godot ships
  verbatim, such as our JSON.
- Positioning UI at fixed viewport coordinates. The project stretches with
  `expand`, so a 19.5:9 phone gets a ~585x270 canvas and anything authored near
  x=480 lands mid-screen. Anchor to a corner.
- `PROCESS_MODE_PAUSABLE` on the touch control layer. It contains the button
  that pauses the game, so pausing freezes the only way back out and a
  touch-only player must force-quit. Use `PROCESS_MODE_ALWAYS` and hide the
  gameplay buttons on `EventBus.overlay_toggled`.
- Prompting the player with a key name without checking there is a keyboard.
- Gating a state machine's update on a "can the player act" flag. Control means
  the player may *act*; states still have to tick so gravity, timers and the
  death hand-off keep running. Gate input instead — `Player.wants()` /
  `just_pressed()` are the chokepoints.
- Assuming `StateMachine.transition_to` takes effect immediately. It queues, and
  the current state's next update runs *first* and can overwrite it. Use
  `transition_now()` from signal handlers.
- A touch target under ~9 mm on a 1080p phone (40 canvas units at the 480x270
  reference). Asserted by `ui_touch_anchoring_test.gd`.

## Allowed Libraries / Addons

- None. No third-party Godot addons are in use.
- Asset pipeline (Python, dev-only): Pillow.

## Architecture Decisions Log

| ADR | Title | Status |
|---|---|---|
| ADR-001 | Godot 4.6 with GDScript | Accepted |
| ADR-002 | Autoload service layer and EventBus | Accepted |
| ADR-003 | Node-based finite state machine for the player | Accepted |
| ADR-004 | Area2D hitbox/hurtbox combat with a layer matrix | Accepted |
| ADR-005 | Data-driven balance and rooms | Accepted |
| ADR-006 | Runtime construction of SpriteFrames and TileSet | Accepted |
| ADR-007 | Rendering and lighting | Accepted |
| ADR-008 | Touch input scheme (virtual stick) | Accepted |

## Engine Specialists

- **Primary**: `godot-specialist`
- **Language/Code Specialist**: `godot-gdscript-specialist`
- **Shader Specialist**: `godot-shader-specialist`
- **UI Specialist**: `godot-specialist` (no dedicated Godot UI agent exists)
- **Additional Specialists**: `godot-csharp-specialist` and
  `godot-gdextension-specialist` are available but unused — the project is
  GDScript-only.
- **Routing Notes**: Gameplay code routes to the GDScript specialist. Anything
  touching the room builder, tileset construction or autoload wiring routes to
  the primary specialist, since those cross system boundaries.

### File Extension Routing

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| `*.gd` (gameplay code) | `godot-gdscript-specialist` |
| `*.gdshader` / material | `godot-shader-specialist` |
| `src/ui/**` screens | `godot-gdscript-specialist` |
| `*.tscn` scene / room data | `godot-specialist` |
| Native extension / plugin | `godot-gdextension-specialist` |
| General architecture review | `godot-specialist` |
