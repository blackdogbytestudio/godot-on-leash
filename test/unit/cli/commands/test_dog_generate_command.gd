# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogGenerateCommand metadata, parse_request (its own errors, the line each step
## gets, the errors of the steps) and options_for: no files involved. The prefix
## and suffix settings are their defaults (dog, 2d).

const FIX_KEYS := [DogSettings.PREFIX, DogSettings.SUFFIX]

var _command: DogGenerateCommand
var _saved := {}


func before_each() -> void:
	_command = DogGenerateCommand.new()
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


func _request(line: String) -> DogGenerateCommand.Request:
	return DogGenerateCommand.parse_request(DogCli.tokenize(line))


## Asserts that `line` fails in `step` with `error`.
func _assert_error(line: String, step: String, error: String) -> void:
	var request := _request(line)
	assert_eq([request.step, request.error], [step, error], line)


# --- command metadata ---------------------------------------------------------


func test_command_name_description_and_usage() -> void:
	assert_eq(_command.command_name(), "generate")
	assert_ne(_command.description(), "")
	for part in ["generate <actor>", "--bind a,b", "--extends-actor", "--extends-state", "-f | -u"]:
		assert_string_contains(_command.usage(), part)


# --- the steps ----------------------------------------------------------------


func test_parse_without_a_type_has_no_state_step() -> void:
	var request := _request("knight")
	assert_eq(request.error, "")
	assert_eq(request.actor.actor, "knight")
	assert_null(request.state)
	assert_eq(request.bind.actor, "knight")
	assert_eq(request.bind.components, [])


func test_parse_with_a_type_and_a_tree() -> void:
	var request := _request("knight hpda alive .grounded dead --initial dead")
	assert_eq(request.error, "")
	assert_eq(request.state.type, "hpda")
	assert_eq(request.state.tree.nodes.size(), 3)
	assert_eq(request.state.initial, "dead")


func test_parse_bind_list_gets_the_prefix_and_suffix() -> void:
	assert_eq(_request("knight --bind move,jump").bind.components, ["dog_move_2d", "dog_jump_2d"])
	var full := _request("knight --bind fixture_jump_2d --no-fix")
	assert_eq(full.bind.components, ["fixture_jump_2d"])
	assert_eq(_request("knight --bind jump --prefix=").bind.components, ["jump_2d"])


func test_parse_fix_flags_go_only_to_the_steps_that_use_them() -> void:
	var to_bind := _request("knight --bind jump --prefix=")
	assert_eq(to_bind.error, "")
	assert_eq(to_bind.actor.extends_class, "")

	var to_actor := _request("knight --extends-actor area_2d --prefix=")
	assert_eq(to_actor.error, DogGenerateCommand.FIX_WITHOUT_TARGET, "the actor takes none")


func test_parse_extends_actor_keeps_a_pascal_case_name() -> void:
	var request := _request("knight --extends-actor CPUParticles2D --bind move")
	assert_eq(request.actor.extends_class, "CPUParticles2D")
	assert_eq(request.bind.components, ["dog_move_2d"])


func test_parse_template_extends_state_and_folder() -> void:
	var line := "knight fsm alive --template area_2d --extends-state hero_state"
	var request := _request(line + " --folder enemies/knight")
	assert_eq(request.error, "")
	assert_eq(request.actor.template, "area_2d")
	assert_eq(request.state.extends_state, "hero_state")
	for folder in [request.actor.folder, request.state.folder, request.bind.folder]:
		assert_eq(folder, "enemies/knight")


func test_parse_force_goes_to_actor_and_state_never_to_bind() -> void:
	var request := _request("knight hpda alive -f")
	assert_true(request.actor.force)
	assert_eq(request.state.mode, DogScriptMerge.Mode.FORCE)
	assert_eq(request.bind.mode, DogScriptMerge.Mode.ADD)


func test_parse_update_goes_to_state_and_bind_never_to_actor() -> void:
	var request := _request("knight hpda alive -u")
	assert_eq(request.error, "")
	assert_false(request.actor.force)
	assert_eq(request.state.mode, DogScriptMerge.Mode.UPDATE)
	assert_eq(request.bind.mode, DogScriptMerge.Mode.UPDATE)
	assert_eq(_request("knight --update").bind.mode, DogScriptMerge.Mode.UPDATE)


