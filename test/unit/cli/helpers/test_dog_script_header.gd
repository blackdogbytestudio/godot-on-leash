extends GutTest
## DogScriptHeader: reading and setting the class_name of a script's text.

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
