@tool
class_name DogCommand
extends RefCounted
## Base class for every leash generator command.

signal printed(text: String)

# Error messages
const RUN_NOT_IMPLEMENTED := "Dog: '%s' does not implement run()."

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


## The lines `help <command>` prints after the usage: one per option.
func options_help() -> Array[String]:
	return []


## One line per option of `parser` (positionals first): its names, then its description.
static func option_lines(parser: DogOptParse) -> Array[String]:
	var names: Array[String] = []
	var descriptions: Array[String] = []
	for option in parser.options.positional:
		var text: String = option.option_name
		names.append("<%s>" % text if option.required else "[%s]" % text)
		descriptions.append(option.description)
	for option in parser.options.options:
		var all: Array[String] = [option.option_name]
		all.append_array(option.aliases)
		names.append(", ".join(all))
		descriptions.append(option.description)

	var width := 0
	for text in names:
		width = maxi(width, text.length())
	var lines: Array[String] = []
	for i in names.size():
		lines.append("    %s  %s" % [names[i].rpad(width), descriptions[i]])
	return lines