func test_options_for_copies_each_step() -> void:
	var line := "knight hpda alive --bind move --extends-actor area_2d --prefix= -u"
	var options := DogGenerateCommand.options_for(_request(line))
	assert_eq(options.actor.actor, "knight")
	assert_eq(options.actor.base, "Area2D")
	assert_eq(options.state.type, "hpda")
	assert_eq(options.state.mode, DogScriptMerge.Mode.UPDATE)
	assert_eq(options.bind.components, ["move_2d"])
	assert_eq(options.bind.mode, DogScriptMerge.Mode.UPDATE)
	assert_null(DogGenerateCommand.options_for(_request("knight")).state)


# --- errors of generate -------------------------------------------------------


func test_parse_requires_the_actor() -> void:
	_assert_error("", "generate", DogGenerateCommand.MISSING_ARGUMENT % "actor")


func test_parse_rejects_unknown_options() -> void:
	_assert_error("knight --nope", "generate", DogGenerateCommand.UNKNOWN_OPTION % "--nope")


func test_parse_extends_alone_is_ambiguous() -> void:
	var expected := "'--extends' is ambiguous here: use --extends-actor or --extends-state"
	assert_eq(DogGenerateCommand.AMBIGUOUS_EXTENDS, expected)
	for line in ["knight --extends Area2D", "knight hpda alive --extends=hero_state"]:
		_assert_error(line, "generate", expected)


func test_parse_force_and_update_together_are_an_error() -> void:
	_assert_error("knight hpda alive -f -u", "generate", DogScriptMerge.FORCE_AND_UPDATE)


func test_parse_state_flags_without_a_type_are_an_error() -> void:
	_assert_error("knight --initial alive", "generate", DogGenerateCommand.NEEDS_TYPE % "--initial")
	var extends_state := DogGenerateCommand.NEEDS_TYPE % "--extends-state"
	_assert_error("knight --extends-state hero_state", "generate", extends_state)


func test_parse_fix_flags_without_bind_or_extends_actor_are_an_error() -> void:
	for line in ["knight --prefix dog", "knight hpda alive --suffix=", "knight --no-fix"]:
		_assert_error(line, "generate", DogGenerateCommand.FIX_WITHOUT_TARGET)


func test_parse_no_fix_with_prefix_is_an_error() -> void:
	_assert_error("knight --bind jump --no-fix --prefix=", "generate", DogFix.NO_FIX_AND_FIX)


func test_parse_flags_given_empty_are_an_error() -> void:
	for flag in ["--template", "--initial", "--folder"]:
		var expected := DogGenerateCommand.EMPTY_VALUE % flag
		_assert_error("knight hpda alive %s=" % flag, "generate", expected)
	var extends_state := DogGenerateCommand.EMPTY_VALUE % "--extends-state"
	_assert_error("knight hpda alive --extends-state=", "generate", extends_state)


func test_parse_empty_bind_is_an_error() -> void:
	for line in ["knight --bind=", "knight --bind ,"]:
		_assert_error(line, "generate", DogGenerateCommand.EMPTY_BIND)


# --- errors of the steps ------------------------------------------------------


func test_parse_errors_of_the_steps_name_the_step() -> void:
	_assert_error("Knight", "actor", DogNames.INVALID_ACTOR % "Knight")
	_assert_error("knight --template Bo-dy", "actor", DogActorGenerator.INVALID_TEMPLATE % "Bo-dy")
	_assert_error("knight --extends-actor=", "actor", DogActorCommand.EMPTY_EXTENDS)
	_assert_error("knight nope alive", "state", DogStateCommand.UNKNOWN_TYPE % "nope")
	_assert_error("knight hpda", "state", DogStateTree.NO_STATES)
	_assert_error("knight fsm a .b", "state", DogStateCommand.NESTED_IN_FLAT % "fsm")
	var invalid := DogBindCommand.INVALID_COMPONENT % "dog_Jump_2d"
	_assert_error("knight --bind Jump", "bind", invalid)


# --- run ----------------------------------------------------------------------


func test_run_prints_a_parse_error_with_its_step() -> void:
	var lines: Array[String] = []
	_command.printed.connect(func(text: String) -> void: lines.append(text))
	assert_eq(_command.run(DogCli.tokenize("knight -f -u")), ERR_INVALID_PARAMETER)
	assert_eq(_command.run(DogCli.tokenize("knight nope a")), ERR_INVALID_PARAMETER)
	var expected := [
		"Dog: generate: " + DogScriptMerge.FORCE_AND_UPDATE,
		"Dog: state: " + DogStateCommand.UNKNOWN_TYPE % "nope",
	]
	assert_eq(lines, expected)
