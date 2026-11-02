@tool
class_name DogActorGenerator
extends RefCounted
## Creates an actor from a scene template: a copy of the template's scene and script
## (never an instance of them), renamed after the actor.
##
## A template is a PascalCase folder `<Template>/` holding `<Template>.tscn` and
## `<Template>.gd`, the root of the scene using that script. It is named like any
## class name: snake_case, PascalCase (literal) or hybrid (character_body_2d,
## CharacterBody2D), and looked for by its PascalCase name in TEMPLATE_ROOTS, in
## order, so the project's folder wins over the addon's. Both files are read as text;
## nothing but the actor is copied into the project.
##
## The script gets `class_name <Actor>` (see DogScriptHeader.set_class_name). The
## scene loses its uid, its root is renamed to <Actor> and the root's script points
## to the actor's script, without uid: Godot writes the new uids when it saves them.
## The rest of both texts is kept as is. A template script needs an `extends` line.
##
## `base` changes the class the actor extends, a class name as typed (see
## DogNames.to_pascal): the script's `extends` names it, and the root of the scene gets
## the native type at the end of its chain (a scene can't use a class_name as a node
## type). It must be a node class, native or global, and <Actor> must not be a class
## already (except the actor's own script, for force).
##
## The actor goes in its directory (see DogSettings.actor_dir). When both its scene
## and its script are there, the actor is kept: nothing is checked against the
## template and nothing is written, and asking to change it (a template or a base) is
## an error. When only one of them is there, it is an error. Force recreates both
## from the template.

const DEFAULT_TEMPLATE := "CharacterBody2D"
const TEMPLATE_ROOTS: PackedStringArray = [
	"res://scene_templates",
	"res://addons/leash/scene_templates",
]
# Error messages
const INVALID_TEMPLATE := (
	"'%s' is not a valid template name (snake_case or PascalCase, e.g. CharacterBody2D)."
)
const TEMPLATE_NOT_FOUND := "template '%s' not found in %s."
const TEMPLATE_FILE_MISSING := "template '%s' has no %s."
const TEMPLATE_EDIT_FAILED := "%s: %s"
const WRONG_TEMPLATE_SCRIPT := "%s: the root node uses %s, not the template's own %s."
const ALREADY_EXISTS := "the actor already has %s (-f recreates it from the template)."
const KEPT_CHANGE := (
	"the actor already exists, so %s can't change it: -f recreates it from the template,"
	+ " destroying the current scene and script."
)
const NATIVE_CLASS_EXISTS := "class '%s' already exists in Godot: name the actor something else."
const GLOBAL_CLASS_EXISTS := "class '%s' already exists in %s: name the actor something else."
const NOT_A_NODE_CLASS := "'%s' is not a node class."
const COULD_NOT_CREATE := "could not create '%s' (error %d)."
const COULD_NOT_WRITE := "could not write '%s' (error %d)."


## build + write. Nothing is written when build fails or keeps the actor.
static func generate(options: Options) -> Result:
	var result := build(options)
	if not result.error.is_empty() or result.kept:
		return result

	result.error = _write_all(result)
	DogEditor.refresh(PackedStringArray(result.written))
	return result


## Everything except writing: checks the names, checks whether the actor is there
## (kept, unless force), finds and checks the template, checks the classes and
## renders the scene and the script. Returns a Result whose `scene_source` and
## `script_source` are what generate writes, or with `kept` set.
static func build(options: Options) -> Result:
	var result := Result.new()
	var template := options.template if not options.template.is_empty() else DEFAULT_TEMPLATE
	result.error = _input_error(options, template)
	if not result.error.is_empty():
		return result
	template = DogNames.to_pascal(template)

	var dir := DogSettings.actor_dir(options.actor, options.folder)
	result.scene_path = dir.path_join(options.actor + ".tscn")
	result.script_path = dir.path_join(options.actor + ".gd")
	if not options.force:
		result.error = _existing_error(result, options)
		if not result.error.is_empty() or result.kept:
			return result

	result.error = _find_template(result, template)
	if not result.error.is_empty():
		return result

	result.actor_class = DogNames.to_pascal(options.actor)
	result.error = _class_error(result, options)
	if not result.error.is_empty():
		return result

	var base := DogNames.to_pascal(options.base)
	result.error = _render_scene(result, base)
	if not result.error.is_empty():
		return result
	result.error = _render_script(result, base)
	return result


## Why `base` (a class name as typed, see DogNames.to_pascal) can't be extended by an
## actor, or "": it must be a node class, native or global.
static func base_error(base: String) -> String:
	if not DogNames.is_valid_class_token(base):
		return DogNames.INVALID_CLASS % base
	var pascal := DogNames.to_pascal(base)
	return "" if DogClasses.is_node(pascal) else NOT_A_NODE_CLASS % pascal


## Why the actor, the folder, the template or the folder settings can't be used,
## or "".
static func _input_error(options: Options, template: String) -> String:
	var error := DogNames.actor_error(options.actor)
	if error.is_empty():
		error = DogNames.folder_error(options.folder)
	if error.is_empty() and not DogNames.is_valid_class_token(template):
		error = INVALID_TEMPLATE % template
	if error.is_empty():
		error = DogSettings.error()
	return error


