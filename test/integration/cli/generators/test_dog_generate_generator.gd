extends GutTest
## DogGenerateGenerator without the command: what build checks before anything is
## written, and what generate reports when a step fails. Actors go in
## res://scenes/tmp, which every test removes; the folder settings point there.

const ROOT_DIR := "scenes/tmp/generate_gen_test"
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


## Options for `actor` with a hpda state step (`tree`, "" = no state step) and the
## listed components.
func _options(
	actor: String,
	tree := "",
	components: Array = [],
) -> DogGenerateGenerator.Options:
	var options := DogGenerateGenerator.Options.new()
	options.actor.actor = actor
	options.bind.actor = actor
	options.bind.components = components
	if not tree.is_empty():
		options.state = DogStateGenerator.Options.new()
		options.state.actor = actor
		options.state.type = "hpda"
		options.state.tree = DogStateTree.parse(DogCli.tokenize(tree))
	return options


func _remove(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	for sub in dir.get_directories():
		_remove(path.path_join(sub))
	DirAccess.remove_absolute(path)


func test_build_checks_every_step_and_writes_nothing() -> void:
	var result := DogGenerateGenerator.build(_options("knight", "alive", ["dog_move_2d"]))
	assert_eq(result.error, "")
	assert_eq(result.actor.script_path, ROOT.path_join("knight/knight.gd"))
	assert_null(result.state, "state build needs the scene")
	assert_null(result.bind, "bind build needs the scene")
	assert_eq(result.written, [])
	assert_false(DirAccess.dir_exists_absolute(ROOT))


func test_build_names_the_step_that_fails() -> void:
	var actor := DogGenerateGenerator.build(_options("area_2d"))
	var native := DogActorGenerator.NATIVE_CLASS_EXISTS % "Area2D"
	assert_eq([actor.step, actor.error], ["actor", native])

	var state_options := _options("knight", "alive")
	state_options.state.base = "enemy_state"
	var state := DogGenerateGenerator.build(state_options)
	assert_eq([state.step, state.error], ["state", DogStateGenerator.NOT_A_CLASS % "EnemyState"])

	var bind := DogGenerateGenerator.build(_options("knight", "", ["dog_hpda"]))
	assert_eq([bind.step, bind.error], ["bind", DogBindGenerator.MACHINE_COMPONENT % "dog_hpda"])
	assert_false(DirAccess.dir_exists_absolute(ROOT))


func test_generate_runs_the_steps_and_lists_what_it_wrote() -> void:
	var result := DogGenerateGenerator.generate(_options("knight", "alive", ["dog_move_2d"]))
	assert_eq(result.error, "")
	var dir := ROOT.path_join("knight")
	var expected: Array[String] = [
		dir.path_join("knight.tscn"),
		dir.path_join("knight.gd"),
		dir.path_join("states/knight_state.gd"),
		dir.path_join("states/knight_alive_state.gd"),
		dir.path_join("knight.tscn"),
		dir.path_join("knight.gd"),
		dir.path_join("knight.tscn"),
		dir.path_join("knight.gd"),
	]
	assert_eq(result.written, expected)
	assert_not_null(result.state)
	assert_not_null(result.bind)


func test_listed_error_checks_the_components_without_a_scene() -> void:
	assert_eq(DogBindGenerator.listed_error([]), "")
	assert_eq(DogBindGenerator.listed_error(["dog_move_2d", "fixture_jump_2d"]), "")
	var unknown := DogBindGenerator.UNKNOWN_CLASS % "dog_nope"
	assert_eq(DogBindGenerator.listed_error(["dog_move_2d", "dog_nope"]), unknown)
	var machine := DogBindGenerator.MACHINE_COMPONENT % "dog_fsm"
	assert_eq(DogBindGenerator.listed_error(["dog_fsm"]), machine)
