# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## The pure parts of DogStateGenerator: no scene, no files.

const Command := preload("res://addons/leash/cli/commands/dog_state_command.gd")
const Generator := preload("res://addons/leash/cli/generators/dog_state_generator.gd")
const ROOT := "user://never_written"
const KEYS := [DogSettings.IMPLICIT_FOLDER, DogSettings.EXPLICIT_FOLDER]

var _saved := {}


func before_each() -> void:
	_saved.clear()
	for key in KEYS:
		if ProjectSettings.has_setting(key):
			_saved[key] = ProjectSettings.get_setting(key)


func after_each() -> void:
	for key in KEYS:
		if _saved.has(key):
			ProjectSettings.set_setting(key, _saved[key])
		elif ProjectSettings.has_setting(key):
			ProjectSettings.clear(key)


func _request(args: PackedStringArray) -> DogStateCommand.Request:
	return Command.parse_request(args)


func _initial(args: Array) -> String:
	var request := _request(PackedStringArray(args))
	return (
		Generator.default_initial(request.tree) if request.initial.is_empty()
		else request.initial
	)


# --- initial state ------------------------------------------------------------


func test_initial_defaults_to_the_deepest_state() -> void:
	assert_eq(
		_initial(["p", "hpda", "alive", ".grounded", "..run", "...run_ground", "..idle", "dead"]),
		"run_ground",
	)


func test_initial_tie_picks_the_first_declared() -> void:
	assert_eq(_initial(["p", "hpda", "alive", ".run", ".idle", "dead", ".gone"]), "run")


func test_initial_on_a_flat_tree_is_the_first() -> void:
	assert_eq(_initial(["p", "fsm", "idle", "run"]), "idle")


# --- is_safe_states_dir ------------------------------------------------------


func test_only_the_actor_states_folder_inside_the_root_can_be_deleted() -> void:
	assert_true(Generator.is_safe_states_dir(ROOT + "/enemies/slime/states", ROOT))
	assert_false(Generator.is_safe_states_dir(ROOT + "/enemies/../states", ROOT))
	assert_false(Generator.is_safe_states_dir("user://elsewhere/slime/states", ROOT))
	assert_false(Generator.is_safe_states_dir(ROOT + "/slime", ROOT))
	assert_false(Generator.is_safe_states_dir(ROOT + "/states", ROOT))
	assert_false(Generator.is_safe_states_dir(ROOT + "_evil/slime/states", ROOT))


func test_the_root_defaults_to_the_project() -> void:
	assert_true(Generator.is_safe_states_dir("res://scenes/slime/states"))
	assert_true(Generator.is_safe_states_dir("res://slime/states"))
	assert_false(Generator.is_safe_states_dir("res://states"))
	assert_false(Generator.is_safe_states_dir("user://scenes/slime/states"))


# --- names and paths ---------------------------------------------------------


func test_file_name_of_the_actor_base_and_of_a_state() -> void:
	assert_eq(Generator.file_name("enemy"), "enemy_state.gd")
	assert_eq(Generator.file_name("enemy", "alive"), "enemy_alive_state.gd")


func test_state_class_of_the_actor_base_and_of_a_state() -> void:
	assert_eq(Generator.state_class("enemy"), "EnemyState")
	assert_eq(Generator.state_class("skinny_man", "run_ground"), "SkinnyManRunGroundState")
	assert_eq(Generator.state_class("robot_2d", "idle"), "Robot2DIdleState")


func test_output_dir_without_a_folder_is_the_actor_under_the_implicit_root() -> void:
	ProjectSettings.set_setting(DogSettings.IMPLICIT_FOLDER, "game/actors")
	assert_eq(Generator.output_dir("", "player"), "res://game/actors/player/states")


func test_output_dir_with_a_folder_starts_at_the_explicit_root() -> void:
	ProjectSettings.set_setting(DogSettings.IMPLICIT_FOLDER, "somewhere/else")
	ProjectSettings.set_setting(DogSettings.EXPLICIT_FOLDER, "game")
	assert_eq(
		Generator.output_dir("actors/enemies/slime", "slime"),
		"res://game/actors/enemies/slime/states",
	)


# --- host_blocks -------------------------------------------------------------


func _blocks() -> Array:
	var tree := DogStateTree.parse(PackedStringArray(["alive", ".grounded"]))
	return Generator.host_blocks("enemy", tree, "DogHPDA", "Brain", "grounded")


func test_host_blocks_has_a_var_per_state_in_tree_order() -> void:
	var blocks := _blocks()
	assert_eq(blocks[0], {
		"kind": "var",
		"name": "alive_state",
		"text": "var alive_state := EnemyAliveState.new()",
	})
	assert_eq(blocks[1]["text"], "var grounded_state := EnemyGroundedState.new()")


func test_host_blocks_references_the_machine_node() -> void:
	assert_eq(_blocks()[2]["text"], "@onready var _dog_hpda: DogHPDA = $Brain")


func test_host_blocks_inits_with_the_initial_and_updates_with_delta() -> void:
	var blocks := _blocks()
	assert_eq(blocks[3]["func"], "_ready")
	assert_eq(blocks[3]["text"], "\t_dog_hpda.init(grounded_state)")
	assert_eq(blocks[4]["func"], "_physics_process")
	assert_eq(blocks[4]["text"], "\t_dog_hpda.update(delta)")
	assert_eq(blocks.size(), 5)
