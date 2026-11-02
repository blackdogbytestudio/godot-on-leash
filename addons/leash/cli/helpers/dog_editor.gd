@tool
class_name DogEditor
extends RefCounted
## Lets the editor see what a command wrote. Outside the editor (headless runs,
## tests) it does nothing.


## Scans the filesystem for the new and changed files, then reloads from disk what
## the editor has open of them: the scenes in `paths` (the files the command wrote),
## and the scripts open in the script editor when any of them is in `paths`. A scene
## is reloaded as it is on disk, so unsaved changes in an open scene a command wrote
## are lost; not checked yet for an open script with unsaved changes either.
static func refresh(paths := PackedStringArray()) -> void:
	if not Engine.is_editor_hint():
		return
	var fs := EditorInterface.get_resource_filesystem()
	if fs != null and not fs.is_scanning():
		fs.scan()

	_reload_open_scenes(paths)
	_reload_open_scripts(paths)


## Reloads each scene of `paths` that is open in the editor, so the Scene dock and the
## 2D / 3D view show what was written instead of the version loaded before.
static func _reload_open_scenes(paths: PackedStringArray) -> void:
	for scene in EditorInterface.get_open_scenes():
		if scene in paths:
			EditorInterface.reload_scene_from_path(scene)


## Reloads the open scripts from disk when any of them is in `paths`.
static func _reload_open_scripts(paths: PackedStringArray) -> void:
	var script_editor := EditorInterface.get_script_editor()
	if script_editor == null:
		return
	for script in script_editor.get_open_scripts():
		if script.resource_path in paths:
			script_editor.reload_open_files()
			return
