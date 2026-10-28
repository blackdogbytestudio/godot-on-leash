@tool
class_name DogApiCommand
extends DogCommand
## api <actor> <component...> [--prefix p] [--suffix s | --no-fix] [--folder path] [--root path]
##     [-f | -u]
##
## Fills the script on the root node of <actor>.tscn with an API that forwards to
## the components you list, which must be direct children of the root. Attach the
## script in Godot first. Components are snake_case class names; the prefix and
## suffix settings are added around each one (dog, 2d: jump -> dog_jump_2d).
## --prefix / --suffix replace a setting (empty, as in --prefix=, drops that side)
## and --no-fix drops both, for full names (--no-fix dog_jump_2d).

# Error messages
const MISSING_ARGUMENT := "missing <%s>."
const UNKNOWN_OPTION := "unknown option '%s'."
const INVALID_COMPONENT := "'%s' is not a valid component name (use snake_case, e.g. dog_jump_2d)."
const NO_FIX_AND_FIX := "use either --no-fix or --prefix / --suffix, not both."

# Overridable so tests never write into res://. While empty, it reads
# DogSettings.actors_root() each time, so a changed setting applies on the next run.
var root := "":
	get:
		return root if not root.is_empty() else DogSettings.actors_root()


func command_name() -> String:
	return "api"


func description() -> String:
	return "Fill an actor's script with an API for its components."


func usage() -> String:
	return (
		"api <actor> <component...>"
		+ " [--prefix p] [--suffix s | --no-fix]"
		+ " [--folder path] [--root path]"
		+ " [-f | -u]"
	)


func run(args: PackedStringArray) -> Error:
	var request := parse_request(args)
	if not request.error.is_empty():
		print_line("Dog: api: %s" % request.error)
		return ERR_INVALID_PARAMETER

	var result := DogApiGenerator.generate(options_for(request, root))
	var error: String = result["error"]
	if not error.is_empty():
		print_line("Dog: api: %s" % error)
		return FAILED

	for line in result["report"]:
		print_line(line)
	for warning in result["warnings"]:
		print_line("warning: %s" % warning)
	if result["source"] == result["original"]:
		print_line("kept %s" % result["path"])
	else:
		print_line("updated %s" % result["path"])
	return OK


## The generator options for a parsed `request`; `default_root` is used when
## --root wasn't given.
static func options_for(request: Request, default_root: String) -> DogApiGenerator.Options:
	var options := DogApiGenerator.Options.new()
	options.actor = request.actor
	options.components = request.components
	options.folder = request.folder
	options.root = request.root if not request.root.is_empty() else default_root
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
	parser.add("--folder", "", "actor directory below the root, e.g. enemies/slime")
	parser.add("--root", "", "where to look, e.g. res://scenes (default: scenes/characters)")
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
static func _read_components(parser: DogOptParse, request: Request) -> String:
	var given_prefix: Variant = parser.get_value_or_null("--prefix")
	var given_suffix: Variant = parser.get_value_or_null("--suffix")
	var no_fix: bool = parser.get_value("--no-fix")
	if no_fix and (given_prefix != null or given_suffix != null):
		return NO_FIX_AND_FIX

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


## --folder, --root and the -f / -u mode.
static func _read_options(parser: DogOptParse, request: Request) -> String:
	request.folder = parser.get_value("--folder")
	request.root = parser.get_value("--root")
	return _read_mode(parser, request)


static func _read_mode(parser: DogOptParse, request: Request) -> String:
	var force: bool = parser.get_value("--force")
	var update: bool = parser.get_value("--update")
	if force and update:
		return DogScriptMerge.FORCE_AND_UPDATE
	request.mode = DogScriptMerge.mode_from(force, update)
	return ""


class Request:
	var actor: String = ""
	var folder: String = ""
	var root: String = ""
	var components: Array = []
	var mode: DogScriptMerge.Mode = DogScriptMerge.Mode.ADD
	var error: String = ""
