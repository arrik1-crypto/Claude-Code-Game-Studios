class_name MistGate
extends StaticBody2D

## A shimmering barrier that only the Mist Dash can cross.
##
## The gate is a normal solid wall until the player enters mist form, at which
## point every gate in the room turns permeable at once — [Player] broadcasts to
## the `mist_gates` group rather than each gate polling the player.
##
## Gates stay visible when permeable (dimmed rather than hidden) so the player
## can see they went through something, which is what teaches the mechanic.

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var visual: ColorRect = $Visual

var _permeable: bool = false


func _ready() -> void:
	add_to_group(&"mist_gates")
	_apply_state()


## Called on the whole group by [method Player.set_mist_intangible].
func set_permeable(permeable: bool) -> void:
	if _permeable == permeable:
		return
	_permeable = permeable
	_apply_state()


func _apply_state() -> void:
	# Deferred: collision shapes must not be toggled during physics resolution.
	collision.set_deferred("disabled", _permeable)
	visual.modulate.a = 0.28 if _permeable else 0.85


func is_permeable() -> bool:
	return _permeable
