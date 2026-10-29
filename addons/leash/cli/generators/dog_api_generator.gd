@tool
class_name DogApiGenerator
extends RefCounted
## Fills the root script of a scene with an API that forwards to the components
## you name (direct children of the root, found by their class_name in snake_case:
## `dog_jump_2d` -> DogJump2D): one `@onready` reference per component, a forwarding
## func per public method, and a re-declared + connected signal per public signal.
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
const NO_COMPONENTS := "no components given. components in %s: %s"
const NOT_A_CHILD := (
	"%s is not a child of %s: add the node to the scene first"
	+ " (children with a class: %s)."
)
const UNKNOWN_CLASS := "no class in the project matches '%s'."
const REPEATED_COMPONENT := "more than one %s under %s: %s. A component class must appear once."
const SCENE_NOT_FOUND := "no scene at %s (use --folder if the actor lives somewhere else)."
const MEMBER_SKIPPED := "%s %s of %s was skipped: %s already provides it"


## build + write. Nothing is written on error, when `options.write` is false, or
## when the merged source equals the file.
static func generate(options: Options) -> Result:
	var result := build(options)
	if not result.error.is_empty() or not options.write or result.source == result.original:
		return result
	var file := FileAccess.open(result.path, FileAccess.WRITE)
	if file == null:
		result.error = COULD_NOT_WRITE % result.path
		return result
	file.store_string(result.source)
	file.close()
	DogEditor.refresh(PackedStringArray([result.path]))
	return result


## Everything except the write. Returns a Result whose `source` is what generate
## writes to `path`, the host script.
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

	if options.components.is_empty():
		var message := NO_COMPONENTS % [scene_path, ", ".join(candidates(host))]
		host.free()
		return _failure(message)

	var planned := plan(host, options.components)
	host.free()
	var plan_error: String = planned["error"]
	if not plan_error.is_empty():
		return _failure(plan_error)

	return _merge_into(loaded["path"], scene_path, planned, options.mode)


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
## a class_name: what can be named in `components`.
static func candidates(host: Node) -> Array:
	var names := _children_by_class(host).keys()
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


## Why `component_name` can't be planned for `host`, or "".
static func _component_error(host: Node, children: Dictionary, component_name: String) -> String:
	if not children.has(component_name):
		if not _class_exists(component_name):
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


static func _class_exists(snake_name: String) -> bool:
	for entry in ProjectSettings.get_global_class_list():
		if String(entry["class"]).to_snake_case() == snake_name:
			return true
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


static func _failure(message: String) -> Result:
	var result := Result.new()
	result.error = message
	return result


static func _scene_error(message: String) -> Dictionary:
	return { "path": "", "error": message }


## What to generate. `components` are snake_case class names (prefix / suffix
## already applied); with `write` false, build runs but nothing is written.
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
	## What the merge did, one line per item ("add func jump", ...).
	var report: Array[String] = []
	var warnings: Array[String] = []
	## The planned blocks (see DogScriptMerge).
	var blocks: Array = []
	var error := ""
