@tool
class_name DogHelpCommand
extends DogCommand

# Error messages
const UNKNOWN_COMMAND := "Dog: help: unknown command '%s'. Try 'help'."
const UNEXPECTED_ARGUMENT := "Dog: help: unexpected argument '%s'."


func command_name() -> String:
	return "help"


func description() -> String:
	return "List all commands, or show the options of one."


func usage() -> String:
	return "help [command]"


func options_help() -> Array[String]:
	return ["    [command]  command to describe (without it, list all)"]


func run(args: PackedStringArray) -> Error:
	if args.is_empty():
		for command in cli.commands():
			_print_command(command)
		return OK
	if args.size() > 1:
		print_line(UNEXPECTED_ARGUMENT % args[1])
		return ERR_INVALID_PARAMETER

	for command in cli.commands():
		if command.command_name() == args[0]:
			_print_command(command)
			for line in command.options_help():
				print_line(line)
			return OK
	print_line(UNKNOWN_COMMAND % args[0])
	return ERR_DOES_NOT_EXIST


func _print_command(command: DogCommand) -> void:
	print_line("%s  -  %s" % [command.command_name(), command.description()])
	if command.usage() != "":
		print_line("    usage: %s" % command.usage())
