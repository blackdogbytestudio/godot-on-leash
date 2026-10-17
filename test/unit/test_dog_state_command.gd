# gdstyle:ignore-file=quality/max-public-methods
extends GutTest

const Command := preload("res://addons/dog/cli/commands/dog_state_command.gd")
const Generator := preload("res://addons/dog/cli/generators/dog_state_generator.gd")
const ROOT := "user://dog_state_command_test"
const MACHINES := {
	"DogFSM": "res://addons/dog/components/machines/dog_fsm.gd",
	"DogPDA": "res://addons/dog/components/machines/dog_pda.gd",
	"DogHFSM": "res://addons/dog/components/machines/dog_hfsm.gd",
	"DogHPDA": "res://addons/dog/components/machines/dog_hpda.gd",
}
# --- host plumbing --------------------------------------------------------------
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


func before_each() -> void:
	_remove(ROOT)


func after_each() -> void:
	_remove(ROOT)


func _request(args: PackedStringArray):
	return Command.parse_request(args)


func _generate(args: PackedStringArray):
	var request = _request(args)
	assert_eq(request.error, "", "unexpected parse error: %s" % request.error)
	return Generator.generate(
		request.type, request.actor, request.folder,
		request.extends_state, request.tree, request.mode, ROOT, request.initial
	)


