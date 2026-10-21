# gdstyle:ignore-file=quality/max-public-methods
extends GutTest

const FakeCommand := preload("res://test/doubles/fake_command.gd")

var _cli: DogCli


func before_each() -> void:
	_cli = DogCli.new()


func after_each() -> void:
	_cli.dispose()


func _names() -> Array:
	var result := []
	for command in _cli.commands():
		result.append(command.command_name())
	return result


func test_tokenize_splits_on_any_whitespace() -> void:
	assert_eq(DogCli.tokenize("a\tb\n c  d"), PackedStringArray(["a", "b", "c", "d"]))


func test_tokenize_blank_line_gives_no_tokens() -> void:
	assert_eq(DogCli.tokenize("   \t ").size(), 0)


func test_register_skips_a_command_without_name() -> void:
	_cli.register(FakeCommand.new(""))
	assert_eq(_cli.commands().size(), 0)
	assert_push_warning("has no name")


func test_register_skips_a_duplicate_name() -> void:
	var first := FakeCommand.new("same")
	_cli.register(first)
	_cli.register(FakeCommand.new("same"))
	assert_eq(_cli.commands().size(), 1)
	assert_eq(_cli.commands()[0], first)
	assert_push_warning("already registered")


func test_dispose_breaks_the_reference_cycle() -> void:
	var command := FakeCommand.new("x")
	_cli.register(command)
	assert_eq(command.cli, _cli)
	_cli.dispose()
	assert_null(command.cli)
	assert_eq(_cli.commands().size(), 0)


func test_execute_dispatches_with_the_remaining_args() -> void:
	var command := FakeCommand.new("go")
	_cli.register(command)
	assert_eq(_cli.execute("go a b"), OK)
	assert_true(command.ran)
	assert_eq(command.received, PackedStringArray(["a", "b"]))


func test_execute_accepts_the_leash_prefix() -> void:
	var command := FakeCommand.new("go")
	_cli.register(command)
	assert_eq(_cli.execute("leash go a"), OK)
	assert_true(command.ran)
	assert_eq(command.received, PackedStringArray(["a"]))


func test_execute_unknown_command_reports_it() -> void:
	var lines: Array[String] = []
	_cli.printed.connect(func(text: String) -> void: lines.append(text))
	assert_eq(_cli.execute("nope"), ERR_DOES_NOT_EXIST)
	assert_eq(lines.size(), 1)
	assert_string_contains(lines[0], "unknown command")


func test_execute_blank_line_and_bare_prefix_are_ok() -> void:
	assert_eq(_cli.execute(""), OK)
	assert_eq(_cli.execute("   "), OK)
	assert_eq(_cli.execute("leash"), OK)


func test_command_output_reaches_the_cli() -> void:
	var lines: Array[String] = []
	_cli.printed.connect(func(text: String) -> void: lines.append(text))
	_cli.register(DogHelloCommand.new())
	_cli.execute("hello kns")
	assert_eq(lines, ["Hello, kns!"] as Array[String])


func test_register_folder_finds_the_builtin_commands() -> void:
	_cli.register_folder("res://addons/leash/cli/commands")
	assert_has(_names(), "hello")
	assert_has(_names(), "help")
	assert_has(_names(), "state")
