# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogBindCommand metadata and parse_request: no files involved.

var _command: DogBindCommand
var _saved := {}


func before_each() -> void:
	_command = DogBindCommand.new()
	_saved.clear()
	for key in [DogSettings.PREFIX, DogSettings.SUFFIX]:
		if ProjectSettings.has_setting(key):
			_saved[key] = ProjectSettings.get_setting(key)
		ProjectSettings.set_setting(key, DogSettings.DEFAULTS[key])


func after_each() -> void:
	for key in [DogSettings.PREFIX, DogSettings.SUFFIX]:
		ProjectSettings.clear(key)
		if _saved.has(key):
			ProjectSettings.set_setting(key, _saved[key])


func _args(line: String) -> PackedStringArray:
	return DogCli.tokenize(line)


# --- command metadata ------------------------------------------------------


func test_command_name_and_usage() -> void:
	assert_eq(_command.command_name(), "bind")
	assert_ne(_command.description(), "")
	assert_string_contains(_command.usage(), "bind <actor> [component...]")
	assert_string_contains(_command.usage(), "--no-fix")
	assert_string_contains(_command.usage(), "--folder")


func test_usage_has_no_root_option() -> void:
	assert_false(_command.usage().contains("--root"))


# --- parse_request ---------------------------------------------------------


func test_parse_actor_only_defaults_to_add_mode() -> void:
	var r := DogBindCommand.parse_request(_args("player"))
	assert_eq(r.error, "")
	assert_eq(r.actor, "player")
	assert_eq(r.folder, "")
	assert_eq(r.mode, DogScriptMerge.Mode.ADD)


func test_parse_force_flag_short_and_long() -> void:
	assert_eq(DogBindCommand.parse_request(_args("player -f")).mode, DogScriptMerge.Mode.FORCE)
	assert_eq(DogBindCommand.parse_request(_args("player --force")).mode, DogScriptMerge.Mode.FORCE)


func test_parse_update_flag_short_and_long() -> void:
	assert_eq(DogBindCommand.parse_request(_args("player -u")).mode, DogScriptMerge.Mode.UPDATE)
	var request := DogBindCommand.parse_request(_args("player --update"))
	assert_eq(request.mode, DogScriptMerge.Mode.UPDATE)


func test_parse_force_and_update_together_is_an_error() -> void:
	var r := DogBindCommand.parse_request(_args("player -f -u"))
	assert_string_contains(r.error, "-f")
	assert_string_contains(r.error, "-u")


func test_parse_folder_value() -> void:
	var r := DogBindCommand.parse_request(_args("slime --folder characters/enemies/slime"))
	assert_eq(r.error, "")
	assert_eq(r.folder, "characters/enemies/slime")


func test_parse_root_is_not_an_option_anymore() -> void:
	var r := DogBindCommand.parse_request(_args("slime --root res://scenes"))
	assert_string_contains(r.error, "--root")


func test_parse_actor_with_a_digit_part_is_valid() -> void:
	var r := DogBindCommand.parse_request(_args("character_body_2d"))
	assert_eq(r.error, "")
	assert_eq(r.actor, "character_body_2d")


func test_parse_missing_actor_is_an_error() -> void:
	var r := DogBindCommand.parse_request(_args(""))
	assert_string_contains(r.error, "actor")


func test_parse_invalid_actor_is_an_error() -> void:
	var r := DogBindCommand.parse_request(_args("Player"))
	assert_string_contains(r.error, "Player")


func test_parse_unknown_option_is_an_error() -> void:
	var r := DogBindCommand.parse_request(_args("player --bogus"))
	assert_string_contains(r.error, "--bogus")


func test_parse_components_are_the_tokens_after_the_actor() -> void:
	var r := DogBindCommand.parse_request(_args("player --no-fix dog_jump_2d dog_move_2d"))
	assert_eq(r.error, "")
	assert_eq(r.components, ["DogJump2D", "DogMove2D"])


func test_parse_without_components_is_not_a_parse_error() -> void:
	var r := DogBindCommand.parse_request(_args("player"))
	assert_eq(r.error, "")
	assert_eq(r.components, [])


func test_parse_prefix_and_suffix_wrap_every_component() -> void:
	var r := DogBindCommand.parse_request(
		_args("player --prefix dog --suffix 2d jump gravity move")
	)
	assert_eq(r.error, "")
	assert_eq(r.components, ["DogJump2D", "DogGravity2D", "DogMove2D"])


func test_parse_prefix_alone_and_suffix_alone() -> void:
	assert_eq(
		DogBindCommand.parse_request(_args("player --prefix fx jump")).components,
		["FxJump2D"],
	)
	assert_eq(
		DogBindCommand.parse_request(_args("player --suffix 3d jump")).components,
		["DogJump3D"],
	)


