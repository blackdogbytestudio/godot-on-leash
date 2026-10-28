@tool
class_name DogEditor
extends RefCounted
## Lets the editor see what a command wrote. Outside the editor (headless runs,
## tests) it does nothing.


## Scans the filesystem for the new and changed files, then reloads the scripts
## open in the script editor from disk when any of them is in `paths` (the files
## the command wrote). Not checked yet: an open script with unsaved changes may
## lose either those changes or what the command wrote.
static func refresh(paths := PackedStringArray()) -> void:
	if not Engine.is_editor_hint():
		return
	var fs := EditorInterface.get_resource_filesystem()
	if fs != null and not fs.is_scanning():
		fs.scan()

	var script_editor := EditorInterface.get_script_editor()
	if script_editor == null:
		return
	for script in script_editor.get_open_scripts():
		if script.resource_path in paths:
			script_editor.reload_open_files()
			return
