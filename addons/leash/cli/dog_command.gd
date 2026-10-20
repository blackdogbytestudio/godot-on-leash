@tool
class_name DogCommand
extends RefCounted
## Base class for every DOG generator command.

signal printed(text: String)

# Error messages
const RUN_NOT_IMPLEMENTED := "DOG: '%s' does not implement run()."

var cli: DogCli


func command_name() -> String:
	return ""


func description() -> String:
	return ""


func usage() -> String:
	return ""


func run(_args: PackedStringArray) -> Error:
	push_error(RUN_NOT_IMPLEMENTED % command_name())
	return ERR_UNCONFIGURED


func print_line(text: String) -> void:
	printed.emit(text)
