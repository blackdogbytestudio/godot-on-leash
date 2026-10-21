# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogStateCommand.parse_request and the run paths that stop before generating.

const Command := preload("res://addons/leash/cli/commands/dog_state_command.gd")
const ROOT := "user://dog_state_command_test"


func before_each() -> void:
	_remove(ROOT)


func after_each() -> void:
	_remove(ROOT)


func _request(args: PackedStringArray) -> DogStateCommand.Request:
	return Command.parse_request(args)


func _run(args: PackedStringArray) -> Array:
	var command := Command.new()
	command.root = ROOT
	var lines: Array[String] = []
	command.printed.connect(func(text: String) -> void: lines.append(text))
	var error := command.run(args)
	return [error, lines]


func _remove(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	for sub in dir.get_directories():
		_remove(path.path_join(sub))
	DirAccess.remove_absolute(path)


# --- parse ------------------------------------------------------------------


func test_parse_accepts_hpda() -> void:
	var request := _request(PackedStringArray(["hpda", "enemy", "alive", ".grounded", "dead"]))
	assert_eq(request.error, "")
	assert_eq(request.type, "hpda")
	assert_eq(request.actor, "enemy")
	assert_eq(request.tree.nodes.size(), 3)


func test_parse_reads_folder_and_extends() -> void:
	var request := _request(PackedStringArray([
		"hpda", "slime", "--folder", "enemies/slime",
		"--extends", "enemy_alive_state", "jump",
	]))
	assert_eq(request.error, "")
	assert_eq(request.folder, "enemies/slime")
	assert_eq(request.extends_state, "enemy_alive_state")


func test_parse_rejects_host_option() -> void:
	var request := _request(PackedStringArray(["hpda", "slime", "--host", "Slime", "jump"]))
	assert_string_contains(request.error, "unknown option '--host'")


func test_parse_rejects_hdpa() -> void:
	assert_ne(_request(PackedStringArray(["hdpa", "enemy", "alive"])).error, "")


func test_parse_requires_actor() -> void:
	assert_ne(_request(PackedStringArray(["fsm"])).error, "")


func test_parse_rejects_invalid_actor() -> void:
	assert_ne(_request(PackedStringArray(["fsm", "Player"])).error, "")


func test_parse_rejects_unknown_option() -> void:
	assert_ne(_request(PackedStringArray(["fsm", "player", "--nope"])).error, "")


func test_parse_rejects_nesting_on_flat_types() -> void:
	assert_ne(_request(PackedStringArray(["fsm", "player", "alive", ".run"])).error, "")


func test_flat_types_accept_multiple_roots() -> void:
	var request := _request(PackedStringArray(["fsm", "player", "alive", "dead"]))
	assert_eq(request.error, "")
	assert_eq(request.tree.nodes.size(), 2)


func test_parse_accepts_actor_with_a_digit_part() -> void:
	assert_eq(_request(PackedStringArray(["fsm", "character_body_2d", "idle"])).error, "")


func test_initial_with_dots_is_a_parse_error() -> void:
	assert_ne(
		_request(PackedStringArray(["hpda", "enemy", "--initial", ".alive", "alive"])).error,
		"",
	)


func test_force_with_update_is_a_parse_error() -> void:
	assert_string_contains(
		_request(PackedStringArray(["hpda", "enemy", "-f", "-u", "alive"])).error,
		"-f or -u",
	)


func test_folder_with_parent_traversal_is_a_parse_error() -> void:
	assert_ne(_request(PackedStringArray(["hpda", "enemy", "--folder", "../x", "alive"])).error, "")
	assert_ne(
		_request(PackedStringArray(["hpda", "enemy", "--folder", "a/../b", "alive"])).error,
		"",
	)


# --- run (parse errors only) ------------------------------------------------


func test_run_reports_parse_errors() -> void:
	var result := _run(PackedStringArray(["hdpa", "enemy", "alive"]))
	assert_eq(result[0], ERR_INVALID_PARAMETER)
	assert_eq(result[1].size(), 1)
	assert_string_contains(result[1][0], "Dog: state:")
	assert_eq(DirAccess.open(ROOT), null)


func test_run_reports_unknown_type() -> void:
	var result := _run(PackedStringArray(["nope", "enemy", "alive"]))
	assert_eq(result[0], ERR_INVALID_PARAMETER)
	assert_string_contains(result[1][0], "unknown type")
