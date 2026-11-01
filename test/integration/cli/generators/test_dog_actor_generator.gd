# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogActorGenerator end to end: actors are created in res://scenes/tmp and project
## templates in res://scene_templates, which every test removes. The folder settings
## are pointed at res://scenes/tmp.

const ROOT_DIR := "scenes/tmp/actor_gen_test"
const ROOT := "res://" + ROOT_DIR
const PROJECT_TEMPLATES := "res://scene_templates"
const ADDON_TEMPLATE := "res://addons/leash/scene_templates/character_body_2d"
const KEYS := [DogSettings.IMPLICIT_FOLDER, DogSettings.EXPLICIT_FOLDER]

var _saved := {}
var _templates: Array[String] = []


func before_each() -> void:
	_saved.clear()
	_templates.clear()
	for key in KEYS:
		if ProjectSettings.has_setting(key):
			_saved[key] = ProjectSettings.get_setting(key)
		ProjectSettings.set_setting(key, ROOT_DIR)
	_remove(ROOT)


func after_each() -> void:
	_remove(ROOT)
	DirAccess.remove_absolute("res://scenes/tmp")  # only succeeds when empty
	for dir in _templates:
		_remove(dir)
	DirAccess.remove_absolute(PROJECT_TEMPLATES)  # only succeeds when empty
	for key in KEYS:
		if _saved.has(key):
			ProjectSettings.set_setting(key, _saved[key])
		elif ProjectSettings.has_setting(key):
			ProjectSettings.clear(key)


func _options(
	actor: String,
	template := "",
	folder := "",
	force := false,
	base := "",
) -> DogActorGenerator.Options:
	var options := DogActorGenerator.Options.new()
	options.actor = actor
	options.template = template
	options.folder = folder
	options.force = force
	options.base = base
	return options


func _based(actor: String, base: String, fixed := false) -> DogActorGenerator.Options:
	var options := _options(actor, "", "", false, base)
	options.base_fixed = fixed
	return options


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Writes res://scene_templates/<template>/ with a scene whose root (of `type`) uses
## `script_path` ("" = the template's own .gd, "-" = no script), and the template's
## .gd with `script_source` ("" = no .gd file).
func _template(
	template: String,
	script_source := "extends Node2D\n",
	type := "Node2D",
	script_path := "",
) -> String:
	var dir := PROJECT_TEMPLATES.path_join(template)
	_templates.append(dir)
	var own := dir.path_join(template + ".gd")
	if not script_source.is_empty():
		_write(own, script_source)
	var used := own if script_path.is_empty() else script_path
	var text := "[gd_scene load_steps=3 format=3 uid=\"uid://tmpl\"]\n\n"
	if used != "-":
		text += "[ext_resource type=\"Script\" uid=\"uid://s\" path=\"%s\" id=\"1_s\"]\n" % used
	text += "[ext_resource type=\"Texture2D\" path=\"res://icon.svg\" id=\"2_t\"]\n\n"
	text += "[node name=\"%s\" type=\"%s\"]\n" % [DogNames.to_pascal(template), type]
	if used != "-":
		text += "script = ExtResource(\"1_s\")\n"
	text += "\n[node name=\"Sprite2D\" type=\"Sprite2D\" parent=\".\"]\n"
	text += "texture = ExtResource(\"2_t\")\n"
	_write(dir.path_join(template + ".tscn"), text)
	return dir


