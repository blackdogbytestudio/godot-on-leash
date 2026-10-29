# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogApiGenerator against real scenes: find_scene and build read the fixtures in
## test/doubles/api/scenes, generate writes on a copy in res://scenes/tmp that
## every test removes. The folder settings are pointed at those folders.

const ROOT_DIR := "test/doubles/api/scenes"
const ROOT := "res://" + ROOT_DIR
const TMP_DIR := "scenes/tmp/api_test"
const TMP := "res://" + TMP_DIR
const BOTH := ["fixture_jump_2d", "fixture_dash"]
const KEYS := [DogSettings.IMPLICIT_FOLDER, DogSettings.EXPLICIT_FOLDER]
const ACTOR_GD := "extends CharacterBody2D\n\n\nfunc _ready() -> void:\n\tpass\n"
const ACTOR_TSCN := """[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scenes/tmp/api_test/actor/actor.gd" id="1"]
[ext_resource type="Script" path="res://test/doubles/api/fixture_jump.gd" id="2"]
[ext_resource type="Script" path="res://test/doubles/api/fixture_dash.gd" id="3"]

[node name="Actor" type="CharacterBody2D"]
script = ExtResource("1")

[node name="Jump" type="Node" parent="."]
script = ExtResource("2")

[node name="Dash" type="Node" parent="."]
script = ExtResource("3")
"""

var _saved := {}


func before_each() -> void:
	_saved.clear()
	for key in KEYS:
		if ProjectSettings.has_setting(key):
			_saved[key] = ProjectSettings.get_setting(key)
	_use(ROOT_DIR)


func after_each() -> void:
	_remove_tree(TMP)
	DirAccess.remove_absolute("res://scenes/tmp")  # only succeeds when empty
	for key in KEYS:
		if _saved.has(key):
			ProjectSettings.set_setting(key, _saved[key])
		elif ProjectSettings.has_setting(key):
			ProjectSettings.clear(key)


## Points both folder settings at `dir` (below res://).
func _use(dir: String) -> void:
	for key in KEYS:
		ProjectSettings.set_setting(key, dir)


## Creates the actor in TMP and points the settings at it.
func _use_tmp() -> void:
	DirAccess.make_dir_recursive_absolute(TMP + "/actor")
	_write(TMP + "/actor/actor.gd", ACTOR_GD)
	_write(TMP + "/actor/actor.tscn", ACTOR_TSCN)
	_use(TMP_DIR)


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_remove_tree(path.path_join(sub))
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(path)


func _options(
	actor: String,
	components: Array,
	mode := DogScriptMerge.Mode.ADD,
	write := true,
) -> DogApiGenerator.Options:
	var options := DogApiGenerator.Options.new()
	options.actor = actor
	options.components = components
	options.mode = mode
	options.write = write
	return options


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	return text


func _compile(source: String) -> int:
	var script := GDScript.new()
	# Only checks that it compiles: unused params and signals are expected here.
	var ignore := "@warning_ignore_start(\"unused_parameter\", \"unused_signal\")\n"
	script.source_code = ignore + source
	return script.reload()


# --- find_scene ------------------------------------------------------------


func test_find_scene_without_a_folder_is_under_the_implicit_root() -> void:
	var r := DogApiGenerator.find_scene("actor")
	assert_eq(r.path, ROOT + "/actor/actor.tscn")
	assert_eq(r.error, "")


func test_find_scene_folder_is_the_whole_actor_directory_from_the_explicit_root() -> void:
	var r := DogApiGenerator.find_scene("slime", "enemies/slime")
	assert_eq(r.path, ROOT + "/enemies/slime/slime.tscn")
	assert_eq(r.error, "")


func test_find_scene_folder_does_not_use_the_implicit_root() -> void:
	ProjectSettings.set_setting(DogSettings.IMPLICIT_FOLDER, "somewhere/else")
	var r := DogApiGenerator.find_scene("slime", "enemies/slime")
	assert_eq(r.path, ROOT + "/enemies/slime/slime.tscn")


func test_find_scene_does_not_search_below_the_folder() -> void:
	var r := DogApiGenerator.find_scene("slime", "enemies")
	assert_eq(r.path, "")
	assert_string_contains(r.error, ROOT + "/enemies/slime.tscn")


func test_find_scene_does_not_search_below_the_implicit_root() -> void:
	var r := DogApiGenerator.find_scene("slime")
	assert_eq(r.path, "")
	assert_string_contains(r.error, ROOT + "/slime/slime.tscn")


