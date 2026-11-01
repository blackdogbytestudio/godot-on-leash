extends GutTest
## DogClasses: native and global classes, with classes that exist in the repo (a
## node component, a RefCounted helper and a RefCounted state).

const MOVE_PATH := "res://addons/leash/components/2d/character/dog_move_2d.gd"


func test_exists_for_native_and_global_classes() -> void:
	for class_text in ["Node", "Area2D", "RefCounted", "DogMove2D", "DogNames", "DogState"]:
		assert_true(DogClasses.exists(class_text), class_text)
	for class_text in ["", "NoSuchClass", "dog_move_2d", "Area2d"]:
		assert_false(DogClasses.exists(class_text), class_text)


func test_global_path_is_the_script_of_a_global_class() -> void:
	assert_eq(DogClasses.global_path("DogMove2D"), MOVE_PATH)
	assert_eq(DogClasses.global_path("Node"), "", "a native class has no script")
	assert_eq(DogClasses.global_path("NoSuchClass"), "")


func test_native_base_of_a_native_class_is_itself() -> void:
	assert_eq(DogClasses.native_base("Area2D"), "Area2D")
	assert_eq(DogClasses.native_base("RefCounted"), "RefCounted")


func test_native_base_walks_the_chain_of_a_global_class() -> void:
	# DogMove2D -> DogCharacter2D -> DogComponent -> Node
	assert_eq(DogClasses.native_base("DogMove2D"), "Node")
	assert_eq(DogClasses.native_base("DogNames"), "RefCounted")
	assert_eq(DogClasses.native_base("DogFSMState"), "RefCounted")


func test_native_base_of_a_missing_class_is_empty() -> void:
	assert_eq(DogClasses.native_base("NoSuchClass"), "")
	assert_eq(DogClasses.native_base(""), "")


func test_is_node_for_node_classes_only() -> void:
	for class_text in ["Node", "Area2D", "CPUParticles2D", "DogMove2D", "DogComponent"]:
		assert_true(DogClasses.is_node(class_text), class_text)
	for class_text in ["RefCounted", "Resource", "DogNames", "DogState", "NoSuchClass", ""]:
		assert_false(DogClasses.is_node(class_text), class_text)
