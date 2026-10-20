@tool
class_name DogPanel
extends VBoxContainer

var _cli: DogCli
var _output := RichTextLabel.new()
var _input := LineEdit.new()


func _init(cli: DogCli) -> void:
	_cli = cli
	name = "DOG"

	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.scroll_following = true
	_output.selection_enabled = true
	add_child(_output)

	_input.placeholder_text = "help"
	_input.text_submitted.connect(_on_submitted)
	add_child(_input)

	_cli.printed.connect(_print)


func _print(text: String) -> void:
	_output.add_text(text + "\n")


func _on_submitted(line: String) -> void:
	_print("> " + line)
	_input.clear()
	_cli.execute(line)
