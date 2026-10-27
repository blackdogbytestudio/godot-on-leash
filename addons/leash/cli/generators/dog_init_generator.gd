@tool
class_name DogInitGenerator
extends RefCounted
## Sets up a project for leash: the scaffold folders and the script templates.
##
## The folders come from the addon's config/scaffold.json (read in place, never
## copied) and are created below `root` as written there; its `scenes` is not the
## leash/generators/scenes setting. The templates are copied from the addon to
## `<root>/script_templates`, with a fresh .gdignore. Only what is missing is
## created: nothing is ever overwritten. Warns when GUT isn't installed.

const SCAFFOLD := "res://addons/leash/config/scaffold.json"
const TEMPLATE_SRC := "res://addons/leash/script_templates"
const TEMPLATE_DIR := "script_templates"
const GDIGNORE := ".gdignore"
const GUT_PLUGIN := "addons/gut/plugin.cfg"
# Error messages
const SCAFFOLD_NOT_FOUND := "scaffold not found at %s."
const SCAFFOLD_INVALID := "%s is not a JSON object of folders."
const TEMPLATES_NOT_FOUND := "script templates not found at %s."
const COULD_NOT_CREATE := "could not create '%s' (error %d)."
const COULD_NOT_COPY := "could not copy '%s' (error %d)."
const COULD_NOT_WRITE := "could not write '%s' (error %d)."
const GUT_MISSING := "GUT is not installed (no %s): the tests need it."


## build + write. Nothing is written when build fails.
static func generate(options: Options) -> Result:
	var result := build(options)
	if not result.error.is_empty():
		return result

	for dir in result.dirs:
		var make_error := DirAccess.make_dir_recursive_absolute(dir)
		if make_error != OK:
			result.error = COULD_NOT_CREATE % [dir, make_error]
			return result
	if not result.ignore.is_empty():
		var ignore_error := _write_empty(result.ignore)
		if ignore_error != OK:
			result.error = COULD_NOT_WRITE % [result.ignore, ignore_error]
			return result
	for dest in result.files:
		var copy_error := DirAccess.copy_absolute(result.files[dest], dest)
		if copy_error != OK:
			result.error = COULD_NOT_COPY % [dest, copy_error]
			return result

	_scan()
	return result


## Everything except writing: reads the scaffold, lists what is missing below
## `root` and reports each item as "create <path>" or "exist <path>".
static func build(options: Options) -> Result:
	var result := Result.new()

	var scaffold := read_scaffold(result)
	if not result.error.is_empty():
		return result
	for dir in folders(scaffold, options.root):
		_plan_dir(result, dir)

	if not options.skip_templates:
		result.error = _plan_templates(result, options.root)
		if not result.error.is_empty():
			return result

	var gut := options.root.path_join(GUT_PLUGIN)
	if not FileAccess.file_exists(gut):
		result.warnings.append(GUT_MISSING % gut)
	return result


## The scaffold as a Dictionary of folders, or {} with result.error set.
static func read_scaffold(result: Result) -> Dictionary:
	if not FileAccess.file_exists(SCAFFOLD):
		result.error = SCAFFOLD_NOT_FOUND % SCAFFOLD
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCAFFOLD))
	if not data is Dictionary:
		result.error = SCAFFOLD_INVALID % SCAFFOLD
		return {}
	return data


## Every folder of `scaffold` below `root`, parents first, in the file's order.
static func folders(scaffold: Dictionary, root: String) -> Array[String]:
	var found: Array[String] = []
	for key: String in scaffold:
		var path := root.path_join(key)
		found.append(path)
		var children: Variant = scaffold[key]
		if children is Dictionary:
			found.append_array(folders(children, path))
	return found


## Every template file below `dir`, relative to it, sorted. The .gdignore is
## left out: init writes its own.
static func template_files(dir: String = TEMPLATE_SRC, prefix := "") -> Array[String]:
	var found: Array[String] = []
	var access := DirAccess.open(dir)
	if access == null:
		return found
	for file in access.get_files():
		if file != GDIGNORE:
			found.append(prefix + file)
	for sub in access.get_directories():
		found.append_array(template_files(dir.path_join(sub), prefix + sub + "/"))
	found.sort()
	return found


## Plans the templates folder, its .gdignore and every missing template. Returns
## an error, or "".
static func _plan_templates(result: Result, root: String) -> String:
	if not DirAccess.dir_exists_absolute(TEMPLATE_SRC):
		return TEMPLATES_NOT_FOUND % TEMPLATE_SRC

	var dest_dir := root.path_join(TEMPLATE_DIR)
	_plan_dir(result, dest_dir)
	var ignore := dest_dir.path_join(GDIGNORE)
	if FileAccess.file_exists(ignore):
		result.report.append("exist %s" % ignore)
	else:
		result.ignore = ignore
		result.report.append("create %s" % ignore)

	for file in template_files():
		var dest := dest_dir.path_join(file)
		_plan_dir(result, dest.get_base_dir())
		if FileAccess.file_exists(dest):
			result.report.append("exist %s" % dest)
		else:
			result.files[dest] = TEMPLATE_SRC.path_join(file)
			result.report.append("create %s" % dest)
	return ""


## Adds `dir` to result.dirs when it's missing, once, and reports it.
static func _plan_dir(result: Result, dir: String) -> void:
	if dir in result.dirs or dir in result.existing:
		return
	if DirAccess.dir_exists_absolute(dir):
		result.existing.append(dir)
		result.report.append("exist %s" % dir)
	else:
		result.dirs.append(dir)
		result.report.append("create %s" % dir)


static func _write_empty(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.close()
	return OK


static func _scan() -> void:
	if not Engine.is_editor_hint():
		return
	var fs := EditorInterface.get_resource_filesystem()
	if fs != null and not fs.is_scanning():
		fs.scan()


## Where to set up. `root` is the project the folders, the templates and the GUT
## check are relative to; the scaffold and the templates are always read from
## the addon.
class Options:
	var root := "res://"
	var skip_templates := false


class Result:
	## "create <path>" / "exist <path>", one per folder or file, in order.
	var report: Array[String] = []
	var warnings: Array[String] = []
	var error := ""
	## Filled by build: the folders to create, parents first.
	var dirs: Array[String] = []
	## Filled by build: the folders already there.
	var existing: Array[String] = []
	## Filled by build: the .gdignore to write ("" = none).
	var ignore := ""
	## Filled by build: destination -> source of every template to copy.
	var files := {}
