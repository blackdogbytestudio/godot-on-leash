@tool
class_name DogActorCommand
extends DogCommand
## actor <actor> [template] [--folder f] [-f]
##
## Creates <actor>.tscn and <actor>.gd as a copy of a scene template (see
## DogActorGenerator), the root renamed after the actor and the script given
## `class_name <Actor>`. The template is a snake_case folder name, looked for in
## res://scene_templates and then in the addon's; without one it is character_body_2d.
## --folder is the actor's directory, written in full from the explicit_folder
## setting (--folder characters/enemies/slime); without it the actor goes under the
## implicit_folder setting. An existing scene or script is an error; -f recreates
## both from the template. There is no -u: nothing in the copy can be updated.

# Error messages
const MISSING_ARGUMENT := "missing <%s>."
const UNKNOWN_OPTION := "unknown option '%s'."
const UNEXPECTED_ARGUMENT := "unexpected argument '%s'."
const NO_UPDATE := (
	"actor has no -u: it creates the actor from the template,"
	+ " or recreates it with -f, overwriting both files."
)


func command_name() -> String:
	return "actor"


func description() -> String:
	return "Create an actor's scene and script from a scene template."


func usage() -> String:
	return "actor <actor> [template] [--folder path] [-f]"


func run(args: PackedStringArray) -> Error:
	var request := parse_request(args)
	if not request.error.is_empty():
		print_line("Dog: actor: %s" % request.error)
		return ERR_INVALID_PARAMETER

	var result := DogActorGenerator.generate(options_for(request))
	if not result.error.is_empty():
		print_line("Dog: actor: %s" % result.error)
		return FAILED

	for path in result.written:
		print_line("created %s" % path)
	return OK


## The generator options for a parsed `request`.
static func options_for(request: Request) -> DogActorGenerator.Options:
	var options := DogActorGenerator.Options.new()
	options.actor = request.actor
	options.template = request.template
	options.folder = request.folder
	options.force = request.force
	return options


static func parse_request(args: PackedStringArray) -> Request:
	var request := Request.new()
	var parser := _build_parser()
	parser.parse(args)  # always pass args: null would read the editor's cmdline

	request.error = _read_arguments(parser, request)
	if not request.error.is_empty():
		return request
	request.error = _read_options(parser, request)
	return request


static func _build_parser() -> DogOptParse:
	var parser := DogOptParse.new()
	parser.add_positional_required("actor", "", "actor name (snake_case)")
	parser.add_positional(
		"template",
		"",
		"scene template folder (default: %s)" % DogActorGenerator.DEFAULT_TEMPLATE,
	)
	parser.add("--folder", "", "actor directory in full, e.g. characters/enemies/slime")
	parser.add(["--force", "-f"], false, "recreate the scene and the script from the template")
	parser.add(["--update", "-u"], false, "not supported: rejected with a message")
	return parser


## Positional <actor> and [template]. Also rejects unknown options and extra
## arguments.
static func _read_arguments(parser: DogOptParse, request: Request) -> String:
	var missing: Array = parser.get_missing_required_options()
	if not missing.is_empty():
		return MISSING_ARGUMENT % missing[0].option_name

	for token in parser.unused:
		if parser.is_option(token):
			return UNKNOWN_OPTION % token
		return UNEXPECTED_ARGUMENT % token

	request.actor = parser.get_value("actor")
	var error := DogNames.actor_error(request.actor)
	if not error.is_empty():
		return error

	request.template = parser.get_value("template")
	if not request.template.is_empty() and not DogNames.is_valid_name(request.template):
		return DogActorGenerator.INVALID_TEMPLATE % request.template
	return ""


## --folder, -f, and -u, which is rejected.
static func _read_options(parser: DogOptParse, request: Request) -> String:
	if parser.get_value("--update"):
		return NO_UPDATE
	request.folder = parser.get_value("--folder")
	request.force = parser.get_value("--force")
	return DogNames.folder_error(request.folder)


class Request:
	var actor: String = ""
	var template: String = ""
	var folder: String = ""
	var force: bool = false
	var error: String = ""
