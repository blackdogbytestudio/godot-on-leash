extends GutTest
## DogScriptHeader: reading and setting the class_name and the extends of a script's
## text.

const BODY := """extends CharacterBody2D
## A body.

const SPEED := 3.0


func _physics_process(delta: float) -> void:
	move_and_slide()
"""


func test_inserts_class_name_right_before_extends() -> void:
	var edit := DogScriptHeader.set_class_name("extends CharacterBody2D\n", "Hero")
	assert_eq(edit, { "source": "class_name Hero\nextends CharacterBody2D\n", "error": "" })


func test_keeps_the_body_and_what_comes_before_extends() -> void:
	var source := "@tool\n@icon(\"res://icon.svg\")\n" + BODY
	var edit := DogScriptHeader.set_class_name(source, "Hero")
	assert_eq(edit["error"], "")
	assert_eq(edit["source"], "@tool\n@icon(\"res://icon.svg\")\nclass_name Hero\n" + BODY)


func test_replaces_an_existing_class_name_in_place() -> void:
	var source := "class_name Thing  # the template\n" + BODY
	var edit := DogScriptHeader.set_class_name(source, "Hero")
	assert_eq(edit["error"], "")
	assert_eq(edit["source"], "class_name Hero  # the template\n" + BODY)


func test_replaces_a_class_name_on_the_extends_line() -> void:
	var edit := DogScriptHeader.set_class_name("class_name Thing extends Node2D\n", "Hero")
	assert_eq(edit["source"], "class_name Hero extends Node2D\n")


func test_ignores_class_name_in_comments_and_indented_text() -> void:
	var source := "# class_name Old\nextends Node\n\n\nfunc a() -> void:\n\tprint(\"class_name\")\n"
	var edit := DogScriptHeader.set_class_name(source, "Hero")
	assert_eq(edit["source"], "# class_name Old\nclass_name Hero\n" + source.substr(17))


func test_a_script_without_extends_is_an_error_and_the_text_is_kept() -> void:
	var edit := DogScriptHeader.set_class_name("func a() -> void:\n\tpass\n", "Hero")
	assert_eq(edit["error"], DogScriptHeader.NO_EXTENDS)
	assert_eq(edit["source"], "func a() -> void:\n\tpass\n")


func test_an_invalid_class_name_is_an_error() -> void:
	var edit := DogScriptHeader.set_class_name(BODY, "2Hero")
	assert_eq(edit["error"], DogScriptHeader.INVALID_CLASS % "2Hero")
	assert_eq(edit["source"], BODY)


func test_declared_class_name_reads_the_class_name_line() -> void:
	assert_eq(DogScriptHeader.declared_class_name("class_name Hero\n" + BODY), "Hero")
	assert_eq(DogScriptHeader.declared_class_name("extends Node\nclass_name Hero\n"), "Hero")
	assert_eq(DogScriptHeader.declared_class_name("class_name Hero extends Node\n"), "Hero")
	assert_eq(DogScriptHeader.declared_class_name(BODY), "")
	assert_eq(DogScriptHeader.declared_class_name("# class_name Hero\n" + BODY), "")


# --- extends ------------------------------------------------------------------


func test_set_extends_replaces_the_class_after_extends() -> void:
	var edit := DogScriptHeader.set_extends("@tool\nclass_name Hero\n" + BODY, "Area2D")
	var expected := "@tool\nclass_name Hero\n" + BODY.replace("CharacterBody2D", "Area2D")
	assert_eq(edit, { "source": expected, "error": "" })


func test_set_extends_keeps_a_comment_after_the_class() -> void:
	var edit := DogScriptHeader.set_extends("extends Node2D  # base\n", "PlayerBase")
	assert_eq(edit["source"], "extends PlayerBase  # base\n")


func test_set_extends_on_the_class_name_line() -> void:
	var edit := DogScriptHeader.set_extends("class_name Hero extends Node2D\n", "Area2D")
	assert_eq(edit["source"], "class_name Hero extends Area2D\n")


func test_set_extends_replaces_a_path_or_a_dotted_name() -> void:
	var path := DogScriptHeader.set_extends("extends \"res://a.gd\"\n", "Node")
	assert_eq(path["source"], "extends Node\n")
	var dotted := DogScriptHeader.set_extends("extends Outer.Inner\n", "Node")
	assert_eq(dotted["source"], "extends Node\n")


func test_set_extends_ignores_extends_in_comments_and_indented_text() -> void:
	var source := "# extends Old\nextends Node\n\n\nclass Inner:\n\textends RefCounted\n"
	var edit := DogScriptHeader.set_extends(source, "Node2D")
	assert_eq(edit["source"], source.replace("extends Node\n", "extends Node2D\n"))


func test_set_extends_without_extends_is_an_error_and_the_text_is_kept() -> void:
	var source := "class_name Hero\n\n\nfunc a() -> void:\n\tpass\n"
	var edit := DogScriptHeader.set_extends(source, "Node")
	assert_eq(edit, { "source": source, "error": DogScriptHeader.NO_EXTENDS })


func test_set_extends_with_an_invalid_class_is_an_error() -> void:
	var edit := DogScriptHeader.set_extends(BODY, "Area 2D")
	assert_eq(edit, { "source": BODY, "error": DogScriptHeader.INVALID_CLASS % "Area 2D" })


func test_declared_extends_reads_the_class_as_written() -> void:
	assert_eq(DogScriptHeader.declared_extends(BODY), "CharacterBody2D")
	assert_eq(DogScriptHeader.declared_extends("class_name A extends B\n"), "B")
	assert_eq(DogScriptHeader.declared_extends("extends \"res://a.gd\"\n"), "\"res://a.gd\"")
	assert_eq(DogScriptHeader.declared_extends("class_name A\n# extends B\n"), "")
