extends GutTest
## DogDestroyCommand.run end to end: what it prints after deleting in
## res://scenes/tmp, which every test removes. The folder settings are pointed at it.

const ROOT_DIR := "scenes/tmp/destroy_cmd_test"
const ROOT := "res://" + ROOT_DIR
const KEYS := [DogSettings.IMPLICIT_FOLDER, DogSettings.EXPLICIT_FOLDER]

var _saved := {}


func before_each() -> void:
	_saved.clear()
	for key in KEYS:
		if ProjectSettings.has_setting(key):
			_saved[key] = ProjectSettings.get_setting(key)
		ProjectSettings.set_setting(key, ROOT_DIR)
	_remove(ROOT)


func after_each() -> void:
	_remove(ROOT)
	DirAccess.remove_absolute("res://scenes/tmp")  # only succeeds when empty
	for key in KEYS:
		if _saved.has(key):
			ProjectSettings.set_setting(key, _saved[key])
		elif ProjectSettings.has_setting(key):
			ProjectSettings.clear(key)


func _run(line: String) -> Array:
	var command := DogDestroyCommand.new()
	var lines: Array[String] = []
	command.printed.connect(func(text: String) -> void: lines.append(text))
	var error := command.run(DogCli.tokenize(line))
	return [error, lines]


func _write(path: String, text := "x") -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	for sub in dir.get_directories():
		_remove(path.path_join(sub))
	DirAccess.remove_absolute(path)


## A knight with a scene, a script and one state.
func _knight() -> String:
	var dir := ROOT.path_join("knight")
	_write(dir.path_join("knight.tscn"))
	_write(dir.path_join("knight.gd"))
	_write(dir.path_join("states/knight_idle_state.gd"))
	return dir


func test_run_deletes_only_the_scene_and_the_script_by_default() -> void:
	var dir := _knight()
	var result := _run("knight")
	var expected: Array[String] = [
		"deleted " + dir.path_join("knight.tscn"),
		"deleted " + dir.path_join("knight.gd"),
	]
	assert_eq(result, [OK, expected])
	assert_true(FileAccess.file_exists(dir.path_join("states/knight_idle_state.gd")))


func test_run_with_r_deletes_the_states_and_the_directory() -> void:
	var dir := _knight()
	var result := _run("knight -r")
	var expected: Array[String] = [
		"deleted " + dir.path_join("knight.tscn"),
		"deleted " + dir.path_join("knight.gd"),
		"deleted " + dir.path_join("states/knight_idle_state.gd"),
		"deleted " + dir.path_join("states"),
		"deleted " + dir,
	]
	assert_eq(result, [OK, expected])
	assert_false(DirAccess.dir_exists_absolute(dir))


func test_run_with_r_reports_what_it_left() -> void:
	var dir := _knight()
	_write(dir.path_join("knight.png"))
	var result := _run("knight -r")
	var expected: Array[String] = [
		"deleted " + dir.path_join("knight.tscn"),
		"deleted " + dir.path_join("knight.gd"),
		"deleted " + dir.path_join("states/knight_idle_state.gd"),
		"deleted " + dir.path_join("states"),
		"kept %s (not empty: knight.png)" % dir,
	]
	assert_eq(result, [OK, expected])
	assert_true(FileAccess.file_exists(dir.path_join("knight.png")))


func test_run_with_f_deletes_everything_in_the_directory() -> void:
	var dir := _knight()
	_write(dir.path_join("knight.png"))
	var result := _run("knight -f")
	var expected: Array[String] = [
		"deleted " + dir.path_join("knight.gd"),
		"deleted " + dir.path_join("knight.png"),
		"deleted " + dir.path_join("knight.tscn"),
		"deleted " + dir.path_join("states/knight_idle_state.gd"),
		"deleted " + dir.path_join("states"),
		"deleted " + dir,
	]
	assert_eq(result, [OK, expected])
	assert_false(DirAccess.dir_exists_absolute(dir))


func test_run_deletes_what_the_actor_command_created() -> void:
	var command := DogActorCommand.new()
	assert_eq(command.run(DogCli.tokenize("knight")), OK)
	var dir := ROOT.path_join("knight")
	assert_true(FileAccess.file_exists(dir.path_join("knight.tscn")))

	assert_eq(_run("knight -r")[0], OK)
	assert_false(DirAccess.dir_exists_absolute(dir))


func test_run_with_folder() -> void:
	var dir := ROOT.path_join("enemies/slime")
	_write(dir.path_join("slime.gd"))
	var result := _run("slime --folder enemies/slime -f")
	assert_eq(result[0], OK)
	assert_has(result[1], "deleted " + dir)
	assert_false(DirAccess.dir_exists_absolute(dir))


func test_run_in_a_shared_folder_deletes_the_files_but_refuses_r_and_f() -> void:
	var dir := ROOT.path_join("enemies")
	_write(dir.path_join("slime.gd"))
	_write(dir.path_join("bat/bat.gd"))
	var message: String = DogDestroyGenerator.WRONG_DIR_NAME % [dir, "slime", "slime"]
	var refused: Array[String] = ["Dog: destroy: " + message]
	for flag in ["-r", "-f"]:
		assert_eq(_run("slime --folder enemies " + flag), [FAILED, refused], flag)
		assert_true(FileAccess.file_exists(dir.path_join("slime.gd")))

	var deleted: Array[String] = ["deleted " + dir.path_join("slime.gd")]
	assert_eq(_run("slime --folder enemies"), [OK, deleted])
	assert_true(FileAccess.file_exists(dir.path_join("bat/bat.gd")))


func test_run_on_a_missing_actor_prints_the_error() -> void:
	var dir := ROOT.path_join("ghost")
	var result := _run("ghost")
	var expected: Array[String] = ["Dog: destroy: " + DogDestroyGenerator.DIR_NOT_FOUND % dir]
	assert_eq(result, [FAILED, expected])


func test_run_with_a_bad_line_prints_the_error_and_deletes_nothing() -> void:
	var dir := ROOT.path_join("knight")
	_write(dir.path_join("knight.gd"))
	var result := _run("Knight")
	var expected: Array[String] = ["Dog: destroy: " + DogNames.INVALID_ACTOR % "Knight"]
	assert_eq(result, [ERR_INVALID_PARAMETER, expected])
	assert_true(FileAccess.file_exists(dir.path_join("knight.gd")))
