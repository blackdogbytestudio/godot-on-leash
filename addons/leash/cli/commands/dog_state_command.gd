@tool
class_name DogStateCommand
extends DogCommand
## state <actor> <type> <tree...> [--folder f] [--extends State] [--initial state] [-f | -u]
## The states' host is always the actor's class (actor in PascalCase). When the
## root of <actor>.tscn has no machine of <type>, a node named after the machine
## class (DogHPDA, ...) is added to the scene; a machine of another type is an error.
## --folder is the actor's directory, written in full from the explicit_folder
## setting (--folder characters/enemies/slime); without it the actor is looked for
## under the implicit_folder setting. The states go in its `states` folder.

const FLAT_TYPES: PackedStringArray = ["fsm", "pda"]
const TREE_TYPES: PackedStringArray = ["hfsm", "hpda"]
# Error messages
const MISSING_ARGUMENT := "missing <%s>."
const UNKNOWN_OPTION := "unknown option '%s'."
const UNKNOWN_TYPE := "unknown type '%s'."
const INVALID_INITIAL := "'%s' is not a valid --initial (a state name, no dots)."
const NESTED_IN_FLAT := "'%s' is flat: nested states are not allowed."


func command_name() -> String:
	return "state"


func description() -> String:
	return "Generate actor state scripts, adding the machine node when it is missing."


func usage() -> String:
	return (
		"state <actor> <fsm|pda|hfsm|hpda> <tree...>"
		+ " [--folder path] [--extends State]"
		+ " [--initial state] [-f | -u]"
	)


func run(args: PackedStringArray) -> Error:
	var request := parse_request(args)
	if not request.error.is_empty():
		print_line("Dog: state: %s" % request.error)
		return ERR_INVALID_PARAMETER

	var result := DogStateGenerator.generate(options_for(request))
	if not result.error.is_empty():
		print_line("Dog: state: %s" % result.error)
		return FAILED

	for warning in result.warnings:
		print_line("warning: %s" % warning)
	print_line("initial: %s" % result.initial)
	for path in result.written:
		print_line("created %s" % path)
	for path in result.skipped:
		print_line("kept %s" % path)
	for line in result.report:
		print_line(line)
	if result.scene_source != result.scene_original:
		print_line("updated %s" % result.scene)
	if result.host_source == result.host_original:
		print_line("kept %s" % result.host_path)
	else:
		print_line("updated %s" % result.host_path)
	return OK


## The generator options for a parsed `request`.
static func options_for(request: Request) -> DogStateGenerator.Options:
	var options := DogStateGenerator.Options.new()
	options.actor = request.actor
	options.type = request.type
	options.folder = request.folder
	options.base = request.extends_state
	options.tree = request.tree
	options.mode = request.mode
	options.initial = request.initial
	return options


static func parse_request(args: PackedStringArray) -> Request:
	var request := Request.new()
	var parser := _build_parser()
	parser.parse(args)  # always pass args: null would read the editor's cmdline

	request.error = _read_arguments(parser, request)
	if not request.error.is_empty():
		return request
	request.error = _read_options(parser, request)
	if not request.error.is_empty():
		return request
	request.error = _read_tree(parser, request)
	return request


static func _build_parser() -> DogOptParse:
	var parser := DogOptParse.new()
	parser.add_positional_required("actor", "", "actor name (snake_case)")
	parser.add_positional_required("type", "", "type: fsm | pda | hfsm | hpda")
	parser.add(
		"--folder",
		"",
		"actor directory in full, e.g. characters/enemies/slime (states go inside it)",
	)
	parser.add("--extends", "", "state class the root states inherit from")
	parser.add(
		"--initial",
		"",
		"state the machine starts in (default: the deepest, first on a tie)",
	)
	parser.add(
		["--force", "-f"],
		false,
		"back to factory: delete states/, recreate it, rewrite the script below its header",
	)
	parser.add(
		["--update", "-u"],
		false,
		"update the host script (e.g. the init line); state files are left alone",
	)
	return parser


## Positional arguments: <actor> <type>. Also rejects unknown options.
static func _read_arguments(parser: DogOptParse, request: Request) -> String:
	var missing: Array = parser.get_missing_required_options()
	if not missing.is_empty():
		return MISSING_ARGUMENT % missing[0].option_name

	for token in parser.unused:
		if parser.is_option(token):
			return UNKNOWN_OPTION % token

	request.actor = parser.get_value("actor")
	var error := DogNames.actor_error(request.actor)
	if not error.is_empty():
		return error

	request.type = parser.get_value("type")
	if request.type not in FLAT_TYPES and request.type not in TREE_TYPES:
		return UNKNOWN_TYPE % request.type
	return ""


## --folder, --extends, --initial and the -f / -u mode.
static func _read_options(parser: DogOptParse, request: Request) -> String:
	request.folder = parser.get_value("--folder")
	var error := DogNames.folder_error(request.folder)
	if not error.is_empty():
		return error

	request.extends_state = parser.get_value("--extends")
	request.initial = parser.get_value("--initial")
	if not request.initial.is_empty() and not DogStateTree.is_valid_name(request.initial):
		return INVALID_INITIAL % request.initial

	var force: bool = parser.get_value("--force")
	var update: bool = parser.get_value("--update")
	request.mode = DogScriptMerge.mode_from(force, update)
	return DogScriptMerge.mode_error(force, update)


## The remaining tokens as the state tree; flat types reject nesting.
static func _read_tree(parser: DogOptParse, request: Request) -> String:
	var tree := DogStateTree.parse(PackedStringArray(parser.unused))
	if not tree.error.is_empty():
		return tree.error
	if request.type in FLAT_TYPES and tree.nodes.any(func(n): return n.depth > 0):
		return NESTED_IN_FLAT % request.type
	request.tree = tree
	return ""


class Request:
	var actor: String = ""
	var type: String = ""
	var folder: String = ""
	var extends_state: String = ""
	var initial: String = ""
	var mode: DogScriptMerge.Mode = DogScriptMerge.Mode.ADD
	var tree: DogStateTree
	var error: String = ""
