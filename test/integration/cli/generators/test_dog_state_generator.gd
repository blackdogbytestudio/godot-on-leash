# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogStateGenerator.generate / build with real scenes: writes in res://scenes/tmp
## (removed by every test), and builds against the hero fixture in
## test/doubles/state. The folder settings are pointed at those folders.

const Command := preload("res://addons/leash/cli/commands/dog_state_command.gd")
const Generator := preload("res://addons/leash/cli/generators/dog_state_generator.gd")
const ROOT_DIR := "scenes/tmp/state_gen_test"
const ROOT := "res://" + ROOT_DIR
const HERO_DIR := "test/doubles/state/scenes"
const HERO_ROOT := "res://" + HERO_DIR
const HERO_ARGS := ["hero", "hpda", "alive", ".grounded", "dead"]
const KEYS := [DogSettings.IMPLICIT_FOLDER, DogSettings.EXPLICIT_FOLDER]
const MACHINES := {
	"DogFSM": "res://addons/leash/components/machines/dog_fsm.gd",
	"DogPDA": "res://addons/leash/components/machines/dog_pda.gd",
	"DogHFSM": "res://addons/leash/components/machines/dog_hfsm.gd",
	"DogHPDA": "res://addons/leash/components/machines/dog_hpda.gd",
}
const ENEMY_HOST := """extends Node

var alive_state := EnemyAliveState.new()
var grounded_state := EnemyGroundedState.new()
var dead_state := EnemyDeadState.new()

@onready var _dog_hpda: DogHPDA = $DogHPDA


func _ready() -> void:
	_dog_hpda.init(grounded_state)


func _physics_process(delta: float) -> void:
	_dog_hpda.update(delta)
"""

var _saved := {}


func before_each() -> void:
	_saved.clear()
	for key in KEYS:
		if ProjectSettings.has_setting(key):
			_saved[key] = ProjectSettings.get_setting(key)
	_use(ROOT_DIR)
	_remove(ROOT)


func after_each() -> void:
	_remove(ROOT)
	DirAccess.remove_absolute("res://scenes/tmp")  # only succeeds when empty
	for key in KEYS:
		if _saved.has(key):
			ProjectSettings.set_setting(key, _saved[key])
		elif ProjectSettings.has_setting(key):
			ProjectSettings.clear(key)


## Points both folder settings at `dir` (below res://).
func _use(dir: String) -> void:
	for key in KEYS:
		ProjectSettings.set_setting(key, dir)


func _request(args: PackedStringArray) -> DogStateCommand.Request:
	return Command.parse_request(args)


func _generate(args: PackedStringArray) -> DogStateGenerator.Result:
	var request := _request(args)
	assert_eq(request.error, "", "unexpected parse error: %s" % request.error)
	return Generator.generate(Command.options_for(request))


