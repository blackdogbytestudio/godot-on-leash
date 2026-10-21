# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogStateCommand.run end to end: what it prints after generating in user://.

const Command := preload("res://addons/leash/cli/commands/dog_state_command.gd")
const ROOT := "user://dog_state_command_test"
const MACHINES := {
	"DogFSM": "res://addons/leash/components/machines/dog_fsm.gd",
	"DogPDA": "res://addons/leash/components/machines/dog_pda.gd",
	"DogHFSM": "res://addons/leash/components/machines/dog_hfsm.gd",
	"DogHPDA": "res://addons/leash/components/machines/dog_hpda.gd",
}


func before_each() -> void:
	_remove(ROOT)


func after_each() -> void:
	_remove(ROOT)


func _run(args: PackedStringArray) -> Array:
	var command := Command.new()
	command.root = ROOT
	var lines: Array[String] = []
	command.printed.connect(func(text: String) -> void: lines.append(text))
	var error := command.run(args)
	return [error, lines]


func _states(folder: String) -> String:
	return ROOT.path_join(folder).path_join("states")


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


func _remove(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	for sub in dir.get_directories():
		_remove(path.path_join(sub))
	DirAccess.remove_absolute(path)


# --- run --------------------------------------------------------------------


func test_run_prints_warnings() -> void:
	_scene("slime")
	var result := _run(PackedStringArray(["hpda", "slime", "alive"]))
	assert_eq(result[0], OK)
	assert_has(
		result[1],
		"warning: states cast host as Slime, but slime.gd has no class_name Slime",
	)


func test_run_prints_validation_errors() -> void:
	var result := _run(PackedStringArray(["hpda", "enemy", "alive"]))
	assert_eq(result[0], FAILED)
	assert_string_contains(result[1][0], "Dog: state: ")


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
