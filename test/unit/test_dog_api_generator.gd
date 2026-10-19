# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogApiGenerator: find the scene by convention, read the direct children, and
## fill the root script. Fixtures live in test/doubles/api/.

const ROOT := "res://test/doubles/api/scenes"
const JUMP_SCRIPT := "res://test/doubles/api/fixture_jump.gd"
const DASH_SCRIPT := "res://test/doubles/api/fixture_dash.gd"
const BASE_SCRIPT := "res://test/doubles/api/fixture_base.gd"
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
	mode := DogApiMerge.Mode.ADD,
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


func _host(components: Dictionary) -> Node:
	var host: Node = autofree(Node2D.new())
	for node_name in components:
		# gdstyle:ignore=quality/allocation-in-loop
		var node := Node.new()
		node.name = node_name
		node.set_script(load(components[node_name]))
		host.add_child(node)
	return host


## plan() with the snake_case class of every classed child, in child order,
## unless `names` is given.
func _plan(host: Node, names: Array = []) -> Dictionary:
	if names.is_empty():
		for child in host.get_children():
			var script := child.get_script() as Script
			if script != null and not String(script.get_global_name()).is_empty():
				names.append(String(script.get_global_name()).to_snake_case())
	return DogApiGenerator.plan(host, names)


func _names(blocks: Array, kind: String) -> Array:
	var names := []
	for block in blocks:
		if block["kind"] == kind:
			names.append(block["name"])
	names.sort()
	return names


func _block(blocks: Array, kind: String, block_name: String) -> Dictionary:
	for block in blocks:
		if block["kind"] == kind and block["name"] == block_name:
			return block
	return {}


# --- normalize_root --------------------------------------------------------


func test_normalize_root_adds_res_and_drops_the_trailing_slash() -> void:
	assert_eq(DogApiGenerator.normalize_root("scenes"), "res://scenes")
	assert_eq(DogApiGenerator.normalize_root("res://scenes/"), "res://scenes")
	assert_eq(DogApiGenerator.normalize_root("user://x"), "user://x")


func test_normalize_root_rejects_parent_traversal_and_empty() -> void:
	assert_eq(DogApiGenerator.normalize_root("res://a/../b"), "")
	assert_eq(DogApiGenerator.normalize_root(".."), "")
	assert_eq(DogApiGenerator.normalize_root(""), "")


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


# --- plan ------------------------------------------------------------------


func test_plan_makes_a_typed_var_per_scripted_child() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT, "Dash": DASH_SCRIPT })
	var p := _plan(host)
	assert_eq(_names(p.blocks, "var"), ["_fixture_dash", "_fixture_jump_2d"])
	assert_eq(
		_block(p.blocks, "var", "_fixture_jump_2d").text,
		"@onready var _fixture_jump_2d: FixtureJump2D = $Jump"
	)


func test_plan_ignores_children_without_a_script() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT })
	host.add_child(Sprite2D.new())
	var p := _plan(host)
	assert_eq(_names(p.blocks, "var"), ["_fixture_jump_2d"])


func test_plan_forwards_public_methods_including_inherited_ones() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT })
	var p := _plan(host)
	assert_eq(_names(p.blocks, "func"), ["disable", "enable", "get_power", "jump", "jump_with"])


func test_plan_skips_internal_and_static_members() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT })
	var p := _plan(host)
	assert_does_not_have(_names(p.blocks, "func"), "_internal")
	assert_does_not_have(_names(p.blocks, "func"), "util")
	assert_does_not_have(_names(p.blocks, "signal"), "_hidden")


func test_plan_renders_the_forwarding_funcs() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT })
	var p := _plan(host)
	assert_eq(
		_block(p.blocks, "func", "jump").text,
		"func jump() -> void:\n\t_fixture_jump_2d.jump()",
	)
	assert_eq(
		_block(p.blocks, "func", "jump_with").text,
		(
			"func jump_with(power: float, times: int = 2) -> void:\n"
			+ "\t_fixture_jump_2d.jump_with(power, times)"
		)
	)
	assert_eq(
		_block(p.blocks, "func", "get_power").text,
		"func get_power() -> float:\n\treturn _fixture_jump_2d.get_power()"
	)