func _states(folder: String) -> String:
	return ROOT.path_join(folder).path_join("states")


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Writes `<ROOT>/<dir>/<actor>.tscn` whose root has `<actor>.gd` (with
## `host_source`) and one child per entry of `children` ({node name: class}).
## dir defaults to the actor. An empty `host_source` leaves the root without script.
func _scene(
	actor: String,
	children := { "DogHPDA": "DogHPDA" },
	dir := "",
	host_source := "extends Node\n"
) -> String:
	var actor_dir := ROOT.path_join(dir if not dir.is_empty() else actor)
	DirAccess.make_dir_recursive_absolute(actor_dir)
	var host_path := actor_dir.path_join(actor + ".gd")
	var text := "[gd_scene format=3]\n\n"
	if not host_source.is_empty():
		_write(host_path, host_source)
		text += "[ext_resource type=\"Script\" path=\"%s\" id=\"host\"]\n" % host_path
	var ids := {}
	for node_name in children:
		var klass: String = children[node_name]
		if not ids.has(klass):
			ids[klass] = "m%d" % ids.size()
			text += "[ext_resource type=\"Script\" path=\"%s\" id=\"%s\"]\n" % [
				MACHINES[klass],
				ids[klass],
			]
	text += "\n[node name=\"%s\" type=\"Node\"]\n" % DogNames.to_pascal(actor)
	if not host_source.is_empty():
		text += "script = ExtResource(\"host\")\n"
	for node_name in children:
		text += (
			"\n[node name=\"%s\" type=\"Node\" parent=\".\"]\n"
			+ "script = ExtResource(\"%s\")\n"
		) % [
			node_name,
			ids[children[node_name]],
		]
	var scene_path := actor_dir.path_join(actor + ".tscn")
	_write(scene_path, text)
	return scene_path


## Every file under `path`, relative to it, sorted.
func _files(path: String, prefix := "") -> Array:
	var found := []
	var dir := DirAccess.open(path)
	if dir == null:
		return found
	for file in dir.get_files():
		found.append(prefix + file)
	for sub in dir.get_directories():
		found.append_array(_files(path.path_join(sub), prefix + sub + "/"))
	found.sort()
	return found


func _remove(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	for sub in dir.get_directories():
		_remove(path.path_join(sub))
	DirAccess.remove_absolute(path)


func _fails_without_writing(args: PackedStringArray, expected: Array) -> void:
	var before := _files(ROOT)
	var result := _generate(args)
	for text in expected:
		assert_string_contains(result.error, text)
	assert_eq(result.written, [])
	assert_eq(_files(ROOT), before)


func _host(actor := "enemy", dir := "") -> String:
	return _text(ROOT.path_join(dir if not dir.is_empty() else actor).path_join(actor + ".gd"))


# --- generate ---------------------------------------------------------------


func test_generate_creates_actor_and_nodes() -> void:
	_scene("enemy", { "DogHPDA": "DogHPDA" }, "enemies")
	_generate(PackedStringArray([
		"enemy", "hpda", "--folder", "enemies",
		"alive", ".grounded", "..idle", ".airborne", "dead",
	]))
	var dir := _states("enemies")

	assert_true(FileAccess.file_exists(dir.path_join("enemy_state.gd")))
	assert_true(FileAccess.file_exists(dir.path_join("enemy_grounded_state.gd")))
	assert_true(FileAccess.file_exists(dir.path_join("enemy_idle_state.gd")))
	assert_true(FileAccess.file_exists(dir.path_join("enemy_dead_state.gd")))

	assert_string_contains(_text(dir.path_join("enemy_state.gd")), "class_name EnemyState")
	assert_string_contains(_text(dir.path_join("enemy_state.gd")), "extends DogHPDAState")
	assert_string_contains(
		_text(dir.path_join("enemy_grounded_state.gd")),
		"extends EnemyAliveState",
	)
	assert_string_contains(
		_text(dir.path_join("enemy_idle_state.gd")),
		"extends EnemyGroundedState",
	)


func test_generate_replaces_every_placeholder() -> void:
	_scene("enemy")
	_generate(PackedStringArray(["enemy", "hpda", "alive", ".grounded"]))
	var text := _text(_states("enemy").path_join("enemy_alive_state.gd"))
	assert_false(text.contains("_CLASS_"))
	assert_false(text.contains("_BASE_"))
	assert_false(text.contains("CUSTOM_HOST"))
	assert_false(text.contains("CUSTOM_BASE"))
	assert_false(text.contains("# Replace '"))


func test_generate_skips_existing_and_force_rewrites() -> void:
	_scene("player")
	var args := PackedStringArray(["player", "hpda", "alive", ".grounded", "..run"])
	_generate(args)
	var run_path := _states("player").path_join("player_run_state.gd")
	_write(run_path, "custom")

	var kept := _generate(args)
	assert_has(kept.skipped, run_path)
	assert_eq(_text(run_path), "custom")

	_generate(PackedStringArray(["player", "hpda", "-f", "alive", ".grounded", "..run"]))
	assert_ne(_text(run_path), "custom")
	assert_string_contains(_text(run_path), "class_name PlayerRunState")


func test_generate_extends_suppresses_actor_base() -> void:
	_scene("slime", { "DogHPDA": "DogHPDA" }, "enemies/slime")
	var result := _generate(PackedStringArray([
		"slime", "hpda", "--extends", "enemy_alive_state",
		"--folder", "enemies/slime", "jump",
	]))
	var dir := _states("enemies/slime")

	assert_eq(result.written.size(), 1)
	assert_false(FileAccess.file_exists(dir.path_join("slime_state.gd")))
	assert_string_contains(_text(dir.path_join("slime_jump_state.gd")), "class_name SlimeJumpState")
	assert_string_contains(_text(dir.path_join("slime_jump_state.gd")), "extends EnemyAliveState")


func test_generate_extends_only_applies_to_root_states() -> void:
	_scene("slime", { "DogHPDA": "DogHPDA" }, "enemies/slime")
	_generate(PackedStringArray([
		"slime", "hpda", "--extends", "enemy_alive_state",
		"--folder", "enemies/slime", "jump", ".air", "..land", "walk",
	]))
	var dir := _states("enemies/slime")

	# Roots inherit from the --extends state.
	assert_string_contains(_text(dir.path_join("slime_jump_state.gd")), "extends EnemyAliveState")
	assert_string_contains(_text(dir.path_join("slime_walk_state.gd")), "extends EnemyAliveState")
	# Nested states inherit from their parent in the tree, not from --extends.
	assert_string_contains(_text(dir.path_join("slime_air_state.gd")), "extends SlimeJumpState")
	assert_string_contains(_text(dir.path_join("slime_land_state.gd")), "extends SlimeAirState")


func test_generate_flat_states_extend_the_actor_state() -> void:
	_scene("player", { "DogFSM": "DogFSM" })
	_generate(PackedStringArray(["player", "fsm", "alive", "dead"]))
	var dir := _states("player")

	assert_string_contains(_text(dir.path_join("player_state.gd")), "extends DogFSMState")
	assert_string_contains(_text(dir.path_join("player_alive_state.gd")), "extends PlayerState")
	assert_string_contains(_text(dir.path_join("player_dead_state.gd")), "extends PlayerState")


func test_generate_uses_actor_as_host() -> void:
	_scene("enemy")
	_generate(PackedStringArray(["enemy", "hpda", "alive"]))
	assert_string_contains(_text(_states("enemy").path_join("enemy_state.gd")), "host as Enemy")
	assert_string_contains(_text(_states("enemy").path_join("enemy_alive_state.gd")), "host: Enemy")


func test_generate_capitalizes_the_letter_after_a_number() -> void:
	_scene("character_body_2d", { "DogFSM": "DogFSM" })
	_generate(PackedStringArray(["character_body_2d", "fsm", "idle"]))
	var dir := _states("character_body_2d")
	assert_string_contains(
		_text(dir.path_join("character_body_2d_state.gd")),
		"class_name CharacterBody2DState",
	)
	assert_string_contains(
		_text(dir.path_join("character_body_2d_idle_state.gd")),
		"class_name CharacterBody2DIdleState",
	)


# --- validation before writing ---------------------------------------------


func test_missing_scene_is_an_error() -> void:
	_fails_without_writing(
		PackedStringArray(["enemy", "hpda", "alive"]),
		["enemy.tscn", _states("enemy").get_base_dir()],
	)


func test_scene_elsewhere_is_not_found_and_the_error_suggests_folder() -> void:
	_scene("slime", { "DogHPDA": "DogHPDA" }, "enemies/slime")
	_fails_without_writing(
		PackedStringArray(["slime", "hpda", "alive"]),
		[ROOT + "/slime/slime.tscn", "--folder"],
	)


func test_invalid_folder_setting_is_an_error_naming_it() -> void:
	_scene("enemy")
	ProjectSettings.set_setting(DogSettings.EXPLICIT_FOLDER, "res://scenes")
	_fails_without_writing(
		PackedStringArray(["enemy", "hpda", "alive"]),
		[DogSettings.EXPLICIT_FOLDER],
	)


func test_root_without_script_is_an_error() -> void:
	_scene("enemy", { "DogHPDA": "DogHPDA" }, "", "")
	_fails_without_writing(PackedStringArray(["enemy", "hpda", "alive"]), ["no script"])


func test_a_machine_of_another_type_is_an_error_naming_it() -> void:
	_scene("enemy", { "Brain": "DogFSM" })
	_fails_without_writing(
		PackedStringArray(["enemy", "hpda", "alive"]),
		["enemy.tscn already has a machine of another type: Brain (DogFSM)", "needs a DogHPDA"]
	)


func test_a_machine_of_another_type_next_to_the_right_one_is_an_error() -> void:
	_scene("enemy", { "Brain": "DogHPDA", "Spare": "DogFSM" })
	_fails_without_writing(
		PackedStringArray(["enemy", "hpda", "alive"]),
		["already has a machine of another type: Spare (DogFSM)", "remove that node"],
	)


func test_machine_type_is_never_switched() -> void:
	_scene("enemy", { "DogHPDA": "DogHPDA" })
	_fails_without_writing(
		PackedStringArray(["enemy", "pda", "alive"]),
		["another type: DogHPDA (DogHPDA)", "needs a DogPDA"],
	)


func test_two_machines_of_the_type_is_an_error_listing_them() -> void:
	_scene("enemy", { "Brain": "DogHPDA", "Spare": "DogHPDA" })
	_fails_without_writing(
		PackedStringArray(["enemy", "hpda", "alive"]),
		["more than one DogHPDA", "Brain, Spare"],
	)


func test_machine_node_name_does_not_matter() -> void:
	_scene("enemy", { "Brain": "DogHPDA" })
	var result := _generate(PackedStringArray(["enemy", "hpda", "alive"]))
	assert_eq(result.error, "")
	assert_eq(result.machine_node, "Brain")


func test_a_scene_without_a_machine_gets_one() -> void:
	_scene("enemy", {})
	var result := _generate(PackedStringArray(["enemy", "hpda", "alive"]))
	assert_eq(result.error, "")
	assert_eq(result.machine_node, "DogHPDA")
	assert_has(result.report, "add node DogHPDA")
	var scene := _text(ROOT.path_join("enemy").path_join("enemy.tscn"))
	assert_string_contains(scene, "[node name=\"DogHPDA\" type=\"Node\" parent=\".\"]")
	assert_string_contains(_host(), "@onready var _dog_hpda: DogHPDA = $DogHPDA\n")


func test_a_scene_that_has_the_machine_is_not_rewritten() -> void:
	var scene_path := _scene("enemy", { "Brain": "DogHPDA" })
	var before := _text(scene_path)
	var result := _generate(PackedStringArray(["enemy", "hpda", "alive"]))
	assert_eq(result.error, "")
	assert_eq(_text(scene_path), before)


func test_force_leaves_the_scene_alone() -> void:
	var scene_path := _scene("enemy", {})
	_generate(PackedStringArray(["enemy", "hpda", "alive"]))
	var before := _text(scene_path)
	_generate(PackedStringArray(["enemy", "hpda", "-f", "alive"]))
	assert_eq(_text(scene_path), before)


func test_host_without_class_name_is_only_a_warning() -> void:
	_scene("slime", { "DogHPDA": "DogHPDA" }, "", "extends Node\n")
	var result := _generate(PackedStringArray(["slime", "hpda", "alive"]))
	assert_eq(result.error, "")
	assert_eq(result.warnings, ["states cast host as Slime, but slime.gd has no class_name Slime"])


func test_host_with_another_class_name_is_only_a_warning() -> void:
	_scene("slime", { "DogHPDA": "DogHPDA" }, "", "class_name Enemy\nextends Node\n")
	var result := _generate(PackedStringArray(["slime", "hpda", "alive"]))
	assert_eq(
		result.warnings,
		["states cast host as Slime, but slime.gd has no class_name Slime (found: Enemy)"],
	)


func test_host_with_the_class_name_has_no_warning() -> void:
	_scene("slime", { "DogHPDA": "DogHPDA" }, "", "class_name Slime\nextends Node\n")
	assert_eq(_generate(PackedStringArray(["slime", "hpda", "alive"])).warnings, [])


# --- initial state ------------------------------------------------------------


func test_initial_flag_overrides_the_default() -> void:
	_scene("enemy")
	var result := _generate(
		PackedStringArray(["enemy", "hpda", "--initial", "alive", "alive", ".grounded"])
	)
	assert_eq(result.initial, "alive")
	assert_string_contains(result.host_source, "_dog_hpda.init(alive_state)")


func test_unknown_initial_is_an_error_listing_the_states() -> void:
	_scene("enemy")
	_fails_without_writing(
		PackedStringArray(["enemy", "hpda", "--initial", "nope", "alive", ".grounded"]),
		["--initial 'nope'", "states: alive, grounded"]
	)


func test_plumbing_is_added_to_the_host_in_style_guide_order() -> void:
	_scene("enemy")
	var result := _generate(PackedStringArray(["enemy", "hpda", "alive", ".grounded", "dead"]))
	assert_eq(result.error, "")
	assert_eq(_host(), ENEMY_HOST)
	assert_eq(result.report, [
		"add var alive_state",
		"add var grounded_state",
		"add var dead_state",
		"add var _dog_hpda",
		"add func _ready",
		"add line _dog_hpda.init",
		"add func _physics_process",
		"add line _dog_hpda.update",
	])


func test_machine_reference_uses_the_real_node_name() -> void:
	_scene("enemy", { "Brain": "DogHPDA" })
	_generate(PackedStringArray(["enemy", "hpda", "alive"]))
	assert_string_contains(_host(), "@onready var _dog_hpda: DogHPDA = $Brain\n")


func test_update_goes_on_top_of_an_existing_physics_process() -> void:
	_scene(
		"enemy",
		{ "DogHPDA": "DogHPDA" },
		"",
		"extends Node\n\n\nfunc _physics_process(delta: float) -> void:\n\tmove()\n",
	)
	_generate(PackedStringArray(["enemy", "hpda", "alive"]))
	assert_string_contains(
		_host(),
		"func _physics_process(delta: float) -> void:\n\t_dog_hpda.update(delta)\n\tmove()\n",
	)


func test_running_twice_changes_nothing_the_second_time() -> void:
	_scene("enemy")
	var args := PackedStringArray(["enemy", "hpda", "alive", ".grounded", "dead"])
	_generate(args)
	var second = _generate(args)
	assert_eq(second.written, [])
	assert_eq(second.host_source, second.host_original)
	for line in second.report:
		assert_true(line.begins_with("skip "), line)


func test_reference_already_written_by_bind_is_not_duplicated() -> void:
	_scene(
		"enemy",
		{ "DogHPDA": "DogHPDA" },
		"",
		"extends Node\n\n@onready var _dog_hpda: DogHPDA = $DogHPDA\n",
	)
	var result := _generate(PackedStringArray(["enemy", "hpda", "alive"]))
	assert_has(result.report, "skip var _dog_hpda")
	assert_eq(_host().count("var _dog_hpda"), 1)


func test_add_keeps_the_init_line_when_the_initial_changes() -> void:
	_scene("enemy")
	_generate(PackedStringArray(["enemy", "hpda", "alive", ".grounded"]))
	var result := _generate(PackedStringArray(["enemy", "hpda", "alive", ".grounded", "..run"]))
	assert_has(result.report, "skip line _dog_hpda.init")
	assert_string_contains(_host(), "_dog_hpda.init(grounded_state)")


func test_update_changes_the_init_line_and_leaves_state_files_alone() -> void:
	_scene("enemy")
	_generate(PackedStringArray(["enemy", "hpda", "alive", ".grounded"]))
	var grounded := _states("enemy").path_join("enemy_grounded_state.gd")
	_write(grounded, "custom")
	var result := _generate(
		PackedStringArray(["enemy", "hpda", "-u", "--initial", "alive", "alive", ".grounded"])
	)
	assert_has(result.report, "update line _dog_hpda.init")
	assert_string_contains(_host(), "\t_dog_hpda.init(alive_state)\n")
	assert_false(_host().contains("init(grounded_state)"))
	assert_eq(_text(grounded), "custom")
	assert_eq(result.written, [])


func test_host_merge_error_writes_nothing() -> void:
	_scene("enemy", { "DogHPDA": "DogHPDA" }, "", "extends Node\n\n\nfunc _ready(): pass\n")
	_fails_without_writing(PackedStringArray(["enemy", "hpda", "alive"]), ["enemy.gd", "_ready"])


# --- -f: back to factory ----------------------------------------------------------


func test_force_deletes_the_whole_states_folder_and_reports_each_file() -> void:
	_scene(
		"enemy",
		{ "DogHPDA": "DogHPDA" },
		"",
		"extends Node\n\n\nfunc mine() -> void:\n\tpass\n",
	)
	_generate(PackedStringArray(["enemy", "hpda", "alive", ".grounded"]))
	var dir := _states("enemy")
	_write(dir.path_join("enemy_old_state.gd"), "old")
	DirAccess.make_dir_recursive_absolute(dir.path_join("sub"))
	_write(dir.path_join("sub/notes.txt"), "x")

	var result := _generate(PackedStringArray(["enemy", "hpda", "-f", "alive"]))
	assert_eq(result.error, "")
	assert_eq(_files(dir), ["enemy_alive_state.gd", "enemy_state.gd"])
	for file in [
		"enemy_alive_state.gd",
		"enemy_grounded_state.gd",
		"enemy_old_state.gd",
		"enemy_state.gd",
		"sub/notes.txt",
	]:
		assert_has(result.report, "drop file states/" + file)
	assert_has(result.report, "drop func mine")
	assert_has(result.report, "drop var grounded_state")
	assert_false(_host().contains("mine"))
	assert_false(_host().contains("grounded"))


func test_force_without_a_states_folder_just_creates_it() -> void:
	_scene("enemy")
	var result := _generate(PackedStringArray(["enemy", "hpda", "-f", "alive"]))
	assert_eq(result.error, "")
	assert_eq(_files(_states("enemy")), ["enemy_alive_state.gd", "enemy_state.gd"])


func test_force_deletes_nothing_when_validation_fails() -> void:
	_scene("enemy")
	_generate(PackedStringArray(["enemy", "hpda", "alive"]))
	_scene("enemy", { "Brain": "DogFSM" })
	var before := _files(ROOT)
	var result := _generate(PackedStringArray(["enemy", "hpda", "-f", "alive"]))
	assert_string_contains(result.error, "machine of another type")
	assert_eq(_files(ROOT), before)


func test_add_never_deletes_files_in_states() -> void:
	_scene("enemy")
	_generate(PackedStringArray(["enemy", "hpda", "alive"]))
	_write(_states("enemy").path_join("enemy_old_state.gd"), "old")
	_generate(PackedStringArray(["enemy", "hpda", "alive"]))
	assert_true(FileAccess.file_exists(_states("enemy").path_join("enemy_old_state.gd")))


# --- build against the hero fixture ------------------------------------------
# The hero scene in test/doubles/state (class_name Hero, a DogHPDA child named
# Brain) and its states, already generated and registered. build never writes,
# so the fixture stays untouched.


func _build_hero(extra: Array = []) -> DogStateGenerator.Result:
	_use(HERO_DIR)
	var request := DogStateCommand.parse_request(PackedStringArray(HERO_ARGS + extra))
	assert_eq(request.error, "", "unexpected parse error: %s" % request.error)
	return DogStateGenerator.build(DogStateCommand.options_for(request))


## The host is the global class Hero already, so compile it without its class_name.
func _compile(source: String) -> int:
	var script := GDScript.new()
	# Only checks that it compiles: unused params and signals are expected here.
	var ignore := "@warning_ignore_start(\"unused_parameter\", \"unused_signal\")\n"
	script.source_code = ignore + source.replace("class_name Hero\n", "")
	return script.reload()


func _assert_in_order(source: String, parts: Array) -> void:
	var at := -1
	for part in parts:
		var found := source.find(part)
		assert_gt(found, at, "'%s' out of order in:\n%s" % [part, source])
		at = found


func test_add_result_compiles_in_style_guide_order_and_keeps_user_code() -> void:
	var result := _build_hero()
	assert_eq(result.error, "")
	assert_eq(result.warnings, [])
	assert_eq(result.files, {})
	assert_eq(_compile(result.host_source), OK, result.host_source)
	_assert_in_order(result.host_source, [
		"class_name Hero", "extends CharacterBody2D", "var speed := 200.0",
		"var alive_state := HeroAliveState.new()", "var grounded_state := HeroGroundedState.new()",
		"var dead_state := HeroDeadState.new()", "@onready var _dog_hpda: DogHPDA = $Brain",
		"func _ready() -> void:\n\t_dog_hpda.init(grounded_state)\n\tpass",
		"func _physics_process(delta: float) -> void:\n\t_dog_hpda.update(delta)",
		"func jump() -> void:",
	])


func test_add_twice_only_skips() -> void:
	var first := _build_hero()
	var blocks := DogStateGenerator.host_blocks(
		"hero",
		DogStateTree.parse(PackedStringArray(HERO_ARGS.slice(2))),
		"DogHPDA",
		"Brain",
		"grounded",
	)
	var second := DogScriptMerge.merge(first.host_source, blocks)
	assert_eq(second.source, first.host_source)
	for line in second.report:
		assert_true(line.begins_with("skip "), line)


func test_force_result_compiles_and_lists_what_it_drops() -> void:
	var result := _build_hero(["-f"])
	assert_eq(result.error, "")
	assert_eq(_compile(result.host_source), OK, result.host_source)
	_assert_in_order(result.host_source, [
		"class_name Hero", "extends CharacterBody2D", "var alive_state", "@onready var _dog_hpda",
		"func _ready() -> void:", "func _physics_process(delta: float) -> void:",
	])
	assert_false(result.host_source.contains("jump"))
	assert_eq(result.delete_dir, HERO_ROOT + "/hero/states")
	for line in [
		"drop file states/hero_state.gd",
		"drop file states/hero_alive_state.gd",
		"drop var speed",
		"drop func jump",
	]:
		assert_has(result.report, line)
	assert_eq(result.files.size(), 4)


func test_build_never_writes() -> void:
	var before := FileAccess.get_file_as_string(HERO_ROOT + "/hero/hero.gd")
	_build_hero(["-f"])
	assert_eq(FileAccess.get_file_as_string(HERO_ROOT + "/hero/hero.gd"), before)
	assert_true(FileAccess.file_exists(HERO_ROOT + "/hero/states/hero_dead_state.gd"))
