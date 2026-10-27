@tool
class_name DogInitCommand
extends DogCommand
## init [--skip-templates]
##
## Sets up the project: creates the folders of the addon's config/scaffold.json
## and copies the script templates to res://script_templates. Only what is
## missing is created; nothing is overwritten. --skip-templates leaves the
## templates out.

# Error messages
const UNKNOWN_OPTION := "unknown option '%s'."
const UNEXPECTED_ARGUMENT := "unexpected argument '%s'."

# Overridable so tests never write into res://.
var root: String = "res://"


func command_name() -> String:
	return "init"


func description() -> String:
	return "Create the project folders and script templates."


func usage() -> String:
	return "init [--skip-templates]"


func run(args: PackedStringArray) -> Error:
	var request := parse_request(args)
	if not request.error.is_empty():
		print_line("Dog: init: %s" % request.error)
		return ERR_INVALID_PARAMETER

	var result := DogInitGenerator.generate(options_for(request, root))
	if not result.error.is_empty():
		print_line("Dog: init: %s" % result.error)
		return FAILED

	for line in result.report:
		print_line(line)
	for warning in result.warnings:
		print_line("warning %s" % warning)
	return OK


## The generator options for a parsed `request`, setting up below `root`.
static func options_for(request: Request, root: String) -> DogInitGenerator.Options:
	var options := DogInitGenerator.Options.new()
	options.root = root
	options.skip_templates = request.skip_templates
	return options


static func parse_request(args: PackedStringArray) -> Request:
	var request := Request.new()
	var parser := _build_parser()
	parser.parse(args)  # always pass args: null would read the editor's cmdline

	if not parser.unused.is_empty():
		var token: String = parser.unused[0]
		var message := UNKNOWN_OPTION if parser.is_option(token) else UNEXPECTED_ARGUMENT
		request.error = message % token
		return request

	request.skip_templates = parser.get_value("--skip-templates")
	return request


static func _build_parser() -> DogOptParse:
	var parser := DogOptParse.new()
	parser.add("--skip-templates", false, "don't copy the script templates")
	return parser


class Request:
	var skip_templates := false
	var error: String = ""
