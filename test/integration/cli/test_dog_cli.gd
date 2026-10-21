extends GutTest
## DogCli end to end: the real commands of the addon, a typed line, and the
## files it leaves in user://. state and api are checked apart: running both in
## one line is the job of `generate`.

const COMMANDS := "res://addons/leash/cli/commands"
const ROOT := "user://dog_cli_e2e"
const HPDA := "res://addons/leash/components/machines/dog_hpda.gd"
const JUMP := "res://test/doubles/api/fixture_jump.gd"

var _cli: DogCli
var _lines: Array[String] = []


func before_each() -> void:
	_remove(ROOT)
	_lines.clear()
	_cli = DogCli.new()
	_cli.register_folder(COMMANDS)
	_cli.printed.connect(func(text: String) -> void: _lines.append(text))
	for command in _cli.commands():
		if "root" in command:
			command.root = ROOT


func after_each() -> void:
	_cli.dispose()
	_remove(ROOT)


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
	assert_eq(names, ["api", "hello", "help", "state"])


func test_help_lists_the_commands() -> void:
	assert_eq(_cli.execute("help"), OK)
	var text := "\n".join(_lines)
	for command_name in ["api", "hello", "help", "state"]:
		assert_string_contains(text, command_name + "  -  ")


func test_state_line_writes_the_states_and_wires_the_host() -> void:
	_scene("enemy", "Brain", HPDA)
	assert_eq(_cli.execute("leash state hpda enemy alive .grounded dead"), OK)

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


func test_api_line_fills_the_host_with_the_component_api() -> void:
	_scene("actor", "Jump", JUMP)
	assert_eq(_cli.execute("leash api actor fixture_jump_2d"), OK)

	var host := _text(ROOT.path_join("actor/actor.gd"))
	assert_string_contains(host, "@onready var _fixture_jump_2d: FixtureJump2D = $Jump")
	assert_string_contains(host, "func jump(")
	assert_has(_lines, "updated %s" % ROOT.path_join("actor/actor.gd"))


func test_a_bad_line_prints_the_error_and_writes_nothing() -> void:
	assert_eq(_cli.execute("state hpda Enemy alive"), ERR_INVALID_PARAMETER)
	assert_string_contains(_lines[0], "Dog: state:")
	assert_null(DirAccess.open(ROOT))


func test_an_unknown_command_is_reported() -> void:
	assert_eq(_cli.execute("leash nope"), ERR_DOES_NOT_EXIST)
	assert_eq(_lines, [DogCli.UNKNOWN_COMMAND % "nope"])
