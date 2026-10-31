extends GutTest
## DogActorCommand.run end to end: what it prints after generating in
## res://scenes/tmp, which every test removes. The folder settings are pointed at it.

const ROOT_DIR := "scenes/tmp/actor_cmd_test"
const ROOT := "res://" + ROOT_DIR
const PROJECT_TEMPLATE := "res://scene_templates/character_body_2d"
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
	var result := _run("hero")
	var scene := ROOT.path_join("hero/hero.tscn")
	var script := ROOT.path_join("hero/hero.gd")
	assert_eq(result, [OK, ["created " + scene, "created " + script]])
	assert_eq(_read(script), "class_name Hero\nextends CharacterBody2D\n")
	assert_string_contains(_read(scene), "[node name=\"Hero\" type=\"CharacterBody2D\"]")


func test_run_uses_the_project_template_first() -> void:
	var own := PROJECT_TEMPLATE.path_join("character_body_2d.gd")
	_write(own, "extends CharacterBody2D\n# project\n")
	var scene := "[gd_scene load_steps=2 format=3]\n\n"
	scene += "[ext_resource type=\"Script\" path=\"%s\" id=\"1_t\"]\n\n" % own
	scene += "[node name=\"CharacterBody2D\" type=\"CharacterBody2D\"]\n"
	scene += "script = ExtResource(\"1_t\")\n"
	_write(PROJECT_TEMPLATE.path_join("character_body_2d.tscn"), scene)

	assert_eq(_run("hero character_body_2d")[0], OK)
	var expected := "class_name Hero\nextends CharacterBody2D\n# project\n"
	assert_eq(_read(ROOT.path_join("hero/hero.gd")), expected)


func test_run_with_folder() -> void:
	var result := _run("slime --folder enemies/slime")
	assert_eq(result[0], OK)
	assert_has(result[1], "created " + ROOT.path_join("enemies/slime/slime.gd"))


func test_run_on_an_existing_actor_prints_the_error_and_keeps_it() -> void:
	var script := ROOT.path_join("hero/hero.gd")
	_write(script, "mine")
	var result := _run("hero")
	assert_eq(result[0], FAILED)
	assert_eq(result[1], ["Dog: actor: " + DogActorGenerator.ALREADY_EXISTS % script])
	assert_eq(_read(script), "mine")
	assert_false(FileAccess.file_exists(ROOT.path_join("hero/hero.tscn")))


func test_run_with_force_recreates_the_actor() -> void:
	var script := ROOT.path_join("hero/hero.gd")
	_write(script, "mine")
	var result := _run("hero -f")
	assert_eq(result[0], OK)
	assert_eq(result[1].size(), 2)
	assert_eq(_read(script), "class_name Hero\nextends CharacterBody2D\n")


func test_run_with_a_missing_template_prints_the_error() -> void:
	var result := _run("hero actor_cmd_none")
	assert_eq(result[0], FAILED)
	assert_string_contains(result[1][0], "Dog: actor: template 'actor_cmd_none' not found in")
	assert_false(DirAccess.dir_exists_absolute(ROOT))


func test_run_with_bad_names_prints_the_error() -> void:
	for line in ["Hero", "hero Body", "hero --folder X"]:
		var result := _run(line)
		assert_eq(result[0], ERR_INVALID_PARAMETER, line)
		assert_string_contains(result[1][0], "Dog: actor: ")
	assert_false(DirAccess.dir_exists_absolute(ROOT))
