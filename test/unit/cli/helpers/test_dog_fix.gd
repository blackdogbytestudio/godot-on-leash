extends GutTest
## DogFix: the --prefix / --suffix / --no-fix flags, read from a parser built like
## the commands build theirs. The prefix and suffix settings are their defaults
## (dog, 2d).

const KEYS := [DogSettings.PREFIX, DogSettings.SUFFIX]

var _saved := {}


func before_each() -> void:
	_saved.clear()
	for key in KEYS:
		if ProjectSettings.has_setting(key):
			_saved[key] = ProjectSettings.get_setting(key)
		ProjectSettings.set_setting(key, DogSettings.DEFAULTS[key])


func after_each() -> void:
	for key in KEYS:
		ProjectSettings.clear(key)
		if _saved.has(key):
			ProjectSettings.set_setting(key, _saved[key])


func _fix(line: String) -> DogFix:
	var parser := DogOptParse.new()
	parser.add("--prefix", "", "")
	parser.add("--suffix", "", "")
	parser.add("--no-fix", false, "")
	parser.parse(DogCli.tokenize(line))
	return DogFix.from_parser(parser)


func test_without_flags_the_settings_apply() -> void:
	var fix := _fix("")
	assert_eq(fix.error, "")
	assert_false(fix.given)
	assert_true(fix.is_applied())
	assert_eq(fix.apply("jump"), "dog_jump_2d")


func test_prefix_and_suffix_replace_the_settings() -> void:
	var fix := _fix("--prefix fx --suffix 3d")
	assert_true(fix.given)
	assert_eq(fix.apply("jump"), "fx_jump_3d")


func test_an_empty_flag_drops_only_that_side() -> void:
	assert_eq(_fix("--prefix=").apply("area"), "area_2d")
	assert_eq(_fix("--suffix=").apply("jump"), "dog_jump")
	assert_true(_fix("--prefix=").given)


func test_a_stray_underscore_is_tolerated() -> void:
	assert_eq(_fix("--prefix dog_ --suffix _2d").apply("jump"), "dog_jump_2d")


func test_no_fix_drops_both() -> void:
	var fix := _fix("--no-fix")
	assert_true(fix.given)
	assert_false(fix.is_applied())
	assert_eq(fix.apply("CPUParticles2D"), "CPUParticles2D")


func test_no_fix_with_prefix_or_suffix_is_an_error() -> void:
	for line in ["--no-fix --prefix dog", "--no-fix --suffix="]:
		assert_eq(_fix(line).error, DogFix.NO_FIX_AND_FIX, line)


func test_empty_settings_apply_nothing() -> void:
	ProjectSettings.set_setting(DogSettings.PREFIX, "")
	ProjectSettings.set_setting(DogSettings.SUFFIX, "")
	var fix := _fix("")
	assert_false(fix.is_applied())
	assert_eq(fix.apply("jump"), "jump")
