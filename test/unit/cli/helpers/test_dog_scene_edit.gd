extends GutTest
## DogSceneEdit: adding a node to the text of a .tscn.

const JUMP := "res://addons/leash/components/2d/character/dog_jump_2d.gd"
const MOVE := "res://move.gd"
const PLAIN := """[gd_scene format=3]

[node name="Player" type="CharacterBody2D"]
"""
const WITH_RESOURCE := """[gd_scene load_steps=2 format=3 uid="uid://b1"]

[ext_resource type="Script" path="res://move.gd" id="1_move"]

[node name="Player" type="CharacterBody2D"]

[node name="DogMove2D" type="Node" parent="."]
script = ExtResource("1_move")

[node name="Sprite2D" type="Sprite2D" parent="."]

[node name="Shape" type="CollisionShape2D" parent="Sprite2D"]
"""


func test_adds_a_node_with_its_script_to_a_scene_without_resources() -> void:
	var edit := DogSceneEdit.add_node(PLAIN, "DogJump2D", "Node", JUMP)
	assert_eq(edit["error"], "")
	var id := "1_" + JUMP.md5_text().substr(0, 5)
	var expected := """[gd_scene format=3]

[ext_resource type="Script" path="%s" id="%s"]

[node name="Player" type="CharacterBody2D"]

[node name="DogJump2D" type="Node" parent="."]
script = ExtResource("%s")
""" % [JUMP, id, id]
	assert_eq(edit["source"], expected)


func test_adds_the_resource_after_the_last_one_with_the_next_ordinal() -> void:
	var edit := DogSceneEdit.add_node(WITH_RESOURCE, "DogJump2D", "Node", JUMP)
	assert_eq(edit["error"], "")
	var id := "2_" + JUMP.md5_text().substr(0, 5)
	var source: String = edit["source"]
	assert_true(source.contains("id=\"1_move\"]\n[ext_resource type=\"Script\" path=\"%s\"" % JUMP))
	assert_true(source.contains("script = ExtResource(\"%s\")" % id))


func test_the_node_goes_last_after_the_children_of_other_nodes() -> void:
	var source: String = DogSceneEdit.add_node(WITH_RESOURCE, "DogJump2D", "Node", JUMP)["source"]
	var id := "2_" + JUMP.md5_text().substr(0, 5)
	var shape := "[node name=\"Shape\" type=\"CollisionShape2D\" parent=\"Sprite2D\"]\n"
	var jump := "[node name=\"DogJump2D\" type=\"Node\" parent=\".\"]\n"
	assert_true(source.ends_with(shape + "\n" + jump + "script = ExtResource(\"%s\")\n" % id))


func test_bumps_load_steps_when_it_adds_a_resource() -> void:
	var source: String = DogSceneEdit.add_node(WITH_RESOURCE, "DogJump2D", "Node", JUMP)["source"]
	assert_true(source.begins_with("[gd_scene load_steps=3 format=3 uid=\"uid://b1\"]"))


func test_reuses_the_resource_the_scene_already_has() -> void:
	var edit := DogSceneEdit.add_node(WITH_RESOURCE, "OtherMove", "Node", MOVE)
	assert_eq(edit["error"], "")
	var source: String = edit["source"]
	assert_eq(source.count("[ext_resource"), 1)
	assert_true(source.begins_with("[gd_scene load_steps=2"))
	var node := "[node name=\"OtherMove\" type=\"Node\" parent=\".\"]\n"
	assert_true(source.contains(node + "script = ExtResource(\"1_move\")"))


func test_writes_the_uid_of_the_script_when_given() -> void:
	var edit := DogSceneEdit.add_node(PLAIN, "DogJump2D", "Node", JUMP, "uid://c2")
	var line := "[ext_resource type=\"Script\" uid=\"uid://c2\" path=\"%s\"" % JUMP
	assert_true(String(edit["source"]).contains(line))


func test_adds_a_node_without_script() -> void:
	var edit := DogSceneEdit.add_node(PLAIN, "Sprite2D", "Sprite2D")
	assert_eq(edit["error"], "")
	assert_eq(edit["source"], PLAIN + "\n[node name=\"Sprite2D\" type=\"Sprite2D\" parent=\".\"]\n")


