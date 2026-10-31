@tool
class_name DogBindGenerator
extends RefCounted
## Fills the root script of a scene with an API that forwards to its components
## (direct children of the root, found by their class_name in snake_case:
## `dog_jump_2d` -> DogJump2D): one `@onready` reference per component, a forwarding
## func per public method, and a re-declared + connected signal per public signal.
##
## It always binds every direct child of the root that has a class and is not a state
## machine. The classes listed in `components` are added to the scene first when it
## does not have them yet (only classes of the project; naming a machine is an error,
## the state command owns machines).
##
## Convention: the scene is `<actor>.tscn` inside the actor's directory (see
## DogSettings.actor_dir), with a script already attached to the root node (create
## it in Godot first, so `extends` is right). Members starting with `_` are
## internal and never forwarded.

# Error messages
const COULD_NOT_WRITE := "could not write %s"
const COULD_NOT_READ := "could not read %s"
const COULD_NOT_LOAD := "could not load %s"
const COULD_NOT_INSTANTIATE := "could not instantiate %s"
const NO_HOST_SCRIPT := "the root node of %s has no script: attach one in Godot first"
const BUILT_IN_SCRIPT := "the script of %s is built into the scene: save it as a .gd file first"
const MACHINE_COMPONENT := "%s is a state machine, not a component: the state command handles it."
const NOT_A_CHILD := (
	"%s is not a child of %s: add the node to the scene first"
	+ " (components in the scene: %s)."
)
const UNKNOWN_CLASS := "no class in the project matches '%s'."
const NOT_A_NODE := "%s is not a node class, so it can't be added to %s."
const SCENE_EDIT_FAILED := "%s: %s"
const REPEATED_COMPONENT := "more than one %s under %s: %s. A component class must appear once."
const SCENE_NOT_FOUND := "no scene at %s (use --folder if the actor lives somewhere else)."
const NOTHING_TO_BIND := "no components in %s: nothing to bind."
const MEMBER_SKIPPED := "%s %s of %s was skipped: %s already provides it"


## build + write: the scene first, then the host script, each one only when it
## changed. Nothing is written on error or when `options.write` is false.
static func generate(options: Options) -> Result:
	var result := build(options)
	if not result.error.is_empty() or not options.write:
		return result
	var written := PackedStringArray()
	if result.scene_source != result.scene_original:
		if not _write_text(result.scene, result.scene_source):
			result.error = COULD_NOT_WRITE % result.scene
			return result
		written.append(result.scene)
	if result.source != result.original:
		if not _write_text(result.path, result.source):
			result.error = COULD_NOT_WRITE % result.path
			return result
		written.append(result.path)
	if not written.is_empty():
		DogEditor.refresh(written)
	return result


## Everything except the writes. Returns a Result whose `scene_source` and `source`
## are what generate writes to `scene` and to `path`, the host script.
static func build(options: Options) -> Result:
	var found := find_scene(options.actor, options.folder)
	var find_error: String = found["error"]
	if not find_error.is_empty():
		return _failure(find_error)
	var scene_path: String = found["path"]

	var loaded := _load_host(scene_path)
	var load_error: String = loaded["error"]
	if not load_error.is_empty():
		return _failure(load_error)
	var host: Node = loaded["host"]

	var chosen := _plan_components(host, options.components, scene_path)
	host.free()
	var chosen_error: String = chosen["error"]
	if not chosen_error.is_empty():
		return _failure(chosen_error)

	var result := _merge_into(loaded["path"], scene_path, chosen["planned"], options.mode)
	var added: Dictionary = chosen["added"]
	if not String(added["source"]).is_empty():
		result.scene_original = _read_text(scene_path)
		result.scene_source = added["source"]
	result.report.assign(added["report"] + Array(result.report))
	return result


## Everything build does with the live host: adds the listed components the scene
## does not have, then plans the blocks of every component in the scene. Returns
## {planned, added, error}.
static func _plan_components(host: Node, listed: Array, scene_path: String) -> Dictionary:
	var warnings: Array = []
	var added := { "source": "", "report": [], "error": "" }
	if not listed.is_empty():
		added = _add_missing(host, listed, scene_path)
		if not String(added["error"]).is_empty():
			return { "error": added["error"] }

	var components := _bindable(host)
	if components.is_empty():
		warnings.append(NOTHING_TO_BIND % scene_path)
	var planned := plan(host, components)
	if not String(planned["error"]).is_empty():
		return { "error": planned["error"] }
	planned["warnings"] = warnings + planned["warnings"]
	return { "planned": planned, "added": added, "error": "" }


## Builds the blocks for the named components (snake_case class names, in the
## order given; repeats are taken once). Returns {blocks, warnings, error}: any
## name that is not exactly one child of `host` is an error and nothing is planned.
## A member already provided by an earlier component is skipped with a warning, so
## the generated script still compiles.
static func plan(host: Node, components: Array) -> Dictionary:
	var blocks: Array = []
	var warnings: Array = []
	var owners := {}
	var taken := {}

	var children := _children_by_class(host)
	for component in components:
		var component_name := String(component)
		if taken.has(component_name):
			continue
		taken[component_name] = true

		var error := _component_error(host, children, component_name)
		if not error.is_empty():
			return { "blocks": [], "warnings": [], "error": error }
		var child: Node = children[component_name][0]
		_plan_component(child, owners, blocks, warnings)

	return { "blocks": blocks, "warnings": warnings, "error": "" }


