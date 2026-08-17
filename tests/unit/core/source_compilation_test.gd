extends TestCase

## Every GDScript under `src/` must actually compile.
##
## This exists because `parallax_backdrop.gd` shipped in a commit with a parse
## error — it assigned `modulate` on a `ParallaxBackground`, which is a
## `CanvasLayer` and has no such property. Nothing caught it: the 111 tests in
## this suite never touch the world scene, and the screenshot harness reported
## PASS because a failed script load is an engine error, not a harness error.
##
## The failure was not even contained. `world.gd` declares a typed field of that
## class, so the broken script took `world.gd` down with it, and the parallax
## backdrop silently never rendered while the screenshots looked plausible —
## the room's own background tile layer was standing in for it.
##
## A compile check is cheap and total. Every script, every commit.

const SOURCE_ROOT: String = "res://src"

## Scripts that legitimately cannot be instantiated: `@abstract` base classes and
## scripts whose base type is itself abstract. They still have to *compile*, so
## they are checked for a resolved base type, just not for instantiability.
const ABSTRACT_MARKER: String = "@abstract"


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
			var clean: String = entry.trim_suffix(".remap")
			if clean.ends_with(".gd"):
				found.append("%s/%s" % [root, clean])
		entry = dir.get_next()
	dir.list_dir_end()
	return found


func test_the_source_tree_is_discoverable() -> void:
	# A discovery bug would make every other assertion here vacuously true.
	assert_gt(float(_discover(SOURCE_ROOT).size()), 30.0,
		"expected to find the project's scripts under %s" % SOURCE_ROOT)


func test_every_source_script_compiles() -> void:
	for path: String in _discover(SOURCE_ROOT):
		var script: GDScript = load(path) as GDScript
		assert_not_null(script, "%s failed to load as a GDScript" % path)
		if script == null:
			continue

		# A script that fails to compile still loads as an object, but it never
		# resolves a base type. That is the signal a parse error leaves behind.
		var base: String = String(script.get_instance_base_type())
		assert_true(base != "",
			"%s does not compile — it resolved no base type" % path)


func test_every_concrete_script_can_be_instantiated() -> void:
	for path: String in _discover(SOURCE_ROOT):
		var script: GDScript = load(path) as GDScript
		if script == null:
			continue

		var source: String = script.source_code
		if source.contains(ABSTRACT_MARKER):
			continue

		assert_true(script.can_instantiate(),
			"%s compiles but cannot be instantiated" % path)
