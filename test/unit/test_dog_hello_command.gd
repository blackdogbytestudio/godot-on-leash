extends GutTest

var _lines := []


func _run_hello(args: PackedStringArray) -> Error:
	_lines = []
	var command := DogHelloCommand.new()
	command.printed.connect(func(text: String) -> void: _lines.append(text))
	return command.run(args)


func test_default_name() -> void:
	assert_eq(_run_hello(PackedStringArray()), OK)
	assert_eq(_lines, ["Hello, world!"])


func test_with_name() -> void:
	_run_hello(PackedStringArray(["Kns"]))
	assert_eq(_lines, ["Hello, Kns!"])
