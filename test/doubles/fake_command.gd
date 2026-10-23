@tool
extends DogCommand
## Test double: records whether it ran and the args it received.

var ran := false
var received := PackedStringArray()
var _name: String
var _description: String
var _usage: String


func _init(name_: String, description_ := "", usage_ := "") -> void:
	_name = name_
	_description = description_
	_usage = usage_


func command_name() -> String:
	return _name


func description() -> String:
	return _description


func usage() -> String:
	return _usage


func run(args: PackedStringArray) -> Error:
	ran = true
	received = args
	return OK
