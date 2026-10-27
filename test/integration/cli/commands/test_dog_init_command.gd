extends GutTest
## DogInitCommand.run end to end: what it prints after setting up user://.

const Command := preload("res://addons/leash/cli/commands/dog_init_command.gd")
const ROOT := "user://dog_init_command_test"


func before_each() -> void:
	_remove(ROOT)


func after_each() -> void:
	_remove(ROOT)


func _run(args: Array) -> Array:
	var command := Command.new()
	command.root = ROOT
	var lines: Array[String] = []
	command.printed.connect(func(text: String) -> void: lines.append(text))
	var error := command.run(PackedStringArray(args))
	return [error, lines]


func _lines_starting(lines: Array, prefix: String) -> Array:
	return lines.filter(func(line: String) -> bool: return line.begins_with(prefix))


func _remove(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	for file in dir.get_files():
		dir.remove(file)
	for sub in dir.get_directories():
		_remove(path.path_join(sub))
	DirAccess.remove_absolute(path)


func test_prints_one_create_line_per_item() -> void:
	var ran := _run([])
	var lines: Array = ran[1]
	assert_eq(ran[0], OK)
	assert_eq(lines[0], "create %s/assets" % ROOT)
	assert_has(lines, "create %s/scenes/characters/player" % ROOT)
	assert_has(lines, "create %s/script_templates/.gdignore" % ROOT)
	assert_has(lines, "create %s/script_templates/DogHPDAState/state.gd" % ROOT)
	assert_eq(_lines_starting(lines, "exist "), [])


func test_prints_exist_for_what_is_already_there() -> void:
	_run([])
	var lines: Array = _run([])[1]
	assert_eq(_lines_starting(lines, "create "), [])
	assert_has(lines, "exist %s/assets" % ROOT)
	assert_has(lines, "exist %s/script_templates/DogFSMState/class.gd" % ROOT)


func test_prints_the_gut_warning_last() -> void:
	var lines: Array = _run([])[1]
	assert_eq(
		lines[-1],
		"warning GUT is not installed (no %s/addons/gut/plugin.cfg): the tests need it." % ROOT,
	)


func test_skip_templates_prints_no_template() -> void:
	var lines: Array = _run(["--skip-templates"])[1]
	assert_eq(_lines_starting(lines, "create %s/script_templates" % ROOT), [])
	assert_false(DirAccess.dir_exists_absolute(ROOT + "/script_templates"))


func test_an_unknown_option_writes_nothing() -> void:
	var ran := _run(["--templates"])
	assert_eq(ran[0], ERR_INVALID_PARAMETER)
	assert_eq(ran[1], ["Dog: init: unknown option '--templates'."])
	assert_false(DirAccess.dir_exists_absolute(ROOT))
