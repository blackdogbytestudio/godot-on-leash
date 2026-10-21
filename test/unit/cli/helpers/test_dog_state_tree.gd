# gdstyle:ignore-file=quality/max-public-methods
extends GutTest


func _parents(tree: DogStateTree) -> Dictionary:
	var result := {}
	for node in tree.nodes:
		result[node.name] = node.parent
	return result


func test_single_root() -> void:
	var tree := DogStateTree.parse(PackedStringArray(["alive"]))
	assert_eq(tree.error, "")
	assert_eq(tree.nodes.size(), 1)
	assert_eq(tree.nodes[0].parent, "")
	assert_eq(tree.nodes[0].depth, 0)


func test_nested_tree() -> void:
	var tokens := DogCli.tokenize("alive .grounded ..run ...run_ground ..idle dead")
	var tree := DogStateTree.parse(tokens)
	assert_eq(tree.error, "")
	assert_eq(_parents(tree), {
		"alive": "",
		"grounded": "alive",
		"run": "grounded",
		"run_ground": "run",
		"idle": "grounded",
		"dead": "",
	})


func test_parent_always_comes_before_children() -> void:
	var tree := DogStateTree.parse(DogCli.tokenize("alive .grounded ..run dead"))
	var seen := {}
	for node in tree.nodes:
		if node.parent != "":
			assert_true(seen.has(node.parent), "%s came before its parent" % node.name)
		seen[node.name] = true


func test_empty_is_an_error() -> void:
	assert_ne(DogStateTree.parse(PackedStringArray()).error, "")


func test_too_deep_is_an_error() -> void:
	assert_ne(DogStateTree.parse(PackedStringArray(["alive", "...run"])).error, "")


func test_duplicate_name_is_an_error() -> void:
	assert_ne(DogStateTree.parse(PackedStringArray(["alive", ".idle", "dead", ".idle"])).error, "")


func test_dots_without_name_is_an_error() -> void:
	assert_ne(DogStateTree.parse(PackedStringArray(["alive", ".."])).error, "")


func test_quoted_input_is_an_error() -> void:
	var tree := DogStateTree.parse(DogCli.tokenize("'alive .grounded'"))
	assert_ne(tree.error, "")


func test_invalid_characters_are_an_error() -> void:
	assert_ne(DogStateTree.parse(PackedStringArray(["Alive"])).error, "")
	assert_ne(DogStateTree.parse(PackedStringArray(["al ive"])).error, "")
	assert_ne(DogStateTree.parse(PackedStringArray(["1alive"])).error, "")


func test_is_valid_name_accepts_snake_case_state_names() -> void:
	for ok in ["alive", "run_ground", "jump2", "a1_b2"]:
		assert_true(DogStateTree.is_valid_name(ok), ok)


func test_is_valid_name_rejects_parts_that_start_with_a_digit() -> void:
	# Unlike DogNames (actors, components): a state part can't start with a digit.
	for bad in ["", "Alive", "_alive", "alive_", "a__b", "run_2d", "2run", ".alive", "a-b"]:
		assert_false(DogStateTree.is_valid_name(bad), bad)
