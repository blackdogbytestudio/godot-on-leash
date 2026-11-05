extends GutTest
## DogHelpCommand: the commands with their usage, or the options of one.

const FakeCommand := preload("res://test/doubles/fake_command.gd")

var _cli: DogCli
var _lines: Array[String] = []


func before_each() -> void:
	_cli = DogCli.new()
	_lines.clear()
	_cli.printed.connect(func(text: String) -> void: _lines.append(text))


func after_each() -> void:
	_cli.dispose()


func test_command_name_description_and_usage() -> void:
	var command := DogHelpCommand.new()
	assert_eq(command.command_name(), "help")
	assert_ne(command.description(), "")
	assert_eq(command.usage(), "help [command]")


func test_lists_every_command_with_its_description() -> void:
	_cli.register(DogHelpCommand.new())
	_cli.register(FakeCommand.new("go"))
	assert_eq(_cli.execute("help"), OK)
	assert_eq(
		_lines,
		[
			"help  -  List all commands, or show the options of one.",
			"    usage: help [command]",
			"go  -  ",
		],
	)


func test_prints_the_usage_only_when_there_is_one() -> void:
	_cli.register(FakeCommand.new("fake", "A fake command.", "fake [arg]"))
	_cli.register(FakeCommand.new("go"))
	_cli.register(DogHelpCommand.new())
	_cli.execute("help")
	assert_eq(_lines.slice(0, 3), ["fake  -  A fake command.", "    usage: fake [arg]", "go  -  "])


func test_a_command_shows_its_options_and_only_its_own() -> void:
	_cli.register(DogHelpCommand.new())
	_cli.register(FakeCommand.new("fake", "A fake command.", "fake [arg]", ["    [arg]  the arg"]))
	assert_eq(_cli.execute("help fake"), OK)
	assert_eq(_lines, ["fake  -  A fake command.", "    usage: fake [arg]", "    [arg]  the arg"])


func test_an_unknown_command_is_an_error() -> void:
	_cli.register(DogHelpCommand.new())
	assert_eq(_cli.execute("help nope"), ERR_DOES_NOT_EXIST)
	assert_eq(_lines, ["Dog: help: unknown command 'nope'. Try 'help'."])


func test_more_than_one_command_is_an_error() -> void:
	_cli.register(DogHelpCommand.new())
	assert_eq(_cli.execute("help a b"), ERR_INVALID_PARAMETER)
	assert_eq(_lines, ["Dog: help: unexpected argument 'b'."])


func test_every_command_with_options_documents_them() -> void:
	_cli.register_folder("res://addons/leash/cli/commands")
	for command in _cli.commands():
		if "[" in command.usage() or "<" in command.usage():
			assert_ne(command.options_help(), [], command.command_name())
