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
