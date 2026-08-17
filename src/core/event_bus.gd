extends Node

## Autoload: global signal hub.
##
## Systems that must not know about each other — HUD and combat, map and rooms,
## audio and everything — communicate through here. The rule is deliberately
## narrow: EventBus carries *notifications*, never commands, and never holds
## state. Anything that needs to be remembered belongs in GameState.

# -- Combat ------------------------------------------------------------------

## A damageable entity took damage. [param target] is the node that was hit.
signal damage_dealt(target: Node, amount: int, is_critical: bool)

## Player health changed for any reason (damage, healing, level up).
signal player_health_changed(current: int, maximum: int)

## Player magic points changed.
signal player_mp_changed(current: float, maximum: float)

## Player heart count changed (the sub-weapon resource).
signal player_hearts_changed(current: int, maximum: int)

## Player gold changed.
signal player_gold_changed(amount: int)

## Player died. Emitted once, before the game-over flow begins.
signal player_died()

## An enemy was defeated. Carries rewards so the HUD and progression can react.
signal enemy_defeated(enemy_id: String, exp_reward: int, gold_reward: int)

# -- Progression -------------------------------------------------------------

## Player gained experience.
signal exp_gained(amount: int, total: int)

## Player reached a new level.
signal level_up(new_level: int, stats: Dictionary)

## A traversal ability was unlocked (double_jump, mist_dash, ...).
signal ability_unlocked(ability_id: String)

## A sub-weapon was picked up and equipped.
signal subweapon_equipped(subweapon_id: String)

# -- World -------------------------------------------------------------------

## A room finished loading. [param room_id] matches design/levels/room-graph.md.
signal room_entered(room_id: String)

## The player left a room (emitted before the next room loads).
signal room_exited(room_id: String)

## A room was revealed on the map for the first time.
signal room_discovered(room_id: String)

## The game was saved at a save point.
signal game_saved(slot: int)

## A save was loaded into GameState.
signal game_loaded(slot: int)

# -- Boss --------------------------------------------------------------------

## A boss encounter began; the HUD shows the boss bar in response.
signal boss_encounter_started(boss_id: String, display_name: String, max_hp: int)

## Boss health changed.
signal boss_health_changed(current: int, maximum: int)

## Boss encounter ended. [param defeated] distinguishes a win from a player death.
signal boss_encounter_ended(boss_id: String, defeated: bool)

# -- Presentation ------------------------------------------------------------

## Request a screen shake. Systems emit this; the camera decides how to honour it.
signal screen_shake_requested(strength: float, duration: float)

## Request a brief hit-stop freeze, in seconds of unscaled time.
signal hit_stop_requested(duration: float)

## Show a transient message in the HUD (item pickups, ability unlocks).
signal toast_requested(message: String)
