@tool
extends DogCommand
## Test double: records whether it ran and the args it received.

var ran := false
var received := PackedStringArray()
var _name: String
var _description: String
var _usage: String
var _options: Array[String]


func _init(name_: String, description_ := "", usage_ := "", options_: Array[String] = []) -> void:
	_name = name_
	_description = description_
	_usage = usage_
	_options = options_


func command_name() -> String:
	return _name


func description() -> String:
	return _description


func usage() -> String:
	return _usage


func options_help() -> Array[String]:
	return _options


func run(args: PackedStringArray) -> Error:
	ran = true
	received = args
	return OK
