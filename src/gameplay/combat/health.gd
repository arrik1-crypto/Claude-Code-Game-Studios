class_name Health
extends Node

## Hit points for any damageable entity.
##
## Deliberately dumb: it tracks a number, clamps it, and announces changes. It
## does not know about knockback, i-frames or death animations — those belong to
## the owning entity, which listens to [signal died] and decides what to do.
##
## The player's Health mirrors its value into [GameState] so that HP survives
## room transitions; see `_on_changed` wiring in player.gd.

## Emitted whenever current HP changes, for any reason.
signal changed(current: int, maximum: int)

## Emitted when HP is reduced. [param info] may be null for scripted damage.
signal damaged(amount: int, info: DamageInfo)

## Emitted when HP is restored.
signal healed(amount: int)

## Emitted once when HP reaches zero. Further damage is ignored afterwards.
signal died()

@export var max_hp: int = 10:
	set(value):
		max_hp = maxi(1, value)
		current_hp = mini(current_hp, max_hp)

## When true, incoming damage is ignored entirely (i-frames, cutscenes).
@export var invulnerable: bool = false

var current_hp: int = 10
var _dead: bool = false


func _ready() -> void:
	if current_hp <= 0:
		current_hp = max_hp


## Configure both the ceiling and the current value, e.g. when spawning an enemy
## from balance.json. Resets the dead flag so pooled entities can be reused.
func setup(maximum: int, current: int = -1) -> void:
	max_hp = maxi(1, maximum)
	current_hp = max_hp if current < 0 else clampi(current, 0, max_hp)
	_dead = current_hp <= 0
	changed.emit(current_hp, max_hp)


func is_dead() -> bool:
	return _dead


func health_fraction() -> float:
	return float(current_hp) / float(maxi(1, max_hp))


## Apply damage. Returns the amount actually taken (0 if invulnerable or dead).
func take_damage(amount: int, info: DamageInfo = null) -> int:
	if _dead or invulnerable or amount <= 0:
		return 0

	var applied: int = mini(amount, current_hp)
	current_hp -= applied
	changed.emit(current_hp, max_hp)
	damaged.emit(applied, info)

	if current_hp <= 0:
		_dead = true
		died.emit()
	return applied


func heal(amount: int) -> int:
	if _dead or amount <= 0:
		return 0
	var applied: int = mini(amount, max_hp - current_hp)
	if applied <= 0:
		return 0
	current_hp += applied
	changed.emit(current_hp, max_hp)
	healed.emit(applied)
	return applied


## Restore to full and clear the dead flag.
func revive(fraction: float = 1.0) -> void:
	_dead = false
	current_hp = clampi(int(round(float(max_hp) * fraction)), 1, max_hp)
	changed.emit(current_hp, max_hp)


## Kill outright, bypassing invulnerability. Used by pits and despawn logic.
func kill() -> void:
	if _dead:
		return
	current_hp = 0
	_dead = true
	changed.emit(current_hp, max_hp)
	died.emit()
