# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogDestroyGenerator end to end: the actors are made in res://scenes/tmp, which
## every test removes. The folder settings are pointed at it.

const ROOT_DIR := "scenes/tmp/destroy_gen_test"
const ROOT := "res://" + ROOT_DIR
const KEYS := [DogSettings.IMPLICIT_FOLDER, DogSettings.EXPLICIT_FOLDER]
const FILES := DogDestroyGenerator.Mode.FILES
const STATES := DogDestroyGenerator.Mode.STATES
const ALL := DogDestroyGenerator.Mode.ALL

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


func _options(
	actor: String,
	folder := "",
	mode := DogDestroyGenerator.Mode.FILES,
) -> DogDestroyGenerator.Options:
	var options := DogDestroyGenerator.Options.new()
	options.actor = actor
	options.folder = folder
	options.mode = mode
	return options


func _write(path: String, text := "x") -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


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


## A knight: scene, script and its .uid, and a states folder two levels deep.
func _knight() -> String:
	var dir := ROOT.path_join("knight")
	_write(dir.path_join("knight.tscn"))
	_write(dir.path_join("knight.gd"))
	_write(dir.path_join("knight.gd.uid"))
	_write(dir.path_join("states/knight_idle_state.gd"))
	_write(dir.path_join("states/sub/deep.gd"))
	return dir


func _exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


# --- FILES --------------------------------------------------------------------


func test_files_plans_the_scene_the_script_and_its_uid() -> void:
	var dir := _knight()
	var result := DogDestroyGenerator.build(_options("knight"))
	assert_eq(result.error, "")
	assert_eq(result.dir, dir)
	var expected: Array[String] = [
		dir.path_join("knight.tscn"),
		dir.path_join("knight.gd"),
		dir.path_join("knight.gd.uid"),
	]
	assert_eq(result.paths, expected)
	assert_eq(result.deleted.size(), 0, "build deletes nothing")
	assert_true(_exists(dir.path_join("knight.gd")))


func test_files_deletes_only_those_and_leaves_the_rest() -> void:
	var dir := _knight()
	_write(dir.path_join("knight.png"))

	var result := DogDestroyGenerator.generate(_options("knight"))
	assert_eq(result.error, "")
	assert_eq(result.deleted, result.paths)
	for name in ["knight.tscn", "knight.gd", "knight.gd.uid"]:
		assert_false(_exists(dir.path_join(name)), name)
	assert_true(_exists(dir.path_join("knight.png")))
	assert_true(_exists(dir.path_join("states/knight_idle_state.gd")))


func test_files_works_in_a_folder_shared_with_other_actors() -> void:
	var dir := ROOT.path_join("enemies")
	_write(dir.path_join("slime.gd"))
	_write(dir.path_join("slime.gd.uid"))
	_write(dir.path_join("bat/bat.gd"))

	var result := DogDestroyGenerator.generate(_options("slime", "enemies"))
	assert_eq(result.error, "")
	assert_false(_exists(dir.path_join("slime.gd")))
	assert_false(_exists(dir.path_join("slime.gd.uid")))
	assert_true(_exists(dir.path_join("bat/bat.gd")))


func test_files_deletes_an_actor_with_only_its_scene_or_only_its_script() -> void:
	_write(ROOT.path_join("half_a/half_a.tscn"))
	_write(ROOT.path_join("half_b/half_b.gd"))
	assert_eq(DogDestroyGenerator.generate(_options("half_a")).error, "")
	assert_eq(DogDestroyGenerator.generate(_options("half_b")).error, "")
	assert_false(_exists(ROOT.path_join("half_a/half_a.tscn")))
	assert_false(_exists(ROOT.path_join("half_b/half_b.gd")))


# --- STATES -------------------------------------------------------------------


func test_states_plans_the_files_the_states_folder_and_the_directory() -> void:
	var dir := _knight()
	var result := DogDestroyGenerator.build(_options("knight", "", STATES))
	assert_eq(result.error, "")
	var expected: Array[String] = [
		dir.path_join("knight.tscn"),
		dir.path_join("knight.gd"),
		dir.path_join("knight.gd.uid"),
		dir.path_join("states/knight_idle_state.gd"),
		dir.path_join("states/sub/deep.gd"),
		dir.path_join("states/sub"),
		dir.path_join("states"),
		dir,
	]
	assert_eq(result.paths, expected)
	assert_eq(result.kept.size(), 0)


func test_states_deletes_the_directory_when_nothing_else_is_left() -> void:
	var dir := _knight()
	var sibling := ROOT.path_join("squire/squire.gd")
	_write(sibling)

	var result := DogDestroyGenerator.generate(_options("knight", "", STATES))
	assert_eq(result.error, "")
	assert_eq(result.deleted, result.paths)
	assert_false(_exists(dir))
	assert_true(_exists(sibling), "another actor stays")
	assert_true(_exists(ROOT), "the parent folder stays")


func test_states_keeps_the_directory_and_reports_what_is_left() -> void:
	var dir := _knight()
	_write(dir.path_join("knight.png"))
	_write(dir.path_join("notes.txt"))

	var result := DogDestroyGenerator.generate(_options("knight", "", STATES))
	assert_eq(result.error, "")
	var kept: Array[String] = ["knight.png", "notes.txt"]
	assert_eq(result.kept, kept)
	assert_does_not_have(result.deleted, dir)
	assert_true(_exists(dir.path_join("knight.png")))
	assert_true(_exists(dir.path_join("notes.txt")))
	assert_false(_exists(dir.path_join("states")))
	assert_false(_exists(dir.path_join("knight.tscn")))


