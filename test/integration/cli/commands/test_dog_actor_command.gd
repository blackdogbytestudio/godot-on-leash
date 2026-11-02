extends GutTest
## DogActorCommand.run end to end: what it prints after generating in
## res://scenes/tmp, which every test removes. The folder settings are pointed at it.

const ROOT_DIR := "scenes/tmp/actor_cmd_test"
const ROOT := "res://" + ROOT_DIR
const PROJECT_TEMPLATE := "res://scene_templates/CharacterBody2D"
const KEYS := [
	DogSettings.IMPLICIT_FOLDER,
	DogSettings.EXPLICIT_FOLDER,
	DogSettings.PREFIX,
	DogSettings.SUFFIX,
]

var _saved := {}


func before_each() -> void:
	_saved.clear()
	for key in KEYS:
		if ProjectSettings.has_setting(key):
			_saved[key] = ProjectSettings.get_setting(key)
		ProjectSettings.set_setting(key, DogSettings.DEFAULTS[key])
	ProjectSettings.set_setting(DogSettings.IMPLICIT_FOLDER, ROOT_DIR)
	ProjectSettings.set_setting(DogSettings.EXPLICIT_FOLDER, ROOT_DIR)
	_remove(ROOT)


func after_each() -> void:
	_remove(ROOT)
	DirAccess.remove_absolute("res://scenes/tmp")  # only succeeds when empty
	_remove(PROJECT_TEMPLATE)
	DirAccess.remove_absolute(PROJECT_TEMPLATE.get_base_dir())  # only succeeds when empty
	for key in KEYS:
		if _saved.has(key):
			ProjectSettings.set_setting(key, _saved[key])
		elif ProjectSettings.has_setting(key):
			ProjectSettings.clear(key)


func _run(line: String) -> Array:
	var command := DogActorCommand.new()
	var lines: Array[String] = []
	command.printed.connect(func(text: String) -> void: lines.append(text))
	var error := command.run(DogCli.tokenize(line))
	return [error, lines]


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _write(path: String, text: String) -> void:
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


func test_run_creates_the_actor_from_the_default_template() -> void:
	var result := _run("knight")
	var scene := ROOT.path_join("knight/knight.tscn")
	var script := ROOT.path_join("knight/knight.gd")
	assert_eq(result, [OK, ["created " + scene, "created " + script]])
	assert_eq(_read(script), "class_name Knight\nextends CharacterBody2D\n")
	assert_string_contains(_read(scene), "[node name=\"Knight\" type=\"CharacterBody2D\"]")


func test_run_uses_the_project_template_first() -> void:
	var own := PROJECT_TEMPLATE.path_join("CharacterBody2D.gd")
	_write(own, "extends CharacterBody2D\n# project\n")
	var scene := "[gd_scene load_steps=2 format=3]\n\n"
	scene += "[ext_resource type=\"Script\" path=\"%s\" id=\"1_t\"]\n\n" % own
	scene += "[node name=\"CharacterBody2D\" type=\"CharacterBody2D\"]\n"
	scene += "script = ExtResource(\"1_t\")\n"
	_write(PROJECT_TEMPLATE.path_join("CharacterBody2D.tscn"), scene)

	assert_eq(_run("knight character_body_2d")[0], OK)
	var expected := "class_name Knight\nextends CharacterBody2D\n# project\n"
	assert_eq(_read(ROOT.path_join("knight/knight.gd")), expected)


func test_run_with_folder() -> void:
	var result := _run("slime --folder enemies/slime")
	assert_eq(result[0], OK)
	assert_has(result[1], "created " + ROOT.path_join("enemies/slime/slime.gd"))


func test_run_on_an_existing_actor_prints_the_error_and_keeps_it() -> void:
	var script := ROOT.path_join("knight/knight.gd")
	_write(script, "mine")
	var result := _run("knight")
	assert_eq(result[0], FAILED)
	assert_eq(result[1], ["Dog: actor: " + DogActorGenerator.ALREADY_EXISTS % script])
	assert_eq(_read(script), "mine")
	assert_false(FileAccess.file_exists(ROOT.path_join("knight/knight.tscn")))


func test_run_with_force_recreates_the_actor() -> void:
	var script := ROOT.path_join("knight/knight.gd")
	_write(script, "mine")
	var result := _run("knight -f")
	assert_eq(result[0], OK)
	assert_eq(result[1].size(), 2)
	assert_eq(_read(script), "class_name Knight\nextends CharacterBody2D\n")


func test_run_with_a_missing_template_prints_the_error() -> void:
	var result := _run("knight actor_cmd_none")
	assert_eq(result[0], FAILED)
	assert_string_contains(result[1][0], "Dog: actor: template 'ActorCmdNone' not found in")
	assert_false(DirAccess.dir_exists_absolute(ROOT))


func test_run_with_bad_names_prints_the_error() -> void:
	for line in ["Knight", "knight Bo-dy", "knight --folder X"]:
		var result := _run(line)
		assert_eq(result[0], ERR_INVALID_PARAMETER, line)
		assert_string_contains(result[1][0], "Dog: actor: ")
	assert_false(DirAccess.dir_exists_absolute(ROOT))


