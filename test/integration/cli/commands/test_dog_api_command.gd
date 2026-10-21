# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogApiCommand.run against a copy of the actor in user://.

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


# --- run -------------------------------------------------------------------


func test_run_invalid_request_prints_the_error_and_writes_nothing() -> void:
	var code := _command.run(_args("Player"))
	assert_eq(code, ERR_INVALID_PARAMETER)
	assert_eq(_lines.size(), 1)
	assert_true(_lines[0].begins_with("Dog: api: "))
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
	assert_true(_lines[0].begins_with("Dog: api: "))
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
	var edited := _read(TMP + "/actor/actor.gd").replace(
		"\t_fixture_jump_2d.jump()\n",
		"\tprint(1)\n\t_fixture_jump_2d.jump()\n",
	)
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
