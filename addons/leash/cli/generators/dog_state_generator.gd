@tool
class_name DogStateGenerator
extends RefCounted
## Builds actor state scripts from the leash script_templates.
##
## The actor base is created from class.gd (its own enter/exit/update
## wrappers); every tree node is created from state.gd, extending its
## parent state's class. Existing files are kept unless force is set.
##
## The actor's scene is required: `<actor>.tscn` inside the actor's directory (see
## DogSettings.actor_dir), with a saved .gd script on its root. Its machine is the
## direct child whose script is the machine class of `type` (see FAMILIES); when the
## root has none, a node named after the class is added to the scene. A machine of
## another type, or two of this one, is an error. Everything is checked before any
## file is written.
##
## FORCE puts things back to factory: the whole `states/` folder of the actor is
## deleted (only that computed folder, see is_safe_states_dir), the states are
## recreated and the host script is rewritten below its header. The scene is left
## as it is.

const STATES_DIR := "states"
const TEMPLATE_ROOTS: PackedStringArray = [
	"res://script_templates",
	"res://addons/leash/script_templates",
]
const ACTOR_TEMPLATE := "class.gd"
const NODE_TEMPLATE := "state.gd"
## The only supported machines: one row per `type`. `machine` is the class_name
## of the machine node the host must have as a direct child.
const FAMILIES := {
	"fsm": { "dir": "DogFSMState", "base": "DogFSMState", "machine": "DogFSM" },
	"pda": { "dir": "DogPDAState", "base": "DogPDAState", "machine": "DogPDA" },
	"hfsm": { "dir": "DogHFSMState", "base": "DogHFSMState", "machine": "DogHFSM" },
	"hpda": { "dir": "DogHPDAState", "base": "DogHPDAState", "machine": "DogHPDA" },
}
# Error messages
const COULD_NOT_DELETE := "could not delete '%s' (error %d)."
const COULD_NOT_CREATE := "could not create '%s' (error %d)."
const COULD_NOT_WRITE := "could not write '%s' (error %d)."
const COULD_NOT_LOAD := "could not load %s."
const INITIAL_NOT_IN_TREE := "--initial '%s' is not in the tree. states: %s."
const TEMPLATE_DIR_NOT_FOUND := "template folder '%s' not found."
const TEMPLATE_MISSING := "template '%s' is missing or empty."
const UNSAFE_DELETE := "refusing to delete '%s': not an actor states folder inside %s."
const HOST_MERGE_FAILED := "%s: %s."
const NO_HOST_SCRIPT := "the root node of %s has no script: attach one in Godot first."
const BUILT_IN_SCRIPT := "the script of %s is built into the scene: save it as a .gd file first."
const OTHER_MACHINE := "%s already has a machine of another type: %s (this type needs a %s)."
const NO_MACHINE_CLASS := "no class %s in the project."
const SCENE_EDIT_FAILED := "%s: %s"
const MANY_MACHINES := "more than one %s child in %s: %s."
const HOST_CLASS_MISMATCH := "states cast host as %s, but %s has no class_name %s"
const HOST_CLASS_FOUND := " (found: %s)"


## build + write. Nothing is written when build fails.
static func generate(options: Options) -> Result:
	var result := build(options)
	if not result.error.is_empty():
		return result

	if result.scene_source != result.scene_original:
		var scene_error := _write_text(result.scene, result.scene_source)
		if scene_error != OK:
			result.error = COULD_NOT_WRITE % [result.scene, scene_error]
			return result

	if not result.delete_dir.is_empty():
		var remove_error := _remove_dir(result.delete_dir)
		if remove_error != OK:
			result.error = COULD_NOT_DELETE % [result.delete_dir, remove_error]
			return result

	if not result.files.is_empty():
		var dir := output_dir(options.folder, options.actor)
		var make_error := DirAccess.make_dir_recursive_absolute(dir)
		if make_error != OK:
			result.error = COULD_NOT_CREATE % [dir, make_error]
			return result
	for path in result.files:
		var write_error := _write_text(path, result.files[path])
		if write_error != OK:
			result.error = COULD_NOT_WRITE % [path, write_error]
			return result
		result.written.append(path)

	if result.host_source != result.host_original:
		var host_error := _write_text(result.host_path, result.host_source)
		if host_error != OK:
			result.error = COULD_NOT_WRITE % [result.host_path, host_error]
			return result

	DogEditor.refresh(_written_paths(result))
	return result


