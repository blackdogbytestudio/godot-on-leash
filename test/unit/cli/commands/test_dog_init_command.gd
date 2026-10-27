extends GutTest
## DogInitCommand.parse_request and the run paths that stop before generating.

const Command := preload("res://addons/leash/cli/commands/dog_init_command.gd")
const ROOT := "user://dog_init_command_test"


func _request(args: Array) -> DogInitCommand.Request:
	return Command.parse_request(PackedStringArray(args))


func _run(args: Array) -> Array:
	var command := Command.new()
	command.root = ROOT
	var lines: Array[String] = []
	command.printed.connect(func(text: String) -> void: lines.append(text))
	var error := command.run(PackedStringArray(args))
	return [error, lines]


func test_name_and_usage() -> void:
	var command := Command.new()
	assert_eq(command.command_name(), "init")
	assert_eq(command.usage(), "init [--skip-templates]")


func test_parse_without_arguments_copies_the_templates() -> void:
	var request := _request([])
	assert_eq(request.error, "")
	assert_false(request.skip_templates)


func test_parse_reads_skip_templates() -> void:
	var request := _request(["--skip-templates"])
	assert_eq(request.error, "")
	assert_true(request.skip_templates)


func test_parse_rejects_an_unknown_option() -> void:
	assert_eq(_request(["--force"]).error, "unknown option '--force'.")
	assert_eq(_request(["-f"]).error, "unknown option '-f'.")


func test_parse_rejects_an_argument() -> void:
	assert_eq(_request(["game"]).error, "unexpected argument 'game'.")


func test_options_carry_the_root_and_skip_templates() -> void:
	var options := Command.options_for(_request(["--skip-templates"]), ROOT)
	assert_eq(options.root, ROOT)
	assert_true(options.skip_templates)


func test_root_defaults_to_the_project() -> void:
	assert_eq(Command.new().root, "res://")


func test_run_with_an_unknown_option_prints_the_error_and_writes_nothing() -> void:
	var ran := _run(["--force"])
	assert_eq(ran[0], ERR_INVALID_PARAMETER)
	assert_eq(ran[1], ["Dog: init: unknown option '--force'."])
	assert_false(DirAccess.dir_exists_absolute(ROOT))
