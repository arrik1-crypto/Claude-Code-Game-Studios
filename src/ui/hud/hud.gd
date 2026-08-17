class_name HUD
extends CanvasLayer

## The in-game heads-up display.
##
## Purely reactive: the HUD subscribes to [EventBus] and never reaches into
## gameplay nodes. That is what lets the World rebuild a room — or the player be
## freed and respawned — without the HUD needing to re-bind to anything.
##
## Bars are animated towards their target rather than snapped, so a big hit reads
## as a drain and a level-up reads as a surge.

const BAR_LERP_SPEED: float = 6.0
const TOAST_DURATION: float = 2.2

@onready var hp_fill: ColorRect = %HpFill
@onready var mp_fill: ColorRect = %MpFill
@onready var hp_label: Label = %HpLabel
@onready var stats_label: Label = %StatsLabel
@onready var hearts_label: Label = %HeartsLabel
@onready var subweapon_label: Label = %SubweaponLabel
@onready var toast_label: Label = %ToastLabel
@onready var boss_panel: Control = %BossPanel
@onready var boss_fill: ColorRect = %BossFill
@onready var boss_name: Label = %BossName

var _hp_width: float = 0.0
var _mp_width: float = 0.0
var _boss_width: float = 0.0

var _hp_target: float = 1.0
var _mp_target: float = 1.0
var _boss_target: float = 1.0

var _toast_timer: float = 0.0


func _ready() -> void:
	layer = 10

	_hp_width = hp_fill.size.x
	_mp_width = mp_fill.size.x
	_boss_width = boss_fill.size.x

	boss_panel.visible = false
	toast_label.visible = false

	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.player_mp_changed.connect(_on_mp_changed)
	EventBus.player_hearts_changed.connect(_on_hearts_changed)
	EventBus.player_gold_changed.connect(_on_gold_changed)
	EventBus.level_up.connect(_on_level_up)
	EventBus.exp_gained.connect(_on_exp_gained)
	EventBus.subweapon_equipped.connect(_on_subweapon_equipped)
	EventBus.ability_unlocked.connect(_on_ability_unlocked)
	EventBus.toast_requested.connect(show_toast)

	EventBus.boss_encounter_started.connect(_on_boss_started)
	EventBus.boss_health_changed.connect(_on_boss_health_changed)
	EventBus.boss_encounter_ended.connect(_on_boss_ended)

	# Paint the current state immediately; the player also re-emits on spawn, but
	# doing it here means the HUD is never blank for a frame.
	_on_health_changed(GameState.current_hp, GameState.max_hp)
	_on_mp_changed(GameState.current_mp, GameState.max_mp)
	_on_hearts_changed(GameState.hearts, GameState.max_hearts)
	_on_subweapon_equipped(GameState.equipped_subweapon)
	_refresh_stats()


func _process(delta: float) -> void:
	var t: float = clampf(delta * BAR_LERP_SPEED, 0.0, 1.0)
	hp_fill.size.x = lerpf(hp_fill.size.x, _hp_width * _hp_target, t)
	mp_fill.size.x = lerpf(mp_fill.size.x, _mp_width * _mp_target, t)
	if boss_panel.visible:
		boss_fill.size.x = lerpf(boss_fill.size.x, _boss_width * _boss_target, t)

	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			toast_label.visible = false


# -- Player state ------------------------------------------------------------


func _on_health_changed(current: int, maximum: int) -> void:
	_hp_target = clampf(float(current) / float(maxi(1, maximum)), 0.0, 1.0)
	hp_label.text = "%d/%d" % [current, maximum]


func _on_mp_changed(current: float, maximum: float) -> void:
	_mp_target = clampf(current / maxf(1.0, maximum), 0.0, 1.0)


func _on_hearts_changed(current: int, _maximum: int) -> void:
	hearts_label.text = "♥ %d" % current


func _on_gold_changed(_amount: int) -> void:
	_refresh_stats()


func _on_exp_gained(_amount: int, _total: int) -> void:
	_refresh_stats()


func _on_level_up(level: int, _stats: Dictionary) -> void:
	_refresh_stats()
	show_toast("Level %d" % level)


func _on_subweapon_equipped(subweapon_id: String) -> void:
	if subweapon_id == "":
		subweapon_label.text = "— none —"
		return
	var cfg: Dictionary = Balance.entry("subweapons", subweapon_id)
	subweapon_label.text = "%s (%d♥)" % [
		String(cfg.get("displayName", subweapon_id)),
		int(cfg.get("heartCost", 1)),
	]


func _on_ability_unlocked(ability_id: String) -> void:
	match ability_id:
		GameState.ABILITY_DOUBLE_JUMP:
			show_toast("Twin Step — jump again in mid-air")
		GameState.ABILITY_MIST_DASH:
			show_toast("Mist Dash — pass through the blue gates")
		_:
			show_toast("New ability unlocked")


func _refresh_stats() -> void:
	stats_label.text = "LV %d   EXP %d   %d G" % [
		GameState.level, GameState.exp_to_next_level(), GameState.gold]


## Show a transient message near the bottom of the screen.
func show_toast(message: String) -> void:
	toast_label.text = message
	toast_label.visible = true
	_toast_timer = TOAST_DURATION


# -- Boss --------------------------------------------------------------------


func _on_boss_started(_boss_id: String, display_name: String, _max_hp: int) -> void:
	boss_panel.visible = true
	boss_name.text = display_name
	_boss_target = 1.0
	boss_fill.size.x = _boss_width


func _on_boss_health_changed(current: int, maximum: int) -> void:
	_boss_target = clampf(float(current) / float(maxi(1, maximum)), 0.0, 1.0)


func _on_boss_ended(_boss_id: String, defeated: bool) -> void:
	boss_panel.visible = false
	if defeated:
		show_toast("The Sanguine Knight falls.")
