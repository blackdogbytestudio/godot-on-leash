extends GutTest
## DogPanel: echoes the line, clears the input, runs it on the cli and shows what
## the cli prints.

const FakeCommand := preload("res://test/doubles/fake_command.gd")

var _cli: DogCli
var _panel: DogPanel


func before_each() -> void:
	_cli = DogCli.new()
	_panel = autofree(DogPanel.new(_cli))


func after_each() -> void:
	_cli.dispose()


func _log() -> RichTextLabel:
	return _panel.get_child(0) as RichTextLabel


func _line_edit() -> LineEdit:
	return _panel.get_child(1) as LineEdit


func test_has_an_output_and_an_input() -> void:
	assert_not_null(_log())
	assert_not_null(_line_edit())
	assert_eq(_line_edit().placeholder_text, "help")


func test_submit_echoes_the_line_and_clears_the_input() -> void:
	_line_edit().text = "nope"
	_line_edit().text_submitted.emit("nope")
	assert_string_starts_with(_log().get_parsed_text(), "> nope\n")
	assert_eq(_line_edit().text, "")


func test_submit_runs_the_line_on_the_cli() -> void:
	var command := FakeCommand.new("go")
	_cli.register(command)
	_line_edit().text_submitted.emit("go a")
	assert_true(command.ran)
	assert_eq(command.received, PackedStringArray(["a"]))


func test_shows_what_the_cli_prints() -> void:
	_line_edit().text_submitted.emit("nope")
	assert_string_contains(_log().get_parsed_text(), "unknown command 'nope'")
