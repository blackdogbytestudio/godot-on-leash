extends GutTest
## leash_cmdln.gd: runs a command in a headless Godot of its own, the way a terminal
## or a CI job would, and reports the result in the exit code.

const RUNNER := "res://addons/leash/cli/leash_cmdln.gd"
## Where the runs that write go: --folder RUN_FOLDER/... under res://scenes.
const RUN_FOLDER := "tmp/runner_test"
const RUN_DIR := "res://scenes/" + RUN_FOLDER


## Runs the runner with `args` after `--`. Returns {code, text} (stdout and stderr).
func _run(args: Array) -> Dictionary:
	var params := PackedStringArray([
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"-s",
		RUNNER,
		"--",
	])
	params.append_array(PackedStringArray(args))
	var output := []
	var code := OS.execute(OS.get_executable_path(), params, output, true)
	return { "code": code, "text": "\n".join(output) }


func test_without_arguments_it_lists_the_commands() -> void:
	var result := _run([])
	assert_eq(result["code"], 0)
	for command in ["actor", "bind", "generate", "help", "init", "state"]:
		assert_string_contains(result["text"], command + "  -  ")


func test_an_unknown_command_fails_with_exit_code_1() -> void:
	var result := _run(["nope"])
	assert_eq(result["code"], 1)
	assert_string_contains(result["text"], "unknown command 'nope'")


func test_a_failing_command_exits_with_1_and_prints_why() -> void:
	var result := _run(["bind", "no_such_actor_for_the_runner_test"])
	assert_eq(result["code"], 1)
	assert_string_contains(result["text"], "no scene at")


func test_a_command_that_works_exits_with_0() -> void:
	var result := _run(["help"])
	assert_eq(result["code"], 0)
	assert_string_contains(result["text"], "usage: bind <actor>")


func _remove(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	for sub in dir.get_directories():
		_remove(path.path_join(sub))
	DirAccess.remove_absolute(path)


func after_each() -> void:
	_remove(RUN_DIR)
	DirAccess.remove_absolute("res://scenes/tmp")  # only succeeds when empty


func test_actor_runs_and_writes_the_actor() -> void:
	# The runner reads the project settings: the explicit folder is res://scenes.
	var result := _run(["actor", "runner_knight", "--folder", RUN_FOLDER + "/runner_knight"])
	assert_eq(result["code"], 0, result["text"])
	var script := RUN_DIR.path_join("runner_knight/runner_knight.gd")
	assert_string_contains(result["text"], "created " + script)
	var expected := "class_name RunnerKnight\nextends CharacterBody2D\n"
	assert_eq(FileAccess.get_file_as_string(script), expected)


func test_generate_runs_every_step() -> void:
	var args := ["generate", "runner_squire", "fsm", "idle", "--bind", "move"]
	var result := _run(args + ["--folder", RUN_FOLDER + "/runner_squire"])
	assert_eq(result["code"], 0, result["text"])
	var dir := RUN_DIR.path_join("runner_squire")
	var created := "created " + dir.path_join("runner_squire.gd")
	for line in [created, "initial: idle", "add node DogMove2D"]:
		assert_string_contains(result["text"], line)
	var script := FileAccess.get_file_as_string(dir.path_join("runner_squire.gd"))
	assert_string_contains(script, "_dog_fsm.init(idle_state)")
	assert_string_contains(script, "$DogMove2D")


func test_generate_runs_and_fails_before_writing() -> void:
	var result := _run(["generate", "no_such_actor_for_the_runner_test", "--initial", "a"])
	assert_eq(result["code"], 1)
	var expected := DogGenerateCommand.NEEDS_TYPE % "--initial"
	assert_string_contains(result["text"], "Dog: generate: " + expected)
