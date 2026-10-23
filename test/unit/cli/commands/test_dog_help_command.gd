extends GutTest
## DogHelpCommand: one line per registered command, plus its usage when it has one.

const FakeCommand := preload("res://test/doubles/fake_command.gd")

var _cli: DogCli
var _lines: Array[String] = []


func before_each() -> void:
	_cli = DogCli.new()
	_lines.clear()
	_cli.printed.connect(func(text: String) -> void: _lines.append(text))


func after_each() -> void:
	_cli.dispose()


func test_command_name_and_description() -> void:
	var command := DogHelpCommand.new()
	assert_eq(command.command_name(), "help")
	assert_ne(command.description(), "")
	assert_eq(command.usage(), "")


func test_lists_every_command_with_its_description() -> void:
	_cli.register(DogHelpCommand.new())
	_cli.register(FakeCommand.new("go"))
	assert_eq(_cli.execute("help"), OK)
	assert_eq(_lines, ["help  -  List all commands.", "go  -  "])


func test_prints_the_usage_only_when_there_is_one() -> void:
	_cli.register(DogHelpCommand.new())
	_cli.register(FakeCommand.new("fake", "A fake command.", "fake [arg]"))
	_cli.execute("help")
	assert_eq(
		_lines,
		["help  -  List all commands.", "fake  -  A fake command.", "    usage: fake [arg]"],
	)
