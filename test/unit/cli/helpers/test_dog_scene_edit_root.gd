# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogSceneEdit: the edits and queries of the root node (uid, name, type, script).

const OLD := "res://scene_templates/thing/thing.gd"
const NEW := "res://scenes/hero/hero.gd"
const TEMPLATE := """[gd_scene load_steps=3 format=3 uid="uid://b1"]

[ext_resource type="Texture2D" uid="uid://t1" path="res://icon.svg" id="2_tex"]
[ext_resource type="Script" uid="uid://s1" path="res://scene_templates/thing/thing.gd" id="1_s"]

[node name="Thing" type="CharacterBody2D"]
script = ExtResource("1_s")
speed = 3

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")

[node name="Thing" type="Node" parent="Sprite2D"]
"""
const PLAIN := """[gd_scene format=3]

[ext_resource type="Script" path="res://scene_templates/thing/thing.gd" id="1_s"]

[node name="Thing" type="Node2D"]
script = ExtResource("1_s")
"""
const NO_SCRIPT := """[gd_scene format=3]

[node name="Thing" type="Node2D"]
"""


## `source` with `from` replaced by `to` exactly once, to compare against.
func _replaced(source: String, from: String, to: String) -> String:
	assert_eq(source.count(from), 1, "fixture has '%s' once" % from)
	return source.replace(from, to)


# --- strip_uid ----------------------------------------------------------------


func test_strip_uid_drops_the_uid_of_the_header_only() -> void:
	var edit := DogSceneEdit.strip_uid(TEMPLATE)
	assert_eq(edit["error"], "")
	var expected := _replaced(
		TEMPLATE,
		"[gd_scene load_steps=3 format=3 uid=\"uid://b1\"]",
		"[gd_scene load_steps=3 format=3]",
	)
	assert_eq(edit["source"], expected)


func test_strip_uid_keeps_a_header_without_uid() -> void:
	var edit := DogSceneEdit.strip_uid(PLAIN)
	assert_eq(edit["error"], "")
	assert_eq(edit["source"], PLAIN)


func test_strip_uid_handles_a_uid_before_load_steps() -> void:
	var scene := "[gd_scene uid=\"uid://b1\" format=3]\n\n[node name=\"A\" type=\"Node\"]\n"
	var source: String = DogSceneEdit.strip_uid(scene)["source"]
	assert_true(source.begins_with("[gd_scene format=3]\n"))


func test_strip_uid_of_text_that_is_not_a_scene_is_an_error() -> void:
	var edit := DogSceneEdit.strip_uid("extends Node\n")
	assert_eq(edit["error"], DogSceneEdit.NOT_A_SCENE)
	assert_eq(edit["source"], "extends Node\n")


# --- rename_root --------------------------------------------------------------


func test_rename_root_renames_only_the_root() -> void:
	var edit := DogSceneEdit.rename_root(TEMPLATE, "Hero")
	assert_eq(edit["error"], "")
	var expected := _replaced(
		TEMPLATE,
		"[node name=\"Thing\" type=\"CharacterBody2D\"]",
		"[node name=\"Hero\" type=\"CharacterBody2D\"]",
	)
	assert_eq(edit["source"], expected)


func test_rename_root_without_name_is_an_error() -> void:
	var edit := DogSceneEdit.rename_root(PLAIN, "")
	assert_eq(edit["error"], DogSceneEdit.NO_NODE_NAME)
	assert_eq(edit["source"], PLAIN)


func test_rename_root_without_root_is_an_error() -> void:
	var edit := DogSceneEdit.rename_root("[gd_scene format=3]\n", "Hero")
	assert_eq(edit["error"], DogSceneEdit.NO_ROOT)
	assert_eq(DogSceneEdit.rename_root("x", "Hero")["error"], DogSceneEdit.NOT_A_SCENE)


# --- root_type ----------------------------------------------------------------


func test_root_type_reads_the_type_of_the_root() -> void:
	assert_eq(DogSceneEdit.root_type(TEMPLATE), { "type": "CharacterBody2D", "error": "" })
	assert_eq(DogSceneEdit.root_type(PLAIN)["type"], "Node2D")


func test_root_type_of_an_instanced_root_is_an_error() -> void:
	var scene := """[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://base.tscn" id="1_b"]

[node name="Thing" instance=ExtResource("1_b")]
"""
	assert_eq(DogSceneEdit.root_type(scene), { "type": "", "error": DogSceneEdit.NO_ROOT_TYPE })


func test_root_type_errors_on_bad_text() -> void:
	assert_eq(DogSceneEdit.root_type("extends Node")["error"], DogSceneEdit.NOT_A_SCENE)
	assert_eq(DogSceneEdit.root_type("[gd_scene format=3]\n")["error"], DogSceneEdit.NO_ROOT)


# --- root_script_path ---------------------------------------------------------