func _run(args: PackedStringArray) -> Array:
	var command = Command.new()
	command.root = ROOT
	var lines: Array[String] = []
	command.printed.connect(func(text: String) -> void: lines.append(text))
	var error := command.run(args)
	return [error, lines]


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
		text += "\n[node name=\"%s\" type=\"Node\" parent=\".\"]\nscript = ExtResource(\"%s\")\n" % [
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


# --- parse ------------------------------------------------------------------


func test_parse_accepts_hpda() -> void:
	var request = _request(PackedStringArray(["hpda", "enemy", "alive", ".grounded", "dead"]))
	assert_eq(request.error, "")
	assert_eq(request.type, "hpda")
	assert_eq(request.actor, "enemy")
	assert_eq(request.tree.nodes.size(), 3)


func test_parse_reads_folder_and_extends() -> void:
	var request = _request(PackedStringArray([
		"hpda", "slime", "--folder", "enemies/slime",
		"--extends", "enemy_alive_state", "jump",
	]))
	assert_eq(request.error, "")
	assert_eq(request.folder, "enemies/slime")
	assert_eq(request.extends_state, "enemy_alive_state")


func test_parse_rejects_host_option() -> void:
	var request = _request(PackedStringArray(["hpda", "slime", "--host", "Slime", "jump"]))
	assert_string_contains(request.error, "unknown option '--host'")


func test_parse_rejects_hdpa() -> void:
	assert_ne(_request(PackedStringArray(["hdpa", "enemy", "alive"])).error, "")


func test_parse_requires_actor() -> void:
	assert_ne(_request(PackedStringArray(["fsm"])).error, "")


func test_parse_rejects_invalid_actor() -> void:
	assert_ne(_request(PackedStringArray(["fsm", "Player"])).error, "")


func test_parse_rejects_unknown_option() -> void:
	assert_ne(_request(PackedStringArray(["fsm", "player", "--nope"])).error, "")


func test_parse_rejects_nesting_on_flat_types() -> void:
	assert_ne(_request(PackedStringArray(["fsm", "player", "alive", ".run"])).error, "")


func test_flat_types_accept_multiple_roots() -> void:
	var request = _request(PackedStringArray(["fsm", "player", "alive", "dead"]))
	assert_eq(request.error, "")
	assert_eq(request.tree.nodes.size(), 2)


# --- generate ---------------------------------------------------------------


func test_generate_creates_actor_and_nodes() -> void:
	_scene("enemy", { "DogHPDA": "DogHPDA" }, "enemies")
	_generate(PackedStringArray([
		"hpda", "enemy", "--folder", "enemies",
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
	_generate(PackedStringArray(["hpda", "enemy", "alive", ".grounded"]))
	var text := _text(_states("enemy").path_join("enemy_alive_state.gd"))
	assert_false(text.contains("_CLASS_"))
	assert_false(text.contains("_BASE_"))
	assert_false(text.contains("CUSTOM_HOST"))
	assert_false(text.contains("CUSTOM_BASE"))
	assert_false(text.contains("# Replace '"))


func test_generate_skips_existing_and_force_rewrites() -> void:
	_scene("player")
	var args := PackedStringArray(["hpda", "player", "alive", ".grounded", "..run"])
	_generate(args)
	var run_path := _states("player").path_join("player_run_state.gd")
	_write(run_path, "custom")

	var kept = _generate(args)
	assert_has(kept.skipped, run_path)
	assert_eq(_text(run_path), "custom")

	_generate(PackedStringArray(["hpda", "player", "-f", "alive", ".grounded", "..run"]))
	assert_ne(_text(run_path), "custom")
	assert_string_contains(_text(run_path), "class_name PlayerRunState")


func test_generate_extends_suppresses_actor_base() -> void:
	_scene("slime", { "DogHPDA": "DogHPDA" }, "enemies/slime")
	var result = _generate(PackedStringArray([
		"hpda", "slime", "--extends", "enemy_alive_state",
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
		"hpda", "slime", "--extends", "enemy_alive_state",
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
	_generate(PackedStringArray(["fsm", "player", "alive", "dead"]))
	var dir := _states("player")

	assert_string_contains(_text(dir.path_join("player_state.gd")), "extends DogFSMState")
	assert_string_contains(_text(dir.path_join("player_alive_state.gd")), "extends PlayerState")
	assert_string_contains(_text(dir.path_join("player_dead_state.gd")), "extends PlayerState")


func test_generate_uses_actor_as_host() -> void:
	_scene("enemy")
	_generate(PackedStringArray(["hpda", "enemy", "alive"]))
	assert_string_contains(_text(_states("enemy").path_join("enemy_state.gd")), "host as Enemy")
	assert_string_contains(_text(_states("enemy").path_join("enemy_alive_state.gd")), "host: Enemy")


func test_parse_accepts_actor_with_a_digit_part() -> void:
	assert_eq(_request(PackedStringArray(["fsm", "character_body_2d", "idle"])).error, "")


func test_generate_capitalizes_the_letter_after_a_number() -> void:
	_scene("character_body_2d", { "DogFSM": "DogFSM" })
	_generate(PackedStringArray(["fsm", "character_body_2d", "idle"]))
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


func _fails_without_writing(args: PackedStringArray, expected: Array) -> void:
	var before := _files(ROOT)
	var result = _generate(args)
	for text in expected:
		assert_string_contains(result.error, text)
	assert_eq(result.written, [])
	assert_eq(_files(ROOT), before)


func test_missing_scene_is_an_error() -> void:
	_fails_without_writing(
		PackedStringArray(["hpda", "enemy", "alive"]),
		["enemy.tscn", _states("enemy").get_base_dir()],
	)


func test_scene_elsewhere_is_an_error_that_suggests_folder() -> void:
	_scene("slime", { "DogHPDA": "DogHPDA" }, "enemies/slime")
	_fails_without_writing(
		PackedStringArray(["hpda", "slime", "alive"]),
		["enemies/slime/slime.tscn", "--folder enemies/slime"],
	)


func test_root_without_script_is_an_error() -> void:
	_scene("enemy", { "DogHPDA": "DogHPDA" }, "", "")
	_fails_without_writing(PackedStringArray(["hpda", "enemy", "alive"]), ["no script"])


func test_missing_machine_lists_the_children_with_a_class() -> void:
	_scene("enemy", { "Brain": "DogFSM" })
	_fails_without_writing(
		PackedStringArray(["hpda", "enemy", "alive"]),
		["no DogHPDA child in enemy.tscn", "children with a class: Brain (DogFSM)"]
	)


func test_machine_type_is_never_switched() -> void:
	_scene("enemy", { "DogHPDA": "DogHPDA" })
	_fails_without_writing(PackedStringArray(["pda", "enemy", "alive"]), ["no DogPDA child"])


func test_two_machines_of_the_type_is_an_error_listing_them() -> void:
	_scene("enemy", { "Brain": "DogHPDA", "Spare": "DogHPDA" })
	_fails_without_writing(
		PackedStringArray(["hpda", "enemy", "alive"]),
		["more than one DogHPDA", "Brain, Spare"],
	)


func test_machine_node_name_does_not_matter() -> void:
	_scene("enemy", { "Brain": "DogHPDA" })
	var result = _generate(PackedStringArray(["hpda", "enemy", "alive"]))
	assert_eq(result.error, "")
	assert_eq(result.machine_node, "Brain")


func test_host_without_class_name_is_only_a_warning() -> void:
	_scene("slime", { "DogHPDA": "DogHPDA" }, "", "extends Node\n")
	var result = _generate(PackedStringArray(["hpda", "slime", "alive"]))
	assert_eq(result.error, "")
	assert_eq(result.warnings, ["states cast host as Slime, but slime.gd has no class_name Slime"])


func test_host_with_another_class_name_is_only_a_warning() -> void:
	_scene("slime", { "DogHPDA": "DogHPDA" }, "", "class_name Enemy\nextends Node\n")
	var result = _generate(PackedStringArray(["hpda", "slime", "alive"]))
	assert_eq(
		result.warnings,
		["states cast host as Slime, but slime.gd has no class_name Slime (found: Enemy)"],
	)


func test_host_with_the_class_name_has_no_warning() -> void:
	_scene("slime", { "DogHPDA": "DogHPDA" }, "", "class_name Slime\nextends Node\n")
	assert_eq(_generate(PackedStringArray(["hpda", "slime", "alive"])).warnings, [])


func test_run_prints_warnings() -> void:
	_scene("slime")
	var result = _run(PackedStringArray(["hpda", "slime", "alive"]))
	assert_eq(result[0], OK)
	assert_has(
		result[1],
		"warning: states cast host as Slime, but slime.gd has no class_name Slime",
	)


func test_run_prints_validation_errors() -> void:
	var result = _run(PackedStringArray(["hpda", "enemy", "alive"]))
	assert_eq(result[0], FAILED)
	assert_string_contains(result[1][0], "DOG: state: ")


# --- initial state ------------------------------------------------------------


func _initial(args: Array) -> String:
	var request = _request(PackedStringArray(args))
	return Generator.default_initial(request.tree) if request.initial.is_empty() else request.initial


func test_initial_defaults_to_the_deepest_state() -> void:
	assert_eq(
		_initial(["hpda", "p", "alive", ".grounded", "..run", "...run_ground", "..idle", "dead"]),
		"run_ground",
	)


func test_initial_tie_picks_the_first_declared() -> void:
	assert_eq(_initial(["hpda", "p", "alive", ".run", ".idle", "dead", ".gone"]), "run")


func test_initial_on_a_flat_tree_is_the_first() -> void:
	assert_eq(_initial(["fsm", "p", "idle", "run"]), "idle")


func test_initial_flag_overrides_the_default() -> void:
	_scene("enemy")
	var result = _generate(PackedStringArray(["hpda", "enemy", "--initial", "alive", "alive", ".grounded"]))
	assert_eq(result.initial, "alive")
	assert_string_contains(result.host_source, "_dog_hpda.init(alive_state)")


func test_unknown_initial_is_an_error_listing_the_states() -> void:
	_scene("enemy")
	_fails_without_writing(
		PackedStringArray(["hpda", "enemy", "--initial", "nope", "alive", ".grounded"]),
		["--initial 'nope'", "states: alive, grounded"]
	)


func test_initial_with_dots_is_a_parse_error() -> void:
	assert_ne(
		_request(PackedStringArray(["hpda", "enemy", "--initial", ".alive", "alive"])).error,
		"",
	)


func test_force_with_update_is_a_parse_error() -> void:
	assert_string_contains(
		_request(PackedStringArray(["hpda", "enemy", "-f", "-u", "alive"])).error,
		"-f or -u",
	)


func _host(actor := "enemy", dir := "") -> String:
	return _text(ROOT.path_join(dir if not dir.is_empty() else actor).path_join(actor + ".gd"))


func test_plumbing_is_added_to_the_host_in_style_guide_order() -> void:
	_scene("enemy")
	var result = _generate(PackedStringArray(["hpda", "enemy", "alive", ".grounded", "dead"]))
	assert_eq(result.error, "")
	assert_eq(_host(), ENEMY_HOST)
	assert_eq(result.report, [
		"add var alive_state", "add var grounded_state", "add var dead_state", "add var _dog_hpda",
		"add func _ready", "add line _dog_hpda.init", "add func _physics_process", "add line _dog_hpda.update",
	])


func test_machine_reference_uses_the_real_node_name() -> void:
	_scene("enemy", { "Brain": "DogHPDA" })
	_generate(PackedStringArray(["hpda", "enemy", "alive"]))
	assert_string_contains(_host(), "@onready var _dog_hpda: DogHPDA = $Brain\n")


func test_update_goes_on_top_of_an_existing_physics_process() -> void:
	_scene(
		"enemy",
		{ "DogHPDA": "DogHPDA" },
		"",
		"extends Node\n\n\nfunc _physics_process(delta: float) -> void:\n\tmove()\n",
	)
	_generate(PackedStringArray(["hpda", "enemy", "alive"]))
	assert_string_contains(
		_host(),
		"func _physics_process(delta: float) -> void:\n\t_dog_hpda.update(delta)\n\tmove()\n",
	)


func test_running_twice_changes_nothing_the_second_time() -> void:
	_scene("enemy")
	var args := PackedStringArray(["hpda", "enemy", "alive", ".grounded", "dead"])
	_generate(args)
	var second = _generate(args)
	assert_eq(second.written, [])
	assert_eq(second.host_source, second.host_original)
	for line in second.report:
		assert_true(line.begins_with("skip "), line)


func test_reference_already_written_by_api_is_not_duplicated() -> void:
	_scene(
		"enemy",
		{ "DogHPDA": "DogHPDA" },
		"",
		"extends Node\n\n@onready var _dog_hpda: DogHPDA = $DogHPDA\n",
	)
	var result = _generate(PackedStringArray(["hpda", "enemy", "alive"]))
	assert_has(result.report, "skip var _dog_hpda")
	assert_eq(_host().count("var _dog_hpda"), 1)


func test_add_keeps_the_init_line_when_the_initial_changes() -> void:
	_scene("enemy")
	_generate(PackedStringArray(["hpda", "enemy", "alive", ".grounded"]))
	var result = _generate(PackedStringArray(["hpda", "enemy", "alive", ".grounded", "..run"]))
	assert_has(result.report, "skip line _dog_hpda.init")
	assert_string_contains(_host(), "_dog_hpda.init(grounded_state)")


func test_update_changes_the_init_line_and_leaves_state_files_alone() -> void:
	_scene("enemy")
	_generate(PackedStringArray(["hpda", "enemy", "alive", ".grounded"]))
	var grounded := _states("enemy").path_join("enemy_grounded_state.gd")
	_write(grounded, "custom")
	var result = _generate(PackedStringArray(["hpda", "enemy", "-u", "--initial", "alive", "alive", ".grounded"]))
	assert_has(result.report, "update line _dog_hpda.init")
	assert_string_contains(_host(), "\t_dog_hpda.init(alive_state)\n")
	assert_false(_host().contains("init(grounded_state)"))
	assert_eq(_text(grounded), "custom")
	assert_eq(result.written, [])


func test_host_merge_error_writes_nothing() -> void:
	_scene("enemy", { "DogHPDA": "DogHPDA" }, "", "extends Node\n\n\nfunc _ready(): pass\n")
	_fails_without_writing(PackedStringArray(["hpda", "enemy", "alive"]), ["enemy.gd", "_ready"])


# --- -f: back to factory ----------------------------------------------------------


func test_force_deletes_the_whole_states_folder_and_reports_each_file() -> void:
	_scene(
		"enemy",
		{ "DogHPDA": "DogHPDA" },
		"",
		"extends Node\n\n\nfunc mine() -> void:\n\tpass\n",
	)
	_generate(PackedStringArray(["hpda", "enemy", "alive", ".grounded"]))
	var dir := _states("enemy")
	_write(dir.path_join("enemy_old_state.gd"), "old")
	DirAccess.make_dir_recursive_absolute(dir.path_join("sub"))
	_write(dir.path_join("sub/notes.txt"), "x")

	var result = _generate(PackedStringArray(["hpda", "enemy", "-f", "alive"]))
	assert_eq(result.error, "")
	assert_eq(_files(dir), ["enemy_alive_state.gd", "enemy_state.gd"])
	for file in ["enemy_alive_state.gd", "enemy_grounded_state.gd", "enemy_old_state.gd", "enemy_state.gd", "sub/notes.txt"]:
		assert_has(result.report, "drop file states/" + file)
	assert_has(result.report, "drop func mine")
	assert_has(result.report, "drop var grounded_state")
	assert_false(_host().contains("mine"))
	assert_false(_host().contains("grounded"))


func test_force_without_a_states_folder_just_creates_it() -> void:
	_scene("enemy")
	var result = _generate(PackedStringArray(["hpda", "enemy", "-f", "alive"]))
	assert_eq(result.error, "")
	assert_eq(_files(_states("enemy")), ["enemy_alive_state.gd", "enemy_state.gd"])


func test_force_deletes_nothing_when_validation_fails() -> void:
	_scene("enemy")
	_generate(PackedStringArray(["hpda", "enemy", "alive"]))
	_scene("enemy", { "Brain": "DogFSM" })
	var before := _files(ROOT)
	var result = _generate(PackedStringArray(["hpda", "enemy", "-f", "alive"]))
	assert_string_contains(result.error, "no DogHPDA child")
	assert_eq(_files(ROOT), before)


func test_add_never_deletes_files_in_states() -> void:
	_scene("enemy")
	_generate(PackedStringArray(["hpda", "enemy", "alive"]))
	_write(_states("enemy").path_join("enemy_old_state.gd"), "old")
	_generate(PackedStringArray(["hpda", "enemy", "alive"]))
	assert_true(FileAccess.file_exists(_states("enemy").path_join("enemy_old_state.gd")))


func test_folder_with_parent_traversal_is_a_parse_error() -> void:
	assert_ne(_request(PackedStringArray(["hpda", "enemy", "--folder", "../x", "alive"])).error, "")
	assert_ne(
		_request(PackedStringArray(["hpda", "enemy", "--folder", "a/../b", "alive"])).error,
		"",
	)


func test_only_the_actor_states_folder_inside_the_root_can_be_deleted() -> void:
	assert_true(Generator.is_safe_states_dir(ROOT + "/enemies/slime/states", ROOT))
	assert_false(Generator.is_safe_states_dir(ROOT + "/enemies/../states", ROOT))
	assert_false(Generator.is_safe_states_dir("user://elsewhere/slime/states", ROOT))
	assert_false(Generator.is_safe_states_dir(ROOT + "/slime", ROOT))
	assert_false(Generator.is_safe_states_dir(ROOT + "/states", ROOT))
	assert_false(Generator.is_safe_states_dir(ROOT + "_evil/slime/states", ROOT))


# --- run --------------------------------------------------------------------


func test_run_prints_created_and_keeps() -> void:
	_scene("player", { "DogHPDA": "DogHPDA" }, "", "class_name Player\nextends Node\n")
	var first = _run(PackedStringArray(["hpda", "player", "alive"]))
	assert_eq(first[0], OK)
	assert_eq(first[1][0], "initial: alive")
	assert_has(first[1], "created %s" % _states("player").path_join("player_state.gd"))
	assert_has(first[1], "created %s" % _states("player").path_join("player_alive_state.gd"))
	assert_has(first[1], "updated %s" % ROOT.path_join("player/player.gd"))

	var second = _run(PackedStringArray(["hpda", "player", "alive", ".grounded"]))
	assert_eq(second[0], OK)
	assert_string_contains(
		" ".join(second[1]),
		"kept %s" % _states("player").path_join("player_state.gd"),
	)
	assert_string_contains(" ".join(second[1]), "created")


func test_run_reports_parse_errors() -> void:
	var result = _run(PackedStringArray(["hdpa", "enemy", "alive"]))
	assert_eq(result[0], ERR_INVALID_PARAMETER)
	assert_eq(result[1].size(), 1)
	assert_string_contains(result[1][0], "DOG: state:")
	assert_eq(DirAccess.open(ROOT), null)


func test_run_reports_unknown_type() -> void:
	var result = _run(PackedStringArray(["nope", "enemy", "alive"]))
	assert_eq(result[0], ERR_INVALID_PARAMETER)
	assert_string_contains(result[1][0], "unknown type")