func test_parse_prefix_and_suffix_tolerate_a_stray_underscore() -> void:
	var r := DogBindCommand.parse_request(_args("player --prefix dog_ --suffix _2d jump"))
	assert_eq(r.components, ["DogJump2D"])
	ProjectSettings.set_setting(DogSettings.PREFIX, "dog_")
	ProjectSettings.set_setting(DogSettings.SUFFIX, "_2d")
	assert_eq(DogBindCommand.parse_request(_args("player jump")).components, ["DogJump2D"])


func test_parse_prefix_is_not_deduplicated() -> void:
	var r := DogBindCommand.parse_request(_args("player dog_jump_2d"))
	assert_eq(r.components, ["DogDogJump2D2D"])


func test_parse_without_flags_uses_the_settings() -> void:
	var r := DogBindCommand.parse_request(_args("player jump move"))
	assert_eq(r.error, "")
	assert_eq(r.components, ["DogJump2D", "DogMove2D"])


func test_parse_uses_a_changed_setting() -> void:
	ProjectSettings.set_setting(DogSettings.PREFIX, "my")
	ProjectSettings.set_setting(DogSettings.SUFFIX, "")
	assert_eq(DogBindCommand.parse_request(_args("player jump")).components, ["MyJump"])


func test_parse_empty_prefix_or_suffix_drops_only_that_side() -> void:
	assert_eq(DogBindCommand.parse_request(_args("player --prefix= jump")).components, ["Jump2D"])
	assert_eq(DogBindCommand.parse_request(_args("player --suffix= jump")).components, ["DogJump"])


func test_parse_no_fix_drops_prefix_and_suffix() -> void:
	var r := DogBindCommand.parse_request(_args("player --no-fix jump dog_move_2d"))
	assert_eq(r.error, "")
	assert_eq(r.components, ["Jump", "DogMove2D"])


func test_parse_fix_flags_without_components_are_an_error() -> void:
	var lines := ["player --prefix dog", "player --suffix 2d", "player --prefix="]
	lines.append("player --no-fix")
	for line in lines:
		var r := DogBindCommand.parse_request(_args(line))
		assert_string_contains(r.error, "need components", line)


func test_parse_no_fix_with_prefix_or_suffix_is_an_error() -> void:
	for line in ["player --no-fix --prefix dog jump", "player --no-fix --suffix= jump"]:
		var r := DogBindCommand.parse_request(_args(line))
		assert_string_contains(r.error, "--no-fix", line)


func test_parse_invalid_component_is_an_error() -> void:
	var r := DogBindCommand.parse_request(_args("player Wall-Climb"))
	assert_eq(r.error, DogBindCommand.INVALID_COMPONENT % "Wall-Climb")
	r = DogBindCommand.parse_request(_args("player --prefix=a-b jump"))
	assert_eq(r.error, DogBindCommand.INVALID_COMPONENT % "a-b_jump_2d")


func test_parse_a_component_with_an_upper_case_letter_is_literal() -> void:
	var r := DogBindCommand.parse_request(_args("player move FixtureWallClimb DogJump2D"))
	assert_eq(r.error, "")
	assert_eq(r.components, ["DogMove2D", "FixtureWallClimb", "DogJump2D"])


func test_parse_a_hybrid_component_is_literal_and_made_pascal() -> void:
	var r := DogBindCommand.parse_request(_args("player CPU_particles_2d Fixture_wall_climb"))
	assert_eq(r.components, ["CPUParticles2D", "FixtureWallClimb"])


func test_parse_fix_flags_apply_only_to_lower_case_components() -> void:
	var r := DogBindCommand.parse_request(_args("player --prefix fx --suffix 3d jump DogMove2D"))
	assert_eq(r.components, ["FxJump3D", "DogMove2D"])
	var full := DogBindCommand.parse_request(_args("player --no-fix fixture_dash FixtureDash"))
	assert_eq(full.components, ["FixtureDash", "FixtureDash"])


# --- options_for -------------------------------------------------------------


func test_options_for_copies_the_request() -> void:
	var request := DogBindCommand.parse_request(
		_args("player dog_jump_2d --no-fix --folder characters/enemies/slime -f")
	)
	var options := DogBindCommand.options_for(request)
	assert_eq(options.actor, "player")
	assert_eq(options.components, ["DogJump2D"])
	assert_eq(options.folder, "characters/enemies/slime")
	assert_eq(options.mode, DogScriptMerge.Mode.FORCE)
