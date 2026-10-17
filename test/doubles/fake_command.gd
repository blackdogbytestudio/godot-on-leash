@tool
extends DogCommand
## Test double: records whether it ran and the args it received.

var ran := false
var received := PackedStringArray()
var _name: String


func _init(name_: String) -> void:
	_name = name_


func command_name() -> String:
	return _name


func run(args: PackedStringArray) -> Error:
	ran = true
	received = args
	return OK