func test_run_on_a_complete_actor_keeps_it() -> void:
	var scene := ROOT.path_join("knight/knight.tscn")
	var script := ROOT.path_join("knight/knight.gd")
	_write(scene, "my scene")
	_write(script, "my script")
	var result := _run("knight")
	assert_eq(result, [OK, ["kept " + scene, "kept " + script]])
	assert_eq(_read(scene), "my scene")
	assert_eq(_read(script), "my script")


func test_run_on_a_complete_actor_rejects_what_would_change_it() -> void:
	_write(ROOT.path_join("knight/knight.tscn"), "my scene")
	_write(ROOT.path_join("knight/knight.gd"), "my script")
	var cases := {
		"knight character_body_2d": "template 'character_body_2d'",
		"knight --extends Area2D": "--extends",
		"knight --extends area_2d": "--extends",
	}
	for line in cases:
		var result := _run(line)
		var expected := "Dog: actor: " + DogActorGenerator.KEPT_CHANGE % cases[line]
		assert_eq(result, [FAILED, [expected]], line)
	assert_eq(_read(ROOT.path_join("knight/knight.gd")), "my script")


func test_run_with_extends_in_snake_pascal_and_hybrid() -> void:
	var cases := {
		"knight --extends dog_move_2d": ["DogMove2D", "Node"],
		"knight --extends CPUParticles2D": ["CPUParticles2D", "CPUParticles2D"],
		"knight --extends CPU_particles_2d": ["CPUParticles2D", "CPUParticles2D"],
	}
	for line in cases:
		var result := _run(line + " -f")
		assert_eq(result[0], OK, line)
		var expected := "class_name Knight\nextends %s\n" % cases[line][0]
		assert_eq(_read(ROOT.path_join("knight/knight.gd")), expected, line)
		var scene := _read(ROOT.path_join("knight/knight.tscn"))
		var root := "[node name=\"Knight\" type=\"%s\"]" % cases[line][1]
		assert_string_contains(scene, root, line)


func test_run_with_an_extends_that_is_not_a_node_class() -> void:
	var short := _run("knight --extends area")
	assert_eq(short, [FAILED, ["Dog: actor: " + DogActorGenerator.NOT_A_NODE_CLASS % "Area"]])
	var full := _run("knight --extends RefCounted")
	var plain := "Dog: actor: " + DogActorGenerator.NOT_A_NODE_CLASS % "RefCounted"
	assert_eq(full, [FAILED, [plain]])
	assert_false(DirAccess.dir_exists_absolute(ROOT))


func test_run_with_an_extends_that_inherits_from_the_actor() -> void:
	# fixture_knight in test/doubles/actor is the FixtureKnight fixture: the errors
	# come before anything is written, so the fixture is never touched.
	ProjectSettings.set_setting(DogSettings.EXPLICIT_FOLDER, "test/doubles")
	var fixture := FileAccess.get_file_as_string("res://test/doubles/actor/fixture_knight.gd")
	var cases := {
		"FixtureKnight": "FixtureKnight",
		"fixture_paladin": "FixturePaladin",
	}
	for token in cases:
		var result := _run("fixture_knight --folder actor -f --extends " + token)
		var message := DogActorGenerator.INHERITS_ACTOR % [cases[token], "FixtureKnight"]
		assert_eq(result, [FAILED, ["Dog: actor: " + message]], token)
	var after := FileAccess.get_file_as_string("res://test/doubles/actor/fixture_knight.gd")
	assert_eq(after, fixture)
	assert_false(FileAccess.file_exists("res://test/doubles/actor/fixture_knight.tscn"))


func test_run_with_an_extends_that_does_not_inherit_from_the_actor() -> void:
	var result := _run("knight --extends FixturePaladin")
	assert_eq(result[0], OK)
	var expected := "class_name Knight\nextends FixturePaladin\n"
	assert_eq(_read(ROOT.path_join("knight/knight.gd")), expected)


func test_run_with_an_abstract_extends() -> void:
	var cases := {
		"knight --extends CanvasItem": "CanvasItem",
		"knight --extends fixture_canvas_item": "FixtureCanvasItem",
	}
	for line in cases:
		var message := "Dog: actor: " + DogActorGenerator.ABSTRACT_BASE % cases[line]
		assert_eq(_run(line), [FAILED, [message]], line)
	assert_false(DirAccess.dir_exists_absolute(ROOT))


func test_run_with_an_actor_that_is_already_a_class() -> void:
	var native := _run("area_2d")
	assert_eq(native, [FAILED, ["Dog: actor: " + DogActorGenerator.NATIVE_CLASS_EXISTS % "Area2D"]])
	var global := _run("hero")
	assert_eq(global[0], FAILED)
	assert_string_contains(global[1][0], "class 'Hero' already exists in res://test/doubles/")
	assert_false(DirAccess.dir_exists_absolute(ROOT))


func test_run_with_a_removed_fix_flag_is_an_unknown_option() -> void:
	for flag in ["--prefix", "--suffix", "--no-fix"]:
		var result := _run("knight --extends Area2D " + flag)
		var expected := "Dog: actor: " + DogActorCommand.UNKNOWN_OPTION % flag
		assert_eq(result, [ERR_INVALID_PARAMETER, [expected]], flag)
	assert_false(DirAccess.dir_exists_absolute(ROOT))
