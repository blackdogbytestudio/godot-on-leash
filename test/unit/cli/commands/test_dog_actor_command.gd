# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogActorCommand metadata, parse_request and the run paths that stop before
## generating: no files involved.

const FIX_KEYS := [DogSettings.PREFIX, DogSettings.SUFFIX]  # dog / 2d: must not apply

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
	var usage := "actor <actor> [template] [--extends class] [--folder path] [-f]"
	assert_eq(_command.usage(), usage)


# --- parse --------------------------------------------------------------------


func test_parse_reads_only_the_actor() -> void:
	var request := _request("hero")
	assert_eq(request.error, "")
	assert_eq(request.actor, "hero")
	assert_eq(request.template, "")
	assert_eq(request.folder, "")
	assert_eq(request.extends_class, "")
	assert_false(request.force)


func test_parse_reads_a_template_in_any_class_format() -> void:
	for template in ["character_body_2d", "CharacterBody2D", "Character_body_2d"]:
		var request := _request("slime " + template)
		assert_eq(request.error, "", template)
		assert_eq(request.template, template, "the generator turns it into PascalCase")


func test_parse_reads_template_folder_and_force() -> void:
	var request := _request("slime character_body_2d --folder enemies/slime -f")
	assert_eq(request.error, "")
	assert_eq(request.template, "character_body_2d")
	assert_eq(request.folder, "enemies/slime")
	assert_true(request.force)
	assert_true(_request("slime --force").force)


func test_options_for_copies_the_request() -> void:
	var line := "slime area_2d --extends dog_move_2d --folder a/b -f"
	var options := DogActorCommand.options_for(_request(line))
	assert_eq(options.actor, "slime")
	assert_eq(options.template, "area_2d")
	assert_eq(options.folder, "a/b")
	assert_eq(options.base, "DogMove2D")
	assert_true(options.force)


# --- --extends ----------------------------------------------------------------


func test_parse_extends_takes_snake_pascal_and_hybrid_as_typed() -> void:
	var cases := {
		"area_2d": "Area2D",
		"Area2D": "Area2D",
		"CPUParticles2D": "CPUParticles2D",
		"CPU_particles_2d": "CPUParticles2D",
		"move": "Move",
	}
	for token in cases:
		var request := _request("hero --extends " + token)
		assert_eq(request.error, "", token)
		assert_eq(request.extends_class, cases[token], token)


func test_parse_extends_ignores_the_prefix_and_suffix_settings() -> void:
	# The settings are dog / 2d: they belong to bind only.
	assert_eq(_request("hero --extends move").extends_class, "Move")


func test_parse_fix_flags_are_unknown_options() -> void:
	for flag in ["--prefix=dog", "--suffix=2d", "--no-fix"]:
		var request := _request("hero --extends Area2D " + flag)
		assert_eq(request.error, DogActorCommand.UNKNOWN_OPTION % flag, flag)


func test_parse_extends_with_a_bad_class_name_is_an_error() -> void:
	for token in ["area-2d", "_Area", "2d", "a__b"]:
		var request := _request("hero --extends=" + token)
		assert_eq(request.error, DogNames.INVALID_CLASS % token, token)


func test_parse_empty_extends_is_an_error() -> void:
	assert_eq(_request("hero --extends=").error, DogActorCommand.EMPTY_EXTENDS)


func test_parse_requires_the_actor() -> void:
	assert_eq(_request("").error, DogActorCommand.MISSING_ARGUMENT % "actor")


func test_parse_rejects_bad_names() -> void:
	assert_eq(_request("Hero").error, DogNames.INVALID_ACTOR % "Hero")
	assert_eq(_request("hero Bo-dy").error, DogActorGenerator.INVALID_TEMPLATE % "Bo-dy")
	assert_eq(_request("hero body__2d").error, DogActorGenerator.INVALID_TEMPLATE % "body__2d")
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