func test_plan_redeclares_and_connects_public_signals() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT, "Dash": DASH_SCRIPT })
	var p := _plan(host)
	assert_eq(_names(p.blocks, "signal"), ["dashed", "landed"])
	assert_eq(_block(p.blocks, "signal", "landed").text, "signal landed(speed: float)")
	assert_eq(_names(p.blocks, "ready_line"), ["_fixture_dash.dashed", "_fixture_jump_2d.landed"])


func test_plan_two_children_of_the_same_class_is_an_error() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT, "Jump2": JUMP_SCRIPT })
	var p := _plan(host)
	assert_string_contains(p.error, "more than one")
	assert_string_contains(p.error, "Jump2")
	assert_eq(p.blocks, [])


func test_plan_only_takes_the_listed_components() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT, "Dash": DASH_SCRIPT })
	var p := _plan(host, ["fixture_dash"])
	assert_eq(p.error, "")
	assert_eq(_names(p.blocks, "var"), ["_fixture_dash"])
	assert_does_not_have(_names(p.blocks, "func"), "jump")


func test_plan_follows_the_order_of_the_list_not_of_the_scene() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT, "Dash": DASH_SCRIPT })
	var p := _plan(host, ["fixture_dash", "fixture_jump_2d"])
	var vars: Array = []
	for block in p.blocks:
		if block["kind"] == "var":
			vars.append(block["name"])
	assert_eq(vars, ["_fixture_dash", "_fixture_jump_2d"])


func test_plan_a_repeated_component_is_taken_once() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT })
	var p := _plan(host, ["fixture_jump_2d", "fixture_jump_2d"])
	assert_eq(p.error, "")
	assert_eq(_names(p.blocks, "var"), ["_fixture_jump_2d"])


func test_plan_a_class_that_is_not_a_child_is_an_error_listing_the_children() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT })
	var p := _plan(host, ["fixture_dash"])
	assert_string_contains(p.error, "fixture_dash")
	assert_string_contains(p.error, "not a child")
	assert_string_contains(p.error, "fixture_jump_2d")


func test_plan_a_name_that_matches_no_class_is_an_error() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT })
	var p := _plan(host, ["fixture_nothing"])
	assert_string_contains(p.error, "fixture_nothing")
	assert_string_contains(p.error, "no class")


func test_plan_a_failing_component_stops_everything() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT })
	var p := _plan(host, ["fixture_jump_2d", "fixture_dash"])
	assert_ne(p.error, "")
	assert_eq(p.blocks, [])


func test_plan_skips_members_another_component_already_provides() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT, "Base": BASE_SCRIPT })
	var p := _plan(host)
	assert_eq(_names(p.blocks, "func").count("enable"), 1)
	assert_eq(_names(p.blocks, "func").count("jump"), 1)
	assert_string_contains("\n".join(p.warnings), "enable")


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
	for mode in [DogApiMerge.Mode.ADD, DogApiMerge.Mode.FORCE]:
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


# --- generate (writes, on a copy in user://) -------------------------------


func test_generate_writes_the_merged_source() -> void:
	var r := DogApiGenerator.generate(_options("actor", BOTH, TMP))
	assert_eq(r.error, "")
	assert_eq(_read(TMP + "/actor/actor.gd"), r.source)
	assert_string_contains(_read(TMP + "/actor/actor.gd"), "func jump() -> void:")


func test_generate_without_write_leaves_the_file_alone() -> void:
	var r := DogApiGenerator.generate(_options("actor", BOTH, TMP, DogApiMerge.Mode.ADD, false))
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
	var updated := DogApiGenerator.generate(_options("actor", BOTH, TMP, DogApiMerge.Mode.UPDATE))
	assert_has(updated.report, "update func jump")
	assert_false(_read(TMP + "/actor/actor.gd").contains("print(1)"))


func test_generate_force_drops_what_was_written_below_the_header() -> void:
	_write(
		TMP + "/actor/actor.gd",
		"extends CharacterBody2D\n\nvar my_counter := 1\n\n\nfunc mine() -> void:\n\tpass\n",
	)
	DogApiGenerator.generate(_options("actor", BOTH, TMP, DogApiMerge.Mode.FORCE))
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


func test_plan_never_forwards_property_accessors() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT })
	var p := _plan(host)
	host.free()
	for func_name in _names(p.blocks, "func"):
		assert_false(func_name.begins_with("@"), func_name)
