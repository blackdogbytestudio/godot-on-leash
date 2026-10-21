# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## The pure parts of DogApiGenerator: normalize_root and plan, on nodes built in
## memory from the fixture scripts in test/doubles/api/.

const JUMP_SCRIPT := "res://test/doubles/api/fixture_jump.gd"
const DASH_SCRIPT := "res://test/doubles/api/fixture_dash.gd"
const BASE_SCRIPT := "res://test/doubles/api/fixture_base.gd"


func _host(components: Dictionary) -> Node:
	var host: Node = autofree(Node2D.new())
	for node_name in components:
		# gdstyle:ignore=quality/allocation-in-loop
		var node := Node.new()
		node.name = node_name
		node.set_script(load(components[node_name]))
		host.add_child(node)
	return host


## plan() with the snake_case class of every classed child, in child order,
## unless `names` is given.
func _plan(host: Node, names: Array = []) -> Dictionary:
	if names.is_empty():
		for child in host.get_children():
			var script := child.get_script() as Script
			if script != null and not String(script.get_global_name()).is_empty():
				names.append(String(script.get_global_name()).to_snake_case())
	return DogApiGenerator.plan(host, names)


func _names(blocks: Array, kind: String) -> Array:
	var names := []
	for block in blocks:
		if block["kind"] == kind:
			names.append(block["name"])
	names.sort()
	return names


func _block(blocks: Array, kind: String, block_name: String) -> Dictionary:
	for block in blocks:
		if block["kind"] == kind and block["name"] == block_name:
			return block
	return {}


# --- normalize_root --------------------------------------------------------


func test_normalize_root_adds_res_and_drops_the_trailing_slash() -> void:
	assert_eq(DogApiGenerator.normalize_root("scenes"), "res://scenes")
	assert_eq(DogApiGenerator.normalize_root("res://scenes/"), "res://scenes")
	assert_eq(DogApiGenerator.normalize_root("user://x"), "user://x")


func test_normalize_root_rejects_parent_traversal_and_empty() -> void:
	assert_eq(DogApiGenerator.normalize_root("res://a/../b"), "")
	assert_eq(DogApiGenerator.normalize_root(".."), "")
	assert_eq(DogApiGenerator.normalize_root(""), "")


# --- plan ------------------------------------------------------------------


func test_plan_makes_a_typed_var_per_scripted_child() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT, "Dash": DASH_SCRIPT })
	var p := _plan(host)
	assert_eq(_names(p.blocks, "var"), ["_fixture_dash", "_fixture_jump_2d"])
	assert_eq(
		_block(p.blocks, "var", "_fixture_jump_2d").text,
		"@onready var _fixture_jump_2d: FixtureJump2D = $Jump"
	)


func test_plan_ignores_children_without_a_script() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT })
	host.add_child(Sprite2D.new())
	var p := _plan(host)
	assert_eq(_names(p.blocks, "var"), ["_fixture_jump_2d"])


func test_plan_forwards_public_methods_including_inherited_ones() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT })
	var p := _plan(host)
	assert_eq(_names(p.blocks, "func"), ["disable", "enable", "get_power", "jump", "jump_with"])


func test_plan_skips_internal_and_static_members() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT })
	var p := _plan(host)
	assert_does_not_have(_names(p.blocks, "func"), "_internal")
	assert_does_not_have(_names(p.blocks, "func"), "util")
	assert_does_not_have(_names(p.blocks, "signal"), "_hidden")


func test_plan_renders_the_forwarding_funcs() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT })
	var p := _plan(host)
	assert_eq(
		_block(p.blocks, "func", "jump").text,
		"func jump() -> void:\n\t_fixture_jump_2d.jump()",
	)
	assert_eq(
		_block(p.blocks, "func", "jump_with").text,
		(
			"func jump_with(power: float, times: int = 2) -> void:\n"
			+ "\t_fixture_jump_2d.jump_with(power, times)"
		)
	)
	assert_eq(
		_block(p.blocks, "func", "get_power").text,
		"func get_power() -> float:\n\treturn _fixture_jump_2d.get_power()"
	)