## Everything except writing: checks the scene (adding the machine node when it is
## missing), picks the initial state, renders the state files that are missing (all
## of them with FORCE) and merges the machine plumbing into the host script. Returns
## a Result whose `scene_source`, `files` and `host_source` are what generate writes.
static func build(options: Options) -> Result:
	var result := Result.new()
	var family: Dictionary = FAMILIES[options.type]

	result.error = _pick_initial(result, options)
	if not result.error.is_empty():
		return result

	var template_dir := _find_template_dir(family["dir"])
	if template_dir.is_empty():
		result.error = TEMPLATE_DIR_NOT_FOUND % family["dir"]
		return result

	_inspect_scene(result, options, family["machine"])
	if not result.error.is_empty():
		return result

	var dropped_files: Array[String] = []
	result.error = _plan_force(result, options, dropped_files)
	if not result.error.is_empty():
		return result

	result.error = _plan_states(result, options, template_dir, family["base"])
	if not result.error.is_empty():
		return result

	result.error = _merge_host(result, options, family["machine"], dropped_files)
	return result


## True only for `<root>/<actor dir>/states`: inside `root`, no `..`, with at
## least one folder between the root and `states`.
static func is_safe_states_dir(dir: String, root: String = DogSettings.ROOT) -> bool:
	var base := root.trim_suffix("/") + "/"
	if not dir.begins_with(base):
		return false
	var relative := dir.trim_prefix(base)
	if not relative.ends_with("/" + STATES_DIR):
		return false
	var actor_dir := relative.trim_suffix("/" + STATES_DIR)
	for part in actor_dir.split("/"):
		if part.is_empty() or part == "." or part == "..":
			return false
	return true


## Every file below `dir`, relative to it, sorted.
static func _files_below(dir: String, prefix := "") -> Array[String]:
	var found: Array[String] = []
	var access := DirAccess.open(dir)
	if access == null:
		return found
	access.include_hidden = true
	for file in access.get_files():
		found.append(prefix + file)
	for sub in access.get_directories():
		found.append_array(_files_below(dir.path_join(sub), prefix + sub + "/"))
	found.sort()
	return found


static func _remove_dir(dir: String) -> Error:
	var access := DirAccess.open(dir)
	if access == null:
		return DirAccess.get_open_error()
	access.include_hidden = true
	for sub in access.get_directories():
		var sub_error := _remove_dir(dir.path_join(sub))
		if sub_error != OK:
			return sub_error
	for file in access.get_files():
		var file_error := access.remove(file)
		if file_error != OK:
			return file_error
	return DirAccess.remove_absolute(dir)


## The deepest state; the first declared one on a tie.
static func default_initial(tree: DogStateTree) -> String:
	var best: DogStateTree.StateNode = null
	for node in tree.nodes:
		if best == null or node.depth > best.depth:
			best = node
	return best.name if best != null else ""


## The machine plumbing for the host script, as DogScriptMerge blocks: one
## `var <state>_state := <Actor><State>State.new()` per state (tree order), the
## `@onready` reference to the machine node, `init(<initial>_state)` in `_ready`
## and `update(delta)` at the top of `_physics_process`.
static func host_blocks(
	actor: String,
	tree: DogStateTree,
	machine_class: String,
	machine_node: String,
	initial: String
) -> Array:
	var blocks: Array = []
	for node in tree.nodes:
		blocks.append({
			"kind": "var",
			"name": node.name + "_state",
			"text": "var %s_state := %s.new()" % [node.name, state_class(actor, node.name)],
		})
	var machine_var := DogScriptRender.var_name(machine_class, machine_node)
	blocks.append(DogScriptRender.ref_block(machine_var, machine_class, machine_node))
	blocks.append({
		"kind": "func_line",
		"func": "_ready",
		"name": machine_var + ".init",
		"match": machine_var + ".init(",
		"text": "\t%s.init(%s_state)" % [machine_var, initial],
	})
	blocks.append({
		"kind": "func_line",
		"func": "_physics_process",
		"name": machine_var + ".update",
		"match": machine_var + ".update(",
		"text": "\t%s.update(delta)" % machine_var,
	})
	return blocks


## Where the states of an actor go: the `states` folder of its directory.
static func output_dir(folder: String, actor: String) -> String:
	return DogSettings.actor_dir(actor, folder).path_join(STATES_DIR)


## Fills result.scene, host_path, machine_node, warnings and, when the machine is
## missing, scene_source and report; or result.error.
static func _inspect_scene(result: Result, options: Options, machine_class: String) -> void:
	var found := DogBindGenerator.find_scene(options.actor, options.folder)
	var find_error: String = found["error"]
	if not find_error.is_empty():
		result.error = find_error
		return
	var path: String = found["path"]

	var packed := ResourceLoader.load(
		path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE,
	) as PackedScene
	var host := packed.instantiate() if packed != null else null
	if host == null:
		result.error = COULD_NOT_LOAD % path
		return

	var host_script := host.get_script() as Script
	var children := _classed_children(host, machine_class)
	host.free()

	result.error = _host_error(path.get_file(), host_script, machine_class, children)
	if not result.error.is_empty():
		return

	result.scene = path
	result.host_path = host_script.resource_path
	var machines: Array = children["machines"]
	if machines.is_empty():
		result.error = _plan_machine_node(result, machine_class)
		if not result.error.is_empty():
			return
	else:
		result.machine_node = machines[0]
	_check_host_class(result, _pascal(options.actor))


