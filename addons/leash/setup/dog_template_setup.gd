@tool
class_name DogTemplateSetup
extends DogSetup

## Default templates folder path inside the addon.
const TEMPLATE_SRC: String = "res://addons/leash/script_templates"
## User-editable templates folder path required by Godot.
const TEMPLATE_DEST: String = "res://script_templates"


static func install() -> void:
	if not DirAccess.dir_exists_absolute(TEMPLATE_DEST):
		DirAccess.make_dir_recursive_absolute(TEMPLATE_DEST)
	_ignore_folder(TEMPLATE_DEST)

	var src: DirAccess = DirAccess.open(TEMPLATE_SRC)
	if not src:
		push_warning("Dog: script_templates not found at %s" % TEMPLATE_SRC)
		return

	for family in src.get_directories():
		var dest_dir: String = "%s/%s" % [TEMPLATE_DEST, family]
		if not DirAccess.dir_exists_absolute(dest_dir):
			DirAccess.make_dir_recursive_absolute(dest_dir)

		var family_dir: DirAccess = DirAccess.open("%s/%s" % [TEMPLATE_SRC, family])
		for file in family_dir.get_files():
			var dest_file: String = "%s/%s" % [dest_dir, file]
			if FileAccess.file_exists(dest_file):
				continue

			DirAccess.copy_absolute(
				"%s/%s/%s" % [TEMPLATE_SRC, family, file],
				dest_file
			)


## Godot would parse the templates as scripts (and fail on _BASE_): keep it out.
static func _ignore_folder(path: String) -> void:
	var ignore := path.path_join(".gdignore")
	if not FileAccess.file_exists(ignore):
		FileAccess.open(ignore, FileAccess.WRITE)
