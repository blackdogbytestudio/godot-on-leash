extends GutTest
## DogSettings: the Leash settings in Project Settings and how they are read.

var _saved := {}


func before_each() -> void:
	_saved.clear()
	for key in DogSettings.DEFAULTS:
		if ProjectSettings.has_setting(key):
			_saved[key] = ProjectSettings.get_setting(key)
		_clear(key)


func after_each() -> void:
	for key in DogSettings.DEFAULTS:
		_clear(key)
		if _saved.has(key):
			ProjectSettings.set_setting(key, _saved[key])


func _clear(key: String) -> void:
	if ProjectSettings.has_setting(key):
		ProjectSettings.clear(key)


func _put(key: String, value: String) -> void:
	ProjectSettings.set_setting(key, value)


# --- defaults ---------------------------------------------------------------


func test_unregistered_settings_give_the_defaults() -> void:
	assert_eq(DogSettings.implicit_folder(), "scenes/characters")
	assert_eq(DogSettings.explicit_folder(), "scenes")
	assert_eq(DogSettings.implicit_root(), "res://scenes/characters")
	assert_eq(DogSettings.explicit_root(), "res://scenes")
	assert_eq(DogSettings.prefix(), "dog")
	assert_eq(DogSettings.suffix(), "2d")


func test_a_changed_setting_is_read() -> void:
	_put(DogSettings.IMPLICIT_FOLDER, "game/actors")
	_put(DogSettings.EXPLICIT_FOLDER, "game")
	assert_eq(DogSettings.implicit_root(), "res://game/actors")
	assert_eq(DogSettings.explicit_root(), "res://game")


func test_the_two_folders_do_not_depend_on_each_other() -> void:
	_put(DogSettings.EXPLICIT_FOLDER, "")
	assert_eq(DogSettings.explicit_root(), "res://")
	assert_eq(DogSettings.implicit_root(), "res://scenes/characters")


# --- _read --------------------------------------------------------------------


func test_spaces_and_edge_slashes_are_dropped() -> void:
	_put(DogSettings.EXPLICIT_FOLDER, " /scenes/ ")
	_put(DogSettings.IMPLICIT_FOLDER, " scenes/characters/ ")
	_put(DogSettings.PREFIX, " dog ")
	assert_eq(DogSettings.explicit_folder(), "scenes")
	assert_eq(DogSettings.implicit_folder(), "scenes/characters")
	assert_eq(DogSettings.prefix(), "dog")


func test_an_empty_folder_is_the_project_root() -> void:
	_put(DogSettings.EXPLICIT_FOLDER, "")
	_put(DogSettings.IMPLICIT_FOLDER, "  ")
	assert_eq(DogSettings.explicit_root(), "res://")
	assert_eq(DogSettings.implicit_root(), "res://")


func test_empty_prefix_and_suffix_mean_none() -> void:
	_put(DogSettings.PREFIX, "")
	_put(DogSettings.SUFFIX, " ")
	assert_eq(DogSettings.prefix(), "")
	assert_eq(DogSettings.suffix(), "")


# --- error --------------------------------------------------------------------


func test_error_is_empty_for_the_defaults_and_for_the_root() -> void:
	assert_eq(DogSettings.error(), "")
	_put(DogSettings.EXPLICIT_FOLDER, "")
	assert_eq(DogSettings.error(), "")


func test_error_accepts_res_as_a_folder_name() -> void:
	_put(DogSettings.EXPLICIT_FOLDER, "res")
	assert_eq(DogSettings.error(), "")


func test_error_names_the_explicit_setting() -> void:
	_put(DogSettings.EXPLICIT_FOLDER, "res://scenes")
	var key := DogSettings.EXPLICIT_FOLDER
	assert_eq(DogSettings.error(), DogNames.folder_error("res://scenes", key))
	assert_string_contains(DogSettings.error(), key)


func test_error_names_the_implicit_setting() -> void:
	_put(DogSettings.IMPLICIT_FOLDER, "Scenes/characters")
	var key := DogSettings.IMPLICIT_FOLDER
	assert_eq(DogSettings.error(), DogNames.folder_error("Scenes/characters", key))
	assert_string_contains(DogSettings.error(), key)


func test_error_shows_what_was_typed() -> void:
	_put(DogSettings.EXPLICIT_FOLDER, "scenes//game")
	assert_string_contains(DogSettings.error(), "'scenes//game'")


# --- register -----------------------------------------------------------------


func test_register_adds_every_setting_with_its_default() -> void:
	DogSettings.register()
	for key in DogSettings.DEFAULTS:
		assert_eq(ProjectSettings.get_setting(key), DogSettings.DEFAULTS[key], key)
		assert_eq(ProjectSettings.property_get_revert(key), DogSettings.DEFAULTS[key], key)


func test_register_keeps_a_value_already_set() -> void:
	_put(DogSettings.EXPLICIT_FOLDER, "game")
	DogSettings.register()
	assert_eq(DogSettings.explicit_folder(), "game")
