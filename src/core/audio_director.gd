extends Node

## Autoload: music and sound-effect playback.
##
## Owns a small pool of [AudioStreamPlayer] nodes so that rapid-fire effects
## (whip hits, heart pickups) never cut each other off, and cross-fades music
## between the explore and boss cues.
##
## Every stream is optional: if an audio file is missing the director logs once
## and stays silent rather than erroring per-call, so the game remains playable
## while audio is still being produced.

const SFX_POOL_SIZE: int = 12
const MUSIC_FADE_TIME: float = 0.9

const SFX_PATHS: Dictionary = {
	"whip": "res://assets/audio/sfx/whip.wav",
	"hit": "res://assets/audio/sfx/hit.wav",
	"enemy_hit": "res://assets/audio/sfx/enemy_hit.wav",
	"player_hurt": "res://assets/audio/sfx/player_hurt.wav",
	"jump": "res://assets/audio/sfx/jump.wav",
	"land": "res://assets/audio/sfx/land.wav",
	"dash": "res://assets/audio/sfx/dash.wav",
	"pickup": "res://assets/audio/sfx/pickup.wav",
	"heart": "res://assets/audio/sfx/heart.wav",
	"subweapon": "res://assets/audio/sfx/subweapon.wav",
	"level_up": "res://assets/audio/sfx/level_up.wav",
	"save": "res://assets/audio/sfx/save.wav",
	"enemy_death": "res://assets/audio/sfx/enemy_death.wav",
	"player_death": "res://assets/audio/sfx/player_death.wav",
	"boss_hit": "res://assets/audio/sfx/boss_hit.wav",
	"ui_select": "res://assets/audio/sfx/ui_select.wav",
}

const MUSIC_PATHS: Dictionary = {
	"title": "res://assets/audio/music/title.ogg",
	"explore": "res://assets/audio/music/explore.ogg",
	"boss": "res://assets/audio/music/boss.wav",
}

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx: int = 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _current_track: String = ""
var _fade_tween: Tween

var _sfx_cache: Dictionary = {}
var _warned: Dictionary = {}

var music_volume_db: float = -8.0
var sfx_volume_db: float = -4.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i: int in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		player.volume_db = sfx_volume_db
		add_child(player)
		_sfx_players.append(player)

	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_active_music = _music_a

	_connect_events()


func _make_music_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = "Master"
	player.volume_db = -80.0
	add_child(player)
	return player


## Wire the director to gameplay events so no other system needs to know about
## audio. Adding a sound becomes a one-line change here.
func _connect_events() -> void:
	EventBus.enemy_defeated.connect(func(_id: String, _e: int, _g: int) -> void: play_sfx("enemy_death"))
	EventBus.level_up.connect(func(_lvl: int, _s: Dictionary) -> void: play_sfx("level_up"))
	EventBus.player_died.connect(func() -> void: play_sfx("player_death"))
	EventBus.game_saved.connect(func(_slot: int) -> void: play_sfx("save"))
	EventBus.boss_encounter_started.connect(
		func(_id: String, _name: String, _hp: int) -> void: play_music("boss"))
	EventBus.boss_encounter_ended.connect(
		func(_id: String, _defeated: bool) -> void: play_music("explore"))


## Play a named effect from [constant SFX_PATHS].
##
## [param pitch_variation] randomises pitch by +/- this fraction, which stops
## repeated hits from sounding like a machine gun.
func play_sfx(sound: String, volume_offset_db: float = 0.0, pitch_variation: float = 0.08) -> void:
	var stream: AudioStream = _get_sfx(sound)
	if stream == null:
		return

	var player: AudioStreamPlayer = _sfx_players[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx_players.size()

	player.stream = stream
	player.volume_db = sfx_volume_db + volume_offset_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


func _get_sfx(sound: String) -> AudioStream:
	if _sfx_cache.has(sound):
		return _sfx_cache[sound]
	if not SFX_PATHS.has(sound):
		_warn_once("sfx:" + sound, "AudioDirector: unknown sound '%s'" % sound)
		return null

	var path: String = SFX_PATHS[sound]
	if not ResourceLoader.exists(path):
		_warn_once("sfx:" + sound, "AudioDirector: missing audio file %s (staying silent)" % path)
		_sfx_cache[sound] = null
		return null

	var stream: AudioStream = load(path) as AudioStream
	_sfx_cache[sound] = stream
	return stream


## Cross-fade to a music track. Re-requesting the current track is a no-op, so
## room transitions inside the same zone do not restart the music.
func play_music(track: String) -> void:
	if track == _current_track:
		return
	if not MUSIC_PATHS.has(track):
		_warn_once("music:" + track, "AudioDirector: unknown track '%s'" % track)
		return

	var path: String = MUSIC_PATHS[track]
	if not ResourceLoader.exists(path):
		_warn_once("music:" + track, "AudioDirector: missing music file %s (staying silent)" % path)
		return

	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	# Loop whichever container the track arrived in. WAV and Ogg expose looping
	# through different properties, so both are set explicitly rather than
	# relying on the importer's defaults.
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true

	var incoming: AudioStreamPlayer = _music_b if _active_music == _music_a else _music_a
	var outgoing: AudioStreamPlayer = _active_music

	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(incoming, "volume_db", music_volume_db, MUSIC_FADE_TIME)
	_fade_tween.tween_property(outgoing, "volume_db", -80.0, MUSIC_FADE_TIME)
	_fade_tween.chain().tween_callback(outgoing.stop)

	_active_music = incoming
	_current_track = track


func stop_music(fade: bool = true) -> void:
	_current_track = ""
	if not fade:
		_music_a.stop()
		_music_b.stop()
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_active_music, "volume_db", -80.0, MUSIC_FADE_TIME)
	_fade_tween.tween_callback(_active_music.stop)


func set_music_volume_db(db: float) -> void:
	music_volume_db = db
	if _active_music.playing:
		_active_music.volume_db = db


func set_sfx_volume_db(db: float) -> void:
	sfx_volume_db = db


func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(message)
