@tool
class_name DogDestroyGenerator
extends RefCounted
## Deletes an actor, at one of three levels (see Mode):
## FILES: its scene, its script and the script's .uid, in whatever folder they are.
## STATES: the same, plus its states folder, and its directory when nothing else is
## left in it (what is left is reported, not deleted).
## ALL: its directory and everything in it, even what was added next to the files the
## commands made.
##
## The actor is in its directory (see DogSettings.actor_dir), at exactly that path (no
## searching below it), which must hold the actor's scene or its script. STATES and ALL
## delete folders, so the directory must also be named after the actor (--folder
## characters/enemies/slime, not --folder characters/enemies): a wrong --folder can't
## take the other actors with it. FILES deletes three files by their exact names, so it
## works in any folder. Nothing is moved to the trash, and nothing is looked for
## elsewhere: the scenes that instance the actor and the code that uses its class are
## left as they are, and Godot reports what is missing the next time it loads them. No
## node is removed from any scene, and tests are not touched.

enum Mode {
	FILES,
	STATES,
	ALL,
}

# Error messages
const DIR_NOT_FOUND := (
	"no actor directory at %s (use --folder if the actor lives somewhere else)."
)
const WRONG_DIR_NAME := (
	"%s is not named after the actor '%s', and -r / -f delete folders"
	+ " (--folder .../%s): nothing was deleted."
)
const NOT_AN_ACTOR := (
	"%s has neither %s nor %s: it is not the directory of '%s', nothing was deleted."
)
const COULD_NOT_READ := "could not read %s"
const COULD_NOT_DELETE := "could not delete %s (error %d)."


## build + delete, in the order build planned. Stops at the first path that can't be
## deleted: result.deleted holds what is already gone. Nothing is deleted when build
## fails.
static func generate(options: Options) -> Result:
	var result := build(options)
	if not result.error.is_empty():
		return result

	for path in result.paths:
		var error := DirAccess.remove_absolute(path)
		if error != OK:
			result.error = COULD_NOT_DELETE % [path, error]
			break
		result.deleted.append(path)
	DogEditor.refresh()
	return result


## Everything except the deletes: checks the names and the folder settings, finds the
## actor's directory, checks that it holds the actor's scene or script (and that it is
## named after the actor, unless the mode is FILES) and plans what to delete. Returns a
## Result whose `paths` are what generate deletes.
static func build(options: Options) -> Result:
	var result := Result.new()
	result.error = _input_error(options)
	if not result.error.is_empty():
		return result

	result.dir = DogSettings.actor_dir(options.actor, options.folder)
	if options.mode != Mode.FILES and result.dir.get_file() != options.actor:
		result.error = WRONG_DIR_NAME % [result.dir, options.actor, options.actor]
		return result
	if not DirAccess.dir_exists_absolute(result.dir):
		result.error = DIR_NOT_FOUND % result.dir
		return result

	var scene := result.dir.path_join(options.actor + ".tscn")
	var script := result.dir.path_join(options.actor + ".gd")
	if not FileAccess.file_exists(scene) and not FileAccess.file_exists(script):
		var names := [result.dir, scene.get_file(), script.get_file(), options.actor]
		result.error = NOT_AN_ACTOR % names
		return result

	if options.mode == Mode.ALL:
		result.error = _list(result.dir, result.paths)
		return result
	for path in [scene, script, script + ".uid"]:
		if FileAccess.file_exists(path):
			result.paths.append(path)
	if options.mode == Mode.STATES:
		result.error = _plan_states(result)
	return result


## Why the actor, the folder or the folder settings can't be used, or "".
static func _input_error(options: Options) -> String:
	var error := DogNames.actor_error(options.actor)
	if error.is_empty():
		error = DogNames.folder_error(options.folder)
	if error.is_empty():
		error = DogSettings.error()
	return error


## STATES: adds the states folder to result.paths, when there is one, then the
## directory itself if everything in it is planned. Otherwise result.kept gets the
## names that stay. Returns an error, or "".
static func _plan_states(result: Result) -> String:
	var states := result.dir.path_join(DogStateGenerator.STATES_DIR)
	if DirAccess.dir_exists_absolute(states):
		var error := _list(states, result.paths)
		if not error.is_empty():
			return error

	var access := DirAccess.open(result.dir)
	if access == null:
		return COULD_NOT_READ % result.dir
	access.include_hidden = true
	var entries := access.get_files() + access.get_directories()
	entries.sort()
	for entry in entries:
		if not result.dir.path_join(entry) in result.paths:
			result.kept.append(entry)
	if result.kept.is_empty():
		result.paths.append(result.dir)
	return ""


## Appends to `paths` what is in `dir`, in an order it can be deleted in: its files,
## then each of its folders (the same way), then `dir` itself. Hidden files are
## listed too, or the folder could not be removed. Returns an error, or "".
static func _list(dir: String, paths: Array[String]) -> String:
	var access := DirAccess.open(dir)
	if access == null:
		return COULD_NOT_READ % dir
	access.include_hidden = true
	var files := access.get_files()
	var folders := access.get_directories()
	files.sort()
	folders.sort()

	for file in files:
		paths.append(dir.path_join(file))
	for folder in folders:
		var error := _list(dir.path_join(folder), paths)
		if not error.is_empty():
			return error
	paths.append(dir)
	return ""


## What to delete: the actor, the folder it is in (like in the other commands) and how
## much of it.
class Options:
	var actor := ""
	var folder := ""
	var mode := Mode.FILES


class Result:
	var error := ""
	## The actor's directory.
	var dir := ""
	## What build plans to delete, in order: files first, each folder after what is in
	## it.
	var paths: Array[String] = []
	## Filled by build in STATES mode: the names left in `dir`, which is then not
	## deleted.
	var kept: Array[String] = []
	## Filled by generate: the paths deleted, in order.
	var deleted: Array[String] = []
