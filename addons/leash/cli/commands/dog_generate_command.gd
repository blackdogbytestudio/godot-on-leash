@tool
class_name DogGenerateCommand
extends DogCommand
## generate <actor> [<fsm|pda|hfsm|hpda> <tree...>] [--bind a,b] [--template t]
## [--extends-actor cls] [--extends-state cls] [--folder f] [--initial s]
## [--prefix p] [--suffix s | --no-fix] [-f | -u]
##
## Runs actor, state and bind on <actor>, in that order (see DogGenerateGenerator),
## and prints their lines in the same order. Each step gets the flags that apply to
## it and parses them as the command of that name would, so its checks and messages
## are the same:
##   actor: [template] from --template, --extends from --extends-actor, -f. It never
##     gets -u: an existing actor is kept.
##   state (only with a type and a tree): the tree, --base from --extends-state,
##     --initial, -f or -u.
##   bind (always): the components of --bind (comma separated), -u. It never gets
##     -f, which would rewrite what state wrote.
## --folder goes to every step; --prefix / --suffix / --no-fix go only to bind. A
## flag that no step would use is an error, and so is --extends, which could mean
## either class.

# Error messages
const MISSING_ARGUMENT := "missing <%s>."
const UNKNOWN_OPTION := "unknown option '%s'."
const AMBIGUOUS_EXTENDS := "'--extends' is ambiguous here: use --extends-actor or --extends-state"
const EMPTY_BIND := "--bind needs components, separated by commas."
const EMPTY_VALUE := "%s needs a value."
const NEEDS_TYPE := "%s needs a machine type and states to apply to."
const FIX_WITHOUT_TARGET := "--prefix, --suffix and --no-fix need --bind to apply to."
const STOPPED := "stopped at %s; already written: %s"


func command_name() -> String:
	return "generate"


func description() -> String:
	return "Create an actor, generate its states and bind its components, in one go."


func usage() -> String:
	return (
		"generate <actor> [<fsm|pda|hfsm|hpda> <tree...>]"
		+ " [--bind a,b] [--template t]"
		+ " [--extends-actor class] [--extends-state class]"
		+ " [--folder path] [--initial state]"
		+ " [--prefix p] [--suffix s | --no-fix]"
		+ " [-f | -u]"
	)


func run(args: PackedStringArray) -> Error:
	var request := parse_request(args)
	if not request.error.is_empty():
		print_line("Dog: %s: %s" % [request.step, request.error])
		return ERR_INVALID_PARAMETER

	var result := DogGenerateGenerator.generate(options_for(request))
	if not result.error.is_empty():
		print_line("Dog: %s: %s" % [result.step, result.error])
		if not result.written.is_empty():
			var written := ", ".join(result.written)
			print_line("Dog: generate: " + STOPPED % [result.step, written])
		return FAILED

	for line in report(result):
		print_line(line)
	return OK


## What run prints for a successful `result`: the lines of each step, in order, as
## its own command prints them.
static func report(result: DogGenerateGenerator.Result) -> Array[String]:
	var lines := DogActorCommand.report(result.actor)
	if result.state != null:
		lines.append_array(DogStateCommand.report(result.state))
	lines.append_array(DogBindCommand.report(result.bind))
	return lines


## The generator options for a parsed `request`.
static func options_for(request: Request) -> DogGenerateGenerator.Options:
	var options := DogGenerateGenerator.Options.new()
	options.actor = DogActorCommand.options_for(request.actor)
	if request.state != null:
		options.state = DogStateCommand.options_for(request.state)
	options.bind = DogBindCommand.options_for(request.bind)
	return options


## Parses the line of generate, then the line of each step with the parser of its
## command. `step` says whose error `error` is: "generate" or the step's.
static func parse_request(args: PackedStringArray) -> Request:
	var request := Request.new()
	var parser := _build_parser()
	parser.parse(args)  # always pass args: null would read the editor's cmdline

	request.error = _read_arguments(parser)
	if request.error.is_empty():
		request.error = _read_flags(parser)
	if not request.error.is_empty():
		return request
	_parse_steps(parser, request)
	return request


static func _build_parser() -> DogOptParse:
	var parser := DogOptParse.new()
	parser.add_positional_required("actor", "", "actor name (snake_case)")
	parser.add_positional("type", "", "type: fsm | pda | hfsm | hpda (no type: no states)")
	parser.add("--bind", "", "components to add and bind, separated by commas")
	parser.add("--template", "", "scene template of a new actor")
	parser.add("--extends-actor", "", "node class a new actor extends (as actor --extends)")
	parser.add("--extends-state", "", "class the root states extend (as state --base)")
	parser.add("--extends", "", "rejected: use --extends-actor or --extends-state")
	parser.add("--folder", "", "actor directory in full, e.g. characters/enemies/slime")
	parser.add("--initial", "", "state the machine starts in")
	parser.add("--prefix", "", "put before every --bind entry")
	parser.add("--suffix", "", "put after every --bind entry")
	parser.add("--no-fix", false, "no prefix and no suffix: full class names")
	parser.add(["--force", "-f"], false, "recreate the actor and the states")
	parser.add(["--update", "-u"], false, "update the states and the bound API")
	return parser


