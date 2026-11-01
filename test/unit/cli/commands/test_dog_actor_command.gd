# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogActorCommand metadata, parse_request and the run paths that stop before
## generating: no files involved.

const FIX_KEYS := [DogSettings.PREFIX, DogSettings.SUFFIX]

var _command: DogActorCommand
var _saved := {}


func before_each() -> void:
	_command = DogActorCommand.new()
	_saved.clear()
	for key in FIX_KEYS:
		if ProjectSettings.has_setting(key):
			_saved[key] = ProjectSettings.get_setting(key)
		ProjectSettings.set_setting(key, DogSettings.DEFAULTS[key])


func after_each() -> void:
	for key in FIX_KEYS:
		ProjectSettings.clear(key)
		if _saved.has(key):
			ProjectSettings.set_setting(key, _saved[key])


func _request(line: String) -> DogActorCommand.Request:
	return DogActorCommand.parse_request(DogCli.tokenize(line))


# --- command metadata ---------------------------------------------------------


func test_command_name_description_and_usage() -> void:
	assert_eq(_command.command_name(), "actor")
	assert_ne(_command.description(), "")
	var usage := "actor <actor> [template] [--extends class]"
	usage += " [--prefix p] [--suffix s | --no-fix] [--folder path] [-f]"
	assert_eq(_command.usage(), usage)


# --- parse --------------------------------------------------------------------


func test_parse_reads_only_the_actor() -> void:
	var request := _request("hero")
	assert_eq(request.error, "")
	assert_eq(request.actor, "hero")
	assert_eq(request.template, "")
	assert_eq(request.folder, "")
	assert_eq(request.extends_class, "")
	assert_false(request.extends_fixed)
	assert_false(request.force)


func test_parse_reads_template_folder_and_force() -> void:
	var request := _request("slime character_body_2d --folder enemies/slime -f")
	assert_eq(request.error, "")
	assert_eq(request.template, "character_body_2d")
	assert_eq(request.folder, "enemies/slime")
	assert_true(request.force)
	assert_true(_request("slime --force").force)


func test_options_for_copies_the_request() -> void:
	var line := "slime area_2d --extends move --folder a/b -f"
	var options := DogActorCommand.options_for(_request(line))
	assert_eq(options.actor, "slime")
	assert_eq(options.template, "area_2d")
	assert_eq(options.folder, "a/b")
	assert_eq(options.base, "DogMove2D")
	assert_true(options.base_fixed)
	assert_true(options.force)


# --- --extends ----------------------------------------------------------------


func test_parse_extends_gets_the_prefix_and_suffix_in_pascal_case() -> void:
	var request := _request("hero --extends move")
	assert_eq(request.error, "")
	assert_eq(request.extends_class, "DogMove2D")
	assert_true(request.extends_fixed)


func test_parse_extends_with_fix_flags() -> void:
	assert_eq(_request("hero --extends area --prefix=").extends_class, "Area2D")
	assert_eq(_request("hero --extends body --prefix fx --suffix 3d").extends_class, "FxBody3D")
	var full := _request("hero --extends area_2d --no-fix")
	assert_eq(full.extends_class, "Area2D")
	assert_false(full.extends_fixed)


func test_parse_extends_keeps_a_pascal_case_name_with_no_fix() -> void:
	# The way to give a class that has no snake_case spelling.
	var request := _request("hero --extends CPUParticles2D --no-fix")
	assert_eq(request.error, "")
	assert_eq(request.extends_class, "CPUParticles2D")


func test_parse_fix_flags_without_extends_are_an_error() -> void:
	for line in ["hero --prefix dog", "hero --suffix=", "hero --no-fix"]:
		assert_eq(_request(line).error, DogActorCommand.FIX_WITHOUT_EXTENDS, line)


func test_parse_no_fix_with_prefix_or_suffix_is_an_error() -> void:
	var request := _request("hero --extends area --no-fix --prefix=")
	assert_eq(request.error, DogFix.NO_FIX_AND_FIX)


func test_parse_empty_extends_is_an_error() -> void:
	assert_eq(_request("hero --extends=").error, DogActorCommand.EMPTY_EXTENDS)


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
