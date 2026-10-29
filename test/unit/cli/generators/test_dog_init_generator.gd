extends GutTest
## The pure parts of DogInitGenerator: build plans, nothing is written.

const Generator := preload("res://addons/leash/cli/generators/dog_init_generator.gd")
const ROOT := "user://never_written"


func _options(skip_templates := false) -> DogInitGenerator.Options:
	var options := Generator.Options.new()
	options.root = ROOT
	options.skip_templates = skip_templates
	return options


func _scaffold() -> Dictionary:
	return Generator.read_scaffold(Generator.Result.new())


func test_folders_lists_parents_first_in_the_file_order() -> void:
	var scaffold := { "assets": { "music": {}, "fonts": {} }, "components": {} }
	assert_eq(
		Generator.folders(scaffold, "res://"),
		["res://assets", "res://assets/music", "res://assets/fonts", "res://components"],
	)


func test_folders_of_an_empty_scaffold_is_empty() -> void:
	assert_eq(Generator.folders({}, ROOT), [])


func test_the_addon_scaffold_is_read_in_place() -> void:
	var scaffold := _scaffold()
	assert_true(scaffold.has("scenes"))
	assert_true(scaffold["scenes"].has("characters"))
	assert_true(scaffold["scenes"].has("objects"))


func test_template_files_skip_the_gdignore() -> void:
	var files := Generator.template_files()
	assert_has(files, "DogFSMState/class.gd")
	assert_has(files, "DogHPDAState/state.gd")
	assert_does_not_have(files, ".gdignore")


func test_build_plans_every_folder_and_template_and_writes_nothing() -> void:
	var result := Generator.build(_options())
	assert_eq(result.error, "")
	assert_eq(result.existing, [])
	for dir in Generator.folders(_scaffold(), ROOT):
		assert_has(result.dirs, dir)
		assert_has(result.report, "create %s" % dir)
	assert_has(result.dirs, ROOT + "/script_templates/DogFSMState")
	assert_eq(result.ignore, ROOT + "/script_templates/.gdignore")
	assert_eq(
		result.files[ROOT + "/script_templates/DogFSMState/class.gd"],
		"res://addons/leash/script_templates/DogFSMState/class.gd",
	)
	assert_eq(result.files.size(), Generator.template_files().size())
	assert_false(DirAccess.dir_exists_absolute(ROOT))


func test_build_creates_scenes_below_the_root_not_the_folder_settings() -> void:
	ProjectSettings.set_setting(DogSettings.IMPLICIT_FOLDER, "elsewhere/actors")
	ProjectSettings.set_setting(DogSettings.EXPLICIT_FOLDER, "elsewhere")
	var result := Generator.build(_options())
	ProjectSettings.clear(DogSettings.IMPLICIT_FOLDER)
	ProjectSettings.clear(DogSettings.EXPLICIT_FOLDER)
	assert_has(result.dirs, ROOT + "/scenes/characters")
	assert_false(result.dirs.any(func(dir: String) -> bool: return "elsewhere" in dir))


func test_build_with_skip_templates_plans_no_template() -> void:
	var result := Generator.build(_options(true))
	assert_eq(result.files, {})
	assert_eq(result.ignore, "")
	assert_false(result.report.any(func(line: String) -> bool: return "script_templates" in line))


func test_build_warns_when_gut_is_missing_from_the_root() -> void:
	var result := Generator.build(_options())
	assert_eq(
		result.warnings,
		["GUT is not installed (no %s/addons/gut/plugin.cfg): the tests need it." % ROOT],
	)


func test_build_does_not_warn_when_the_project_has_gut() -> void:
	var options := _options()
	options.root = "res://"
	assert_eq(Generator.build(options).warnings, [])