## Fills result.template_scene and template_script from the first template root
## that has a `template` folder (`template` in PascalCase). Returns an error, or "".
static func _find_template(result: Result, template: String) -> String:
	var searched: Array[String] = []
	for root in TEMPLATE_ROOTS:
		var dir := root.path_join(template)
		searched.append(dir)
		if not DirAccess.dir_exists_absolute(dir):
			continue
		result.template_scene = dir.path_join(template + ".tscn")
		result.template_script = dir.path_join(template + ".gd")
		for path in [result.template_scene, result.template_script]:
			if not FileAccess.file_exists(path):
				return TEMPLATE_FILE_MISSING % [dir, path.get_file()]
		return ""
	return TEMPLATE_NOT_FOUND % [template, ", ".join(searched)]


## Sets result.kept when both actor files exist. Returns ALREADY_EXISTS naming the
## one that exists when the other is missing, KEPT_CHANGE when the actor is kept but
## the options ask to change it, or "".
static func _existing_error(result: Result, options: Options) -> String:
	var existing: Array[String] = []
	for path in [result.scene_path, result.script_path]:
		if FileAccess.file_exists(path):
			existing.append(path)
	if existing.size() == 1:
		return ALREADY_EXISTS % existing[0]
	if existing.is_empty():
		return ""

	result.kept = true
	if not options.template.is_empty():
		return KEPT_CHANGE % ("template '%s'" % options.template)
	if not options.base.is_empty():
		return KEPT_CHANGE % "--extends"
	return ""


## Why the actor's class can't be created, or "": result.actor_class must not be a
## class yet (unless it is the actor's own script) and options.base must be a node
## class. Fills result.native_type.
static func _class_error(result: Result, options: Options) -> String:
	if ClassDB.class_exists(result.actor_class):
		return NATIVE_CLASS_EXISTS % result.actor_class
	var owner_path := DogClasses.global_path(result.actor_class)
	if not owner_path.is_empty() and owner_path != result.script_path:
		return GLOBAL_CLASS_EXISTS % [result.actor_class, owner_path]

	if options.base.is_empty():
		return ""
	var error := base_error(options.base)
	if error.is_empty():
		result.native_type = DogClasses.native_base(DogNames.to_pascal(options.base))
	return error


## The template scene without uid, its typed root renamed to result.actor_class,
## pointing to result.script_path and, with a `base`, of type result.native_type.
## Returns an error, or "".
static func _render_scene(result: Result, base: String) -> String:
	var source := FileAccess.get_file_as_string(result.template_scene)
	var file := result.template_scene.get_file()
	var type_query := DogSceneEdit.root_type(source)
	var script_query := DogSceneEdit.root_script_path(source)
	for query in [type_query, script_query]:
		var query_error: String = query["error"]
		if not query_error.is_empty():
			return TEMPLATE_EDIT_FAILED % [file, query_error]
	var used: String = script_query["path"]
	if used != result.template_script:
		return WRONG_TEMPLATE_SCRIPT % [file, used, result.template_script.get_file()]

	var edit := DogSceneEdit.strip_uid(source)
	edit = DogSceneEdit.rename_root(edit["source"], result.actor_class)
	edit = DogSceneEdit.retarget_root_script(edit["source"], result.script_path)
	if not base.is_empty():
		edit = DogSceneEdit.set_root_type(edit["source"], result.native_type)
	var edit_error: String = edit["error"]
	if not edit_error.is_empty():
		return TEMPLATE_EDIT_FAILED % [file, edit_error]
	result.scene_source = edit["source"]
	return ""


## The template script with `class_name <result.actor_class>` and, with a `base`,
## `extends <base>`. A template script without extends is an error either way.
## Returns an error, or "".
static func _render_script(result: Result, base: String) -> String:
	var source := FileAccess.get_file_as_string(result.template_script)
	var edit := { "source": source, "error": "" }
	if DogScriptHeader.declared_extends(source).is_empty():
		edit["error"] = DogScriptHeader.NO_EXTENDS
	elif not base.is_empty():
		edit = DogScriptHeader.set_extends(source, base)
	if String(edit["error"]).is_empty():
		edit = DogScriptHeader.set_class_name(edit["source"], result.actor_class)
	var edit_error: String = edit["error"]
	if not edit_error.is_empty():
		return TEMPLATE_EDIT_FAILED % [result.template_script.get_file(), edit_error]
	result.script_source = edit["source"]
	return ""


## Creates the actor's directory, then writes the scene and the script, in that
## order, adding each to result.written. Stops at the first failure. Returns an
## error, or "".
static func _write_all(result: Result) -> String:
	var dir := result.scene_path.get_base_dir()
	var make_error := DirAccess.make_dir_recursive_absolute(dir)
	if make_error != OK:
		return COULD_NOT_CREATE % [dir, make_error]
	var files := {
		result.scene_path: result.scene_source,
		result.script_path: result.script_source,
	}
	for path in files:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return COULD_NOT_WRITE % [path, FileAccess.get_open_error()]
		file.store_string(files[path])
		file.close()
		result.written.append(path)
	return ""


## What to create. `template` "" means DEFAULT_TEMPLATE; `force` overwrites an
## existing scene and script. `base` is the class the actor extends ("" = the
## template's). Both are class names as typed (see DogNames.to_pascal).
class Options:
	var actor := ""
	var template := ""
	var folder := ""
	var base := ""
	var force := false


class Result:
	var error := ""
	## Set by build when both actor files exist: nothing is rendered or written.
	var kept := false
	## The actor's class (PascalCase actor) and, with a base, the root's node type.
	var actor_class := ""
	var native_type := ""
	## The template's files, once found.
	var template_scene := ""
	var template_script := ""
	## The actor's files and, filled by build, their text.
	var scene_path := ""
	var script_path := ""
	var scene_source := ""
	var script_source := ""
	## Filled by generate: the paths written, in order.
	var written: Array[String] = []
