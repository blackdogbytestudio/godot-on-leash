# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogGenerateCommand.run end to end: actors in res://scenes/tmp and project
## templates in res://scene_templates, which every test removes. The folder settings
## are pointed at res://scenes/tmp; the prefix and suffix are their defaults.

const ROOT_DIR := "scenes/tmp/generate_cmd_test"
const ROOT := "res://" + ROOT_DIR
const PROJECT_TEMPLATES := "res://scene_templates"
const DIR := ROOT + "/knight"
const SCENE := DIR + "/knight.tscn"
const SCRIPT := DIR + "/knight.gd"
const STATES := DIR + "/states"
const FSM := "res://addons/leash/components/machines/dog_fsm.gd"
const KEYS := [
	DogSettings.IMPLICIT_FOLDER,
	DogSettings.EXPLICIT_FOLDER,
	DogSettings.PREFIX,
	DogSettings.SUFFIX,
]

var _saved := {}
var _templates: Array[String] = []


func before_each() -> void:
	_saved.clear()
	_templates.clear()
	for key in KEYS:
		if ProjectSettings.has_setting(key):
			_saved[key] = ProjectSettings.get_setting(key)
		ProjectSettings.set_setting(key, DogSettings.DEFAULTS[key])
	ProjectSettings.set_setting(DogSettings.IMPLICIT_FOLDER, ROOT_DIR)
	ProjectSettings.set_setting(DogSettings.EXPLICIT_FOLDER, ROOT_DIR)
	_remove(ROOT)


func after_each() -> void:
	_remove(ROOT)
	DirAccess.remove_absolute("res://scenes/tmp")  # only succeeds when empty
	for dir in _templates:
		_remove(dir)
	DirAccess.remove_absolute(PROJECT_TEMPLATES)  # only succeeds when empty
	for key in KEYS:
		if _saved.has(key):
			ProjectSettings.set_setting(key, _saved[key])
		elif ProjectSettings.has_setting(key):
			ProjectSettings.clear(key)


func _run(line: String) -> Array:
	var command := DogGenerateCommand.new()
	var lines: Array[String] = []
	command.printed.connect(func(text: String) -> void: lines.append(text))
	var error := command.run(DogCli.tokenize(line))
	return [error, lines]


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Writes res://scene_templates/<template>/: a Node2D root with the template's
## script and, with `child_script`, a child node using it.
func _template(template: String, child_script := "") -> void:
	var dir := PROJECT_TEMPLATES.path_join(template)
	_templates.append(dir)
	var own := dir.path_join(template + ".gd")
	_write(own, "extends Node2D\n# %s\n" % template)
	var text := "[gd_scene format=3]\n\n"
	text += "[ext_resource type=\"Script\" path=\"%s\" id=\"1_s\"]\n" % own
	if not child_script.is_empty():
		text += "[ext_resource type=\"Script\" path=\"%s\" id=\"2_c\"]\n" % child_script
	text += "\n[node name=\"Root\" type=\"Node2D\"]\nscript = ExtResource(\"1_s\")\n"
	if not child_script.is_empty():
		text += "\n[node name=\"Child\" type=\"Node\" parent=\".\"]\n"
		text += "script = ExtResource(\"2_c\")\n"
	_write(dir.path_join(template + ".tscn"), text)


