# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## api <actor> [--folder path] [--root path] [-f] [-u]

const TMP := "user://api_cmd_test"
const ACTOR_GD := "extends CharacterBody2D\n\n\nfunc _ready() -> void:\n\tpass\n"
const ACTOR_TSCN := """[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="user://api_cmd_test/actor/actor.gd" id="1"]
[ext_resource type="Script" path="res://test/doubles/api/fixture_jump.gd" id="2"]

[node name="Actor" type="CharacterBody2D"]
script = ExtResource("1")

[node name="Jump" type="Node" parent="."]
script = ExtResource("2")
"""

var _command: DogApiCommand
var _lines: Array = []


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TMP + "/actor")
	_write(TMP + "/actor/actor.gd", ACTOR_GD)
	_write(TMP + "/actor/actor.tscn", ACTOR_TSCN)
	_lines = []
	_command = DogApiCommand.new()
	_command.root = TMP
	_command.printed.connect(func(text: String): _lines.append(text))


func after_each() -> void:
	for path in [TMP + "/actor/actor.gd", TMP + "/actor/actor.tscn"]:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(TMP + "/actor")
	DirAccess.remove_absolute(TMP)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	return text


func _args(line: String) -> PackedStringArray:
	return DogCli.tokenize(line)


# --- command metadata ------------------------------------------------------


func test_command_name_and_usage() -> void:
	assert_eq(_command.command_name(), "api")
	assert_ne(_command.description(), "")
	assert_string_contains(_command.usage(), "api <actor> <component...>")


# --- parse_request ---------------------------------------------------------


func test_parse_actor_only_defaults_to_add_mode() -> void:
	var r := DogApiCommand.parse_request(_args("player"))
	assert_eq(r.error, "")
	assert_eq(r.actor, "player")
	assert_eq(r.folder, "")
	assert_eq(r.root, "")
	assert_eq(r.mode, DogApiMerge.Mode.ADD)


func test_parse_force_flag_short_and_long() -> void:
	assert_eq(DogApiCommand.parse_request(_args("player -f")).mode, DogApiMerge.Mode.FORCE)
	assert_eq(DogApiCommand.parse_request(_args("player --force")).mode, DogApiMerge.Mode.FORCE)


func test_parse_update_flag_short_and_long() -> void:
	assert_eq(DogApiCommand.parse_request(_args("player -u")).mode, DogApiMerge.Mode.UPDATE)
	assert_eq(DogApiCommand.parse_request(_args("player --update")).mode, DogApiMerge.Mode.UPDATE)


func test_parse_force_and_update_together_is_an_error() -> void:
	var r := DogApiCommand.parse_request(_args("player -f -u"))
	assert_string_contains(r.error, "-f")
	assert_string_contains(r.error, "-u")


func test_parse_folder_and_root_values() -> void:
	var r := DogApiCommand.parse_request(_args("slime --folder enemies/slime --root res://scenes"))
	assert_eq(r.error, "")
	assert_eq(r.folder, "enemies/slime")
	assert_eq(r.root, "res://scenes")


func test_parse_actor_with_a_digit_part_is_valid() -> void:
	var r := DogApiCommand.parse_request(_args("character_body_2d"))
	assert_eq(r.error, "")
	assert_eq(r.actor, "character_body_2d")


func test_parse_missing_actor_is_an_error() -> void:
	var r := DogApiCommand.parse_request(_args(""))
	assert_string_contains(r.error, "actor")


func test_parse_invalid_actor_is_an_error() -> void:
	var r := DogApiCommand.parse_request(_args("Player"))
	assert_string_contains(r.error, "Player")


func test_parse_unknown_option_is_an_error() -> void:
	var r := DogApiCommand.parse_request(_args("player --bogus"))
	assert_string_contains(r.error, "--bogus")


func test_parse_components_are_the_tokens_after_the_actor() -> void:
	var r := DogApiCommand.parse_request(_args("player dog_jump_2d dog_move_2d"))
	assert_eq(r.error, "")
	assert_eq(r.components, ["dog_jump_2d", "dog_move_2d"])


func test_parse_without_components_is_not_a_parse_error() -> void:
	var r := DogApiCommand.parse_request(_args("player"))
	assert_eq(r.error, "")
	assert_eq(r.components, [])


func test_parse_prefix_and_suffix_wrap_every_component() -> void:
	var r := DogApiCommand.parse_request(_args("player --prefix dog --suffix 2d jump gravity move"))
	assert_eq(r.error, "")
	assert_eq(r.components, ["dog_jump_2d", "dog_gravity_2d", "dog_move_2d"])


func test_parse_prefix_alone_and_suffix_alone() -> void:
	assert_eq(
		DogApiCommand.parse_request(_args("player --prefix dog jump")).components,
		["dog_jump"],
	)
	assert_eq(DogApiCommand.parse_request(_args("player --suffix 2d jump")).components, ["jump_2d"])


func test_parse_prefix_and_suffix_tolerate_a_stray_underscore() -> void:
	var r := DogApiCommand.parse_request(_args("player --prefix dog_ --suffix _2d jump"))
	assert_eq(r.components, ["dog_jump_2d"])


