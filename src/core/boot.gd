extends Node

## First scene loaded. Verifies the project is wired up, then hands off to the
## title screen.
##
## The checks here exist because the failures they catch are silent ones: a
## dropped input action in project.godot or a missing generated atlas does not
## crash Godot, it just produces a game where jumping does nothing or every
## sprite is invisible. Failing loudly at boot turns a confusing playtest into a
## one-line error.

## Every action gameplay depends on. Must match the [input] block of project.godot.
const REQUIRED_ACTIONS: PackedStringArray = [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "attack", "subweapon", "dash",
	"pause", "map_screen", "interact", "ui_confirm",
]

## Plain data files, shipped byte-for-byte. Godot does not import these, so the
## filesystem is the right place to look for them.
const REQUIRED_DATA_FILES: PackedStringArray = [
	"res://assets/data/game_balance.json",
	"res://assets/art/characters/hero.json",
	"res://assets/art/tiles/castle_tileset.json",
]

## Imported resources the game cannot render without.
##
## These MUST be checked with [ResourceLoader], never [FileAccess]. An exported
## build ships the *imported* form — `.godot/imported/hero.png-<hash>.ctex` — and
## never the source `.png`, so `FileAccess.file_exists("...hero.png")` is false
## in every export even though the texture loads perfectly. Checked the wrong
## way, this self-check reported four missing assets on every launch of the
## Android APK and the Linux build while the game rendered correctly.
## `ResourceLoader.exists` resolves through the import remap and is true in both
## the editor and an export.
const REQUIRED_TEXTURES: PackedStringArray = [
	"res://assets/art/characters/hero.png",
	"res://assets/art/tiles/castle_tileset.png",
	"res://assets/art/props/props.png",
	"res://assets/art/vfx/vfx.png",
]


func _ready() -> void:
	var problems: PackedStringArray = run_self_check()
	for problem: String in problems:
		push_error("Boot: %s" % problem)

	if problems.is_empty():
		print("Crimson Vespers %s — boot checks passed."
			% ProjectSettings.get_setting("application/config/version", "dev"))

	# Head to the title screen either way: a partially-broken build is still more
	# useful to look at than a black screen.
	SceneDirector.go_to_title()


## Returns a list of problems; empty means everything checked out.
## Exposed so the headless test suite can assert on it.
func run_self_check() -> PackedStringArray:
	var problems: PackedStringArray = []

	for action: String in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			problems.append("input action '%s' is missing from project.godot" % action)

	for path: String in REQUIRED_DATA_FILES:
		if not FileAccess.file_exists(path):
			problems.append("missing data file '%s' — run tools/asset-pipeline/generate_assets.py" % path)

	for path: String in REQUIRED_TEXTURES:
		if not ResourceLoader.exists(path):
			problems.append("missing texture '%s' — run tools/asset-pipeline/generate_assets.py" % path)

	if not Balance.is_loaded():
		problems.append("balance data failed to load")

	if RoomIndex.all().is_empty():
		problems.append("no room definitions found under assets/data/rooms/")

	return problems
