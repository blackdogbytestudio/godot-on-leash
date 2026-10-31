extends GutTest
## DogBindGenerator.generate adding the listed components that are not children
## yet: writes on an actor in res://scenes/tmp that every test removes. The folder
## settings are pointed at it.

const TMP_DIR := "scenes/tmp/bind_new_nodes_test"
const TMP := "res://" + TMP_DIR
const KEYS := [DogSettings.IMPLICIT_FOLDER, DogSettings.EXPLICIT_FOLDER]
const SCENE := TMP + "/actor/actor.tscn"
const HOST := TMP + "/actor/actor.gd"
const DASH := "res://test/doubles/bind/fixture_dash.gd"
const DASH_NODE := "[node name=\"FixtureDash\" type=\"Node\" parent=\".\"]"
const ACTOR_GD := "extends CharacterBody2D\n"
const ACTOR_TSCN := """[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/tmp/bind_new_nodes_test/actor/actor.gd" id="1"]
[ext_resource type="Script" path="res://test/doubles/bind/fixture_jump.gd" id="2"]

[node name="Actor" type="CharacterBody2D"]
script = ExtResource("1")

[node name="Jump" type="Node" parent="."]
script = ExtResource("2")
"""

var _saved := {}


func before_each() -> void:
	_saved.clear()
	for key in KEYS:
		if ProjectSettings.has_setting(key):
			_saved[key] = ProjectSettings.get_setting(key)
		ProjectSettings.set_setting(key, TMP_DIR)
	DirAccess.make_dir_recursive_absolute(TMP + "/actor")
	_write(HOST, ACTOR_GD)
	_write(SCENE, ACTOR_TSCN)


func after_each() -> void:
	_remove_tree(TMP)
	DirAccess.remove_absolute("res://scenes/tmp")  # only succeeds when empty
	for key in KEYS:
		if _saved.has(key):
			ProjectSettings.set_setting(key, _saved[key])
		elif ProjectSettings.has_setting(key):
			ProjectSettings.clear(key)


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_remove_tree(path.path_join(sub))
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(path)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _generate(components: Array, write := true) -> DogBindGenerator.Result:
	var options := DogBindGenerator.Options.new()
	options.actor = "actor"
	options.components = components
	options.write = write
	return DogBindGenerator.generate(options)


func _assert_nothing_written() -> void:
	assert_eq(_read(SCENE), ACTOR_TSCN)
	assert_eq(_read(HOST), ACTOR_GD)


func test_a_missing_component_is_added_and_bound() -> void:
	var result := _generate(["fixture_jump_2d", "fixture_dash"])
	assert_eq(result.error, "")
	assert_eq(result.report[0], "add node FixtureDash")
	var scene := _read(SCENE)
	assert_string_contains(scene, DASH_NODE + "\nscript = ExtResource(\"")
	assert_string_contains(scene, "path=\"%s\"" % DASH)
	assert_string_contains(scene, "[gd_scene load_steps=4 ")
	var host := _read(HOST)
	assert_string_contains(host, "@onready var _fixture_dash: FixtureDash = $FixtureDash\n")
	assert_string_contains(host, "func dash() -> void:")
	assert_string_contains(host, "$Jump\n")


func test_the_added_component_has_the_uid_of_its_script() -> void:
	_generate(["fixture_dash"])
	var uid := ResourceUID.id_to_text(ResourceLoader.get_resource_uid(DASH))
	assert_string_contains(_read(SCENE), "uid=\"%s\" path=\"%s\"" % [uid, DASH])


func test_godot_loads_the_edited_scene_with_the_component_attached() -> void:
	_generate(["fixture_dash"])
	var mode := ResourceLoader.CACHE_MODE_IGNORE
	var packed := ResourceLoader.load(SCENE, "PackedScene", mode) as PackedScene
	var root := packed.instantiate()
	var dash := root.get_node("FixtureDash")
	assert_eq((dash.get_script() as Script).get_global_name(), &"FixtureDash")
	root.free()


func test_an_unknown_class_is_an_error_and_nothing_is_written() -> void:
	var result := _generate(["fixture_dash", "nothing_like_this"])
	assert_eq(result.error, DogBindGenerator.UNKNOWN_CLASS % "nothing_like_this")
	_assert_nothing_written()


func test_a_machine_in_the_list_is_an_error_and_nothing_is_written() -> void:
	var result := _generate(["fixture_dash", "dog_fsm"])
	assert_eq(result.error, DogBindGenerator.MACHINE_COMPONENT % "dog_fsm")
	_assert_nothing_written()


func test_a_class_that_is_not_a_node_is_an_error() -> void:
	var result := _generate(["dog_state"])
	assert_string_contains(result.error, "not a node class")
	_assert_nothing_written()


func test_the_automatic_mode_never_adds_nodes() -> void:
	var result := _generate([])
	assert_eq(result.error, "")
	assert_false(result.report.has("add node FixtureDash"))
	assert_eq(_read(SCENE), ACTOR_TSCN)
	assert_eq(result.scene_source, result.scene_original)


func test_without_write_nothing_is_written() -> void:
	var result := _generate(["fixture_dash"], false)
	assert_eq(result.error, "")
	assert_string_contains(result.scene_source, DASH_NODE)
	_assert_nothing_written()


func test_running_again_does_not_add_a_second_node() -> void:
	_generate(["fixture_dash"])
	var second := _generate(["fixture_dash"])
	assert_eq(second.error, "")
	assert_false(second.report.has("add node FixtureDash"))
	assert_eq(second.scene_source, second.scene_original)
	assert_eq(_read(SCENE).count(DASH_NODE), 1)
	assert_eq(_read(HOST).count("var _fixture_dash"), 1)