## snake_case class names of the direct children of `host` that have a script with
## a class_name and are not state machines, sorted: what can be named in
## `components`.
static func candidates(host: Node) -> Array:
	var names := _bindable(host)
	names.sort()
	return names


## Finds the scene of an actor: `<actor>.tscn` inside DogSettings.actor_dir(actor,
## folder), at exactly that path (no searching below it). The actor, the folder and
## the folder settings are checked first. Returns {path, error}.
static func find_scene(actor: String, folder := "") -> Dictionary:
	var error := _scene_input_error(actor, folder)
	if not error.is_empty():
		return _scene_error(error)

	var scene := "%s/%s.tscn" % [DogSettings.actor_dir(actor, folder), actor]
	if not FileAccess.file_exists(scene):
		return _scene_error(SCENE_NOT_FOUND % scene)
	return { "path": scene, "error": "" }


## Adds to `host` (in memory) a node for each listed component that is a class of
## the project but not a child yet, so plan finds it, and the same nodes to the text
## of the scene. Returns {source, report, error}: `source` is the new scene text ("" =
## nothing added) and `report` one "add node <Class>" line per node.
static func _add_missing(host: Node, components: Array, scene_path: String) -> Dictionary:
	var children := _children_by_class(host)
	var source := ""
	var report: Array[String] = []
	for component in components:
		var component_name := String(component)
		var script := class_script(component_name)
		if script != null and is_machine(script):
			return _added_error(MACHINE_COMPONENT % component_name)
		if children.has(component_name):
			continue
		if script == null:
			return _added_error(UNKNOWN_CLASS % component_name)
		var node := ClassDB.instantiate(script.get_instance_base_type()) as Node
		if node == null:
			return _added_error(NOT_A_NODE % [component_name, scene_path.get_file()])

		if source.is_empty():
			source = _read_text(scene_path)
		var edit := add_class_node(source, script)
		var edit_error: String = edit["error"]
		if not edit_error.is_empty():
			node.free()
			return _added_error(SCENE_EDIT_FAILED % [scene_path.get_file(), edit_error])
		source = edit["source"]

		node.set_script(script)
		node.name = script.get_global_name()
		host.add_child(node)
		children[component_name] = [node]
		report.append("add node %s" % node.name)
	return { "source": source, "report": report, "error": "" }


static func _added_error(message: String) -> Dictionary:
	return { "source": "", "report": [], "error": message }


## Loads the scene and checks its root script. Returns {host, path, error}:
## `host` is null on error, otherwise the caller must free it.
static func _load_host(scene_path: String) -> Dictionary:
	var packed := ResourceLoader.load(
		scene_path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE,
	) as PackedScene
	if packed == null:
		return { "host": null, "path": "", "error": COULD_NOT_LOAD % scene_path }
	var host := packed.instantiate()
	if host == null:
		return { "host": null, "path": "", "error": COULD_NOT_INSTANTIATE % scene_path }

	var host_script := host.get_script() as Script
	var error := ""
	if host_script == null:
		error = NO_HOST_SCRIPT % scene_path
	elif host_script.resource_path.is_empty() or host_script.resource_path.contains("::"):
		error = BUILT_IN_SCRIPT % scene_path
	if not error.is_empty():
		host.free()
		return { "host": null, "path": "", "error": error }
	return { "host": host, "path": host_script.resource_path, "error": "" }


## Reads the host script and merges the planned blocks into it.
static func _merge_into(
	host_path: String,
	scene_path: String,
	planned: Dictionary,
	mode: DogScriptMerge.Mode,
) -> Result:
	var file := FileAccess.open(host_path, FileAccess.READ)
	if file == null:
		return _failure(COULD_NOT_READ % host_path)
	var original := file.get_as_text()
	file.close()

	var merged := DogScriptMerge.merge(original, planned["blocks"], mode)
	var result := Result.new()
	result.path = host_path
	result.scene = scene_path
	result.original = original
	result.source = merged["source"]
	result.report.assign(merged["report"])
	result.warnings.assign(planned["warnings"])
	result.blocks = planned["blocks"]
	result.error = merged["error"]
	return result


## What the automatic mode binds: the classes of `_bindable` children, in child
## order.
static func _bindable(host: Node) -> Array:
	var names := []
	var children := _children_by_class(host)
	for key in children:
		if not is_machine(children[key][0].get_script() as Script):
			names.append(key)
	return names


