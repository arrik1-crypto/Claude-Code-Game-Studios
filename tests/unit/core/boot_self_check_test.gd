extends TestCase

## The boot self-check must stay correct in an *exported* build, not just here.
##
## This is a subtle one to test, because the editor cannot reproduce the failure.
## In the editor the source `assets/art/characters/hero.png` is sitting right
## there on disk, so `FileAccess.file_exists` on it returns true and a wrong
## check looks perfectly healthy. An export ships only the imported form —
## `.godot/imported/hero.png-<hash>.ctex` — and the same call returns false.
##
## That is exactly what happened: the self-check reported four missing textures
## on every launch of the exported Linux build and the Android APK, while the
## game rendered them all correctly. Nothing caught it, because every test and
## every screenshot ran against the editor's filesystem.
##
## So these tests assert the *mechanism* rather than the outcome. `ResourceLoader`
## resolves through the import remap and is therefore true in both contexts;
## `FileAccess` is only correct for files Godot ships verbatim.

const BOOT_SCRIPT: String = "res://src/core/boot.gd"

var _boot: GDScript


func before_each() -> void:
	_boot = load(BOOT_SCRIPT) as GDScript


func test_the_boot_script_loads() -> void:
	assert_not_null(_boot, "boot.gd must load")


func test_required_textures_resolve_through_the_resource_loader() -> void:
	# This is the check that survives export. If a texture were genuinely
	# missing, or a path had a typo, this fails in the editor too.
	var textures: PackedStringArray = _boot.get("REQUIRED_TEXTURES")
	assert_gt(float(textures.size()), 0.0, "the texture list must not be empty")
	for path: String in textures:
		assert_true(ResourceLoader.exists(path),
			"%s must resolve through ResourceLoader" % path)


func test_required_textures_are_imported_resources_not_plain_files() -> void:
	# Guards the split: anything in REQUIRED_TEXTURES must be a resource Godot
	# imports, i.e. it must have an accompanying .import descriptor. If a plain
	# data file were listed here it would be checked the wrong way round.
	var textures: PackedStringArray = _boot.get("REQUIRED_TEXTURES")
	for path: String in textures:
		var message: String = ("%s is in REQUIRED_TEXTURES but has no .import "
			+ "descriptor, so it is not an imported resource") % path
		assert_true(FileAccess.file_exists(path + ".import"), message)


func test_required_data_files_are_shipped_verbatim() -> void:
	# The mirror of the above: these must NOT be imported resources, or they
	# would be subject to the same remap and FileAccess would be wrong for them.
	var data_files: PackedStringArray = _boot.get("REQUIRED_DATA_FILES")
	assert_gt(float(data_files.size()), 0.0, "the data file list must not be empty")
	for path: String in data_files:
		assert_true(FileAccess.file_exists(path), "%s must exist on disk" % path)
		assert_false(FileAccess.file_exists(path + ".import"),
			"%s is in REQUIRED_DATA_FILES but Godot imports it" % path)


func test_the_self_check_passes_on_this_project() -> void:
	var boot: Node = _boot.new()
	var problems: PackedStringArray = boot.run_self_check()
	var joined: String = ", ".join(problems)
	assert_eq(problems.size(), 0, "boot self-check reported: %s" % joined)
	boot.free()
