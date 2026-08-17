class_name TestCase
extends RefCounted

## Base class for unit tests.
##
## A deliberately tiny framework rather than a third-party addon: the project has
## no package manager wired up yet, and a vendored test runner would be a
## dependency to maintain. Everything here is ~80 lines and runs headless.
##
## Subclasses live in `tests/unit/<system>/` and are named `<system>_<feature>_test.gd`.
## Every method starting with `test_` is run in isolation, with [method before_each]
## called first.

var failures: PackedStringArray = []
var assertions: int = 0

## Set by the runner so failure messages can name the test.
var current_test: String = ""


## Optional per-test setup hook.
func before_each() -> void:
	pass


## Optional per-test teardown hook.
func after_each() -> void:
	pass


func _fail(message: String) -> void:
	failures.append("%s: %s" % [current_test, message])


func assert_true(condition: bool, message: String = "") -> void:
	assertions += 1
	if not condition:
		_fail("expected true — %s" % message)


func assert_false(condition: bool, message: String = "") -> void:
	assertions += 1
	if condition:
		_fail("expected false — %s" % message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	assertions += 1
	if actual != expected:
		_fail("expected %s, got %s — %s" % [str(expected), str(actual), message])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	assertions += 1
	if actual == unexpected:
		_fail("expected anything but %s — %s" % [str(unexpected), message])


func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.0001,
		message: String = "") -> void:
	assertions += 1
	if absf(actual - expected) > tolerance:
		_fail("expected %f (+/- %f), got %f — %s" % [expected, tolerance, actual, message])


func assert_gt(actual: float, threshold: float, message: String = "") -> void:
	assertions += 1
	if actual <= threshold:
		_fail("expected > %f, got %f — %s" % [threshold, actual, message])


func assert_ge(actual: float, threshold: float, message: String = "") -> void:
	assertions += 1
	if actual < threshold:
		_fail("expected >= %f, got %f — %s" % [threshold, actual, message])


func assert_lt(actual: float, threshold: float, message: String = "") -> void:
	assertions += 1
	if actual >= threshold:
		_fail("expected < %f, got %f — %s" % [threshold, actual, message])


func assert_le(actual: float, threshold: float, message: String = "") -> void:
	assertions += 1
	if actual > threshold:
		_fail("expected <= %f, got %f — %s" % [threshold, actual, message])


func assert_in_range(actual: float, low: float, high: float, message: String = "") -> void:
	assertions += 1
	if actual < low or actual > high:
		_fail("expected within [%f, %f], got %f — %s" % [low, high, actual, message])


func assert_has(container: Variant, key: Variant, message: String = "") -> void:
	assertions += 1
	var present: bool = false
	if container is Dictionary:
		present = (container as Dictionary).has(key)
	elif container is Array:
		present = (container as Array).has(key)
	if not present:
		_fail("expected to contain %s — %s" % [str(key), message])


func assert_not_null(value: Variant, message: String = "") -> void:
	assertions += 1
	if value == null:
		_fail("expected non-null — %s" % message)
