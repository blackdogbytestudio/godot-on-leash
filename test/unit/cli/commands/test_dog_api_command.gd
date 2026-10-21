# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogApiCommand metadata and parse_request: no files involved.

var _command: DogApiCommand


func before_each() -> void:
	_command = DogApiCommand.new()


func _args(line: String) -> PackedStringArray:
	return DogCli.tokenize(line)


# --- command metadata ------------------------------------------------------


func test_command_name_and_usage() -> void:
	assert_eq(_command.command_name(), "api")
	assert_ne(_command.description(), "")
	assert_string_contains(_command.usage(), "api <actor> <component...>")


# --- parse_request ---------------------------------------------------------


func test_parse_actor_only_defaults_to_add_mode() -> void:
	var r := DogApiCommand.parse_request(_args("player"))
	assert_eq(r.error, "")
	assert_eq(r.actor, "player")
	assert_eq(r.folder, "")
	assert_eq(r.root, "")
	assert_eq(r.mode, DogScriptMerge.Mode.ADD)


func test_parse_force_flag_short_and_long() -> void:
	assert_eq(DogApiCommand.parse_request(_args("player -f")).mode, DogScriptMerge.Mode.FORCE)
	assert_eq(DogApiCommand.parse_request(_args("player --force")).mode, DogScriptMerge.Mode.FORCE)


func test_parse_update_flag_short_and_long() -> void:
	assert_eq(DogApiCommand.parse_request(_args("player -u")).mode, DogScriptMerge.Mode.UPDATE)
	var request := DogApiCommand.parse_request(_args("player --update"))
	assert_eq(request.mode, DogScriptMerge.Mode.UPDATE)


func test_parse_force_and_update_together_is_an_error() -> void:
	var r := DogApiCommand.parse_request(_args("player -f -u"))
	assert_string_contains(r.error, "-f")
	assert_string_contains(r.error, "-u")


func test_parse_folder_and_root_values() -> void:
	var r := DogApiCommand.parse_request(_args("slime --folder enemies/slime --root res://scenes"))
	assert_eq(r.error, "")
	assert_eq(r.folder, "enemies/slime")
	assert_eq(r.root, "res://scenes")


func test_parse_actor_with_a_digit_part_is_valid() -> void:
	var r := DogApiCommand.parse_request(_args("character_body_2d"))
	assert_eq(r.error, "")
	assert_eq(r.actor, "character_body_2d")


func test_parse_missing_actor_is_an_error() -> void:
	var r := DogApiCommand.parse_request(_args(""))
	assert_string_contains(r.error, "actor")


func test_parse_invalid_actor_is_an_error() -> void:
	var r := DogApiCommand.parse_request(_args("Player"))
	assert_string_contains(r.error, "Player")


func test_parse_unknown_option_is_an_error() -> void:
	var r := DogApiCommand.parse_request(_args("player --bogus"))
	assert_string_contains(r.error, "--bogus")


func test_parse_components_are_the_tokens_after_the_actor() -> void:
	var r := DogApiCommand.parse_request(_args("player dog_jump_2d dog_move_2d"))
	assert_eq(r.error, "")
	assert_eq(r.components, ["dog_jump_2d", "dog_move_2d"])


func test_parse_without_components_is_not_a_parse_error() -> void:
	var r := DogApiCommand.parse_request(_args("player"))
	assert_eq(r.error, "")
	assert_eq(r.components, [])


func test_parse_prefix_and_suffix_wrap_every_component() -> void:
	var r := DogApiCommand.parse_request(_args("player --prefix dog --suffix 2d jump gravity move"))
	assert_eq(r.error, "")
	assert_eq(r.components, ["dog_jump_2d", "dog_gravity_2d", "dog_move_2d"])


func test_parse_prefix_alone_and_suffix_alone() -> void:
	assert_eq(
		DogApiCommand.parse_request(_args("player --prefix dog jump")).components,
		["dog_jump"],
	)
	assert_eq(DogApiCommand.parse_request(_args("player --suffix 2d jump")).components, ["jump_2d"])


func test_parse_prefix_and_suffix_tolerate_a_stray_underscore() -> void:
	var r := DogApiCommand.parse_request(_args("player --prefix dog_ --suffix _2d jump"))
	assert_eq(r.components, ["dog_jump_2d"])


func test_parse_prefix_is_not_deduplicated() -> void:
	var r := DogApiCommand.parse_request(_args("player --prefix dog dog_jump"))
	assert_eq(r.components, ["dog_dog_jump"])


func test_parse_invalid_component_is_an_error() -> void:
	var r := DogApiCommand.parse_request(_args("player DogJump2D"))
	assert_string_contains(r.error, "DogJump2D")
	r = DogApiCommand.parse_request(_args("player --prefix Dog jump"))
	assert_string_contains(r.error, "Dog_jump")


# --- options_for -------------------------------------------------------------


func test_options_for_copies_the_request() -> void:
	var request := DogApiCommand.parse_request(
		_args("player dog_jump_2d --folder enemies/slime --root res://scenes -f")
	)
	var options := DogApiCommand.options_for(request, "res://default")
	assert_eq(options.actor, "player")
	assert_eq(options.components, ["dog_jump_2d"])
	assert_eq(options.folder, "enemies/slime")
	assert_eq(options.root, "res://scenes")
	assert_eq(options.mode, DogScriptMerge.Mode.FORCE)


func test_options_for_uses_the_default_root_without_root() -> void:
	var request := DogApiCommand.parse_request(_args("player dog_jump_2d"))
	assert_eq(DogApiCommand.options_for(request, "res://default").root, "res://default")
