extends GutTest
## leash_cmdln.gd: runs a command in a headless Godot of its own, the way a terminal
## or a CI job would, and reports the result in the exit code.

const RUNNER := "res://addons/leash/cli/leash_cmdln.gd"


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
	for name in ["bind", "help", "init", "state"]:
		assert_string_contains(result["text"], name + "  -  ")


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
