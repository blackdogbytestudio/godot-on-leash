@tool
class_name DogHelloCommand
extends DogCommand


func command_name() -> String:
	return "hello"


func description() -> String:
	return "Say hello."


func usage() -> String:
	return "hello [name]"


func run(args: PackedStringArray) -> Error:
	var who := args[0] if args.size() > 0 else "world"
	print_line("Hello, %s!" % who)
	return OK
