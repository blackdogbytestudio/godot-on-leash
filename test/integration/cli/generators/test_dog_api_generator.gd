# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogApiGenerator against real scenes: find_scene and build read the fixtures in
## test/doubles/api/scenes, generate writes on a copy in user://.

const ROOT := "res://test/doubles/api/scenes"
const BOTH := ["fixture_jump_2d", "fixture_dash"]
const TMP := "user://api_test"
const ACTOR_GD := "extends CharacterBody2D\n\n\nfunc _ready() -> void:\n\tpass\n"
const ACTOR_TSCN := """[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="user://api_test/actor/actor.gd" id="1"]
[ext_resource type="Script" path="res://test/doubles/api/fixture_jump.gd" id="2"]
[ext_resource type="Script" path="res://test/doubles/api/fixture_dash.gd" id="3"]

[node name="Actor" type="CharacterBody2D"]
script = ExtResource("1")

[node name="Jump" type="Node" parent="."]
script = ExtResource("2")

[node name="Dash" type="Node" parent="."]
script = ExtResource("3")
"""


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TMP + "/actor")
	_write(TMP + "/actor/actor.gd", ACTOR_GD)
	_write(TMP + "/actor/actor.tscn", ACTOR_TSCN)


func after_each() -> void:
	for path in [TMP + "/actor/actor.gd", TMP + "/actor/actor.tscn", TMP + "/check.gd"]:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(TMP + "/actor")
	DirAccess.remove_absolute(TMP)


func _options(
	actor: String,
	components: Array,
	root: String,
	mode := DogScriptMerge.Mode.ADD,
	write := true,
) -> DogApiGenerator.Options:
	var options := DogApiGenerator.Options.new()
	options.actor = actor
	options.components = components
	options.root = root
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


func test_find_scene_exact_path() -> void:
	var r := DogApiGenerator.find_scene("actor", "", ROOT)
	assert_eq(r.path, ROOT + "/actor/actor.tscn")
	assert_eq(r.error, "")


func test_find_scene_folder_is_the_whole_actor_directory_like_state() -> void:
	var r := DogApiGenerator.find_scene("slime", "enemies/slime", ROOT)
	assert_eq(r.path, ROOT + "/enemies/slime/slime.tscn")
	assert_eq(r.error, "")


func test_find_scene_searches_below_the_folder_when_not_exact() -> void:
	var r := DogApiGenerator.find_scene("slime", "enemies", ROOT)
	assert_eq(r.path, ROOT + "/enemies/slime/slime.tscn")


func test_find_scene_searches_below_the_root_without_a_folder() -> void:
	var r := DogApiGenerator.find_scene("slime", "", ROOT)
	assert_eq(r.path, ROOT + "/enemies/slime/slime.tscn")


func test_find_scene_two_matches_is_an_error_listing_both() -> void:
	var r := DogApiGenerator.find_scene("twin", "", ROOT)
	assert_eq(r.path, "")
	assert_string_contains(r.error, "a/twin/twin.tscn")
	assert_string_contains(r.error, "b/twin/twin.tscn")


func test_find_scene_folder_disambiguates() -> void:
	assert_eq(DogApiGenerator.find_scene("twin", "a", ROOT).path, ROOT + "/a/twin/twin.tscn")
	assert_eq(DogApiGenerator.find_scene("twin", "b/twin", ROOT).path, ROOT + "/b/twin/twin.tscn")


func test_find_scene_missing_is_an_error() -> void:
	var r := DogApiGenerator.find_scene("ghost", "", ROOT)
	assert_eq(r.path, "")
	assert_string_contains(r.error, "ghost")


func test_find_scene_rejects_invalid_names() -> void:
	for bad in ["Player", "../x", "a b", "", "1abc"]:
		assert_ne(DogApiGenerator.find_scene(bad, "", ROOT).error, "", "name '%s'" % bad)


func test_find_scene_rejects_invalid_folders() -> void:
	for bad in ["..", "a//b", "Enemies", "/a"]:
		assert_ne(DogApiGenerator.find_scene("actor", bad, ROOT).error, "", "folder '%s'" % bad)


func test_find_scene_rejects_invalid_root() -> void:
	assert_ne(DogApiGenerator.find_scene("actor", "", "res://a/../b").error, "")


# --- build (reads the real fixture scene, writes nothing) -------------------


func test_build_fills_the_root_script_of_the_scene() -> void:
	var r := DogApiGenerator.build(_options("actor", BOTH, ROOT))
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
	var r := DogApiGenerator.build(_options("actor", BOTH, ROOT))
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
	var r := DogApiGenerator.build(_options("actor", BOTH, ROOT))
	assert_eq(r.warnings, [])
	assert_false(r.source.contains("legacy"))


func test_build_generated_source_compiles() -> void:
	for mode in [DogScriptMerge.Mode.ADD, DogScriptMerge.Mode.FORCE]:
		var r := DogApiGenerator.build(_options("actor", BOTH, ROOT, mode))
		assert_eq(_compile(r.source), OK, "mode %d" % mode)


