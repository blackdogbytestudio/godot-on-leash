extends GutTest
## DogInitGenerator.generate writing in user://: folders, templates, the GUT check.

const Generator := preload("res://addons/leash/cli/generators/dog_init_generator.gd")
const ROOT := "user://dog_init_generator_test"
const TEMPLATES := ROOT + "/script_templates"


func before_each() -> void:
	_remove(ROOT)


func after_each() -> void:
	_remove(ROOT)


func _generate(skip_templates := false) -> DogInitGenerator.Result:
	var options := Generator.Options.new()
	options.root = ROOT
	options.skip_templates = skip_templates
	var result := Generator.generate(options)
	assert_eq(result.error, "", "unexpected error: %s" % result.error)
	return result


func _folders() -> Array[String]:
	return Generator.folders(Generator.read_scaffold(Generator.Result.new()), ROOT)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	for file in dir.get_files():
		dir.remove(file)
	for sub in dir.get_directories():
		_remove(path.path_join(sub))
	DirAccess.remove_absolute(path)


func test_creates_every_scaffold_folder() -> void:
	_generate()
	for dir in _folders():
		assert_true(DirAccess.dir_exists_absolute(dir), dir)
	assert_true(DirAccess.dir_exists_absolute(ROOT + "/scenes/objects"))


func test_creates_only_the_missing_folders() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + "/assets/music")
	var result := _generate()
	assert_has(result.report, "exist %s/assets" % ROOT)
	assert_has(result.report, "exist %s/assets/music" % ROOT)
	assert_has(result.report, "create %s/assets/fonts" % ROOT)
	assert_does_not_have(result.dirs, ROOT + "/assets")


func test_copies_the_templates_with_a_fresh_gdignore() -> void:
	_generate()
	assert_true(FileAccess.file_exists(TEMPLATES + "/.gdignore"))
	for file in Generator.template_files():
		assert_eq(
			FileAccess.get_file_as_string(TEMPLATES.path_join(file)),
			FileAccess.get_file_as_string(Generator.TEMPLATE_SRC.path_join(file)),
			file,
		)


func test_never_overwrites_a_file() -> void:
	_write(TEMPLATES + "/DogFSMState/class.gd", "# mine\n")
	_write(TEMPLATES + "/.gdignore", "mine")
	_write(ROOT + "/scenes/keep.txt", "kept")
	var result := _generate()
	assert_eq(FileAccess.get_file_as_string(TEMPLATES + "/DogFSMState/class.gd"), "# mine\n")
	assert_eq(FileAccess.get_file_as_string(TEMPLATES + "/.gdignore"), "mine")
	assert_eq(FileAccess.get_file_as_string(ROOT + "/scenes/keep.txt"), "kept")
	assert_has(result.report, "exist %s/DogFSMState/class.gd" % TEMPLATES)
	assert_has(result.report, "exist %s/.gdignore" % TEMPLATES)
	assert_has(result.report, "create %s/DogFSMState/state.gd" % TEMPLATES)


func test_a_second_run_creates_nothing() -> void:
	_generate()
	var result := _generate()
	assert_eq(result.dirs, [])
	assert_eq(result.files, {})
	assert_eq(result.ignore, "")
	assert_false(result.report.any(func(line: String) -> bool: return line.begins_with("create")))


func test_skip_templates_copies_nothing() -> void:
	_generate(true)
	assert_true(DirAccess.dir_exists_absolute(ROOT + "/scenes"))
	assert_false(DirAccess.dir_exists_absolute(TEMPLATES))


func test_warns_without_gut() -> void:
	var result := _generate()
	assert_eq(result.warnings.size(), 1)
	assert_string_contains(result.warnings[0], ROOT + "/addons/gut/plugin.cfg")


func test_does_not_warn_with_gut() -> void:
	_write(ROOT + "/addons/gut/plugin.cfg", "[plugin]\n")
	assert_eq(_generate().warnings, [])