func test_parse_prefix_is_not_deduplicated() -> void:
	var r := DogApiCommand.parse_request(_args("player --prefix dog dog_jump"))
	assert_eq(r.components, ["dog_dog_jump"])


func test_parse_invalid_component_is_an_error() -> void:
	var r := DogApiCommand.parse_request(_args("player DogJump2D"))
	assert_string_contains(r.error, "DogJump2D")
	r = DogApiCommand.parse_request(_args("player --prefix Dog jump"))
	assert_string_contains(r.error, "Dog_jump")


# --- run -------------------------------------------------------------------


func test_run_invalid_request_prints_the_error_and_writes_nothing() -> void:
	var code := _command.run(_args("Player"))
	assert_eq(code, ERR_INVALID_PARAMETER)
	assert_eq(_lines.size(), 1)
	assert_true(_lines[0].begins_with("DOG: api: "))
	assert_eq(_read(TMP + "/actor/actor.gd"), ACTOR_GD)


func test_run_without_components_fails_listing_the_candidates() -> void:
	var code := _command.run(_args("actor"))
	assert_eq(code, FAILED)
	assert_string_contains(_lines[0], "no components")
	assert_string_contains(_lines[0], "fixture_jump_2d")
	assert_eq(_read(TMP + "/actor/actor.gd"), ACTOR_GD)


func test_run_with_prefix_and_suffix_finds_the_component() -> void:
	var code := _command.run(_args("actor --prefix fixture --suffix 2d jump"))
	assert_eq(code, OK)
	assert_has(_lines, "add func jump")


func test_run_component_that_is_not_a_child_fails_early_and_writes_nothing() -> void:
	var code := _command.run(_args("actor fixture_dash"))
	assert_eq(code, FAILED)
	assert_string_contains(_lines[0], "not a child")
	assert_eq(_read(TMP + "/actor/actor.gd"), ACTOR_GD)


func test_run_missing_scene_fails_with_the_generator_message() -> void:
	var code := _command.run(_args("ghost fixture_jump_2d"))
	assert_eq(code, FAILED)
	assert_true(_lines[0].begins_with("DOG: api: "))
	assert_string_contains(_lines[0], "ghost")


func test_run_fills_the_script_and_reports_each_item() -> void:
	var code := _command.run(_args("actor fixture_jump_2d"))
	assert_eq(code, OK)
	assert_has(_lines, "add var _fixture_jump_2d")
	assert_has(_lines, "add func jump")
	assert_has(_lines, "add connect _fixture_jump_2d.landed")
	assert_has(_lines, "updated " + TMP + "/actor/actor.gd")
	assert_string_contains(_read(TMP + "/actor/actor.gd"), "func jump() -> void:")


func test_run_twice_keeps_the_file_the_second_time() -> void:
	_command.run(_args("actor fixture_jump_2d"))
	var first := _read(TMP + "/actor/actor.gd")
	_lines.clear()
	var code := _command.run(_args("actor fixture_jump_2d"))
	assert_eq(code, OK)
	assert_eq(_read(TMP + "/actor/actor.gd"), first)
	assert_has(_lines, "skip func jump")
	assert_has(_lines, "kept " + TMP + "/actor/actor.gd")
	assert_does_not_have(_lines, "updated " + TMP + "/actor/actor.gd")


func test_run_root_flag_overrides_the_default_root() -> void:
	var plain := DogApiCommand.new()
	plain.printed.connect(func(text: String): _lines.append(text))
	var code := plain.run(_args("actor fixture_jump_2d --root " + TMP))
	assert_eq(code, OK)
	assert_has(_lines, "updated " + TMP + "/actor/actor.gd")


func test_run_update_restores_an_edited_func_and_force_rewrites_below_the_header() -> void:
	_command.run(_args("actor fixture_jump_2d"))
	var edited := _read(TMP + "/actor/actor.gd").replace("\t_fixture_jump_2d.jump()\n", "\tprint(1)\n\t_fixture_jump_2d.jump()\n")
	_write(TMP + "/actor/actor.gd", edited)

	_lines.clear()
	_command.run(_args("actor fixture_jump_2d -u"))
	assert_has(_lines, "update func jump")
	assert_false(_read(TMP + "/actor/actor.gd").contains("print(1)"))

	_write(TMP + "/actor/actor.gd", "extends CharacterBody2D\n\nvar my_counter := 1\n")
	_command.run(_args("actor fixture_jump_2d -f"))
	assert_false(_read(TMP + "/actor/actor.gd").contains("my_counter"))


func test_run_prints_generator_errors_without_writing() -> void:
	_write(TMP + "/actor/actor.gd", "extends CharacterBody2D\n\n\nfunc _ready(): pass\n")
	var code := _command.run(_args("actor fixture_jump_2d"))
	assert_eq(code, FAILED)
	assert_string_contains(_lines[0], "_ready")
	assert_eq(_read(TMP + "/actor/actor.gd"), "extends CharacterBody2D\n\n\nfunc _ready(): pass\n")