func test_find_scene_twins_are_told_apart_by_the_folder() -> void:
	assert_eq(DogApiGenerator.find_scene("twin", "a/twin").path, ROOT + "/a/twin/twin.tscn")
	assert_eq(DogApiGenerator.find_scene("twin", "b/twin").path, ROOT + "/b/twin/twin.tscn")
	assert_ne(DogApiGenerator.find_scene("twin").error, "")


func test_find_scene_missing_is_an_error() -> void:
	var r := DogApiGenerator.find_scene("ghost")
	assert_eq(r.path, "")
	assert_string_contains(r.error, "ghost")


func test_find_scene_rejects_invalid_names() -> void:
	for bad in ["Player", "../x", "a b", "", "1abc"]:
		assert_ne(DogApiGenerator.find_scene(bad).error, "", "name '%s'" % bad)


func test_find_scene_rejects_invalid_folders() -> void:
	for bad in ["..", "a//b", "Enemies", "/a"]:
		assert_ne(DogApiGenerator.find_scene("actor", bad).error, "", "folder '%s'" % bad)


func test_find_scene_rejects_an_invalid_explicit_folder_setting() -> void:
	ProjectSettings.set_setting(DogSettings.EXPLICIT_FOLDER, "res://scenes")
	assert_string_contains(DogApiGenerator.find_scene("actor").error, DogSettings.EXPLICIT_FOLDER)


func test_find_scene_rejects_an_invalid_implicit_folder_setting() -> void:
	ProjectSettings.set_setting(DogSettings.IMPLICIT_FOLDER, "Scenes")
	assert_string_contains(DogApiGenerator.find_scene("actor").error, DogSettings.IMPLICIT_FOLDER)


# --- build (reads the real fixture scene, writes nothing) -------------------


func test_build_fills_the_root_script_of_the_scene() -> void:
	var r := DogApiGenerator.build(_options("actor", BOTH))
	assert_eq(r.error, "")
	assert_eq(r.path, ROOT + "/actor/actor.gd")
	assert_eq(r.original, ACTOR_GD)
	assert_string_contains(r.source, "signal landed(speed: float)\nsignal dashed\n")
	assert_string_contains(r.source, "@onready var _fixture_jump_2d: FixtureJump2D = $Jump\n")
	assert_string_contains(r.source, "@onready var _fixture_dash: FixtureDash = $Dash\n")
	assert_string_contains(r.source, "func jump() -> void:\n\t_fixture_jump_2d.jump()\n")
	assert_string_contains(r.source, "func dash() -> void:\n\t_fixture_dash.dash()\n")
	assert_false(r.source.contains("_internal"))


func test_build_inserts_connect_lines_under_the_existing_ready() -> void:
	var r := DogApiGenerator.build(_options("actor", BOTH))
	assert_string_contains(
		r.source,
		(
			"func _ready() -> void:\n"
			+ "\t_fixture_jump_2d.landed.connect(landed.emit)\n"
			+ "\t_fixture_dash.dashed.connect(dashed.emit)\n"
			+ "\tpass\n"
		)
	)
	assert_does_not_have(r.report, "add func _ready")


func test_build_ignores_children_that_were_not_asked_for() -> void:
	var r := DogApiGenerator.build(_options("actor", BOTH))
	assert_eq(r.warnings, [])
	assert_false(r.source.contains("legacy"))


func test_build_generated_source_compiles() -> void:
	for mode in [DogScriptMerge.Mode.ADD, DogScriptMerge.Mode.FORCE]:
		var r := DogApiGenerator.build(_options("actor", BOTH, mode))
		assert_eq(_compile(r.source), OK, "mode %d" % mode)


func test_build_error_when_the_root_node_has_no_script() -> void:
	var r := DogApiGenerator.build(_options("noscript", BOTH))
	assert_string_contains(r.error, "no script")
	assert_eq(r.source, "")


func test_build_without_components_is_an_error_listing_the_candidates() -> void:
	var r := DogApiGenerator.build(_options("actor", []))
	assert_string_contains(r.error, "no components")
	assert_string_contains(r.error, "fixture_jump_2d")
	assert_string_contains(r.error, "fixture_dash")
	assert_eq(r.source, "")


func test_build_only_forwards_the_listed_components() -> void:
	var r := DogApiGenerator.build(_options("actor", ["fixture_dash"]))
	assert_eq(r.error, "")
	assert_string_contains(r.source, "func dash() -> void:")
	assert_false(r.source.contains("jump"))