func test_the_node_goes_before_connections_and_editable_instances() -> void:
	var scene := PLAIN + "\n[connection signal=\"ready\" from=\".\" to=\".\" method=\"_x\"]\n"
	var source: String = DogSceneEdit.add_node(scene, "Sprite2D", "Sprite2D")["source"]
	var node_at := source.find("[node name=\"Sprite2D\"")
	assert_gt(node_at, source.find("[node name=\"Player\""))
	assert_lt(node_at, source.find("[connection"))
	assert_true(source.contains("parent=\".\"]\n\n[connection"))

	var editable := PLAIN + "\n[editable path=\"Inst\"]\n"
	var edited: String = DogSceneEdit.add_node(editable, "Sprite2D", "Sprite2D")["source"]
	assert_lt(edited.find("[node name=\"Sprite2D\""), edited.find("[editable"))


func test_trailing_blank_lines_become_a_single_newline() -> void:
	var edit := DogSceneEdit.add_node(PLAIN + "\n\n\n", "Sprite2D", "Sprite2D")
	assert_true(String(edit["source"]).ends_with("parent=\".\"]\n"))
	assert_false(String(edit["source"]).ends_with("\n\n"))


func test_a_taken_id_is_skipped() -> void:
	var taken := "1_" + JUMP.md5_text().substr(0, 5)
	var sub := "[sub_resource type=\"X\" id=\"%s\"]\n\n" % taken
	var scene := PLAIN.replace("[node", sub + "[node")
	var source: String = DogSceneEdit.add_node(scene, "DogJump2D", "Node", JUMP)["source"]
	assert_true(source.contains("id=\"2_%s\"]" % JUMP.md5_text().substr(0, 5)))


func test_same_edit_gives_the_same_text() -> void:
	var first := DogSceneEdit.add_node(PLAIN, "DogJump2D", "Node", JUMP)
	var second := DogSceneEdit.add_node(PLAIN, "DogJump2D", "Node", JUMP)
	assert_eq(first["source"], second["source"])


func test_a_child_with_that_name_is_an_error_and_the_text_is_kept() -> void:
	var edit := DogSceneEdit.add_node(WITH_RESOURCE, "Sprite2D", "Sprite2D")
	assert_eq(edit["error"], DogSceneEdit.NODE_EXISTS % "Sprite2D")
	assert_eq(edit["source"], WITH_RESOURCE)


func test_a_deeper_node_with_that_name_is_not_a_clash() -> void:
	var edit := DogSceneEdit.add_node(WITH_RESOURCE, "Shape", "CollisionShape2D")
	assert_eq(edit["error"], "")


func test_text_that_is_not_a_scene_is_an_error() -> void:
	var edit := DogSceneEdit.add_node("extends Node\n", "A", "Node")
	assert_eq(edit["error"], DogSceneEdit.NOT_A_SCENE)
	assert_eq(edit["source"], "extends Node\n")
	assert_eq(DogSceneEdit.add_node("", "A", "Node")["error"], DogSceneEdit.NOT_A_SCENE)


func test_a_scene_without_root_is_an_error() -> void:
	var edit := DogSceneEdit.add_node("[gd_scene format=3]\n", "A", "Node")
	assert_eq(edit["error"], DogSceneEdit.NO_ROOT)


func test_a_node_without_type_is_an_error() -> void:
	var edit := DogSceneEdit.add_node(PLAIN, "A", "")
	assert_eq(edit["error"], DogSceneEdit.NO_NODE_TYPE)
	assert_eq(edit["source"], PLAIN)


func test_godot_loads_the_edited_scene_with_the_script_attached() -> void:
	var source: String = DogSceneEdit.add_node(PLAIN, "DogJump2D", "Node", JUMP)["source"]
	var path := "user://test_dog_scene_edit.tscn"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()

	var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	var root := (packed as PackedScene).instantiate()
	assert_eq(root.get_child_count(), 1)
	var child := root.get_child(0)
	assert_eq(child.name, &"DogJump2D")
	assert_eq((child.get_script() as Script).get_global_name(), &"DogJump2D")
	root.free()
	DirAccess.remove_absolute(path)