func _remove(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	for sub in dir.get_directories():
		_remove(path.path_join(sub))
	DirAccess.remove_absolute(path)


# --- default template ---------------------------------------------------------


func test_godot_loads_the_default_template() -> void:
	var path := ADDON_TEMPLATE.path_join("character_body_2d.tscn")
	var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	var root := (packed as PackedScene).instantiate()
	assert_eq(root.get_class(), "CharacterBody2D")
	assert_eq(root.get_child_count(), 0)
	var script := root.get_script() as Script
	assert_eq(script.resource_path, ADDON_TEMPLATE.path_join("character_body_2d.gd"))
	assert_eq(script.get_global_name(), &"")
	root.free()


func test_the_default_template_is_character_body_2d() -> void:
	var result := DogActorGenerator.generate(_options("knight"))
	assert_eq(result.error, "")
	var dir := ROOT.path_join("knight")
	assert_eq(result.written, [dir.path_join("knight.tscn"), dir.path_join("knight.gd")])
	assert_eq(_read(dir.path_join("knight.gd")), "class_name Knight\nextends CharacterBody2D\n")
	var expected := """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="%s" id="1_template"]

[node name="Knight" type="CharacterBody2D"]
script = ExtResource("1_template")
""" % dir.path_join("knight.gd")
	assert_eq(_read(dir.path_join("knight.tscn")), expected)


func test_godot_loads_the_actor_with_its_new_script() -> void:
	DogActorGenerator.generate(_options("actor_gen_knight_2d"))
	var dir := ROOT.path_join("actor_gen_knight_2d")
	var path := dir.path_join("actor_gen_knight_2d.tscn")
	var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	var root := (packed as PackedScene).instantiate()
	assert_eq(root.name, &"ActorGenKnight2D")
	assert_eq(root.get_class(), "CharacterBody2D")
	var script := root.get_script() as Script
	assert_eq(script.resource_path, dir.path_join("actor_gen_knight_2d.gd"))
	assert_eq(script.get_global_name(), &"ActorGenKnight2D")
	root.free()


func test_build_writes_nothing() -> void:
	var result := DogActorGenerator.build(_options("knight"))
	assert_eq(result.error, "")
	assert_true(result.scene_source.contains("[node name=\"Knight\""))
	assert_eq(result.script_source, "class_name Knight\nextends CharacterBody2D\n")
	assert_eq(result.written, [])
	assert_false(DirAccess.dir_exists_absolute(ROOT.path_join("knight")))


# --- templates ----------------------------------------------------------------


func test_a_project_template_keeps_everything_but_the_root_and_its_script() -> void:
	var body := "@tool\nextends Node2D\n## Spins.\n\nvar speed := 3.0\n"
	var dir := _template("actor_gen_spinner", body)
	var result := DogActorGenerator.generate(_options("top", "actor_gen_spinner"))
	assert_eq(result.error, "")

	var script := ROOT.path_join("top/top.gd")
	var expected := "@tool\nclass_name Top\nextends Node2D\n## Spins.\n\nvar speed := 3.0\n"
	assert_eq(_read(script), expected)
	var source := _read(dir.path_join("actor_gen_spinner.tscn"))
	source = source.replace(" uid=\"uid://tmpl\"", "")
	source = source.replace("name=\"ActorGenSpinner\"", "name=\"Top\"")
	source = source.replace(
		"uid=\"uid://s\" path=\"%s\"" % dir.path_join("actor_gen_spinner.gd"),
		"path=\"%s\"" % script,
	)
	assert_eq(_read(ROOT.path_join("top/top.tscn")), source)


func test_a_project_template_wins_over_the_addon_one() -> void:
	_template("character_body_2d", "extends CharacterBody2D\n# project\n", "CharacterBody2D")
	var result := DogActorGenerator.generate(_options("knight"))
	assert_eq(result.error, "")
	var template := PROJECT_TEMPLATES.path_join("character_body_2d/character_body_2d.tscn")
	assert_eq(result.template_scene, template)
	assert_string_contains(_read(ROOT.path_join("knight/knight.gd")), "# project")
	assert_string_contains(_read(ROOT.path_join("knight/knight.tscn")), "Sprite2D")


func test_a_template_class_name_is_replaced() -> void:
	_template("actor_gen_named", "class_name Template\nextends Node2D\n")
	DogActorGenerator.generate(_options("knight", "actor_gen_named"))
	assert_eq(_read(ROOT.path_join("knight/knight.gd")), "class_name Knight\nextends Node2D\n")


func test_folder_is_the_actor_directory() -> void:
	var result := DogActorGenerator.generate(_options("slime", "", "enemies/slime"))
	assert_eq(result.error, "")
	var dir := ROOT.path_join("enemies/slime")
	assert_true(FileAccess.file_exists(dir.path_join("slime.tscn")))
	assert_string_contains(_read(dir.path_join("slime.tscn")), dir.path_join("slime.gd"))


# --- errors -------------------------------------------------------------------


func _assert_nothing_written(actor := "knight") -> void:
	assert_false(DirAccess.dir_exists_absolute(ROOT.path_join(actor)), "nothing written")


func test_a_missing_template_names_the_places_searched() -> void:
	var result := DogActorGenerator.generate(_options("knight", "actor_gen_none"))
	var searched := "res://scene_templates/actor_gen_none, "
	searched += "res://addons/leash/scene_templates/actor_gen_none"
	assert_eq(result.error, DogActorGenerator.TEMPLATE_NOT_FOUND % ["actor_gen_none", searched])
	_assert_nothing_written()


func test_a_template_without_its_script_is_an_error() -> void:
	var dir := _template("actor_gen_noscript", "")
	var result := DogActorGenerator.generate(_options("knight", "actor_gen_noscript"))
	var missing := DogActorGenerator.TEMPLATE_FILE_MISSING % [dir, "actor_gen_noscript.gd"]
	assert_eq(result.error, missing)
	_assert_nothing_written()


func test_a_template_without_its_scene_is_an_error() -> void:
	var dir := PROJECT_TEMPLATES.path_join("actor_gen_noscene")
	_templates.append(dir)
	_write(dir.path_join("actor_gen_noscene.gd"), "extends Node\n")
	var result := DogActorGenerator.generate(_options("knight", "actor_gen_noscene"))
	var missing := DogActorGenerator.TEMPLATE_FILE_MISSING % [dir, "actor_gen_noscene.tscn"]
	assert_eq(result.error, missing)
	_assert_nothing_written()


func test_a_template_scene_that_is_not_a_scene_is_an_error() -> void:
	var dir := _template("actor_gen_text")
	_write(dir.path_join("actor_gen_text.tscn"), "hello\n")
	var result := DogActorGenerator.generate(_options("knight", "actor_gen_text"))
	assert_eq(result.error, "actor_gen_text.tscn: " + DogSceneEdit.NOT_A_SCENE)
	_assert_nothing_written()


func test_a_template_root_without_script_is_an_error() -> void:
	_template("actor_gen_bare", "extends Node2D\n", "Node2D", "-")
	var result := DogActorGenerator.generate(_options("knight", "actor_gen_bare"))
	assert_eq(result.error, "actor_gen_bare.tscn: " + DogSceneEdit.NO_ROOT_SCRIPT)
	_assert_nothing_written()


func test_a_template_root_with_another_script_is_an_error() -> void:
	var other := ADDON_TEMPLATE.path_join("character_body_2d.gd")
	_template("actor_gen_other", "extends Node2D\n", "Node2D", other)
	var result := DogActorGenerator.generate(_options("knight", "actor_gen_other"))
	var expected := DogActorGenerator.WRONG_TEMPLATE_SCRIPT % [
		"actor_gen_other.tscn",
		other,
		"actor_gen_other.gd",
	]
	assert_eq(result.error, expected)
	_assert_nothing_written()


func test_an_instanced_template_root_is_an_error() -> void:
	var dir := _template("actor_gen_inst")
	var text := "[gd_scene load_steps=2 format=3]\n\n"
	text += "[ext_resource type=\"PackedScene\" path=\"res://x.tscn\" id=\"1_x\"]\n\n"
	text += "[node name=\"Inst\" instance=ExtResource(\"1_x\")]\n"
	_write(dir.path_join("actor_gen_inst.tscn"), text)
	var result := DogActorGenerator.generate(_options("knight", "actor_gen_inst"))
	assert_eq(result.error, "actor_gen_inst.tscn: " + DogSceneEdit.NO_ROOT_TYPE)
	_assert_nothing_written()


func test_a_template_script_without_extends_is_an_error() -> void:
	_template("actor_gen_noext", "func a() -> void:\n\tpass\n")
	var result := DogActorGenerator.generate(_options("knight", "actor_gen_noext"))
	assert_eq(result.error, "actor_gen_noext.gd: " + DogScriptHeader.NO_EXTENDS)
	_assert_nothing_written()


func test_bad_names_are_errors() -> void:
	var cases := [
		[_options("Knight"), DogNames.INVALID_ACTOR % "Knight"],
		[_options("knight", "", "Bad/x"), DogNames.INVALID_FOLDER % "Bad/x"],
		[_options("knight", "Body"), DogActorGenerator.INVALID_TEMPLATE % "Body"],
		[_options("knight", "../x"), DogActorGenerator.INVALID_TEMPLATE % "../x"],
	]
	for case in cases:
		assert_eq(DogActorGenerator.generate(case[0]).error, case[1])
	assert_false(DirAccess.dir_exists_absolute(ROOT), "nothing written")


func test_an_existing_scene_is_an_error_and_nothing_is_written() -> void:
	var scene := ROOT.path_join("knight/knight.tscn")
	_write(scene, "mine")
	var result := DogActorGenerator.generate(_options("knight"))
	assert_eq(result.error, DogActorGenerator.ALREADY_EXISTS % scene)
	assert_eq(_read(scene), "mine")
	assert_false(FileAccess.file_exists(ROOT.path_join("knight/knight.gd")))


func test_an_existing_script_is_an_error_and_nothing_is_written() -> void:
	var script := ROOT.path_join("knight/knight.gd")
	_write(script, "mine")
	var result := DogActorGenerator.generate(_options("knight"))
	assert_eq(result.error, DogActorGenerator.ALREADY_EXISTS % script)
	assert_eq(_read(script), "mine")
	assert_false(FileAccess.file_exists(ROOT.path_join("knight/knight.tscn")))


func test_a_template_script_with_class_name_but_without_extends_is_an_error() -> void:
	_template("actor_gen_named_noext", "class_name Template\n")
	var result := DogActorGenerator.generate(_options("knight", "actor_gen_named_noext"))
	assert_eq(result.error, "actor_gen_named_noext.gd: " + DogScriptHeader.NO_EXTENDS)
	_assert_nothing_written("knight")


# --- an existing actor --------------------------------------------------------


func _existing_actor() -> Array[String]:
	var scene := ROOT.path_join("knight/knight.tscn")
	var script := ROOT.path_join("knight/knight.gd")
	_write(scene, "my scene")
	_write(script, "my script")
	return [scene, script]


func test_an_existing_actor_is_kept_and_nothing_is_written() -> void:
	var paths := _existing_actor()
	var result := DogActorGenerator.generate(_options("knight"))
	assert_eq(result.error, "")
	assert_true(result.kept)
	assert_eq([result.scene_path, result.script_path], paths)
	assert_eq(result.written, [])
	assert_eq(_read(paths[0]), "my scene")
	assert_eq(_read(paths[1]), "my script")


func test_a_kept_actor_skips_the_template_and_the_class_checks() -> void:
	# Hero is a class of the project, but the actor is not being created.
	var scene := ROOT.path_join("hero/hero.tscn")
	_write(scene, "my scene")
	_write(ROOT.path_join("hero/hero.gd"), "my script")
	var result := DogActorGenerator.generate(_options("hero"))
	assert_eq(result.error, "")
	assert_true(result.kept)
	assert_eq(result.template_scene, "")


func test_a_kept_actor_with_a_template_is_an_error() -> void:
	var paths := _existing_actor()
	var result := DogActorGenerator.generate(_options("knight", "character_body_2d"))
	var flag := "template 'character_body_2d'"
	assert_eq(result.error, DogActorGenerator.KEPT_CHANGE % flag)
	assert_eq(_read(paths[1]), "my script")


func test_a_kept_actor_with_a_base_is_an_error() -> void:
	var paths := _existing_actor()
	var result := DogActorGenerator.generate(_based("knight", "Area2D"))
	assert_eq(result.error, DogActorGenerator.KEPT_CHANGE % "--extends")
	assert_eq(_read(paths[0]), "my scene")


func test_force_recreates_an_existing_actor() -> void:
	var paths := _existing_actor()
	var result := DogActorGenerator.generate(_options("knight", "", "", true, "Area2D"))
	assert_eq(result.error, "")
	assert_false(result.kept)
	assert_eq(result.written, paths)
	assert_eq(_read(paths[1]), "class_name Knight\nextends Area2D\n")


func test_force_recreates_both_files() -> void:
	var scene := ROOT.path_join("knight/knight.tscn")
	var script := ROOT.path_join("knight/knight.gd")
	_write(scene, "mine")
	_write(script, "mine")
	var result := DogActorGenerator.generate(_options("knight", "", "", true))
	assert_eq(result.error, "")
	assert_eq(result.written, [scene, script])
	assert_eq(_read(script), "class_name Knight\nextends CharacterBody2D\n")
	assert_string_contains(_read(scene), "[node name=\"Knight\" type=\"CharacterBody2D\"]")


# --- class names --------------------------------------------------------------


func test_an_actor_named_like_a_native_class_is_an_error() -> void:
	var result := DogActorGenerator.generate(_options("area_2d"))
	assert_eq(result.error, DogActorGenerator.NATIVE_CLASS_EXISTS % "Area2D")
	_assert_nothing_written("area_2d")


func test_an_actor_named_like_a_global_class_is_an_error() -> void:
	var result := DogActorGenerator.generate(_options("dog_move_2d"))
	var where := "res://addons/leash/components/2d/character/dog_move_2d.gd"
	assert_eq(result.error, DogActorGenerator.GLOBAL_CLASS_EXISTS % ["DogMove2D", where])
	_assert_nothing_written("dog_move_2d")


func test_the_actor_own_class_is_not_a_collision() -> void:
	# FixtureDash is res://test/doubles/bind/fixture_dash.gd: the script this actor
	# would be. Only build runs, so the fixture is never touched.
	ProjectSettings.set_setting(DogSettings.EXPLICIT_FOLDER, "test/doubles")
	var own := DogActorGenerator.build(_options("fixture_dash", "", "bind", true))
	assert_eq(own.error, "")
	assert_eq(own.script_path, "res://test/doubles/bind/fixture_dash.gd")
	assert_eq(own.actor_class, "FixtureDash")

	var elsewhere := DogActorGenerator.build(_options("fixture_dash", "", "other", true))
	var expected := DogActorGenerator.GLOBAL_CLASS_EXISTS % [
		"FixtureDash",
		"res://test/doubles/bind/fixture_dash.gd",
	]
	assert_eq(elsewhere.error, expected)


# --- base ---------------------------------------------------------------------


func test_a_native_base_sets_the_extends_and_the_root_type() -> void:
	var result := DogActorGenerator.generate(_based("knight", "Area2D"))
	assert_eq(result.error, "")
	assert_eq(result.native_type, "Area2D")
	assert_eq(_read(ROOT.path_join("knight/knight.gd")), "class_name Knight\nextends Area2D\n")
	var scene := _read(ROOT.path_join("knight/knight.tscn"))
	assert_string_contains(scene, "[node name=\"Knight\" type=\"Area2D\"]")


func test_a_global_base_is_extended_and_the_root_gets_its_native_type() -> void:
	var result := DogActorGenerator.generate(_based("knight", "DogMove2D"))
	assert_eq(result.error, "")
	var script := _read(ROOT.path_join("knight/knight.gd"))
	assert_eq(script, "class_name Knight\nextends DogMove2D\n")
	var scene := _read(ROOT.path_join("knight/knight.tscn"))
	assert_string_contains(scene, "[node name=\"Knight\" type=\"Node\"]")


func test_godot_loads_an_actor_with_a_base() -> void:
	DogActorGenerator.generate(_based("knight", "CPUParticles2D"))
	var path := ROOT.path_join("knight/knight.tscn")
	var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	var root := (packed as PackedScene).instantiate()
	assert_eq(root.get_class(), "CPUParticles2D")
	assert_eq((root.get_script() as Script).get_instance_base_type(), &"CPUParticles2D")
	root.free()


func test_a_base_replaces_the_extends_of_a_template_class_name_line() -> void:
	_template("actor_gen_oneline", "class_name Template extends Node2D\n")
	var options := _based("knight", "Sprite2D")
	options.template = "actor_gen_oneline"
	assert_eq(DogActorGenerator.generate(options).error, "")
	var script := _read(ROOT.path_join("knight/knight.gd"))
	assert_eq(script, "class_name Knight extends Sprite2D\n")


func test_a_base_that_is_not_a_node_class_is_an_error() -> void:
	for base in ["RefCounted", "DogNames", "NoSuchClass"]:
		var result := DogActorGenerator.generate(_based("knight", base))
		assert_eq(result.error, DogActorGenerator.NOT_A_NODE_CLASS % base, base)
	_assert_nothing_written("knight")


func test_a_fixed_base_error_hints_at_the_fix_flags() -> void:
	var result := DogActorGenerator.generate(_based("knight", "DogArea2D", true))
	var expected := DogActorGenerator.NOT_A_NODE_CLASS % "DogArea2D"
	assert_eq(result.error, expected + DogActorGenerator.FIX_HINT)
	_assert_nothing_written("knight")


func test_base_error_is_a_static_check() -> void:
	assert_eq(DogActorGenerator.base_error("Area2D"), "")
	assert_eq(DogActorGenerator.base_error("DogMove2D"), "")
	var expected := DogActorGenerator.NOT_A_NODE_CLASS % "DogState"
	assert_eq(DogActorGenerator.base_error("DogState"), expected)
