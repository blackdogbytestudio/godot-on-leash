# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogBindCommand.run against a copy of the actor in res://scenes/tmp, removed by
## every test. The folder settings are pointed at it.

const TMP_DIR := "scenes/tmp/bind_cmd_test"
const TMP := "res://" + TMP_DIR
const KEYS := [
	DogSettings.PREFIX,
	DogSettings.SUFFIX,
	DogSettings.IMPLICIT_FOLDER,
	DogSettings.EXPLICIT_FOLDER,
]
const ACTOR_GD := "extends CharacterBody2D\n\n\nfunc _ready() -> void:\n\tpass\n"
const ACTOR_TSCN := """[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/tmp/bind_cmd_test/actor/actor.gd" id="1"]
[ext_resource type="Script" path="res://test/doubles/bind/fixture_jump.gd" id="2"]

[node name="Actor" type="CharacterBody2D"]
script = ExtResource("1")

[node name="Jump" type="Node" parent="."]
script = ExtResource("2")
"""

var _command: DogBindCommand
var _lines: Array = []
var _saved := {}


func before_each() -> void:
	_saved.clear()
	for key in KEYS:
		if ProjectSettings.has_setting(key):
			_saved[key] = ProjectSettings.get_setting(key)
	ProjectSettings.set_setting(DogSettings.PREFIX, DogSettings.DEFAULTS[DogSettings.PREFIX])
	ProjectSettings.set_setting(DogSettings.SUFFIX, DogSettings.DEFAULTS[DogSettings.SUFFIX])
	ProjectSettings.set_setting(DogSettings.IMPLICIT_FOLDER, TMP_DIR)
	ProjectSettings.set_setting(DogSettings.EXPLICIT_FOLDER, TMP_DIR)
	DirAccess.make_dir_recursive_absolute(TMP + "/actor")
	_write(TMP + "/actor/actor.gd", ACTOR_GD)
	_write(TMP + "/actor/actor.tscn", ACTOR_TSCN)
	_lines = []
	_command = DogBindCommand.new()
	_command.printed.connect(func(text: String): _lines.append(text))


func after_each() -> void:
	_remove_tree(TMP)
	DirAccess.remove_absolute("res://scenes/tmp")  # only succeeds when empty
	for key in KEYS:
		if _saved.has(key):
			ProjectSettings.set_setting(key, _saved[key])
		elif ProjectSettings.has_setting(key):
			ProjectSettings.clear(key)


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_remove_tree(path.path_join(sub))
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(path)


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
	assert_true(_lines[0].begins_with("Dog: bind: "))
	assert_eq(_read(TMP + "/actor/actor.gd"), ACTOR_GD)


func test_run_without_components_binds_every_component() -> void:
	var code := _command.run(_args("actor"))
	assert_eq(code, OK)
	assert_has(_lines, "add var _fixture_jump_2d")
	assert_has(_lines, "add func jump")
	assert_string_contains(_read(TMP + "/actor/actor.gd"), "func jump() -> void:")


func test_run_naming_a_machine_fails_pointing_to_state_and_writes_nothing() -> void:
	var code := _command.run(_args("actor --no-fix dog_fsm"))
	assert_eq(code, FAILED)
	assert_string_contains(_lines[0], "state command")
	assert_eq(_read(TMP + "/actor/actor.gd"), ACTOR_GD)


func test_run_fix_flags_without_components_fail_and_write_nothing() -> void:
	var code := _command.run(_args("actor --no-fix"))
	assert_eq(code, ERR_INVALID_PARAMETER)
	assert_string_contains(_lines[0], "need components")
	assert_eq(_read(TMP + "/actor/actor.gd"), ACTOR_GD)


func test_run_with_prefix_and_suffix_finds_the_component() -> void:
	var code := _command.run(_args("actor --prefix fixture --suffix 2d jump"))
	assert_eq(code, OK)
	assert_has(_lines, "add func jump")


func test_run_component_that_is_not_a_child_fails_early_and_writes_nothing() -> void:
	var code := _command.run(_args("actor --no-fix fixture_dash"))
	assert_eq(code, FAILED)
	assert_string_contains(_lines[0], "not a child")
	assert_eq(_read(TMP + "/actor/actor.gd"), ACTOR_GD)


func test_run_full_name_without_no_fix_gets_the_settings_and_fails_early() -> void:
	var code := _command.run(_args("actor fixture_jump_2d"))
	assert_eq(code, FAILED)
	assert_string_contains(_lines[0], "dog_fixture_jump_2d_2d")
	assert_eq(_read(TMP + "/actor/actor.gd"), ACTOR_GD)


func test_run_short_names_with_the_prefix_setting() -> void:
	ProjectSettings.set_setting(DogSettings.PREFIX, "fixture")
	var code := _command.run(_args("actor jump"))
	assert_eq(code, OK)
	assert_has(_lines, "add func jump")


