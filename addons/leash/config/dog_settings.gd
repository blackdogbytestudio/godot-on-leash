@tool
class_name DogSettings
extends RefCounted
## The Leash settings, stored in Project Settings under leash/.
##
## The plugin registers them with their defaults. A value is saved to
## project.godot only when it differs from the default. Reading a setting that
## was never registered returns its default, so nothing here needs the plugin.
##
## The folder settings hold only what comes after res://, which is always the
## root and is never typed. An empty folder means res:// itself.

const ROOT := "res://"
const IMPLICIT_FOLDER := "leash/generators/implicit_folder"
const EXPLICIT_FOLDER := "leash/generators/explicit_folder"
const PREFIX := "leash/generators/prefix"
const SUFFIX := "leash/generators/suffix"
const DEFAULTS := {
	IMPLICIT_FOLDER: "scenes/characters",
	EXPLICIT_FOLDER: "scenes",
	PREFIX: "dog",
	SUFFIX: "2d",
}


## Registers every setting, keeping values already set, visible without Advanced.
static func register() -> void:
	for key in DEFAULTS:
		if not ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, DEFAULTS[key])
		ProjectSettings.set_initial_value(key, DEFAULTS[key])
		ProjectSettings.set_as_basic(key, true)
		ProjectSettings.add_property_info({"name": key, "type": TYPE_STRING})


## Where an actor goes when a command gets no --folder, below res://.
static func implicit_folder() -> String:
	return _read_folder(IMPLICIT_FOLDER)


## Where --folder starts from, below res://.
static func explicit_folder() -> String:
	return _read_folder(EXPLICIT_FOLDER)


## implicit_folder() as a full path, e.g. res://scenes/characters.
static func implicit_root() -> String:
	return ROOT + implicit_folder()


## explicit_folder() as a full path, e.g. res://scenes.
static func explicit_root() -> String:
	return ROOT + explicit_folder()


## The directory of an actor, the same for every command. Without a folder it is
## <implicit_root>/<actor>; with one it is <explicit_root>/<folder>, written in
## full (characters/enemies/slime), the actor's own directory included.
static func actor_dir(actor: String, folder := "") -> String:
	if folder.is_empty():
		return implicit_root().path_join(actor)
	return explicit_root().path_join(folder)


## Put before every component name (dog -> dog_jump). Empty means none.
static func prefix() -> String:
	return _read(PREFIX)


## Put after every component name (2d -> jump_2d). Empty means none.
static func suffix() -> String:
	return _read(SUFFIX)


## The error for a folder setting that isn't a valid folder, naming the setting,
## or "". Commands check it before they touch any file.
static func error() -> String:
	for key in [IMPLICIT_FOLDER, EXPLICIT_FOLDER]:
		var problem := DogNames.folder_error(_read_folder(key), key)
		if not problem.is_empty():
			return problem
	return ""


## The setting without surrounding spaces. Empty stays empty.
static func _read(key: String) -> String:
	return str(ProjectSettings.get_setting(key, DEFAULTS[key])).strip_edges()


## A folder setting without spaces or edge slashes. Anything else is left for
## error() to report, so the message shows what was really typed.
static func _read_folder(key: String) -> String:
	return _read(key).lstrip("/").rstrip("/")