## Adds a `machine_class` node to the text of result.scene: fills scene_original,
## scene_source, machine_node and the report line. Returns an error, or "".
static func _plan_machine_node(result: Result, machine_class: String) -> String:
	var script := DogBindGenerator.class_script(machine_class.to_snake_case())
	if script == null:
		return NO_MACHINE_CLASS % machine_class
	result.scene_original = _read_text(result.scene)
	var edit := DogBindGenerator.add_class_node(result.scene_original, script)
	var edit_error: String = edit["error"]
	if not edit_error.is_empty():
		return SCENE_EDIT_FAILED % [result.scene.get_file(), edit_error]
	result.scene_source = edit["source"]
	result.machine_node = machine_class
	result.report.append("add node %s" % machine_class)
	return ""


## The machines among the direct children of `host`: {"machines": names of the
## ones whose class is `machine_class`, "others": "Name (Class)" of the machines of
## any other class}.
static func _classed_children(host: Node, machine_class: String) -> Dictionary:
	var machines: Array[String] = []
	var others: Array[String] = []
	for child in host.get_children():
		var script := child.get_script() as Script
		var klass := String(script.get_global_name()) if script != null else ""
		if klass.is_empty():
			continue
		if klass == machine_class:
			machines.append(child.name)
		elif DogBindGenerator.is_machine(script):
			others.append("%s (%s)" % [child.name, klass])
	return { "machines": machines, "others": others }


## Why the scene's root can't host the states, or "".
static func _host_error(
	scene_file: String,
	host_script: Script,
	machine_class: String,
	children: Dictionary,
) -> String:
	if host_script == null:
		return NO_HOST_SCRIPT % scene_file
	var host_path := host_script.resource_path
	if host_path.is_empty() or host_path.contains("::"):
		return BUILT_IN_SCRIPT % scene_file

	var machines: Array = children["machines"]
	var others: Array = children["others"]
	if machines.is_empty() and not others.is_empty():
		return OTHER_MACHINE % [scene_file, ", ".join(others), machine_class]
	if machines.size() > 1:
		return MANY_MACHINES % [machine_class, scene_file, ", ".join(machines)]
	return ""


## Warns when the host script doesn't declare `class_name <host_class>`.
static func _check_host_class(result: Result, host_class: String) -> void:
	var found_class := _declared_class_name(_read_text(result.host_path))
	if found_class == host_class:
		return
	var warning := HOST_CLASS_MISMATCH % [host_class, result.host_path.get_file(), host_class]
	if not found_class.is_empty():
		warning += HOST_CLASS_FOUND % found_class
	result.warnings.append(warning)


## The `class_name` written in `source`, or "".
static func _declared_class_name(source: String) -> String:
	var re := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")
	var found := re.search(source)
	return found.get_string(1) if found != null else ""


static func file_name(actor: String, node: String = "") -> String:
	if node.is_empty():
		return "%s_state.gd" % actor
	return "%s_%s_state.gd" % [actor, node]


static func state_class(actor: String, node: String = "") -> String:
	return "%s%sState" % [_pascal(actor), _pascal(node)]


## result.initial is --initial or default_initial. Returns an error, or "".
static func _pick_initial(result: Result, options: Options) -> String:
	result.initial = options.initial
	if result.initial.is_empty():
		result.initial = default_initial(options.tree)
	var state_names: Array[String] = []
	for node in options.tree.nodes:
		state_names.append(node.name)
	if result.initial not in state_names:
		return INITIAL_NOT_IN_TREE % [result.initial, ", ".join(state_names)]
	return ""


## With FORCE and an existing states folder: marks it for deletion and lists its
## files in `dropped_files`. Returns an error, or "".
static func _plan_force(result: Result, options: Options, dropped_files: Array[String]) -> String:
	var dir := output_dir(options.folder, options.actor)
	if options.mode != DogScriptMerge.Mode.FORCE or not DirAccess.dir_exists_absolute(dir):
		return ""
	if not is_safe_states_dir(dir):
		return UNSAFE_DELETE % [dir, DogSettings.ROOT]
	result.delete_dir = dir
	for file in _files_below(dir):
		dropped_files.append("drop file %s/%s" % [STATES_DIR, file])
	# Everything is recreated from the templates.
	result.skipped.clear()
	return ""


