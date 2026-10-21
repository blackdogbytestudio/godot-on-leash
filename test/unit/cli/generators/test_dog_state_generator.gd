# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## The pure parts of DogStateGenerator: no scene, no files.

const Command := preload("res://addons/leash/cli/commands/dog_state_command.gd")
const Generator := preload("res://addons/leash/cli/generators/dog_state_generator.gd")
const ROOT := "user://never_written"


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
		_initial(["hpda", "p", "alive", ".grounded", "..run", "...run_ground", "..idle", "dead"]),
		"run_ground",
	)


func test_initial_tie_picks_the_first_declared() -> void:
	assert_eq(_initial(["hpda", "p", "alive", ".run", ".idle", "dead", ".gone"]), "run")


func test_initial_on_a_flat_tree_is_the_first() -> void:
	assert_eq(_initial(["fsm", "p", "idle", "run"]), "idle")


# --- is_safe_states_dir ------------------------------------------------------


func test_only_the_actor_states_folder_inside_the_root_can_be_deleted() -> void:
	assert_true(Generator.is_safe_states_dir(ROOT + "/enemies/slime/states", ROOT))
	assert_false(Generator.is_safe_states_dir(ROOT + "/enemies/../states", ROOT))
	assert_false(Generator.is_safe_states_dir("user://elsewhere/slime/states", ROOT))
	assert_false(Generator.is_safe_states_dir(ROOT + "/slime", ROOT))
	assert_false(Generator.is_safe_states_dir(ROOT + "/states", ROOT))
	assert_false(Generator.is_safe_states_dir(ROOT + "_evil/slime/states", ROOT))
