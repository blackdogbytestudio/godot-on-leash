extends GutTest
## DogActorCommand.run end to end: what it prints after generating in
## res://scenes/tmp, which every test removes. The folder settings are pointed at it.

const ROOT_DIR := "scenes/tmp/actor_cmd_test"
const ROOT := "res://" + ROOT_DIR
const PROJECT_TEMPLATE := "res://scene_templates/character_body_2d"
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
	var own := PROJECT_TEMPLATE.path_join("character_body_2d.gd")
	_write(own, "extends CharacterBody2D\n# project\n")
	var scene := "[gd_scene load_steps=2 format=3]\n\n"
	scene += "[ext_resource type=\"Script\" path=\"%s\" id=\"1_t\"]\n\n" % own
	scene += "[node name=\"CharacterBody2D\" type=\"CharacterBody2D\"]\n"
	scene += "script = ExtResource(\"1_t\")\n"
	_write(PROJECT_TEMPLATE.path_join("character_body_2d.tscn"), scene)

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
	assert_string_contains(result[1][0], "Dog: actor: template 'actor_cmd_none' not found in")
	assert_false(DirAccess.dir_exists_absolute(ROOT))


func test_run_with_bad_names_prints_the_error() -> void:
	for line in ["Knight", "knight Body", "knight --folder X"]:
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
		"knight --extends Area2D --no-fix": "--extends",
		"knight --extends area --prefix=": "--extends",
	}
	for line in cases:
		var result := _run(line)
		var expected := "Dog: actor: " + DogActorGenerator.KEPT_CHANGE % cases[line]
		assert_eq(result, [FAILED, [expected]], line)
	assert_eq(_read(ROOT.path_join("knight/knight.gd")), "my script")


func test_run_with_extends_and_the_settings() -> void:
	# move -> dog_move_2d -> DogMove2D, whose native base is Node.
	var result := _run("knight --extends move")
	assert_eq(result[0], OK)
	assert_eq(_read(ROOT.path_join("knight/knight.gd")), "class_name Knight\nextends DogMove2D\n")
	var scene := _read(ROOT.path_join("knight/knight.tscn"))
	assert_string_contains(scene, "[node name=\"Knight\" type=\"Node\"]")


func test_run_with_extends_and_an_empty_prefix() -> void:
	assert_eq(_run("knight --extends area --prefix=")[0], OK)
	assert_eq(_read(ROOT.path_join("knight/knight.gd")), "class_name Knight\nextends Area2D\n")


func test_run_with_a_pascal_case_extends_and_no_fix() -> void:
	var result := _run("knight --extends CPUParticles2D --no-fix")
	assert_eq(result[0], OK)
	var expected := "class_name Knight\nextends CPUParticles2D\n"
	assert_eq(_read(ROOT.path_join("knight/knight.gd")), expected)
	var scene := _read(ROOT.path_join("knight/knight.tscn"))
	assert_string_contains(scene, "[node name=\"Knight\" type=\"CPUParticles2D\"]")


func test_run_with_an_extends_that_is_not_a_node_class() -> void:
	var fixed := _run("knight --extends area")
	var message := DogActorGenerator.NOT_A_NODE_CLASS % "DogArea2D" + DogActorGenerator.FIX_HINT
	assert_eq(fixed, [FAILED, ["Dog: actor: " + message]])
	var full := _run("knight --extends RefCounted --no-fix")
	var plain := "Dog: actor: " + DogActorGenerator.NOT_A_NODE_CLASS % "RefCounted"
	assert_eq(full, [FAILED, [plain]])
	assert_false(DirAccess.dir_exists_absolute(ROOT))


func test_run_with_an_actor_that_is_already_a_class() -> void:
	var native := _run("area_2d")
	assert_eq(native, [FAILED, ["Dog: actor: " + DogActorGenerator.NATIVE_CLASS_EXISTS % "Area2D"]])
	var global := _run("hero")
	assert_eq(global[0], FAILED)
	assert_string_contains(global[1][0], "class 'Hero' already exists in res://test/doubles/")
	assert_false(DirAccess.dir_exists_absolute(ROOT))


func test_run_with_fix_flags_and_no_extends() -> void:
	var result := _run("knight --prefix=")
	var expected := "Dog: actor: " + DogActorCommand.FIX_WITHOUT_EXTENDS
	assert_eq(result, [ERR_INVALID_PARAMETER, [expected]])
	assert_false(DirAccess.dir_exists_absolute(ROOT))