func test_states_without_a_states_folder_deletes_the_files_and_the_directory() -> void:
	var dir := ROOT.path_join("knight")
	_write(dir.path_join("knight.tscn"))
	_write(dir.path_join("knight.gd"))
	var result := DogDestroyGenerator.generate(_options("knight", "", STATES))
	assert_eq(result.error, "")
	assert_false(_exists(dir))


# --- ALL ----------------------------------------------------------------------


func test_all_plans_everything_with_each_folder_after_its_content() -> void:
	var dir := _knight()
	_write(dir.path_join("knight.png"))
	var result := DogDestroyGenerator.build(_options("knight", "", ALL))
	assert_eq(result.error, "")
	var expected: Array[String] = [
		dir.path_join("knight.gd"),
		dir.path_join("knight.gd.uid"),
		dir.path_join("knight.png"),
		dir.path_join("knight.tscn"),
		dir.path_join("states/knight_idle_state.gd"),
		dir.path_join("states/sub/deep.gd"),
		dir.path_join("states/sub"),
		dir.path_join("states"),
		dir,
	]
	assert_eq(result.paths, expected)
	assert_true(_exists(dir), "build deletes nothing")


func test_all_deletes_the_directory_and_only_that_one() -> void:
	var dir := _knight()
	_write(dir.path_join("knight.png"))
	var sibling := ROOT.path_join("squire/squire.gd")
	_write(sibling)

	var result := DogDestroyGenerator.generate(_options("knight", "", ALL))
	assert_eq(result.error, "")
	assert_eq(result.deleted, result.paths)
	assert_false(_exists(dir))
	assert_true(_exists(sibling), "another actor stays")
	assert_true(_exists(ROOT), "the parent folder stays")


func test_all_deletes_hidden_files_too() -> void:
	var dir := _knight()
	_write(dir.path_join(".hidden"))
	var result := DogDestroyGenerator.generate(_options("knight", "", ALL))
	assert_eq(result.error, "")
	assert_false(_exists(dir))


func test_all_with_folder_finds_the_actor_there() -> void:
	var dir := ROOT.path_join("enemies/slime")
	_write(dir.path_join("slime.tscn"))
	_write(dir.path_join("slime.gd"))
	var other := ROOT.path_join("enemies/bat/bat.gd")
	_write(other)

	var result := DogDestroyGenerator.generate(_options("slime", "enemies/slime", ALL))
	assert_eq(result.error, "")
	assert_false(_exists(dir))
	assert_true(_exists(other))


# --- the folder and the actor -------------------------------------------------


func test_states_and_all_refuse_a_folder_not_named_after_the_actor() -> void:
	var dir := ROOT.path_join("enemies")
	_write(dir.path_join("slime.gd"))
	_write(dir.path_join("bat/bat.gd"))

	for mode in [STATES, ALL]:
		var result := DogDestroyGenerator.generate(_options("slime", "enemies", mode))
		var expected: String = DogDestroyGenerator.WRONG_DIR_NAME % [dir, "slime", "slime"]
		assert_eq(result.error, expected, str(mode))
		assert_eq(result.deleted.size(), 0)
		assert_true(_exists(dir.path_join("slime.gd")))
		assert_true(_exists(dir.path_join("bat/bat.gd")))


func test_the_name_is_checked_before_the_directory_exists() -> void:
	var dir := ROOT.path_join("enemies")
	var expected: String = DogDestroyGenerator.WRONG_DIR_NAME % [dir, "slime", "slime"]
	for mode in [STATES, ALL]:
		assert_eq(DogDestroyGenerator.build(_options("slime", "enemies", mode)).error, expected)
	var files := DogDestroyGenerator.build(_options("slime", "enemies"))
	assert_eq(files.error, DogDestroyGenerator.DIR_NOT_FOUND % dir, "FILES has no name rule")


func test_a_missing_directory_is_an_error() -> void:
	var dir := ROOT.path_join("ghost")
	for mode in [FILES, STATES, ALL]:
		var result := DogDestroyGenerator.generate(_options("ghost", "", mode))
		assert_eq(result.error, DogDestroyGenerator.DIR_NOT_FOUND % dir, str(mode))
		assert_eq(result.deleted.size(), 0)


func test_a_directory_without_the_actor_is_not_touched() -> void:
	var dir := ROOT.path_join("knight")
	_write(dir.path_join("squire.gd"))
	_write(dir.path_join("states/idle.gd"))
	var names := [dir, "knight.tscn", "knight.gd", "knight"]

	for mode in [FILES, STATES, ALL]:
		var result := DogDestroyGenerator.generate(_options("knight", "", mode))
		assert_eq(result.error, DogDestroyGenerator.NOT_AN_ACTOR % names, str(mode))
		assert_eq(result.deleted.size(), 0)
		assert_true(_exists(dir.path_join("squire.gd")))
		assert_true(_exists(dir.path_join("states/idle.gd")))


func test_bad_names_are_errors_and_delete_nothing() -> void:
	var dir := _knight()
	var bad_actor := DogDestroyGenerator.generate(_options("Knight", "", ALL))
	assert_eq(bad_actor.error, DogNames.INVALID_ACTOR % "Knight")
	var bad_folder := DogDestroyGenerator.generate(_options("knight", "../x", ALL))
	assert_eq(bad_folder.error, DogNames.INVALID_FOLDER % "../x")
	assert_true(_exists(dir.path_join("knight.gd")))
