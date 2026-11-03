extends GutTest
## DogDestroyCommand metadata and parse_request: no files involved.

var _command: DogDestroyCommand


func before_each() -> void:
	_command = DogDestroyCommand.new()


func _request(line: String) -> DogDestroyCommand.Request:
	return DogDestroyCommand.parse_request(DogCli.tokenize(line))


func test_command_name_description_and_usage() -> void:
	assert_eq(_command.command_name(), "destroy")
	assert_ne(_command.description(), "")
	assert_eq(_command.usage(), "destroy <actor> [--folder path] [-r | -f]")


func test_parse_reads_the_actor() -> void:
	var request := _request("hero")
	assert_eq(request.error, "")
	assert_eq(request.actor, "hero")
	assert_eq(request.folder, "")
	assert_eq(request.mode, DogDestroyGenerator.Mode.FILES)


func test_parse_reads_the_folder() -> void:
	var request := _request("slime --folder enemies/slime")
	assert_eq(request.error, "")
	assert_eq(request.actor, "slime")
	assert_eq(request.folder, "enemies/slime")


func test_parse_reads_the_mode() -> void:
	assert_eq(_request("hero -r").mode, DogDestroyGenerator.Mode.STATES)
	assert_eq(_request("hero --recursive").mode, DogDestroyGenerator.Mode.STATES)
	assert_eq(_request("hero -f").mode, DogDestroyGenerator.Mode.ALL)
	assert_eq(_request("hero --force").mode, DogDestroyGenerator.Mode.ALL)


func test_force_includes_recursive() -> void:
	assert_eq(_request("hero -r -f").mode, DogDestroyGenerator.Mode.ALL)
	assert_eq(_request("hero -f -r").mode, DogDestroyGenerator.Mode.ALL)


func test_options_for_copies_the_request() -> void:
	var options := DogDestroyCommand.options_for(_request("slime --folder a/b -r"))
	assert_eq(options.actor, "slime")
	assert_eq(options.folder, "a/b")
	assert_eq(options.mode, DogDestroyGenerator.Mode.STATES)


func test_parse_requires_the_actor() -> void:
	assert_eq(_request("").error, DogDestroyCommand.MISSING_ARGUMENT % "actor")


func test_parse_rejects_bad_names() -> void:
	assert_eq(_request("Hero").error, DogNames.INVALID_ACTOR % "Hero")
	assert_eq(_request("hero --folder ../x").error, DogNames.INVALID_FOLDER % "../x")


func test_parse_rejects_unknown_options_and_extra_arguments() -> void:
	for flag in ["-u", "--nope"]:
		var request := _request("hero " + flag)
		assert_eq(request.error, DogDestroyCommand.UNKNOWN_OPTION % flag, flag)
	var extra := _request("hero more")
	assert_eq(extra.error, DogDestroyCommand.UNEXPECTED_ARGUMENT % "more")
