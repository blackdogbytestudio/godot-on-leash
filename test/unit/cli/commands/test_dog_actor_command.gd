# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogActorCommand metadata, parse_request and the run paths that stop before
## generating: no files involved.

var _command: DogActorCommand


func before_each() -> void:
	_command = DogActorCommand.new()


func _request(line: String) -> DogActorCommand.Request:
	return DogActorCommand.parse_request(DogCli.tokenize(line))


# --- command metadata ---------------------------------------------------------


func test_command_name_description_and_usage() -> void:
	assert_eq(_command.command_name(), "actor")
	assert_ne(_command.description(), "")
	assert_eq(_command.usage(), "actor <actor> [template] [--folder path] [-f]")


# --- parse --------------------------------------------------------------------


func test_parse_reads_only_the_actor() -> void:
	var request := _request("hero")
	assert_eq(request.error, "")
	assert_eq(request.actor, "hero")
	assert_eq(request.template, "")
	assert_eq(request.folder, "")
	assert_false(request.force)


func test_parse_reads_template_folder_and_force() -> void:
	var request := _request("slime character_body_2d --folder enemies/slime -f")
	assert_eq(request.error, "")
	assert_eq(request.template, "character_body_2d")
	assert_eq(request.folder, "enemies/slime")
	assert_true(request.force)
	assert_true(_request("slime --force").force)


func test_options_for_copies_the_request() -> void:
	var options := DogActorCommand.options_for(_request("slime area_2d --folder a/b -f"))
	assert_eq(options.actor, "slime")
	assert_eq(options.template, "area_2d")
	assert_eq(options.folder, "a/b")
	assert_true(options.force)


func test_parse_requires_the_actor() -> void:
	assert_eq(_request("").error, DogActorCommand.MISSING_ARGUMENT % "actor")


func test_parse_rejects_bad_names() -> void:
	assert_eq(_request("Hero").error, DogNames.INVALID_ACTOR % "Hero")
	assert_eq(_request("hero Body").error, DogActorGenerator.INVALID_TEMPLATE % "Body")
	assert_eq(_request("hero --folder ../x").error, DogNames.INVALID_FOLDER % "../x")


func test_parse_rejects_update() -> void:
	assert_eq(_request("hero -u").error, DogActorCommand.NO_UPDATE)
	assert_eq(_request("hero --update").error, DogActorCommand.NO_UPDATE)


func test_parse_rejects_unknown_options_and_extra_arguments() -> void:
	assert_eq(_request("hero --nope").error, DogActorCommand.UNKNOWN_OPTION % "--nope")
	var extra := _request("hero character_body_2d more")
	assert_eq(extra.error, DogActorCommand.UNEXPECTED_ARGUMENT % "more")


# --- run ----------------------------------------------------------------------


func test_run_prints_a_parse_error() -> void:
	var lines: Array[String] = []
	_command.printed.connect(func(text: String) -> void: lines.append(text))
	assert_eq(_command.run(PackedStringArray(["hero", "-u"])), ERR_INVALID_PARAMETER)
	assert_eq(lines, ["Dog: actor: " + DogActorCommand.NO_UPDATE])
