@tool
class_name DogDestroyCommand
extends DogCommand
## destroy <actor> [--folder path] [-r | -f]
##
## Deletes an actor (see DogDestroyGenerator), at one of three levels:
##   destroy <actor>      its scene, its script and the script's .uid, in any folder.
##   destroy <actor> -r   also its states folder, and its directory when nothing else
##                        is left in it (what is left is reported, not deleted).
##   destroy <actor> -f   its directory and everything in it. -f includes -r.
## -r and -f delete folders, so the directory must be named after the actor
## (--folder characters/enemies/slime for slime): anything else is an error and
## deletes nothing. It does not ask for confirmation and does not use the trash: it
## prints each path as it deletes it.
## --folder is the actor's directory, written in full from the explicit_folder
## setting (--folder characters/enemies/slime); without it the actor is looked for
## under the implicit_folder setting.

# Error messages
const MISSING_ARGUMENT := "missing <%s>."
const UNKNOWN_OPTION := "unknown option '%s'."
const UNEXPECTED_ARGUMENT := "unexpected argument '%s'."


func command_name() -> String:
	return "destroy"


func description() -> String:
	return "Delete an actor's scene and script; -r adds its states, -f its whole folder."


func usage() -> String:
	return "destroy <actor> [--folder path] [-r | -f]"


func run(args: PackedStringArray) -> Error:
	var request := parse_request(args)
	if not request.error.is_empty():
		print_line("Dog: destroy: %s" % request.error)
		return ERR_INVALID_PARAMETER

	var result := DogDestroyGenerator.generate(options_for(request))
	for line in report(result):
		print_line(line)
	if not result.error.is_empty():
		print_line("Dog: destroy: %s" % result.error)
		return FAILED
	return OK


## What run prints before an error, if any: one line per path deleted, in order, and
## (when the directory stays because it holds other things) what it holds.
static func report(result: DogDestroyGenerator.Result) -> Array[String]:
	var lines: Array[String] = []
	for path in result.deleted:
		lines.append("deleted %s" % path)
	if result.error.is_empty() and not result.kept.is_empty():
		lines.append("kept %s (not empty: %s)" % [result.dir, ", ".join(result.kept)])
	return lines


## The generator options for a parsed `request`.
static func options_for(request: Request) -> DogDestroyGenerator.Options:
	var options := DogDestroyGenerator.Options.new()
	options.actor = request.actor
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
	request.folder = parser.get_value("--folder")
	request.mode = _read_mode(parser)
	request.error = DogNames.folder_error(request.folder)
	return request


static func _build_parser() -> DogOptParse:
	var parser := DogOptParse.new()
	parser.add_positional_required("actor", "", "actor name (snake_case)")
	parser.add("--folder", "", "actor directory in full, e.g. characters/enemies/slime")
	parser.add(
		["--recursive", "-r"],
		false,
		"also delete its states folder, and its directory if nothing else is in it",
	)
	parser.add(
		["--force", "-f"],
		false,
		"delete its directory and everything in it (includes -r)",
	)
	return parser


## Positional <actor>. Also rejects unknown options and extra arguments.
static func _read_arguments(parser: DogOptParse, request: Request) -> String:
	var missing: Array = parser.get_missing_required_options()
	if not missing.is_empty():
		return MISSING_ARGUMENT % missing[0].option_name

	for token in parser.unused:
		if parser.is_option(token):
			return UNKNOWN_OPTION % token
		return UNEXPECTED_ARGUMENT % token

	request.actor = parser.get_value("actor")
	return DogNames.actor_error(request.actor)


## -f is ALL (and includes -r), -r is STATES, neither is FILES.
static func _read_mode(parser: DogOptParse) -> DogDestroyGenerator.Mode:
	if parser.get_value("--force"):
		return DogDestroyGenerator.Mode.ALL
	if parser.get_value("--recursive"):
		return DogDestroyGenerator.Mode.STATES
	return DogDestroyGenerator.Mode.FILES


class Request:
	var actor: String = ""
	var folder: String = ""
	var mode := DogDestroyGenerator.Mode.FILES
	var error: String = ""
