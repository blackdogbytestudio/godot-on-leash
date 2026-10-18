@tool
class_name DogApiCommand
extends DogCommand
## api <actor> <component...> [--prefix p] [--suffix s] [--folder path] [--root path] [-f | -u]
##
## Fills the script on the root node of <actor>.tscn with an API that forwards to
## the components you list, which must be direct children of the root. Attach the
## script in Godot first. Components are snake_case class names (dog_jump_2d);
## --prefix / --suffix are added around each one (--prefix dog --suffix 2d jump).

# Error messages
const MISSING_ARGUMENT := "missing <%s>."
const UNKNOWN_OPTION := "unknown option '%s'."
const INVALID_ACTOR := "'%s' is not a valid actor name (use snake_case)."
const INVALID_COMPONENT := "'%s' is not a valid component name (use snake_case, e.g. dog_jump_2d)."
const FORCE_AND_UPDATE := "use either -f or -u, not both."

# Overridable so tests never write into res://.
var root: String = DogApiGenerator.DEFAULT_ROOT


func command_name() -> String:
	return "api"


func description() -> String:
	return "Fill an actor's script with an API for its components."


func usage() -> String:
	return "api <actor> <component...> [--prefix p] [--suffix s] [--folder path] [--root path] [-f | -u]"


func run(args: PackedStringArray) -> Error:
	var request := parse_request(args)
	if not request.error.is_empty():
		print_line("DOG: api: %s" % request.error)
		return ERR_INVALID_PARAMETER

	var result := DogApiGenerator.generate(
		request.actor,
		request.components,
		request.folder,
		request.root if not request.root.is_empty() else root,
		request.mode
	)
	var error: String = result["error"]
	if not error.is_empty():
		print_line("DOG: api: %s" % error)
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


static func parse_request(args: PackedStringArray) -> Request:
	var request: Request = Request.new()

	var parser := DogOptParse.new()
	parser.add_positional_required("actor", "", "actor name (snake_case)")
	parser.add("--prefix", "", "put before every component, e.g. dog")
	parser.add("--suffix", "", "put after every component, e.g. 2d")
	parser.add("--folder", "", "actor directory below the root, e.g. enemies/slime")
	parser.add("--root", "", "where to look, e.g. res://scenes (default: scenes/characters)")
	parser.add(["--force", "-f"], false, "keep the header, rewrite everything below it")
	parser.add(["--update", "-u"], false, "also rewrite generated funcs whose text changed")
	parser.parse(args)  # always pass args: null would read the editor's cmdline

	var missing: Array = parser.get_missing_required_options()
	if not missing.is_empty():
		request.error = MISSING_ARGUMENT % missing[0].option_name
		return request

	var tokens: Array = []
	for token in parser.unused:
		if parser.is_option(token):
			request.error = UNKNOWN_OPTION % token
			return request
		tokens.append(token)

	request.actor = parser.get_value("actor")
	if not DogNames.is_valid_name(request.actor):
		request.error = INVALID_ACTOR % request.actor
		return request

	var prefix: String = String(parser.get_value("--prefix")).trim_suffix("_")
	var suffix: String = String(parser.get_value("--suffix")).trim_prefix("_")
	for token in tokens:
		var component := String(token)
		if not prefix.is_empty():
			component = prefix + "_" + component
		if not suffix.is_empty():
			component = component + "_" + suffix
		if not DogNames.is_valid_name(component):
			request.error = INVALID_COMPONENT % component
			return request
		request.components.append(component)

	request.folder = parser.get_value("--folder")
	request.root = parser.get_value("--root")

	var force: bool = parser.get_value("--force")
	var update: bool = parser.get_value("--update")
	if force and update:
		request.error = FORCE_AND_UPDATE
		return request
	if force:
		request.mode = DogApiMerge.Mode.FORCE
	elif update:
		request.mode = DogApiMerge.Mode.UPDATE

	return request


class Request:
	var actor: String = ""
	var folder: String = ""
	var root: String = ""
	var components: Array = []
	var mode: DogApiMerge.Mode = DogApiMerge.Mode.ADD
	var error: String = ""