func _remove(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	for sub in dir.get_directories():
		_remove(path.path_join(sub))
	DirAccess.remove_absolute(path)


## The scene and the script of `actor`. Tests that give the actor another base
## than CharacterBody2D use an actor name of their own: Godot keeps a loaded script
## cached by its path, and a cached knight.gd would still extend CharacterBody2D.
func _paths(actor: String) -> Array[String]:
	var dir := ROOT.path_join(actor)
	return [dir.path_join(actor + ".tscn"), dir.path_join(actor + ".gd")]


func _assert_nothing_written(line: String) -> void:
	assert_false(DirAccess.dir_exists_absolute(ROOT), "nothing written: " + line)


# --- full runs ----------------------------------------------------------------


func test_run_creates_the_actor_its_states_and_binds_it() -> void:
	var result := _run("knight hpda alive .grounded dead --bind move,jump")
	assert_eq(result[0], OK)
	var lines: Array = result[1]

	# The lines of each step, in order, as the commands print them.
	assert_eq(lines.slice(0, 3), ["created " + SCENE, "created " + SCRIPT, "initial: grounded"])
	assert_has(lines, "created " + STATES.path_join("knight_alive_state.gd"))
	var machine := lines.find("add node DogHPDA")
	var move := lines.find("add node DogMove2D")
	assert_true(machine > 2 and move > machine, "state before bind")
	assert_lt(lines.find("add node DogJump2D"), lines.find("add func jump"))
	assert_eq(lines.back(), "updated " + SCRIPT)
	assert_eq(lines.count("updated " + SCENE), 2, "by state and by bind")

	var script := _read(SCRIPT)
	assert_true(script.begins_with("class_name Knight\nextends CharacterBody2D\n"))
	for part in ["_dog_hpda.init(grounded_state)", "$DogMove2D", "func jump("]:
		assert_string_contains(script, part)
	var scene := _read(SCENE)
	for node in ["DogHPDA", "DogMove2D", "DogJump2D"]:
		assert_string_contains(scene, "[node name=\"%s\"" % node)
	assert_string_contains(_read(STATES.path_join("knight_dead_state.gd")), "KnightDeadState")


func test_run_without_a_type_creates_and_binds_only() -> void:
	var result := _run("knight --bind move")
	assert_eq(result[0], OK)
	assert_false(" ".join(result[1]).contains("initial:"))
	assert_false(DirAccess.dir_exists_absolute(STATES))
	assert_string_contains(_read(SCRIPT), "@onready var _dog_move_2d: DogMove2D = $DogMove2D")


func test_run_binds_everything_in_the_scene_without_a_list() -> void:
	_template("gen_cmd_with_move", "res://addons/leash/components/2d/character/dog_move_2d.gd")
	assert_eq(_run("squire --template gen_cmd_with_move")[0], OK)
	var script := _read(_paths("squire")[1])
	assert_true(script.begins_with("class_name Squire\nextends Node2D\n# gen_cmd_with_move\n"))
	assert_string_contains(script, "@onready var _dog_move_2d: DogMove2D = $Child")


func test_run_with_a_custom_template_and_extends_actor() -> void:
	_template("gen_cmd_plain")
	var line := "ranger fsm idle walk --template gen_cmd_plain --extends-actor area --prefix="
	var result := _run(line + " --bind dog_move")
	assert_eq(result[0], OK)
	var paths := _paths("ranger")
	var script := _read(paths[1])
	assert_true(script.begins_with("class_name Ranger\nextends Area2D\n# gen_cmd_plain\n"))
	assert_string_contains(_read(paths[0]), "[node name=\"Ranger\" type=\"Area2D\"]")
	assert_string_contains(script, "_dog_fsm.init(idle_state)")
	assert_string_contains(script, "$DogMove2D", "--prefix= applies to --bind too")


func test_run_with_extends_state() -> void:
	var result := _run("knight hpda alive --extends-state hero_state")
	assert_eq(result[0], OK)
	var alive := _read(STATES.path_join("knight_alive_state.gd"))
	assert_string_contains(alive, "extends HeroState")
	assert_false(FileAccess.file_exists(STATES.path_join("knight_state.gd")))


# --- an existing actor --------------------------------------------------------


func test_run_on_an_existing_actor_keeps_it() -> void:
	_run("knight hpda alive --bind move")
	var before := _read(SCRIPT)
	var result := _run("knight hpda alive --bind move")
	assert_eq(result[0], OK)
	assert_eq(result[1].slice(0, 2), ["kept " + SCENE, "kept " + SCRIPT])
	assert_has(result[1], "kept " + STATES.path_join("knight_alive_state.gd"))
	assert_eq(result[1].back(), "kept " + SCRIPT)
	assert_eq(_read(SCRIPT), before)


func test_run_with_update_on_an_existing_actor() -> void:
	_run("knight hpda alive --bind move")
	var edited := _read(SCRIPT).replace("_dog_move_2d.move(direction, delta)", "pass")
	_write(SCRIPT, edited)
	_write(STATES.path_join("knight_alive_state.gd"), "mine")

	var result := _run("knight hpda alive -u")
	assert_eq(result[0], OK)
	assert_eq(result[1][0], "kept " + SCENE)
	assert_string_contains(_read(SCRIPT), "_dog_move_2d.move(direction, delta)")
	assert_eq(_read(STATES.path_join("knight_alive_state.gd")), "mine", "-u keeps the states")


func test_run_with_force_redoes_everything() -> void:
	_run("knight hpda alive dead --bind move")
	_write(SCRIPT, "class_name Knight\nextends CharacterBody2D\n# mine\n")
	_write(STATES.path_join("knight_alive_state.gd"), "mine")

	var result := _run("knight hpda alive --bind jump -f")
	assert_eq(result[0], OK)
	assert_eq(result[1].slice(0, 2), ["created " + SCENE, "created " + SCRIPT])
	var script := _read(SCRIPT)
	assert_false(script.contains("# mine"))
	assert_false(script.contains("DogMove2D"), "the scene came back from the template")
	assert_string_contains(script, "$DogJump2D")
	assert_string_contains(script, "_dog_hpda.init(alive_state)")
	assert_false(FileAccess.file_exists(STATES.path_join("knight_dead_state.gd")))
	assert_ne(_read(STATES.path_join("knight_alive_state.gd")), "mine")


func test_run_on_an_existing_actor_rejects_what_would_change_it() -> void:
	_run("knight")
	var before := _read(SCRIPT)
	var cases := {
		"knight --template character_body_2d": "template 'character_body_2d'",
		"knight --extends-actor Area2D --no-fix": "--extends",
	}
	for line in cases:
		var expected := "Dog: actor: " + DogActorGenerator.KEPT_CHANGE % cases[line]
		assert_eq(_run(line), [FAILED, [expected]], line)
	assert_eq(_read(SCRIPT), before)


# --- errors -------------------------------------------------------------------


func test_errors_of_generate_write_nothing() -> void:
	var cases := {
		"knight --extends Area2D": DogGenerateCommand.AMBIGUOUS_EXTENDS,
		"knight hpda alive -f -u": DogScriptMerge.FORCE_AND_UPDATE,
		"knight --initial alive": DogGenerateCommand.NEEDS_TYPE % "--initial",
		"knight --extends-state hero_state": DogGenerateCommand.NEEDS_TYPE % "--extends-state",
		"knight --prefix=": DogGenerateCommand.FIX_WITHOUT_TARGET,
		"knight hpda alive --no-fix": DogGenerateCommand.FIX_WITHOUT_TARGET,
	}
	for line in cases:
		assert_eq(_run(line), [ERR_INVALID_PARAMETER, ["Dog: generate: " + cases[line]]], line)
		_assert_nothing_written(line)


func test_errors_found_before_writing_write_nothing() -> void:
	var cases := {
		"knight hpda alive --extends-state enemy_state":
		"Dog: state: " + DogStateGenerator.NOT_A_CLASS % "EnemyState",
		"knight hpda alive --initial dead":
		"Dog: state: " + DogStateGenerator.INITIAL_NOT_IN_TREE % ["dead", "alive"],
		"knight --bind nope": "Dog: bind: " + DogBindGenerator.UNKNOWN_CLASS % "dog_nope_2d",
		"knight --bind fsm --suffix=":
		"Dog: bind: " + DogBindGenerator.MACHINE_COMPONENT % "dog_fsm",
		"knight --extends-actor RefCounted --no-fix":
		"Dog: actor: " + DogActorGenerator.NOT_A_NODE_CLASS % "RefCounted",
		"area_2d": "Dog: actor: " + DogActorGenerator.NATIVE_CLASS_EXISTS % "Area2D",
	}
	for line in cases:
		assert_eq(_run(line), [FAILED, [cases[line]]], line)
		_assert_nothing_written(line)


func test_a_step_that_fails_after_a_write_stops_the_run() -> void:
	# The template already has a DogFSM, so the hpda state step fails on the scene.
	_template("gen_cmd_fsm", FSM)
	var result := _run("archer hpda alive --template gen_cmd_fsm --bind move")
	var paths := _paths("archer")
	var other := DogStateGenerator.OTHER_MACHINE % ["archer.tscn", "Child (DogFSM)", "DogHPDA"]
	var stopped := DogGenerateCommand.STOPPED % ["state", ", ".join(paths)]
	assert_eq(result, [FAILED, ["Dog: state: " + other, "Dog: generate: " + stopped]])
	assert_true(FileAccess.file_exists(paths[1]), "no rollback")
	assert_false(_read(paths[1]).contains("DogMove2D"), "bind did not run")