func test_run_missing_scene_fails_with_the_generator_message() -> void:
	var code := _command.run(_args("ghost --no-fix fixture_jump_2d"))
	assert_eq(code, FAILED)
	assert_true(_lines[0].begins_with("Dog: bind: "))
	assert_string_contains(_lines[0], "ghost")


func test_run_fills_the_script_and_reports_each_item() -> void:
	var code := _command.run(_args("actor --no-fix fixture_jump_2d"))
	assert_eq(code, OK)
	assert_has(_lines, "add var _fixture_jump_2d")
	assert_has(_lines, "add func jump")
	assert_has(_lines, "add connect _fixture_jump_2d.landed")
	assert_has(_lines, "updated " + TMP + "/actor/actor.gd")
	assert_string_contains(_read(TMP + "/actor/actor.gd"), "func jump() -> void:")


func test_run_twice_keeps_the_file_the_second_time() -> void:
	_command.run(_args("actor --no-fix fixture_jump_2d"))
	var first := _read(TMP + "/actor/actor.gd")
	_lines.clear()
	var code := _command.run(_args("actor --no-fix fixture_jump_2d"))
	assert_eq(code, OK)
	assert_eq(_read(TMP + "/actor/actor.gd"), first)
	assert_has(_lines, "skip func jump")
	assert_has(_lines, "kept " + TMP + "/actor/actor.gd")
	assert_does_not_have(_lines, "updated " + TMP + "/actor/actor.gd")


func test_run_folder_starts_at_the_explicit_root() -> void:
	ProjectSettings.set_setting(DogSettings.IMPLICIT_FOLDER, "somewhere/else")
	var code := _command.run(_args("actor --no-fix fixture_jump_2d --folder actor"))
	assert_eq(code, OK)
	assert_has(_lines, "updated " + TMP + "/actor/actor.gd")


func test_run_root_is_not_an_option_anymore() -> void:
	var code := _command.run(_args("actor --no-fix fixture_jump_2d --root " + TMP))
	assert_eq(code, ERR_INVALID_PARAMETER)
	assert_string_contains(_lines[0], "--root")
	assert_eq(_read(TMP + "/actor/actor.gd"), ACTOR_GD)


func test_run_reads_the_implicit_folder_setting_on_each_run() -> void:
	ProjectSettings.set_setting(DogSettings.IMPLICIT_FOLDER, "scenes/tmp/bind_cmd_missing")
	var first := _command.run(_args("actor --no-fix fixture_jump_2d"))
	ProjectSettings.set_setting(DogSettings.IMPLICIT_FOLDER, TMP_DIR)
	var second := _command.run(_args("actor --no-fix fixture_jump_2d"))
	assert_eq(first, FAILED)
	assert_string_contains(_lines[0], "res://scenes/tmp/bind_cmd_missing")
	assert_eq(second, OK)
	assert_has(_lines, "updated " + TMP + "/actor/actor.gd")


func test_run_invalid_folder_setting_fails_naming_it_and_writes_nothing() -> void:
	ProjectSettings.set_setting(DogSettings.IMPLICIT_FOLDER, "res://scenes")
	var code := _command.run(_args("actor --no-fix fixture_jump_2d"))
	assert_eq(code, FAILED)
	assert_true(_lines[0].begins_with("Dog: bind: "))
	assert_string_contains(_lines[0], DogSettings.IMPLICIT_FOLDER)
	assert_eq(_read(TMP + "/actor/actor.gd"), ACTOR_GD)


func test_run_update_restores_an_edited_func_and_force_rewrites_below_the_header() -> void:
	_command.run(_args("actor --no-fix fixture_jump_2d"))
	var edited := _read(TMP + "/actor/actor.gd").replace(
		"\t_fixture_jump_2d.jump()\n",
		"\tprint(1)\n\t_fixture_jump_2d.jump()\n",
	)
	_write(TMP + "/actor/actor.gd", edited)

	_lines.clear()
	_command.run(_args("actor --no-fix fixture_jump_2d -u"))
	assert_has(_lines, "update func jump")
	assert_false(_read(TMP + "/actor/actor.gd").contains("print(1)"))

	_write(TMP + "/actor/actor.gd", "extends CharacterBody2D\n\nvar my_counter := 1\n")
	_command.run(_args("actor --no-fix fixture_jump_2d -f"))
	assert_false(_read(TMP + "/actor/actor.gd").contains("my_counter"))


func test_run_prints_generator_errors_without_writing() -> void:
	_write(TMP + "/actor/actor.gd", "extends CharacterBody2D\n\n\nfunc _ready(): pass\n")
	var code := _command.run(_args("actor --no-fix fixture_jump_2d"))
	assert_eq(code, FAILED)
	assert_string_contains(_lines[0], "_ready")
	assert_eq(_read(TMP + "/actor/actor.gd"), "extends CharacterBody2D\n\n\nfunc _ready(): pass\n")