## Why `component_name` can't be planned for `host`, or "".
static func _component_error(host: Node, children: Dictionary, component_name: String) -> String:
	var found_script := class_script(component_name)
	if found_script != null and is_machine(found_script):
		return MACHINE_COMPONENT % component_name

	if not children.has(component_name):
		if found_script == null:
			return UNKNOWN_CLASS % component_name
		var available := ", ".join(candidates(host))
		return NOT_A_CHILD % [component_name, host.name, available]

	var nodes: Array = children[component_name]
	if nodes.size() > 1:
		var node_names := PackedStringArray()
		for node in nodes:
			node_names.append(str(node.name))
		return REPEATED_COMPONENT % [component_name, host.name, ", ".join(node_names)]
	return ""


## Adds the reference, signals and forwarding funcs of `child` to `blocks`.
static func _plan_component(
	child: Node,
	owners: Dictionary,
	blocks: Array,
	warnings: Array,
) -> void:
	var script := child.get_script() as Script
	var class_text := String(script.get_global_name())
	var node_name := str(child.name)
	var var_name := DogScriptRender.var_name(class_text, node_name)
	owners["var " + var_name] = node_name
	blocks.append(DogScriptRender.ref_block(var_name, class_text, node_name))

	for info in script.get_script_signal_list():
		var signal_name := String(info["name"])
		if not _claim(owners, "signal", signal_name, node_name, warnings):
			continue
		blocks.append(DogScriptRender.signal_block(info))
		blocks.append(DogScriptRender.connect_block(var_name, signal_name))

	for method in script.get_script_method_list():
		if (int(method["flags"]) & METHOD_FLAG_STATIC) != 0:
			continue
		if not _claim(owners, "func", String(method["name"]), node_name, warnings):
			continue
		blocks.append(DogScriptRender.func_block(var_name, method))


## Why `actor` or `folder` can't be used, or "". Checked in that order, then the
## folder settings the path is built from.
static func _scene_input_error(actor: String, folder: String) -> String:
	var error := DogNames.actor_error(actor)
	if error.is_empty():
		error = DogNames.folder_error(folder)
	if error.is_empty():
		error = DogSettings.error()
	return error


## {snake_case class name: [child nodes]} for the direct children of `host`, in
## child order. Children without a script, or without a class_name, can't be named.
static func _children_by_class(host: Node) -> Dictionary:
	var result := {}
	for child in host.get_children():
		var script := child.get_script() as Script
		if script == null:
			continue
		var class_name_text := String(script.get_global_name())
		if class_name_text.is_empty():
			continue
		var key := class_name_text.to_snake_case()
		if not result.has(key):
			result[key] = []
		result[key].append(child)
	return result


## The script of the project class named `snake_name`, or null when none matches.
static func class_script(snake_name: String) -> Script:
	for entry in ProjectSettings.get_global_class_list():
		if String(entry["class"]).to_snake_case() == snake_name:
			return load(String(entry["path"])) as Script
	return null


## Adds a direct child of the root to the scene text `source` for the class of
## `script`: named and typed after it, with the script (and its uid, when it has one)
## attached. Returns DogSceneEdit.add_node's {source, error}.
static func add_class_node(source: String, script: Script) -> Dictionary:
	var path := script.resource_path
	var uid := ""
	var uid_id := ResourceLoader.get_resource_uid(path)
	if uid_id != ResourceUID.INVALID_ID:
		uid = ResourceUID.id_to_text(uid_id)
	var node_name := String(script.get_global_name())
	return DogSceneEdit.add_node(source, node_name, script.get_instance_base_type(), path, uid)


## Whether `script` is DogMachine or extends it, directly or not.
static func is_machine(script: Script) -> bool:
	var current := script
	while current != null:
		if current.get_global_name() == &"DogMachine":
			return true
		current = current.get_base_script()
	return false


static func _claim(
	owners: Dictionary,
	kind: String,
	member: String,
	node_name: String,
	warnings: Array,
) -> bool:
	if not DogScriptRender.is_public(member):
		return false
	var key := "%s %s" % [kind, member]
	if owners.has(key):
		if owners[key] != node_name:
			warnings.append(MEMBER_SKIPPED % [kind, member, node_name, owners[key]])
		return false
	owners[key] = node_name
	return true


static func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


static func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


static func _failure(message: String) -> Result:
	var result := Result.new()
	result.error = message
	return result


static func _scene_error(message: String) -> Dictionary:
	return { "path": "", "error": message }


## What to generate. `components` are snake_case class names (prefix / suffix
## already applied) to add to the scene when it does not have them; everything in the
## scene is bound either way. With `write` false, build runs but nothing is written.
class Options:
	var actor := ""
	var components: Array = []
	var folder := ""
	var mode := DogScriptMerge.Mode.ADD
	var write := true


## What build and generate return. `error` is empty on success.
class Result:
	## The host script: the root script of `scene`.
	var path := ""
	var scene := ""
	## The host script as read, and as merged.
	var original := ""
	var source := ""
	## The scene as read, and with the added components; both empty when nothing is
	## added.
	var scene_original := ""
	var scene_source := ""
	## What build plans, one line per item ("add node DogJump2D", "add func jump", ...).
	var report: Array[String] = []
	var warnings: Array[String] = []
	## The planned blocks (see DogScriptMerge).
	var blocks: Array = []
	var error := ""
