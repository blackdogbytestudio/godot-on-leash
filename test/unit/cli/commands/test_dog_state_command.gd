# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogStateCommand.parse_request and the run paths that stop before generating.

const Command := preload("res://addons/leash/cli/commands/dog_state_command.gd")


func _request(args: PackedStringArray) -> DogStateCommand.Request:
	return Command.parse_request(args)


func _run(args: PackedStringArray) -> Array:
	var command := Command.new()
	var lines: Array[String] = []
	command.printed.connect(func(text: String) -> void: lines.append(text))
	var error := command.run(args)
	return [error, lines]


# --- parse ------------------------------------------------------------------


func test_parse_accepts_hpda() -> void:
	var request := _request(PackedStringArray(["enemy", "hpda", "alive", ".grounded", "dead"]))
	assert_eq(request.error, "")
	assert_eq(request.actor, "enemy")
	assert_eq(request.type, "hpda")
	assert_eq(request.tree.nodes.size(), 3)


func test_parse_reads_folder_and_extends() -> void:
	var request := _request(PackedStringArray([
		"slime", "hpda", "--folder", "characters/enemies/slime",
		"--extends", "enemy_alive_state", "jump",
	]))
	assert_eq(request.error, "")
	assert_eq(request.folder, "characters/enemies/slime")
	assert_eq(request.extends_state, "enemy_alive_state")


func test_parse_rejects_host_option() -> void:
	var request := _request(PackedStringArray(["slime", "hpda", "--host", "Slime", "jump"]))
	assert_string_contains(request.error, "unknown option '--host'")


func test_parse_rejects_root_option() -> void:
	var request := _request(PackedStringArray(["slime", "hpda", "--root", "res://x", "jump"]))
	assert_string_contains(request.error, "unknown option '--root'")


func test_parse_rejects_hdpa() -> void:
	assert_ne(_request(PackedStringArray(["enemy", "hdpa", "alive"])).error, "")


func test_parse_requires_actor() -> void:
	assert_string_contains(_request(PackedStringArray([])).error, "missing <actor>")


func test_parse_requires_type() -> void:
	assert_string_contains(_request(PackedStringArray(["player"])).error, "missing <type>")


func test_parse_rejects_type_before_actor() -> void:
	assert_string_contains(
		_request(PackedStringArray(["hpda", "player", "alive"])).error,
		"unknown type 'player'",
	)


func test_parse_rejects_invalid_actor() -> void:
	assert_ne(_request(PackedStringArray(["Player", "fsm"])).error, "")


func test_parse_rejects_unknown_option() -> void:
	assert_ne(_request(PackedStringArray(["player", "fsm", "--nope"])).error, "")


func test_parse_rejects_nesting_on_flat_types() -> void:
	assert_ne(_request(PackedStringArray(["player", "fsm", "alive", ".run"])).error, "")


func test_flat_types_accept_multiple_roots() -> void:
	var request := _request(PackedStringArray(["player", "fsm", "alive", "dead"]))
	assert_eq(request.error, "")
	assert_eq(request.tree.nodes.size(), 2)


func test_parse_accepts_actor_with_a_digit_part() -> void:
	assert_eq(_request(PackedStringArray(["character_body_2d", "fsm", "idle"])).error, "")


func test_initial_with_dots_is_a_parse_error() -> void:
	assert_ne(
		_request(PackedStringArray(["enemy", "hpda", "--initial", ".alive", "alive"])).error,
		"",
	)


func test_force_with_update_is_a_parse_error() -> void:
	assert_string_contains(
		_request(PackedStringArray(["enemy", "hpda", "-f", "-u", "alive"])).error,
		"-f or -u",
	)


func test_folder_with_parent_traversal_is_a_parse_error() -> void:
	assert_ne(_request(PackedStringArray(["enemy", "hpda", "--folder", "../x", "alive"])).error, "")
	assert_ne(
		_request(PackedStringArray(["enemy", "hpda", "--folder", "a/../b", "alive"])).error,
		"",
	)


func test_folder_with_a_scheme_is_a_parse_error() -> void:
	var request := _request(PackedStringArray(["enemy", "hpda", "--folder", "res://x", "alive"]))
	assert_eq(request.error, DogNames.folder_error("res://x"))


# --- run (parse errors only) ------------------------------------------------


func test_run_reports_parse_errors() -> void:
	var result := _run(PackedStringArray(["enemy", "hdpa", "alive"]))
	assert_eq(result[0], ERR_INVALID_PARAMETER)
	assert_eq(result[1].size(), 1)
	assert_string_contains(result[1][0], "Dog: state:")


func test_run_reports_unknown_type() -> void:
	var result := _run(PackedStringArray(["enemy", "nope", "alive"]))
	assert_eq(result[0], ERR_INVALID_PARAMETER)
	assert_string_contains(result[1][0], "unknown type")


# --- options_for -------------------------------------------------------------


func test_options_for_copies_the_request() -> void:
	var request := _request(PackedStringArray([
		"slime", "hpda", "--folder", "characters/enemies/slime", "--extends", "enemy_alive_state",
		"--initial", "jump", "-u", "jump",
	]))
	var options := Command.options_for(request)
	assert_eq(options.actor, "slime")
	assert_eq(options.type, "hpda")
	assert_eq(options.folder, "characters/enemies/slime")
	assert_eq(options.base, "enemy_alive_state")
	assert_eq(options.initial, "jump")
	assert_eq(options.mode, DogScriptMerge.Mode.UPDATE)
	assert_eq(options.tree, request.tree)
