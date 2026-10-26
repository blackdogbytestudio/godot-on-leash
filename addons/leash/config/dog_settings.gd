@tool
class_name DogSettings
extends RefCounted
## The Leash settings, stored in Project Settings under leash/.
##
## The plugin registers them with their defaults. A value is saved to
## project.godot only when it differs from the default. Reading a setting that
## was never registered returns its default, so nothing here needs the plugin.

const SCENES := "leash/generators/scenes"
const FOLDER := "leash/generators/folder"
const PREFIX := "leash/generators/prefix"
const SUFFIX := "leash/generators/suffix"
const DEFAULTS := {
	SCENES: "res://scenes",
	FOLDER: "characters",
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
		ProjectSettings.add_property_info({
			"name": key,
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_DIR if key == SCENES else PROPERTY_HINT_NONE,
		})


## Where every actor scene lives, e.g. res://scenes.
static func scenes() -> String:
	return _read(SCENES)


## The folder below scenes() used when a command gets no --folder.
static func folder() -> String:
	return _read(FOLDER)


## Where a command looks for the actor when it gets no --folder.
static func actors_root() -> String:
	return scenes().path_join(folder())


## Put before every component name (dog -> dog_jump). Empty means none.
static func prefix() -> String:
	return _read(PREFIX, true)


## Put after every component name (2d -> jump_2d). Empty means none.
static func suffix() -> String:
	return _read(SUFFIX, true)


## The setting without surrounding spaces or edge slashes (a root like res://
## keeps its own). Empty gives the default unless `allow_empty`.
static func _read(key: String, allow_empty := false) -> String:
	var value := str(ProjectSettings.get_setting(key, DEFAULTS[key])).strip_edges()
	value = value.trim_prefix("/")
	if not value.ends_with("://"):
		value = value.trim_suffix("/")
	if value.is_empty() and not allow_empty:
		return DEFAULTS[key]
	return value
