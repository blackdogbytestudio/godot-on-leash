@tool
class_name DogActorGenerator
extends RefCounted
## Creates an actor from a scene template: a copy of the template's scene and script
## (never an instance of them), renamed after the actor.
##
## A template is a folder `<template>/` holding `<template>.tscn` and `<template>.gd`,
## the root of the scene using that script. It is looked for in TEMPLATE_ROOTS, in
## order, so the project's folder wins over the addon's. Both files are read as text;
## nothing but the actor is copied into the project.
##
## The script gets `class_name <Actor>` (see DogScriptHeader.set_class_name). The
## scene loses its uid, its root is renamed to <Actor> and the root's script points
## to the actor's script, without uid: Godot writes the new uids when it saves them.
## The rest of both texts is kept as is.
##
## The actor goes in its directory (see DogSettings.actor_dir). When its scene or its
## script is already there, nothing is written; force recreates both from the template.

const DEFAULT_TEMPLATE := "character_body_2d"
const TEMPLATE_ROOTS: PackedStringArray = [
	"res://scene_templates",
	"res://addons/leash/scene_templates",
]
# Error messages
const INVALID_TEMPLATE := "'%s' is not a valid template name (use snake_case)."
const TEMPLATE_NOT_FOUND := "template '%s' not found in %s."
const TEMPLATE_FILE_MISSING := "template '%s' has no %s."
const TEMPLATE_EDIT_FAILED := "%s: %s"
const WRONG_TEMPLATE_SCRIPT := "%s: the root node uses %s, not the template's own %s."
const ALREADY_EXISTS := "the actor already has %s (-f recreates it from the template)."
const COULD_NOT_CREATE := "could not create '%s' (error %d)."
const COULD_NOT_WRITE := "could not write '%s' (error %d)."


## build + write. Nothing is written when build fails.
static func generate(options: Options) -> Result:
	var result := build(options)
	if not result.error.is_empty():
		return result

	result.error = _write_all(result)
	DogEditor.refresh(PackedStringArray(result.written))
	return result


## Everything except writing: checks the names, finds and checks the template,
## checks that the actor is not there yet (unless force) and renders the scene and
## the script. Returns a Result whose `scene_source` and `script_source` are what
## generate writes.
static func build(options: Options) -> Result:
	var result := Result.new()
	var template := options.template if not options.template.is_empty() else DEFAULT_TEMPLATE
	result.error = _input_error(options, template)
	if not result.error.is_empty():
		return result

	result.error = _find_template(result, template)
	if not result.error.is_empty():
		return result

	var dir := DogSettings.actor_dir(options.actor, options.folder)
	result.scene_path = dir.path_join(options.actor + ".tscn")
	result.script_path = dir.path_join(options.actor + ".gd")
	if not options.force:
		result.error = _existing_error(result)
		if not result.error.is_empty():
			return result

	var actor_class := DogNames.to_pascal(options.actor)
	result.error = _render_scene(result, actor_class)
	if not result.error.is_empty():
		return result
	result.error = _render_script(result, actor_class)
	return result


## Why the actor, the folder, the template or the folder settings can't be used,
## or "".
static func _input_error(options: Options, template: String) -> String:
	var error := DogNames.actor_error(options.actor)
	if error.is_empty():
		error = DogNames.folder_error(options.folder)
	if error.is_empty() and not DogNames.is_valid_name(template):
		error = INVALID_TEMPLATE % template
	if error.is_empty():
		error = DogSettings.error()
	return error


## Fills result.template_scene and template_script from the first template root
## that has a `template` folder. Returns an error, or "".
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


## ALREADY_EXISTS naming the actor files that exist, or "".
static func _existing_error(result: Result) -> String:
	var existing: Array[String] = []
	for path in [result.scene_path, result.script_path]:
		if FileAccess.file_exists(path):
			existing.append(path)
	return ALREADY_EXISTS % " and ".join(existing) if not existing.is_empty() else ""


## The template scene without uid, its typed root renamed to `actor_class` and
## pointing to result.script_path. Returns an error, or "".
static func _render_scene(result: Result, actor_class: String) -> String:
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
	edit = DogSceneEdit.rename_root(edit["source"], actor_class)
	edit = DogSceneEdit.retarget_root_script(edit["source"], result.script_path)
	var edit_error: String = edit["error"]
	if not edit_error.is_empty():
		return TEMPLATE_EDIT_FAILED % [file, edit_error]
	result.scene_source = edit["source"]
	return ""


## The template script with `class_name <actor_class>`. Returns an error, or "".
static func _render_script(result: Result, actor_class: String) -> String:
	var source := FileAccess.get_file_as_string(result.template_script)
	var edit := DogScriptHeader.set_class_name(source, actor_class)
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
## existing scene and script.
class Options:
	var actor := ""
	var template := ""
	var folder := ""
	var force := false


class Result:
	var error := ""
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
