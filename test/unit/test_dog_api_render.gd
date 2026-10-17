extends GutTest
## DogApiRender turns reflection dictionaries (as Godot returns them from
## get_script_method_list / get_script_signal_list) into merge blocks.


func _info(
	type: int,
	klass := "",
	usage := 0,
	hint := 0,
	hint_string := "",
	arg_name := "",
) -> Dictionary:
	var info := {
		"type": type,
		"class_name": StringName(klass),
		"usage": usage,
		"hint": hint,
		"hint_string": hint_string,
	}
	if not arg_name.is_empty():
		info["name"] = arg_name
	return info


func _method(
	method_name: String,
	args: Array = [],
	return_info := _info(TYPE_NIL),
	defaults: Array = [],
) -> Dictionary:
	return {
		"name": method_name,
		"args": args,
		"default_args": defaults,
		"flags": 1,
		"return": return_info,
	}


# --- is_public / var_name --------------------------------------------------


func test_underscore_members_are_not_public():
	assert_true(DogApiRender.is_public("jump"))
	assert_false(DogApiRender.is_public("_internal"))


func test_property_accessors_are_not_public():
	assert_false(DogApiRender.is_public("@power_setter"))
	assert_false(DogApiRender.is_public("@host_getter"))


func test_var_name_comes_from_the_component_class():
	assert_eq(DogApiRender.var_name("DogJump2D", "Jump"), "_dog_jump_2d")


func test_var_name_falls_back_to_the_node_name_without_a_class():
	assert_eq(DogApiRender.var_name("", "DashTimer"), "_dash_timer")


# --- type_text -------------------------------------------------------------


func test_type_text_for_builtin_types():
	assert_eq(DogApiRender.type_text(_info(TYPE_FLOAT)), "float")
	assert_eq(DogApiRender.type_text(_info(TYPE_VECTOR2)), "Vector2")
	assert_eq(DogApiRender.type_text(_info(TYPE_STRING)), "String")


func test_type_text_prefers_the_class_name():
	assert_eq(DogApiRender.type_text(_info(TYPE_OBJECT, "Node2D")), "Node2D")


func test_type_text_object_without_class_is_object():
	assert_eq(DogApiRender.type_text(_info(TYPE_OBJECT)), "Object")


func test_type_text_nil_is_void_unless_flagged_as_variant():
	assert_eq(DogApiRender.type_text(_info(TYPE_NIL)), "void")
	assert_eq(DogApiRender.type_text(_info(TYPE_NIL, "", PROPERTY_USAGE_NIL_IS_VARIANT)), "Variant")


func test_type_text_typed_and_plain_arrays():
	assert_eq(
		DogApiRender.type_text(_info(TYPE_ARRAY, "", 0, PROPERTY_HINT_ARRAY_TYPE, "int")),
		"Array[int]",
	)
	assert_eq(DogApiRender.type_text(_info(TYPE_ARRAY)), "Array")


# --- ref_block -------------------------------------------------------------


func test_ref_block_with_a_class_is_typed():
	var b := DogApiRender.ref_block("_dog_jump_2d", "DogJump2D", "Jump")
	assert_eq(b.kind, "var")
	assert_eq(b.name, "_dog_jump_2d")
	assert_eq(b.text, "@onready var _dog_jump_2d: DogJump2D = $Jump")


func test_ref_block_without_a_class_is_untyped():
	var b := DogApiRender.ref_block("_jump", "", "Jump")
	assert_eq(b.text, "@onready var _jump = $Jump")


func test_ref_block_quotes_node_names_that_are_not_identifiers():
	var b := DogApiRender.ref_block("_jump_2", "DogJump2D", "Jump 2")
	assert_eq(b.text, "@onready var _jump_2: DogJump2D = $\"Jump 2\"")


# --- func_block ------------------------------------------------------------


func test_func_block_without_args_returning_void():
	var b := DogApiRender.func_block("_dog_jump_2d", _method("jump"))
	assert_eq(b.kind, "func")
	assert_eq(b.name, "jump")
	assert_eq(b.text, "func jump() -> void:\n\t_dog_jump_2d.jump()")


func test_func_block_returning_a_value_uses_return():
	var b := DogApiRender.func_block("_dog_jump_2d", _method("get_power", [], _info(TYPE_FLOAT)))
	assert_eq(b.text, "func get_power() -> float:\n\treturn _dog_jump_2d.get_power()")


func test_func_block_with_args_and_default_values():
	var args := [
		_info(TYPE_FLOAT, "", 0, 0, "", "power"),
		_info(TYPE_INT, "", 0, 0, "", "times"),
		_info(TYPE_STRING, "", 0, 0, "", "label"),
		_info(TYPE_VECTOR2, "", 0, 0, "", "v"),
	]
	var b := DogApiRender.func_block(
		"_x",
		_method("jump_with", args, _info(TYPE_NIL), [2, "x", Vector2(1, 2)]),
	)
	assert_eq(
		b.text,
		"func jump_with(power: float, times: int = 2, label: String = \"x\", v: Vector2 = Vector2(1, 2)) -> void:\n\t_x.jump_with(power, times, label, v)"
	)


func test_func_block_untyped_args_and_return_become_variant():
	var variant_info := _info(TYPE_NIL, "", PROPERTY_USAGE_NIL_IS_VARIANT)
	var args := [
		_info(TYPE_NIL, "", PROPERTY_USAGE_NIL_IS_VARIANT, 0, "", "a"),
		_info(TYPE_NIL, "", PROPERTY_USAGE_NIL_IS_VARIANT, 0, "", "b"),
	]
	var b := DogApiRender.func_block("_x", _method("untyped", args, variant_info, [3]))
	assert_eq(
		b.text,
		"func untyped(a: Variant, b: Variant = 3) -> Variant:\n\treturn _x.untyped(a, b)",
	)


func test_func_block_with_class_and_typed_array_types():
	var args := [_info(TYPE_OBJECT, "Node", 0, 0, "", "n")]
	var ret := _info(TYPE_ARRAY, "", 0, PROPERTY_HINT_ARRAY_TYPE, "String")
	var b := DogApiRender.func_block("_x", _method("find", args, ret))
	assert_eq(b.text, "func find(n: Node) -> Array[String]:\n\treturn _x.find(n)")


# --- signal_block / connect_block ------------------------------------------


func test_signal_block_with_args():
	var info := {
		"name": "landed",
		"args": [
			_info(TYPE_FLOAT, "", 0, 0, "", "speed"),
			_info(TYPE_OBJECT, "Node", 0, 0, "", "who"),
		],
	}
	var b := DogApiRender.signal_block(info)
	assert_eq(b.kind, "signal")
	assert_eq(b.name, "landed")
	assert_eq(b.text, "signal landed(speed: float, who: Node)")


func test_signal_block_without_args_has_no_parentheses():
	var b := DogApiRender.signal_block({ "name": "plain", "args": [] })
	assert_eq(b.text, "signal plain")


func test_signal_block_untyped_arg_is_variant():
	var info := { "name": "changed", "args": [_info(TYPE_NIL, "", 0, 0, "", "value")] }
	assert_eq(DogApiRender.signal_block(info).text, "signal changed(value: Variant)")


func test_connect_block_forwards_the_signal_with_emit():
	var b := DogApiRender.connect_block("_dog_jump_2d", "landed")
	assert_eq(b.kind, "ready_line")
	assert_eq(b.name, "_dog_jump_2d.landed")
	assert_eq(b.text, "\t_dog_jump_2d.landed.connect(landed.emit)")
