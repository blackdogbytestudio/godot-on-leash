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
	assert_eq(DogSettings.scenes(), "res://scenes")
	assert_eq(DogSettings.folder(), "characters")
	assert_eq(DogSettings.actors_root(), "res://scenes/characters")
	assert_eq(DogSettings.prefix(), "dog")
	assert_eq(DogSettings.suffix(), "2d")


func test_a_changed_setting_is_read() -> void:
	_put(DogSettings.SCENES, "res://game")
	_put(DogSettings.FOLDER, "actors")
	assert_eq(DogSettings.actors_root(), "res://game/actors")


# --- _read --------------------------------------------------------------------


func test_spaces_and_edge_slashes_are_dropped() -> void:
	_put(DogSettings.SCENES, " res://scenes/ ")
	_put(DogSettings.FOLDER, "/characters/")
	_put(DogSettings.PREFIX, " dog ")
	assert_eq(DogSettings.scenes(), "res://scenes")
	assert_eq(DogSettings.folder(), "characters")
	assert_eq(DogSettings.prefix(), "dog")


func test_the_project_root_keeps_its_slashes() -> void:
	_put(DogSettings.SCENES, "res://")
	assert_eq(DogSettings.scenes(), "res://")
	assert_eq(DogSettings.actors_root(), "res://characters")


func test_empty_folders_fall_back_to_the_default() -> void:
	_put(DogSettings.SCENES, "")
	_put(DogSettings.FOLDER, "  ")
	assert_eq(DogSettings.actors_root(), "res://scenes/characters")


func test_empty_prefix_and_suffix_mean_none() -> void:
	_put(DogSettings.PREFIX, "")
	_put(DogSettings.SUFFIX, " ")
	assert_eq(DogSettings.prefix(), "")
	assert_eq(DogSettings.suffix(), "")


# --- register -----------------------------------------------------------------


func test_register_adds_every_setting_with_its_default() -> void:
	DogSettings.register()
	for key in DogSettings.DEFAULTS:
		assert_eq(ProjectSettings.get_setting(key), DogSettings.DEFAULTS[key], key)
		assert_eq(ProjectSettings.property_get_revert(key), DogSettings.DEFAULTS[key], key)


func test_register_keeps_a_value_already_set() -> void:
	_put(DogSettings.SCENES, "res://game")
	DogSettings.register()
	assert_eq(DogSettings.scenes(), "res://game")


# --- users --------------------------------------------------------------------


func test_generators_and_commands_default_to_the_setting() -> void:
	_put(DogSettings.SCENES, "res://game")
	assert_eq(DogStateGenerator.Options.new().root, "res://game/characters")
	assert_eq(DogStateGenerator.output_dir("", "player"), "res://game/characters/player/states")
	assert_eq(DogApiGenerator.Options.new().root, "res://game/characters")
	assert_eq(DogStateCommand.new().root, "res://game/characters")
	assert_eq(DogApiCommand.new().root, "res://game/characters")
