@tool
class_name DogHelpCommand
extends DogCommand


func command_name() -> String:
	return "help"


func description() -> String:
	return "List all commands."


func run(_args: PackedStringArray) -> Error:
	for command in cli.commands():
		print_line("%s  -  %s" % [command.command_name(), command.description()])
		if command.usage() != "":
			print_line("    usage: %s" % command.usage())
	return OK
