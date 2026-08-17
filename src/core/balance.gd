extends Node

## Autoload: read-only access to assets/data/balance.json.
##
## The coding standard forbids hardcoded gameplay values, so every system pulls
## its numbers through here. Lookups fail loudly rather than silently returning
## a default — a typo'd tuning key should break in the first playtest, not
## quietly change balance.

const BALANCE_PATH: String = "res://assets/data/game_balance.json"

var _data: Dictionary = {}
var _loaded: bool = false


func _ready() -> void:
	load_balance()


## Load (or reload) the balance table. Safe to call at runtime for hot-tuning.
func load_balance(path: String = BALANCE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		push_error("Balance: missing data file at %s" % path)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Balance: could not open %s (error %d)" % [path, FileAccess.get_open_error()])
		return false

	var text: String = file.get_as_text()
	file.close()

	var parser: JSON = JSON.new()
	var err: int = parser.parse(text)
	if err != OK:
		push_error("Balance: JSON parse error in %s at line %d: %s"
			% [path, parser.get_error_line(), parser.get_error_message()])
		return false

	if typeof(parser.data) != TYPE_DICTIONARY:
		push_error("Balance: %s must contain a JSON object at the top level" % path)
		return false

	_data = parser.data
	_loaded = true
	return true


## True once the table has been parsed successfully.
func is_loaded() -> bool:
	return _loaded


## Fetch a whole section, e.g. `Balance.section("movement")`.
func section(name: String) -> Dictionary:
	if not _data.has(name):
		push_error("Balance: no section named '%s'" % name)
		return {}
	var value: Variant = _data[name]
	if typeof(value) != TYPE_DICTIONARY:
		push_error("Balance: section '%s' is not an object" % name)
		return {}
	return value


## Fetch a named entry inside a section, e.g. `Balance.entry("enemies", "nightwing")`.
func entry(section_name: String, key: String) -> Dictionary:
	var sec: Dictionary = section(section_name)
	if not sec.has(key):
		push_error("Balance: section '%s' has no entry '%s'" % [section_name, key])
		return {}
	var value: Variant = sec[key]
	if typeof(value) != TYPE_DICTIONARY:
		push_error("Balance: '%s.%s' is not an object" % [section_name, key])
		return {}
	return value


## Read a float from a section. [param fallback] is used only if the key is
## absent, and an error is pushed so the omission is still visible.
func get_float(section_name: String, key: String, fallback: float = 0.0) -> float:
	var sec: Dictionary = section(section_name)
	if not sec.has(key):
		push_error("Balance: '%s.%s' not found; using %f" % [section_name, key, fallback])
		return fallback
	return float(sec[key])


## Read an int from a section.
func get_int(section_name: String, key: String, fallback: int = 0) -> int:
	var sec: Dictionary = section(section_name)
	if not sec.has(key):
		push_error("Balance: '%s.%s' not found; using %d" % [section_name, key, fallback])
		return fallback
	return int(sec[key])


## Read a float from an arbitrary dictionary, with a visible error on absence.
## Used by systems that have already fetched their config block.
static func field(config: Dictionary, key: String, fallback: float = 0.0) -> float:
	if not config.has(key):
		push_error("Balance: config block is missing key '%s'; using %f" % [key, fallback])
		return fallback
	return float(config[key])


## Integer variant of [method field].
static func field_int(config: Dictionary, key: String, fallback: int = 0) -> int:
	if not config.has(key):
		push_error("Balance: config block is missing key '%s'; using %d" % [key, fallback])
		return fallback
	return int(config[key])
