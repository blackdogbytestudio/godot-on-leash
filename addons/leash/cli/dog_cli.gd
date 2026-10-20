@tool
class_name DogCli
extends RefCounted
## Parses a command line and dispatches it to a registered DogCommand.

signal printed(text: String)

# Error messages
const UNNAMED_COMMAND := "DOG: a command has no name and was skipped."
const DUPLICATE_COMMAND := "DOG: command '%s' is already registered and was skipped."
const UNLOADABLE_COMMAND := "DOG: could not load command script '%s' (script error?)."
const UNKNOWN_COMMAND := "DOG: unknown command '%s'. Try 'help'."

var _commands: Dictionary[String, DogCommand] = {}


func register(command: DogCommand) -> void:
	var key := command.command_name()
	if key.is_empty():
		push_warning(UNNAMED_COMMAND)
		return
	if _commands.has(key):
		push_warning(DUPLICATE_COMMAND % key)
		return

	command.cli = self
	command.printed.connect(printed.emit)
	_commands[key] = command


func register_folder(path: String) -> void:
	# get_files_at() makes no promise about order; sort so "help" is stable.
	var files := DirAccess.get_files_at(path)
	files.sort()

	for file in files:
		if not file.ends_with(".gd"):
			continue
		var command := _load_command(path.path_join(file))
		if command != null:
			register(command)


## The command in the script at `path`, or null when it can't be loaded or isn't
## a RefCounted DogCommand.
func _load_command(path: String) -> DogCommand:
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		push_warning(UNLOADABLE_COMMAND % path.get_file())
		return null

	# Avoid leaking a Node (or anything non-RefCounted) by instantiating it.
	if script.get_instance_base_type() != "RefCounted":
		return null

	return script.new() as DogCommand


## Commands hold a reference back to the cli, and the cli holds the commands.
## RefCounted can't free a cycle, so call this when the cli is no longer needed.
func dispose() -> void:
	for command in _commands.values():
		command.cli = null
	_commands.clear()


func commands() -> Array[DogCommand]:
	return _commands.values()


func execute(line: String) -> Error:
	var tokens := tokenize(line)
	if tokens.is_empty():
		return OK

	# Same syntax as in a shell, so the "dog" prefix is optional.
	if tokens[0] == "dog":
		tokens.remove_at(0)
		if tokens.is_empty():
			return OK

	var command: DogCommand = _commands.get(tokens[0])
	if command == null:
		printed.emit(UNKNOWN_COMMAND % tokens[0])
		return ERR_DOES_NOT_EXIST

	tokens.remove_at(0)
	return command.run(tokens)


static func tokenize(line: String) -> PackedStringArray:
	return line.replace("\t", " ").replace("\n", " ").replace("\r", " ").split(" ", false)