func test_plan_redeclares_and_connects_public_signals() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT, "Dash": DASH_SCRIPT })
	var p := _plan(host)
	assert_eq(_names(p.blocks, "signal"), ["dashed", "landed"])
	assert_eq(_block(p.blocks, "signal", "landed").text, "signal landed(speed: float)")
	assert_eq(_names(p.blocks, "ready_line"), ["_fixture_dash.dashed", "_fixture_jump_2d.landed"])


func test_plan_two_children_of_the_same_class_is_an_error() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT, "Jump2": JUMP_SCRIPT })
	var p := _plan(host)
	assert_string_contains(p.error, "more than one")
	assert_string_contains(p.error, "Jump2")
	assert_eq(p.blocks, [])


func test_plan_only_takes_the_listed_components() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT, "Dash": DASH_SCRIPT })
	var p := _plan(host, ["fixture_dash"])
	assert_eq(p.error, "")
	assert_eq(_names(p.blocks, "var"), ["_fixture_dash"])
	assert_does_not_have(_names(p.blocks, "func"), "jump")


func test_plan_follows_the_order_of_the_list_not_of_the_scene() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT, "Dash": DASH_SCRIPT })
	var p := _plan(host, ["fixture_dash", "fixture_jump_2d"])
	var vars: Array = []
	for block in p.blocks:
		if block["kind"] == "var":
			vars.append(block["name"])
	assert_eq(vars, ["_fixture_dash", "_fixture_jump_2d"])


func test_plan_a_repeated_component_is_taken_once() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT })
	var p := _plan(host, ["fixture_jump_2d", "fixture_jump_2d"])
	assert_eq(p.error, "")
	assert_eq(_names(p.blocks, "var"), ["_fixture_jump_2d"])


func test_plan_a_class_that_is_not_a_child_is_an_error_listing_the_children() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT })
	var p := _plan(host, ["fixture_dash"])
	assert_string_contains(p.error, "fixture_dash")
	assert_string_contains(p.error, "not a child")
	assert_string_contains(p.error, "fixture_jump_2d")


func test_plan_a_name_that_matches_no_class_is_an_error() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT })
	var p := _plan(host, ["fixture_nothing"])
	assert_string_contains(p.error, "fixture_nothing")
	assert_string_contains(p.error, "no class")


func test_plan_a_failing_component_stops_everything() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT })
	var p := _plan(host, ["fixture_jump_2d", "fixture_dash"])
	assert_ne(p.error, "")
	assert_eq(p.blocks, [])


func test_plan_skips_members_another_component_already_provides() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT, "Base": BASE_SCRIPT })
	var p := _plan(host)
	assert_eq(_names(p.blocks, "func").count("enable"), 1)
	assert_eq(_names(p.blocks, "func").count("jump"), 1)
	assert_string_contains("\n".join(p.warnings), "enable")


func test_plan_never_forwards_property_accessors() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT })
	var p := _plan(host)
	host.free()
	for func_name in _names(p.blocks, "func"):
		assert_false(func_name.begins_with("@"), func_name)


# --- candidates --------------------------------------------------------------


func test_candidates_are_the_snake_case_classes_of_the_children_sorted() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT, "Dash": DASH_SCRIPT })
	assert_eq(DogApiGenerator.candidates(host), ["fixture_dash", "fixture_jump_2d"])


func test_candidates_skip_children_without_a_class() -> void:
	var host := _host({ "Jump": JUMP_SCRIPT, "Plain": "res://test/doubles/api/no_class.gd" })
	var bare: Node = Node.new()
	bare.name = "Bare"
	host.add_child(bare)
	assert_eq(DogApiGenerator.candidates(host), ["fixture_jump_2d"])
