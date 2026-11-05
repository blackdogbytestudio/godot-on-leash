extends GutTest
## DogCommand: the defaults every command inherits, and print_line.


func test_defaults_are_empty() -> void:
	var command := DogCommand.new()
	assert_eq(command.command_name(), "")
	assert_eq(command.description(), "")
	assert_eq(command.usage(), "")
	assert_null(command.cli)


func test_run_without_an_override_is_unconfigured() -> void:
	var command := DogCommand.new()
	assert_eq(command.run(PackedStringArray()), ERR_UNCONFIGURED)
	assert_push_error("does not implement run()")


func test_print_line_emits_printed() -> void:
	var command := DogCommand.new()
	watch_signals(command)
	command.print_line("hi")
	assert_signal_emitted_with_parameters(command, "printed", ["hi"])


func test_options_help_is_empty_by_default() -> void:
	assert_eq(DogCommand.new().options_help(), [])


func test_option_lines_align_positionals_first_then_options() -> void:
	var parser := DogOptParse.new()
	parser.add_positional_required("actor", "", "actor name")
	parser.add_positional("template", "", "scene template")
	parser.add(["--force", "-f"], false, "recreate")
	parser.add("--folder", "", "directory")
	assert_eq(
		DogCommand.option_lines(parser),
		[
			"    <actor>      actor name",
			"    [template]   scene template",
			"    --force, -f  recreate",
			"    --folder     directory",
		],
	)