## Plans the actor base (only without --extends) and one file per tree node.
## Returns an error, or "".
static func _plan_states(
	result: Result,
	options: Options,
	template_dir: String,
	family_base: String,
) -> String:
	var base_class := _pascal(options.base) if not options.base.is_empty() else ""
	# Without --extends the actor base is the root of the hierarchy.
	if base_class.is_empty():
		var base_error := _plan_file(result, options, template_dir, "", family_base)
		if not base_error.is_empty():
			return base_error

	for node in options.tree.nodes:
		var parent := _parent_class(options.actor, node, base_class)
		var node_error := _plan_file(result, options, template_dir, node.name, parent)
		if not node_error.is_empty():
			return node_error
	return ""


## The class a tree node extends: its parent state, the --extends class for a
## root state, or the actor base.
static func _parent_class(
	actor: String,
	node: DogStateTree.StateNode,
	base_class: String,
) -> String:
	if node.depth > 0:
		return state_class(actor, node.parent)
	if not base_class.is_empty():
		return base_class
	return state_class(actor)


## Puts the rendered file of `node_name` ("" = the actor base) in result.files, or
## its path in result.skipped when it exists and force is off. Returns an error, or "".
static func _plan_file(
	result: Result,
	options: Options,
	template_dir: String,
	node_name: String,
	parent: String,
) -> String:
	var dir := output_dir(options.folder, options.actor)
	var path := dir.path_join(file_name(options.actor, node_name))
	if FileAccess.file_exists(path) and options.mode != DogScriptMerge.Mode.FORCE:
		result.skipped.append(path)
		return ""

	var template_name := ACTOR_TEMPLATE if node_name.is_empty() else NODE_TEMPLATE
	var template := template_dir.path_join(template_name)
	var source := _read_text(template)
	if source.is_empty():
		return TEMPLATE_MISSING % template

	var cls := state_class(options.actor, node_name)
	result.files[path] = _substitute(source, cls, _pascal(options.actor), parent)
	return ""


## Merges the machine plumbing into the host script. Returns an error, or "".
static func _merge_host(
	result: Result,
	options: Options,
	machine_class: String,
	dropped_files: Array[String],
) -> String:
	result.host_original = _read_text(result.host_path)
	var blocks := host_blocks(
		options.actor, options.tree, machine_class, result.machine_node, result.initial
	)
	var merged := DogScriptMerge.merge(result.host_original, blocks, options.mode)
	var merge_error: String = merged["error"]
	if not merge_error.is_empty():
		result.files.clear()
		return HOST_MERGE_FAILED % [result.host_path.get_file(), merge_error]
	result.host_source = merged["source"]
	result.report.append_array(dropped_files + Array(merged["report"]))
	return ""


static func _pascal(name: String) -> String:
	return DogNames.to_pascal(name)


static func _find_template_dir(family_dir: String) -> String:
	for root in TEMPLATE_ROOTS:
		var path := root.path_join(family_dir)
		if DirAccess.dir_exists_absolute(path):
			return path
	return ""


static func _substitute(source: String, cls: String, host: String, parent: String) -> String:
	var text := source
	text = text.replace("_CLASS_", cls)
	text = text.replace("CUSTOM_HOST", host)
	text = text.replace("CUSTOM_BASE", parent)
	text = text.replace("_BASE_", parent)
	return _strip_instructions(text)


# The templates carry "Replace 'X' with..." comments for manual use.
static func _strip_instructions(text: String) -> String:
	var kept: PackedStringArray = []
	for line in text.split("\n"):
		if line.begins_with("# Replace '"):
			continue
		kept.append(line)
	return "\n".join(kept)


static func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


static func _write_text(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK


## The state files written and, when they changed, the scene and the host script.
static func _written_paths(result: Result) -> PackedStringArray:
	var paths := PackedStringArray(result.written)
	if result.scene_source != result.scene_original:
		paths.append(result.scene)
	if result.host_source != result.host_original:
		paths.append(result.host_path)
	return paths


## What to generate. `base` is the --extends state class ("" = none) and
## `initial` the state the machine starts in ("" = default_initial).
class Options:
	var actor := ""
	var type := ""
	var folder := ""
	var base := ""
	var tree: DogStateTree
	var mode := DogScriptMerge.Mode.ADD
	var initial := ""


class Result:
	var written: Array[String] = []
	var skipped: Array[String] = []
	var warnings: Array[String] = []
	## What build plans for the scene and the host script ("add node DogHPDA",
	## "add var alive_state", ...).
	var report: Array[String] = []
	var error := ""
	var scene := ""
	var host_path := ""
	var machine_node := ""
	var initial := ""
	## Filled by build: path -> text of every state file to write.
	var files := {}
	## Filled by build with FORCE: the states folder to delete first ("" = none).
	var delete_dir := ""
	var host_original := ""
	var host_source := ""
	## The scene as read, and with the machine node added; both empty when the scene
	## already has its machine.
	var scene_original := ""
	var scene_source := ""
