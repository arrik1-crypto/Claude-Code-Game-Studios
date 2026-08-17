# Control Manifest — Crimson Vespers

**Manifest Version:** 2026-08-17
**Engine:** Godot 4.6 / GDScript
**Derived from:** ADR-001…006, `.claude/rules/`, `.claude/docs/coding-standards.md`

A flat rules sheet for programmers. ADRs explain *why*; this explains *what to do*.
Every story embeds this manifest version; `/story-done` flags staleness.

---

## Layer 1 — Core (`src/core/`)

### Required
- Autoloads are **services**, not gameplay: `EventBus`, `Balance`, `GameState`,
  `AudioDirector`, `SceneDirector`. Nothing else becomes an autoload.
- `EventBus` carries **notifications only** — past tense, no return values, no
  commands. It holds no state.
- All persistent run state lives in `GameState` and nowhere else.
- Every tuning value is read through `Balance`. Missing keys push an error.
- `CombatMath` is `static` and side-effect free: no engine singletons, no node
  lookups, no RNG unless a seed is passed in.

### Forbidden
- Reading `GameState` from `CombatMath` or any other pure-math helper.
- Core code depending on anything in `src/gameplay/` or `src/ui/`.
- Silent fallbacks. A missing config key logs an error; it does not shrug.

### Guardrails
- `FileAccess.store_*` returns `bool` in 4.4+ — **check it**.
- Save/load never partially mutates: a corrupt file leaves the run untouched.

---

## Layer 2 — Gameplay (`src/gameplay/`)

### Required
- **No hardcoded gameplay values.** Every number comes from
  `assets/data/game_balance.json`. Presentation constants (sprite offsets, tween
  durations, z-indices) may live in code as named `const`.
- Multiply every time-dependent value by `delta`.
- Player states extend `PlayerState`; enemies extend `EnemyBase`. Both are
  `@abstract`.
- States hold **no persistent data**. Anything surviving a transition lives on
  the `Player`.
- Damage always flows `Hitbox → DamageInfo → Hurtbox → Health`. Never call
  `Health.take_damage()` directly from an attack.
- Configure a node's exported properties **before** `add_child()`. `_ready` runs
  during `add_child`, and entities read their exports there.
- Free the outgoing room with `free()`, not `queue_free()`, before building the
  incoming one — two rooms must never share the physics space.

### Forbidden
- `get_node()` on a UI node from gameplay code. Emit on `EventBus` instead.
- Static singletons for mutable gameplay state.
- Instantiating a `TileMap` (removed in 4.3) — use `TileMapLayer`.
- Toggling a `CollisionShape2D.disabled` inside a physics callback without
  `set_deferred`.
- Resizing a `CharacterBody2D`'s body collider mid-frame (it pops through floors).
  Resize the hurtbox instead.

### Guardrails
- Physics layers, by name, from `project.godot`:
  | Layer | Bit | Used by |
  |---|---:|---|
  | `world` | 1 | Tiles, mist gates |
  | `player` | 2 | Player body + hurtbox |
  | `enemy` | 4 | Enemy bodies + hurtboxes |
  | `player_hitbox` | 8 | Whip, player projectiles |
  | `enemy_hitbox` | 16 | Contact damage, enemy projectiles |
  | `pickup` | 32 | Collectables |
  | `interactable` | 64 | Doors, coffins, pedestals |
  | `one_way` | 128 | Drop-through platforms |
- Hurtboxes set a collision **layer** and no mask. Hitboxes set a **mask**.
- A hitbox never damages its own `attacker`.

---

## Layer 3 — UI (`src/ui/`)

### Required
- UI is **reactive**: subscribe to `EventBus`, never poll gameplay nodes.
- Paint current state in `_ready` so a freshly built HUD is never blank.
- Every action must be reachable by touch, with no gestures.
- Overlays that must work while paused set `PROCESS_MODE_ALWAYS`.

### Forbidden
- UI writing to gameplay state directly (except `SceneDirector` calls).
- Branching on input method. Touch, keyboard and gamepad drive identical
  `InputMap` actions.
- Leaving an action pressed when a control layer is removed — release in
  `_exit_tree`.

---

## Layer 4 — Data (`assets/data/`)

### Required
- Filenames follow `[system]_[name].json`, lowercase with underscores.
- Keys are **camelCase** — except identifier keys that are shared with asset
  filenames and animation names (`bone_sentry`, `holy_water`, `brick_solid`),
  which stay snake_case.
- Every data file has a documented schema in its owning design doc.
- Room files pass `tools/ci/validate_rooms.py` before commit.

### Forbidden
- Orphaned entries. Every enemy, pickup and tile must be referenced by code or
  another data file.
- Adding a tuning key without documenting it in the owning GDD's Tuning Knobs.

---

## Layer 5 — Assets & pipeline (`tools/asset-pipeline/`)

### Required
- Generated art is **deterministic** — no RNG. Re-running must produce identical
  bytes.
- Third-party pack assets stay unmodified in `Game-Assets-And-Resources/`;
  game-ready copies are produced by `import_pack_assets.py`.
- Sprite atlases ship a JSON manifest beside the PNG, paired by basename.
- Characters are authored facing **right**; the engine flips.

### Forbidden
- Hand-editing anything under `assets/art/` that a generator or importer owns.
- Committing a `.tres` `SpriteFrames` — they are built at runtime from manifests.

---

## Testing

### Required
- Every formula in `CombatMath` has a unit test covering its boundaries.
- Every new enemy, room or tuning block extends the relevant data test.
- Tests are deterministic: no RNG, no wall-clock, no execution-order dependence.
- Each test constructs and tears down its own state.

### Forbidden
- Skipping or disabling a failing test to get CI green.
- Asserting only that something exists. Assert what it *does* — the tileset test
  checks collision polygons, not tile count, because the bug it caught produced
  tiles with no collision.

### Commands
```bash
python3 tools/ci/validate_rooms.py                     # room data
godot --headless --path . res://tests/test_runner.tscn # unit + integration
xvfb-run -a godot --path . --rendering-driver opengl3 \
    res://tools/debug/capture_scene.tscn -- --out=/tmp/shots   # smoke + screenshots
```
