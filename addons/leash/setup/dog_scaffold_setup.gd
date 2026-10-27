@tool
class_name DogScaffoldSetup
extends DogSetup

## Default scaffold. Copied out on first install.
const SCAFFOLD_SRC := "res://addons/leash/config/scaffold.json"
const CONFIG_DIR := "res://config"
## User-editable copy. The one actually read to build the folder tree.
const SCAFFOLD_DEST := "res://config/scaffold.json"


static func install() -> void:
	if not DirAccess.dir_exists_absolute(CONFIG_DIR):
		DirAccess.make_dir_recursive_absolute(CONFIG_DIR)

	if not FileAccess.file_exists(SCAFFOLD_DEST):
		if not FileAccess.file_exists(SCAFFOLD_SRC):
			push_warning("Dog: scaffold.json not found at %s" % SCAFFOLD_SRC)
			return

		DirAccess.copy_absolute(SCAFFOLD_SRC, SCAFFOLD_DEST)

	var file: FileAccess = FileAccess.open(SCAFFOLD_DEST, FileAccess.READ)
	if file.get_as_text().strip_edges() == "":
		return

	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		push_error("Dog: scaffold.json is corrupted.")
		return

	_create_folders(data, "res://")

	print("Dog: scaffold created\n%s" % JSON.stringify(data, "\t"))

	var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if not fs.is_scanning():
		fs.scan()


static func _create_folders(node: Dictionary, current_path: String) -> void:
	for key: String in node.keys():
		var next_path: String = current_path.path_join(key)
		DirAccess.make_dir_recursive_absolute(next_path)
		#print("Dog: created ", next_path)

		var child: Variant = node[key]
		if child is Dictionary:
			_create_folders(child, next_path)
