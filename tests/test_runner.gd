extends Node

## Headless test runner.
##
##     godot --headless --path . res://tests/test_runner.tscn
##
## Runs as a scene rather than via `--script` so the project's autoloads
## (Balance, GameState, EventBus) are available — several suites verify the real
## balance data, not a fixture of it.
##
## Exits 0 when everything passes and 1 otherwise, so CI can gate on it.

## Covers both `tests/unit` and `tests/integration`; discovery is by the
## `_test.gd` suffix, so the runner itself and the base class are skipped.
const TEST_ROOT: String = "res://tests"

var _total: int = 0
var _passed: int = 0
var _failed: int = 0
var _assertions: int = 0
var _failures: PackedStringArray = []


func _ready() -> void:
	# Integration suites parent real nodes under the scene root. `_ready` runs
	# while the tree is still setting up its children and `add_child` is rejected
	# there, so hand control back for one frame before running anything.
	await get_tree().process_frame

	print("Crimson Vespers — test suite")
	print("=".repeat(60))

	var scripts: PackedStringArray = _discover(TEST_ROOT)
	scripts.sort()

	if scripts.is_empty():
		printerr("No test scripts found under %s" % TEST_ROOT)
		get_tree().quit(1)
		return

	for path: String in scripts:
		_run_suite(path)

	_summarise()
	get_tree().quit(1 if _failed > 0 else 0)


## Recursively collect `*_test.gd` files.
func _discover(root: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return found

	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				found.append_array(_discover("%s/%s" % [root, entry]))
		else:
			# Exported builds append .remap; tolerate both spellings.
			var clean: String = entry.trim_suffix(".remap")
			if clean.ends_with("_test.gd"):
				found.append("%s/%s" % [root, clean])
		entry = dir.get_next()
	dir.list_dir_end()
	return found


func _run_suite(path: String) -> void:
	var script: GDScript = load(path) as GDScript
	if script == null:
		_failed += 1
		_failures.append("%s: could not be loaded" % path)
		return

	var suite_name: String = path.get_file().trim_suffix(".gd")
	print("\n%s" % suite_name)

	# One instance per test method keeps state from leaking between tests, which
	# the testing standards require.
	var probe: Object = script.new()
	if not (probe is TestCase):
		_failed += 1
		_failures.append("%s: does not extend TestCase" % path)
		return

	var method_names: PackedStringArray = []
	for method: Dictionary in probe.get_method_list():
		var name: String = String(method["name"])
		if name.begins_with("test_") and not method_names.has(name):
			method_names.append(name)
	method_names.sort()

	if method_names.is_empty():
		print("  (no tests)")
		return

	for method_name: String in method_names:
		var case: TestCase = script.new() as TestCase
		case.current_test = method_name
		_total += 1

		case.before_each()
		case.call(method_name)
		case.after_each()

		_assertions += case.assertions
		if case.failures.is_empty():
			_passed += 1
			print("  PASS  %s" % method_name)
		else:
			_failed += 1
			for failure: String in case.failures:
				_failures.append("%s :: %s" % [suite_name, failure])
			print("  FAIL  %s" % method_name)
			for failure: String in case.failures:
				print("          %s" % failure)


func _summarise() -> void:
	print("\n" + "=".repeat(60))
	print("%d test(s), %d assertion(s): %d passed, %d failed"
		% [_total, _assertions, _passed, _failed])
	if _failed > 0:
		print("\nFailures:")
		for failure: String in _failures:
			print("  - %s" % failure)
		print("\nRESULT: FAIL")
	else:
		print("RESULT: PASS")