func test_build_error_when_the_root_node_has_no_script() -> void:
	var r := DogApiGenerator.build(_options("noscript", BOTH, ROOT))
	assert_string_contains(r.error, "no script")
	assert_eq(r.source, "")


func test_build_without_components_is_an_error_listing_the_candidates() -> void:
	var r := DogApiGenerator.build(_options("actor", [], ROOT))
	assert_string_contains(r.error, "no components")
	assert_string_contains(r.error, "fixture_jump_2d")
	assert_string_contains(r.error, "fixture_dash")
	assert_eq(r.source, "")


func test_build_only_forwards_the_listed_components() -> void:
	var r := DogApiGenerator.build(_options("actor", ["fixture_dash"], ROOT))
	assert_eq(r.error, "")
	assert_string_contains(r.source, "func dash() -> void:")
	assert_false(r.source.contains("jump"))


func test_build_error_when_the_scene_is_missing() -> void:
	var r := DogApiGenerator.build(_options("ghost", BOTH, ROOT))
	assert_string_contains(r.error, "ghost")


func test_build_reads_the_scene_from_disk_even_when_it_is_cached() -> void:
	# Holding the scene keeps it in the resource cache, as an open editor would.
	var cached := load(TMP + "/actor/actor.tscn") as PackedScene
	_write(TMP + "/actor/actor.tscn", ACTOR_TSCN.replace("Dash", "Sprint"))
	var r := DogApiGenerator.build(_options("actor", BOTH, TMP))
	assert_not_null(cached)
	assert_eq(r.error, "")
	assert_string_contains(r.source, "$Sprint")


func test_build_and_generate_return_a_result_even_on_error() -> void:
	assert_true(DogApiGenerator.build(_options("actor", BOTH, ROOT)) is DogApiGenerator.Result)
	var failed := DogApiGenerator.generate(_options("ghost", BOTH, ROOT))
	assert_true(failed is DogApiGenerator.Result)
	assert_eq(failed.source, "")
	assert_eq(failed.report, [])


# --- generate (writes, on a copy in user://) -------------------------------


func test_generate_writes_the_merged_source() -> void:
	var r := DogApiGenerator.generate(_options("actor", BOTH, TMP))
	assert_eq(r.error, "")
	assert_eq(_read(TMP + "/actor/actor.gd"), r.source)
	assert_string_contains(_read(TMP + "/actor/actor.gd"), "func jump() -> void:")


func test_generate_without_write_leaves_the_file_alone() -> void:
	var r := DogApiGenerator.generate(_options("actor", BOTH, TMP, DogScriptMerge.Mode.ADD, false))
	assert_ne(r.source, r.original)
	assert_eq(_read(TMP + "/actor/actor.gd"), ACTOR_GD)


func test_generate_twice_changes_nothing_the_second_time() -> void:
	DogApiGenerator.generate(_options("actor", BOTH, TMP))
	var first := _read(TMP + "/actor/actor.gd")
	var r := DogApiGenerator.generate(_options("actor", BOTH, TMP))
	assert_eq(_read(TMP + "/actor/actor.gd"), first)
	for line in r.report:
		assert_true(line.begins_with("skip "), line)


func test_generate_update_restores_an_edited_forwarding_func() -> void:
	DogApiGenerator.generate(_options("actor", BOTH, TMP))
	var edited := _read(TMP + "/actor/actor.gd").replace(
		"\t_fixture_jump_2d.jump()\n",
		"\tprint(1)\n\t_fixture_jump_2d.jump()\n",
	)
	_write(TMP + "/actor/actor.gd", edited)
	var plain := DogApiGenerator.generate(_options("actor", BOTH, TMP))
	assert_string_contains(_read(TMP + "/actor/actor.gd"), "print(1)")
	assert_has(plain.report, "skip func jump")
	var update_options := _options("actor", BOTH, TMP, DogScriptMerge.Mode.UPDATE)
	var updated := DogApiGenerator.generate(update_options)
	assert_has(updated.report, "update func jump")
	assert_false(_read(TMP + "/actor/actor.gd").contains("print(1)"))


func test_generate_force_drops_what_was_written_below_the_header() -> void:
	_write(
		TMP + "/actor/actor.gd",
		"extends CharacterBody2D\n\nvar my_counter := 1\n\n\nfunc mine() -> void:\n\tpass\n",
	)
	DogApiGenerator.generate(_options("actor", BOTH, TMP, DogScriptMerge.Mode.FORCE))
	var text := _read(TMP + "/actor/actor.gd")
	assert_true(text.begins_with("extends CharacterBody2D\n"))
	assert_false(text.contains("my_counter"))
	assert_false(text.contains("mine"))
	assert_string_contains(text, "func jump() -> void:")


func test_generate_does_not_write_on_error() -> void:
	_write(TMP + "/actor/actor.gd", "extends CharacterBody2D\n\n\nfunc _ready(): pass\n")
	var r := DogApiGenerator.generate(_options("actor", BOTH, TMP))
	assert_string_contains(r.error, "_ready")
	assert_eq(_read(TMP + "/actor/actor.gd"), "extends CharacterBody2D\n\n\nfunc _ready(): pass\n")