func test_build_error_when_the_scene_is_missing() -> void:
	var r := DogApiGenerator.build(_options("ghost", BOTH))
	assert_string_contains(r.error, "ghost")


func test_build_reads_the_scene_from_disk_even_when_it_is_cached() -> void:
	_use_tmp()
	# Holding the scene keeps it in the resource cache, as an open editor would.
	var cached := load(TMP + "/actor/actor.tscn") as PackedScene
	_write(TMP + "/actor/actor.tscn", ACTOR_TSCN.replace("Dash", "Sprint"))
	var r := DogApiGenerator.build(_options("actor", BOTH))
	assert_not_null(cached)
	assert_eq(r.error, "")
	assert_string_contains(r.source, "$Sprint")


func test_build_and_generate_return_a_result_even_on_error() -> void:
	assert_true(DogApiGenerator.build(_options("actor", BOTH)) is DogApiGenerator.Result)
	var failed := DogApiGenerator.generate(_options("ghost", BOTH))
	assert_true(failed is DogApiGenerator.Result)
	assert_eq(failed.source, "")
	assert_eq(failed.report, [])


# --- generate (writes, on a copy in res://scenes/tmp) -----------------------


func test_generate_writes_the_merged_source() -> void:
	_use_tmp()
	var r := DogApiGenerator.generate(_options("actor", BOTH))
	assert_eq(r.error, "")
	assert_eq(_read(TMP + "/actor/actor.gd"), r.source)
	assert_string_contains(_read(TMP + "/actor/actor.gd"), "func jump() -> void:")


func test_generate_without_write_leaves_the_file_alone() -> void:
	_use_tmp()
	var r := DogApiGenerator.generate(_options("actor", BOTH, DogScriptMerge.Mode.ADD, false))
	assert_ne(r.source, r.original)
	assert_eq(_read(TMP + "/actor/actor.gd"), ACTOR_GD)


func test_generate_twice_changes_nothing_the_second_time() -> void:
	_use_tmp()
	DogApiGenerator.generate(_options("actor", BOTH))
	var first := _read(TMP + "/actor/actor.gd")
	var r := DogApiGenerator.generate(_options("actor", BOTH))
	assert_eq(_read(TMP + "/actor/actor.gd"), first)
	for line in r.report:
		assert_true(line.begins_with("skip "), line)


func test_generate_update_restores_an_edited_forwarding_func() -> void:
	_use_tmp()
	DogApiGenerator.generate(_options("actor", BOTH))
	var edited := _read(TMP + "/actor/actor.gd").replace(
		"\t_fixture_jump_2d.jump()\n",
		"\tprint(1)\n\t_fixture_jump_2d.jump()\n",
	)
	_write(TMP + "/actor/actor.gd", edited)
	var plain := DogApiGenerator.generate(_options("actor", BOTH))
	assert_string_contains(_read(TMP + "/actor/actor.gd"), "print(1)")
	assert_has(plain.report, "skip func jump")
	var update_options := _options("actor", BOTH, DogScriptMerge.Mode.UPDATE)
	var updated := DogApiGenerator.generate(update_options)
	assert_has(updated.report, "update func jump")
	assert_false(_read(TMP + "/actor/actor.gd").contains("print(1)"))


func test_generate_force_drops_what_was_written_below_the_header() -> void:
	_use_tmp()
	_write(
		TMP + "/actor/actor.gd",
		"extends CharacterBody2D\n\nvar my_counter := 1\n\n\nfunc mine() -> void:\n\tpass\n",
	)
	DogApiGenerator.generate(_options("actor", BOTH, DogScriptMerge.Mode.FORCE))
	var text := _read(TMP + "/actor/actor.gd")
	assert_true(text.begins_with("extends CharacterBody2D\n"))
	assert_false(text.contains("my_counter"))
	assert_false(text.contains("mine"))
	assert_string_contains(text, "func jump() -> void:")


func test_generate_does_not_write_on_error() -> void:
	_use_tmp()
	_write(TMP + "/actor/actor.gd", "extends CharacterBody2D\n\n\nfunc _ready(): pass\n")
	var r := DogApiGenerator.generate(_options("actor", BOTH))
	assert_string_contains(r.error, "_ready")
	assert_eq(_read(TMP + "/actor/actor.gd"), "extends CharacterBody2D\n\n\nfunc _ready(): pass\n")
