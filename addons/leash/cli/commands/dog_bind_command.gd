@tool
class_name DogBindCommand
extends DogCommand
## bind <actor> [component...] [--prefix p] [--suffix s | --no-fix] [--folder path] [-f | -u]
##
## Fills the script on the root node of <actor>.tscn with an API that forwards to
## its components, which are direct children of the root. Attach the script in
## Godot first. Without a list it binds every child that has a class and is not a
## state machine. With a list it binds only those: snake_case class names, with the
## prefix and suffix settings added around each one (dog, 2d: jump -> dog_jump_2d).
## --prefix / --suffix replace a setting (empty, as in --prefix=, drops that side)
## and --no-fix drops both, for full names (--no-fix dog_jump_2d); all three need
## a list to apply to.
## --folder is the actor's directory, written in full from the explicit_folder
## setting (--folder characters/enemies/slime); without it the actor is looked for
## under the implicit_folder setting.

# Error messages
const MISSING_ARGUMENT := "missing <%s>."
const UNKNOWN_OPTION := "unknown option '%s'."
const INVALID_COMPONENT := "'%s' is not a valid component name (use snake_case, e.g. dog_jump_2d)."
const NO_FIX_AND_FIX := "use either --no-fix or --prefix / --suffix, not both."
const FIX_WITHOUT_COMPONENTS := "--prefix, --suffix and --no-fix need components to apply to."


func command_name() -> String:
	return "bind"


func description() -> String:
	return "Fill an actor's script with an API for its components."


func usage() -> String:
	return (
		"bind <actor> [component...]"
		+ " [--prefix p] [--suffix s | --no-fix]"
		+ " [--folder path]"
		+ " [-f | -u]"
	)


func run(args: PackedStringArray) -> Error:
	var request := parse_request(args)
	if not request.error.is_empty():
		print_line("Dog: bind: %s" % request.error)
		return ERR_INVALID_PARAMETER

	var result := DogBindGenerator.generate(options_for(request))
	if not result.error.is_empty():
		print_line("Dog: bind: %s" % result.error)
		return FAILED

	for line in result.report:
		print_line(line)
	for warning in result.warnings:
		print_line("warning: %s" % warning)
	if result.source == result.original:
		print_line("kept %s" % result.path)
	else:
		print_line("updated %s" % result.path)
	return OK


## The generator options for a parsed `request`.
static func options_for(request: Request) -> DogBindGenerator.Options:
	var options := DogBindGenerator.Options.new()
	options.actor = request.actor
	options.components = request.components
	options.folder = request.folder
	options.mode = request.mode
	return options


static func parse_request(args: PackedStringArray) -> Request:
	var request := Request.new()
	var parser := _build_parser()
	parser.parse(args)  # always pass args: null would read the editor's cmdline

	request.error = _read_arguments(parser, request)
	if not request.error.is_empty():
		return request
	request.error = _read_components(parser, request)
	if not request.error.is_empty():
		return request
	request.error = _read_options(parser, request)
	return request


static func _build_parser() -> DogOptParse:
	var parser := DogOptParse.new()
	parser.add_positional_required("actor", "", "actor name (snake_case)")
	parser.add("--prefix", "", "put before every component (default: the prefix setting)")
	parser.add("--suffix", "", "put after every component (default: the suffix setting)")
	parser.add("--no-fix", false, "no prefix and no suffix: components are full names")
	parser.add("--folder", "", "actor directory in full, e.g. characters/enemies/slime")
	parser.add(["--force", "-f"], false, "keep the header, rewrite everything below it")
	parser.add(["--update", "-u"], false, "also rewrite generated funcs whose text changed")
	return parser


## Positional <actor>. Also rejects unknown options.
static func _read_arguments(parser: DogOptParse, request: Request) -> String:
	var missing: Array = parser.get_missing_required_options()
	if not missing.is_empty():
		return MISSING_ARGUMENT % missing[0].option_name

	for token in parser.unused:
		if parser.is_option(token):
			return UNKNOWN_OPTION % token

	request.actor = parser.get_value("actor")
	return DogNames.actor_error(request.actor)


## The remaining tokens as components, with the prefix and suffix around each one.
## No tokens means the automatic mode.
static func _read_components(parser: DogOptParse, request: Request) -> String:
	var given_prefix: Variant = parser.get_value_or_null("--prefix")
	var given_suffix: Variant = parser.get_value_or_null("--suffix")
	var no_fix: bool = parser.get_value("--no-fix")
	var fix_given := no_fix or given_prefix != null or given_suffix != null
	if no_fix and (given_prefix != null or given_suffix != null):
		return NO_FIX_AND_FIX
	if fix_given and parser.unused.is_empty():
		return FIX_WITHOUT_COMPONENTS

	var prefix := ""
	var suffix := ""
	if not no_fix:
		prefix = _given_or(given_prefix, DogSettings.prefix()).trim_suffix("_")
		suffix = _given_or(given_suffix, DogSettings.suffix()).trim_prefix("_")
	for token in parser.unused:
		var component := _component_name(String(token), prefix, suffix)
		if not DogNames.is_valid_name(component):
			return INVALID_COMPONENT % component
		request.components.append(component)
	return ""


## `given` when the flag was passed (even empty), otherwise `setting`.
static func _given_or(given: Variant, setting: String) -> String:
	return setting if given == null else String(given)


static func _component_name(token: String, prefix: String, suffix: String) -> String:
	var component := token
	if not prefix.is_empty():
		component = prefix + "_" + component
	if not suffix.is_empty():
		component = component + "_" + suffix
	return component


## --folder and the -f / -u mode.
static func _read_options(parser: DogOptParse, request: Request) -> String:
	request.folder = parser.get_value("--folder")
	var force: bool = parser.get_value("--force")
	var update: bool = parser.get_value("--update")
	request.mode = DogScriptMerge.mode_from(force, update)
	return DogScriptMerge.mode_error(force, update)


class Request:
	var actor: String = ""
	var folder: String = ""
	var components: Array = []
	var mode: DogScriptMerge.Mode = DogScriptMerge.Mode.ADD
	var error: String = ""
