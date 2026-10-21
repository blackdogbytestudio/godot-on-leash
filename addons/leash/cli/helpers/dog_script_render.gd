@tool
class_name DogScriptRender
extends RefCounted
## Turns reflection dictionaries (get_script_method_list / get_script_signal_list)
## into the blocks DogScriptMerge understands. Pure: no scene, file or editor access.
##
## Limitation: default values are written with var_to_str, which is valid GDScript
## for the usual types (numbers, strings, bools, vectors, colors, null).


## `_x` is internal; `@x_setter` / `@x_getter` are the accessors Godot generates
## for properties, and are not valid names to redeclare.
static func is_public(member_name: String) -> bool:
	return not member_name.begins_with("_") and not member_name.begins_with("@")


## `_` + snake_case of the component class (DogJump2D -> _dog_jump_2d), or of the
## node name when the script has no class_name.
static func var_name(component_class: String, node_name: String) -> String:
	var base := component_class if not component_class.is_empty() else node_name
	return "_" + base.to_snake_case()


## GDScript type for a property-info dictionary: {type, class_name, usage, hint, hint_string}.
static func type_text(info: Dictionary) -> String:
	var klass := String(info.get("class_name", ""))
	if not klass.is_empty():
		return klass
	var type: int = info.get("type", TYPE_NIL)
	var usage: int = info.get("usage", 0)
	if type == TYPE_NIL:
		return "Variant" if (usage & PROPERTY_USAGE_NIL_IS_VARIANT) != 0 else "void"
	if type == TYPE_ARRAY and int(info.get("hint", 0)) == PROPERTY_HINT_ARRAY_TYPE:
		var element := String(info.get("hint_string", ""))
		if not element.is_empty():
			return "Array[%s]" % element
	if type == TYPE_OBJECT:
		return "Object"
	return type_string(type)


static func ref_block(var_name: String, component_class: String, node_name: String) -> Dictionary:
	var path := _node_path(node_name)
	var text := "@onready var %s = %s" % [var_name, path]
	if not component_class.is_empty():
		text = "@onready var %s: %s = %s" % [var_name, component_class, path]
	return { "kind": "var", "name": var_name, "text": text }


static func func_block(var_name: String, method: Dictionary) -> Dictionary:
	var method_name := String(method["name"])
	var args: Array = method.get("args", [])
	var params := _params(args, method.get("default_args", []))
	var return_type := type_text(method.get("return", {}))
	var call := "%s.%s(%s)" % [var_name, method_name, ", ".join(_arg_names(args))]
	var body := call if return_type == "void" else "return " + call
	return {
		"kind": "func",
		"name": method_name,
		"text": "func %s(%s) -> %s:\n\t%s" % [method_name, ", ".join(params), return_type, body],
	}


static func signal_block(info: Dictionary) -> Dictionary:
	var signal_name := String(info["name"])
	var args: Array = info.get("args", [])
	var text := "signal " + signal_name
	if not args.is_empty():
		text += "(%s)" % ", ".join(_params(args, []))
	return { "kind": "signal", "name": signal_name, "text": text }


## The line, inside `_ready`, that forwards a component signal through the host's.
static func connect_block(var_name: String, signal_name: String) -> Dictionary:
	return {
		"kind": "ready_line",
		"name": "%s.%s" % [var_name, signal_name],
		"text": "\t%s.%s.connect(%s.emit)" % [var_name, signal_name, signal_name],
	}


## `name: Type` for each argument, with `= default` on the last ones.
static func _params(args: Array, defaults: Array) -> PackedStringArray:
	var first_default := args.size() - defaults.size()
	var params := PackedStringArray()
	for i in args.size():
		var arg: Dictionary = args[i]
		var param := "%s: %s" % [arg["name"], _arg_type(arg)]
		if i >= first_default:
			param += " = " + var_to_str(defaults[i - first_default])
		params.append(param)
	return params


static func _arg_names(args: Array) -> PackedStringArray:
	var names := PackedStringArray()
	for arg in args:
		names.append(String(arg["name"]))
	return names


## An argument is never void: an untyped one is Variant.
static func _arg_type(arg: Dictionary) -> String:
	var text := type_text(arg)
	return "Variant" if text == "void" else text


static func _node_path(node_name: String) -> String:
	if node_name.is_valid_identifier():
		return "$" + node_name
	return "$\"%s\"" % node_name.replace("\"", "\\\"")
