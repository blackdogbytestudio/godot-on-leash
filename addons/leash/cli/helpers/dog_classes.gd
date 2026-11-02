@tool
class_name DogClasses
extends RefCounted
## Looks up class names: the native classes of Godot (ClassDB) and the global
## classes of the project (`class_name`, from ProjectSettings.get_global_class_list).
##
## The global classes come from the class cache, which Godot writes when it scans
## the project: a script created since then is not known yet.


## Whether `name` is a native class or a global class.
static func exists(name: String) -> bool:
	return ClassDB.class_exists(name) or not global_path(name).is_empty()


## The script path of the global class `name`, or "" when there is none.
static func global_path(name: String) -> String:
	var entry: Dictionary = _globals().get(name, {})
	return String(entry.get("path", ""))


## The classes from `name` up to the native class it ends in, both included:
## [FixturePaladin, FixtureKnight, CharacterBody2D], or [Area2D] for a native class.
## Empty when `name` does not exist or its chain is broken (a base that does not
## exist, or a cycle).
static func chain(name: String) -> PackedStringArray:
	var globals := _globals()
	var classes := PackedStringArray()
	var current := name
	while not ClassDB.class_exists(current):
		if current in classes or not globals.has(current):
			return PackedStringArray()
		classes.append(current)
		current = String(globals[current]["base"])
	classes.append(current)
	return classes


## The native class `name` ends in: itself when it is native, otherwise the native
## class at the end of its chain (see chain). "" when the chain is empty.
static func native_base(name: String) -> String:
	var classes := chain(name)
	return "" if classes.is_empty() else classes[classes.size() - 1]


## Whether `name` is a node class: Node or a subclass of it, native or global.
static func is_node(name: String) -> bool:
	var native := native_base(name)
	return not native.is_empty() and ClassDB.is_parent_class(native, &"Node")


## {class: entry of get_global_class_list}.
static func _globals() -> Dictionary:
	var globals := {}
	for entry in ProjectSettings.get_global_class_list():
		globals[String(entry["class"])] = entry
	return globals
