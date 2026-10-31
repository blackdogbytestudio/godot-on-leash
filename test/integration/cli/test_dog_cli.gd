extends GutTest
## DogCli end to end: the real commands of the addon, a typed line, and the
## files it leaves in res://scenes/tmp, removed by every test. state and bind are
## checked apart: running both in one line is the job of `generate`.

## Every command the addon ships. Update it when a command is added or removed.
const COMMAND_NAMES := ["actor", "bind", "help", "init", "state"]
const COMMANDS := "res://addons/leash/cli/commands"
const ROOT_DIR := "scenes/tmp/dog_cli_e2e"
const ROOT := "res://" + ROOT_DIR
const KEYS := [DogSettings.IMPLICIT_FOLDER, DogSettings.EXPLICIT_FOLDER]
const HPDA := "res://addons/leash/components/machines/dog_hpda.gd"
const JUMP := "res://test/doubles/bind/fixture_jump.gd"

var _cli: DogCli
var _lines: Array[String] = []
var _saved := {}


func before_each() -> void:
	_saved.clear()
	for key in KEYS:
		if ProjectSettings.has_setting(key):
			_saved[key] = ProjectSettings.get_setting(key)
		ProjectSettings.set_setting(key, ROOT_DIR)
	_remove(ROOT)
	_lines.clear()
	_cli = DogCli.new()
	_cli.register_folder(COMMANDS)
	_cli.printed.connect(func(text: String) -> void: _lines.append(text))


func after_each() -> void:
	_cli.dispose()
	_remove(ROOT)
	DirAccess.remove_absolute("res://scenes/tmp")  # only succeeds when empty
	for key in KEYS:
		if _saved.has(key):
			ProjectSettings.set_setting(key, _saved[key])
		elif ProjectSettings.has_setting(key):
			ProjectSettings.clear(key)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## `<ROOT>/<actor>/<actor>.tscn` with `<actor>.gd` on the root and one child
## named `child` with the script at `child_script`.
func _scene(actor: String, child: String, child_script: String) -> void:
	var dir := ROOT.path_join(actor)
	_write(dir.path_join(actor + ".gd"), "extends CharacterBody2D\n")
	_write(
		dir.path_join(actor + ".tscn"),
		(
			"[gd_scene format=3]\n\n"
			+ "[ext_resource type=\"Script\" path=\"%s\" id=\"1\"]\n"
			+ "[ext_resource type=\"Script\" path=\"%s\" id=\"2\"]\n\n"
			+ "[node name=\"%s\" type=\"CharacterBody2D\"]\n"
			+ "script = ExtResource(\"1\")\n\n"
			+ "[node name=\"%s\" type=\"Node\" parent=\".\"]\n"
			+ "script = ExtResource(\"2\")\n"
		) % [dir.path_join(actor + ".gd"), child_script, DogNames.to_pascal(actor), child]
	)


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _remove(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	for sub in dir.get_directories():
		_remove(path.path_join(sub))
	DirAccess.remove_absolute(path)


func test_registers_every_command_of_the_addon() -> void:
	var names: Array[String] = []
	for command in _cli.commands():
		names.append(command.command_name())
	names.sort()
	assert_eq(names, COMMAND_NAMES)


func test_help_lists_the_commands() -> void:
	assert_eq(_cli.execute("help"), OK)
	var text := "\n".join(_lines)
	for command_name in COMMAND_NAMES:
		assert_string_contains(text, command_name + "  -  ")


func test_state_line_writes_the_states_and_wires_the_host() -> void:
	_scene("enemy", "Brain", HPDA)
	assert_eq(_cli.execute("leash state enemy hpda alive .grounded dead"), OK)

	var states := ROOT.path_join("enemy/states")
	for file in ["enemy_state.gd", "enemy_alive_state.gd", "enemy_grounded_state.gd"]:
		assert_true(FileAccess.file_exists(states.path_join(file)), file)
	assert_true(FileAccess.file_exists(states.path_join("enemy_dead_state.gd")))
	assert_string_contains(
		_text(states.path_join("enemy_grounded_state.gd")),
		"extends EnemyAliveState",
	)

	var host := _text(ROOT.path_join("enemy/enemy.gd"))
	assert_string_contains(host, "@onready var _dog_hpda: DogHPDA = $Brain")
	assert_string_contains(host, "_dog_hpda.init(grounded_state)")
	assert_string_contains(host, "_dog_hpda.update(delta)")
	assert_has(_lines, "initial: grounded")


func test_bind_line_fills_the_host_with_the_component_api() -> void:
	_scene("actor", "Jump", JUMP)
	assert_eq(_cli.execute("leash bind actor --no-fix fixture_jump_2d"), OK)

	var host := _text(ROOT.path_join("actor/actor.gd"))
	assert_string_contains(host, "@onready var _fixture_jump_2d: FixtureJump2D = $Jump")
	assert_string_contains(host, "func jump(")
	assert_has(_lines, "updated %s" % ROOT.path_join("actor/actor.gd"))


func test_actor_line_creates_the_scene_and_the_script() -> void:
	assert_eq(_cli.execute("leash actor hero"), OK)
	var script := ROOT.path_join("hero/hero.gd")
	assert_eq(_text(script), "class_name Hero\nextends CharacterBody2D\n")
	assert_eq(_lines, ["created %s" % ROOT.path_join("hero/hero.tscn"), "created %s" % script])


func test_a_bad_line_prints_the_error_and_writes_nothing() -> void:
	assert_eq(_cli.execute("state Enemy hpda alive"), ERR_INVALID_PARAMETER)
	assert_string_contains(_lines[0], "Dog: state:")
	assert_null(DirAccess.open(ROOT))


func test_an_unknown_command_is_reported() -> void:
	assert_eq(_cli.execute("leash nope"), ERR_DOES_NOT_EXIST)
	assert_eq(_lines, [DogCli.UNKNOWN_COMMAND % "nope"])