## Positional <actor>. Rejects unknown options.
static func _read_arguments(parser: DogOptParse) -> String:
	var missing: Array = parser.get_missing_required_options()
	if not missing.is_empty():
		return MISSING_ARGUMENT % missing[0].option_name
	for token in parser.unused:
		if parser.is_option(token):
			return UNKNOWN_OPTION % token
	return ""


## The errors of generate itself: --extends, flags given empty, the mode, and flags
## no step would use.
static func _read_flags(parser: DogOptParse) -> String:
	if parser.get_value_or_null("--extends") != null:
		return AMBIGUOUS_EXTENDS
	for flag in ["--template", "--extends-state", "--initial", "--folder"]:
		if parser.get_value_or_null(flag) != null and String(parser.get_value(flag)).is_empty():
			return EMPTY_VALUE % flag
	var mode_error := DogScriptMerge.mode_error(
		parser.get_value("--force"),
		parser.get_value("--update"),
	)
	if not mode_error.is_empty():
		return mode_error
	if parser.get_value_or_null("--bind") != null and _components(parser).is_empty():
		return EMPTY_BIND
	return _unused_flag_error(parser)


## The state flags without a type, and the fix flags without --bind (or given with
## --no-fix and --prefix / --suffix both), or "".
static func _unused_flag_error(parser: DogOptParse) -> String:
	if String(parser.get_value("type")).is_empty():
		for flag in ["--initial", "--extends-state"]:
			if parser.get_value_or_null(flag) != null:
				return NEEDS_TYPE % flag
	var fix := DogFix.from_parser(parser)
	if not fix.error.is_empty():
		return fix.error
	if fix.given and parser.get_value_or_null("--bind") == null:
		return FIX_WITHOUT_TARGET
	return ""


## Builds the line of each step and parses it with its command. Sets request.error
## and request.step on the first error.
static func _parse_steps(parser: DogOptParse, request: Request) -> void:
	request.actor = DogActorCommand.parse_request(_actor_args(parser))
	if _step_failed(request, "actor", request.actor.error):
		return
	if not String(parser.get_value("type")).is_empty():
		request.state = DogStateCommand.parse_request(_state_args(parser))
		if _step_failed(request, "state", request.state.error):
			return
	request.bind = DogBindCommand.parse_request(_bind_args(parser))
	_step_failed(request, "bind", request.bind.error)


static func _step_failed(request: Request, step: String, error: String) -> bool:
	if error.is_empty():
		return false
	request.error = error
	request.step = step
	return true


static func _actor_args(parser: DogOptParse) -> PackedStringArray:
	var args := PackedStringArray([parser.get_value("actor")])
	var template: String = parser.get_value("--template")
	if not template.is_empty():
		args.append(template)
	if parser.get_value_or_null("--extends-actor") != null:
		args.append("--extends=" + String(parser.get_value("--extends-actor")))
	args.append_array(_folder_args(parser))
	if parser.get_value("--force"):
		args.append("-f")
	return args


static func _state_args(parser: DogOptParse) -> PackedStringArray:
	var args := PackedStringArray([parser.get_value("actor"), parser.get_value("type")])
	args.append_array(PackedStringArray(parser.unused))
	if parser.get_value_or_null("--extends-state") != null:
		args.append("--base=" + String(parser.get_value("--extends-state")))
	if parser.get_value_or_null("--initial") != null:
		args.append("--initial=" + String(parser.get_value("--initial")))
	args.append_array(_folder_args(parser))
	args.append_array(_mode_args(parser))
	return args


static func _bind_args(parser: DogOptParse) -> PackedStringArray:
	var args := PackedStringArray([parser.get_value("actor")])
	var components := _components(parser)
	if not components.is_empty():
		args.append_array(components)
		args.append_array(_fix_args(parser))
	args.append_array(_folder_args(parser))
	if parser.get_value("--update"):
		args.append("-u")
	return args


## The comma separated --bind, without empty entries.
static func _components(parser: DogOptParse) -> PackedStringArray:
	return String(parser.get_value("--bind")).split(",", false)


## --prefix, --suffix and --no-fix as given (an empty --prefix= included).
static func _fix_args(parser: DogOptParse) -> PackedStringArray:
	var args := PackedStringArray()
	for flag in ["--prefix", "--suffix"]:
		var given: Variant = parser.get_value_or_null(flag)
		if given != null:
			args.append("%s=%s" % [flag, given])
	if parser.get_value("--no-fix"):
		args.append("--no-fix")
	return args


static func _folder_args(parser: DogOptParse) -> PackedStringArray:
	var folder: String = parser.get_value("--folder")
	if folder.is_empty():
		return PackedStringArray()
	return PackedStringArray(["--folder=" + folder])


static func _mode_args(parser: DogOptParse) -> PackedStringArray:
	if parser.get_value("--force"):
		return PackedStringArray(["-f"])
	if parser.get_value("--update"):
		return PackedStringArray(["-u"])
	return PackedStringArray()


class Request:
	## The request of each step; `state` is null when there is no state step.
	var actor: DogActorCommand.Request
	var state: DogStateCommand.Request
	var bind: DogBindCommand.Request
	## Whose `error` it is: "generate" or a step.
	var step: String = "generate"
	var error: String = ""