func test_root_script_path_reads_the_script_of_the_root() -> void:
	assert_eq(DogSceneEdit.root_script_path(TEMPLATE), { "path": OLD, "error": "" })
	assert_eq(DogSceneEdit.root_script_path(PLAIN)["path"], OLD)


func test_root_script_path_ignores_scripts_of_other_nodes() -> void:
	var child := "\n[node name=\"A\" type=\"Node\" parent=\".\"]\nscript = ExtResource(\"1_s\")\n"
	var scene := PLAIN.replace("script = ExtResource(\"1_s\")\n", "") + child
	var query := DogSceneEdit.root_script_path(scene)
	assert_eq(query, { "path": "", "error": DogSceneEdit.NO_ROOT_SCRIPT })


func test_root_script_path_of_a_root_without_script_is_an_error() -> void:
	var query := DogSceneEdit.root_script_path(NO_SCRIPT)
	assert_eq(query["error"], DogSceneEdit.NO_ROOT_SCRIPT)


func test_root_script_path_of_a_built_in_script_is_an_error() -> void:
	var scene := """[gd_scene load_steps=2 format=3]

[sub_resource type="GDScript" id="GDScript_a"]
script/source = "extends Node2D"

[node name="Thing" type="Node2D"]
script = SubResource("GDScript_a")
"""
	assert_eq(DogSceneEdit.root_script_path(scene)["error"], DogSceneEdit.BUILT_IN_ROOT_SCRIPT)


func test_root_script_path_of_a_missing_resource_is_an_error() -> void:
	var scene := NO_SCRIPT + "script = ExtResource(\"9_x\")\n"
	var error: String = DogSceneEdit.root_script_path(scene)["error"]
	assert_eq(error, DogSceneEdit.NO_SCRIPT_RESOURCE % "9_x")


func test_root_script_path_errors_on_bad_text() -> void:
	assert_eq(DogSceneEdit.root_script_path("x")["error"], DogSceneEdit.NOT_A_SCENE)
	assert_eq(DogSceneEdit.root_script_path("[gd_scene]")["error"], DogSceneEdit.NO_ROOT)


# --- retarget_root_script -----------------------------------------------------


func test_retarget_rewrites_the_path_and_drops_the_uid_of_that_resource_only() -> void:
	var edit := DogSceneEdit.retarget_root_script(TEMPLATE, NEW)
	assert_eq(edit["error"], "")
	var expected := _replaced(
		TEMPLATE,
		"[ext_resource type=\"Script\" uid=\"uid://s1\" path=\"%s\" id=\"1_s\"]" % OLD,
		"[ext_resource type=\"Script\" path=\"%s\" id=\"1_s\"]" % NEW,
	)
	assert_eq(edit["source"], expected)


func test_retarget_a_resource_without_uid() -> void:
	var source: String = DogSceneEdit.retarget_root_script(PLAIN, NEW)["source"]
	assert_eq(source, _replaced(PLAIN, OLD, NEW))


func test_retarget_errors_keep_the_text() -> void:
	var edit := DogSceneEdit.retarget_root_script(NO_SCRIPT, NEW)
	assert_eq(edit["error"], DogSceneEdit.NO_ROOT_SCRIPT)
	assert_eq(edit["source"], NO_SCRIPT)
	assert_eq(DogSceneEdit.retarget_root_script("x", NEW)["error"], DogSceneEdit.NOT_A_SCENE)


func test_crlf_text_is_edited_in_place() -> void:
	var scene := PLAIN.replace("\n", "\r\n")
	var source: String = DogSceneEdit.rename_root(scene, "Hero")["source"]
	assert_eq(source, scene.replace("name=\"Thing\"", "name=\"Hero\""))
	source = DogSceneEdit.retarget_root_script(scene, NEW)["source"]
	assert_eq(source, scene.replace(OLD, NEW))


# --- in Godot -----------------------------------------------------------------


func test_godot_loads_the_copy_with_the_new_name_and_script() -> void:
	var dir := "user://test_dog_scene_edit_root"
	DirAccess.make_dir_recursive_absolute(dir)
	var script_path := dir.path_join("scene_edit_root_hero.gd")
	_write(script_path, "class_name SceneEditRootHero\nextends Node2D\n")

	var source: String = DogSceneEdit.strip_uid(PLAIN)["source"]
	source = DogSceneEdit.rename_root(source, "SceneEditRootHero")["source"]
	source = DogSceneEdit.retarget_root_script(source, script_path)["source"]
	var scene_path := dir.path_join("scene_edit_root_hero.tscn")
	_write(scene_path, source)

	var packed := ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	var root := (packed as PackedScene).instantiate()
	assert_eq(root.name, &"SceneEditRootHero")
	assert_eq(root.get_class(), "Node2D")
	var script := root.get_script() as Script
	assert_eq(script.resource_path, script_path)
	assert_eq(script.get_global_name(), &"SceneEditRootHero")
	root.free()
	DirAccess.remove_absolute(scene_path)
	DirAccess.remove_absolute(script_path)
	DirAccess.remove_absolute(dir)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
