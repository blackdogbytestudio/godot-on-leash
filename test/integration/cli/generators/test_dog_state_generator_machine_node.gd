extends GutTest
## DogStateGenerator.generate adding the machine node to a scene that has none:
## writes in res://scenes/tmp (removed by every test). The folder settings are
## pointed at it.

const Command := preload("res://addons/leash/cli/commands/dog_state_command.gd")
const Generator := preload("res://addons/leash/cli/generators/dog_state_generator.gd")
const ROOT_DIR := "scenes/tmp/state_machine_node_test"
const ROOT := "res://" + ROOT_DIR
const KEYS := [DogSettings.IMPLICIT_FOLDER, DogSettings.EXPLICIT_FOLDER]
const HPDA := "res://addons/leash/components/machines/dog_hpda.gd"
const FSM := "res://addons/leash/components/machines/dog_fsm.gd"
const ARGS := ["enemy", "hpda", "alive", ".grounded"]
const HPDA_NODE := "[node name=\"DogHPDA\" type=\"Node\" parent=\".\"]"

var _saved := {}


func before_each() -> void:
	_saved.clear()
	for key in KEYS:
		if ProjectSettings.has_setting(key):
			_saved[key] = ProjectSettings.get_setting(key)
		ProjectSettings.set_setting(key, ROOT_DIR)
	_remove(ROOT)


func after_each() -> void:
	_remove(ROOT)
	DirAccess.remove_absolute("res://scenes/tmp")  # only succeeds when empty
	for key in KEYS:
		if _saved.has(key):
			ProjectSettings.set_setting(key, _saved[key])
		elif ProjectSettings.has_setting(key):
			ProjectSettings.clear(key)


func _generate(args: Array) -> DogStateGenerator.Result:
	var request := Command.parse_request(PackedStringArray(args))
	assert_eq(request.error, "", "unexpected parse error: %s" % request.error)
	return Generator.generate(Command.options_for(request))


func _dir() -> String:
	return ROOT.path_join("enemy")


func _scene_path() -> String:
	return _dir().path_join("enemy.tscn")


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Writes enemy.tscn, whose root has enemy.gd (with `host_source`), followed by
## the `children` lines as they are. Returns the scene text.
func _scene(children := "", host_source := "extends Node\n") -> String:
	DirAccess.make_dir_recursive_absolute(_dir())
	var host_path := _dir().path_join("enemy.gd")
	_write(host_path, host_source)
	var text := (
		"[gd_scene format=3]\n\n"
		+ "[ext_resource type=\"Script\" path=\"%s\" id=\"host\"]\n" % host_path
		+ "[ext_resource type=\"Script\" path=\"%s\" id=\"fsm\"]\n" % FSM
		+ "[ext_resource type=\"Script\" path=\"%s\" id=\"hpda\"]\n\n" % HPDA
		+ "[node name=\"Enemy\" type=\"Node\"]\nscript = ExtResource(\"host\")\n"
		+ children
	)
	_write(_scene_path(), text)
	return text


func _child(node_name: String, script_id: String) -> String:
	return "\n[node name=\"%s\" type=\"Node\" parent=\".\"]\nscript = ExtResource(\"%s\")\n" % [
		node_name,
		script_id,
	]


func _remove(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	for sub in dir.get_directories():
		_remove(path.path_join(sub))
	DirAccess.remove_absolute(path)


func test_a_scene_without_machine_gets_the_node_and_the_rest_goes_on() -> void:
	_scene()
	var result := _generate(ARGS)
	assert_eq(result.error, "")
	assert_eq(result.machine_node, "DogHPDA")
	assert_eq(result.report[0], "add node DogHPDA")
	var scene := _text(_scene_path())
	assert_string_contains(scene, HPDA_NODE + "\nscript = ExtResource(\"hpda\")\n")
	assert_eq(scene.count("[ext_resource"), 3)
	assert_string_contains(_text(_dir().path_join("enemy.gd")), "= $DogHPDA\n")
	assert_true(FileAccess.file_exists(_dir().path_join("states/enemy_grounded_state.gd")))


func test_the_machine_script_is_added_with_its_uid_when_the_scene_lacks_it() -> void:
	DirAccess.make_dir_recursive_absolute(_dir())
	var host_path := _dir().path_join("enemy.gd")
	_write(host_path, "extends Node\n")
	_write(_scene_path(), (
		"[gd_scene format=3]\n\n"
		+ "[ext_resource type=\"Script\" path=\"%s\" id=\"host\"]\n\n" % host_path
		+ "[node name=\"Enemy\" type=\"Node\"]\nscript = ExtResource(\"host\")\n"
	))
	assert_eq(_generate(ARGS).error, "")
	var uid := ResourceUID.id_to_text(ResourceLoader.get_resource_uid(HPDA))
	var line := "[ext_resource type=\"Script\" uid=\"%s\" path=\"%s\"" % [uid, HPDA]
	assert_string_contains(_text(_scene_path()), line)


func test_a_machine_of_another_type_is_an_error_and_nothing_is_written() -> void:
	var before := _scene(_child("Brain", "fsm"))
	var result := _generate(ARGS)
	assert_string_contains(result.error, "another type: Brain (DogFSM)")
	assert_eq(_text(_scene_path()), before)
	assert_false(DirAccess.dir_exists_absolute(_dir().path_join("states")))
	assert_eq(_text(_dir().path_join("enemy.gd")), "extends Node\n")


func test_a_scene_with_the_machine_is_not_changed() -> void:
	var before := _scene(_child("Brain", "hpda"))
	var result := _generate(ARGS)
	assert_eq(result.error, "")
	assert_eq(result.machine_node, "Brain")
	assert_false("add node DogHPDA" in result.report)
	assert_eq(_text(_scene_path()), before)


func test_force_does_not_touch_the_scene() -> void:
	var before := _scene(_child("Brain", "hpda"))
	_generate(ARGS)
	assert_eq(_generate(ARGS + ["-f"]).error, "")
	assert_eq(_text(_scene_path()), before)


func test_running_again_does_not_add_a_second_node() -> void:
	_scene()
	_generate(ARGS)
	var second := _generate(ARGS)
	assert_eq(second.error, "")
	assert_eq(second.machine_node, "DogHPDA")
	assert_false("add node DogHPDA" in second.report)
	assert_eq(_text(_scene_path()).count(HPDA_NODE), 1)


func test_an_error_later_on_leaves_the_scene_as_it_was() -> void:
	var before := _scene("", "extends Node\n\n\nfunc _ready(): pass\n")
	var result := _generate(ARGS)
	assert_string_contains(result.error, "_ready")
	assert_eq(_text(_scene_path()), before)
	assert_false(DirAccess.dir_exists_absolute(_dir().path_join("states")))


func test_a_child_named_like_the_machine_without_its_script_is_an_error() -> void:
	var before := _scene("\n[node name=\"DogHPDA\" type=\"Node\" parent=\".\"]\n")
	var result := _generate(ARGS)
	assert_string_contains(result.error, "already has a node named DogHPDA")
	assert_eq(_text(_scene_path()), before)


func test_godot_loads_the_edited_scene_with_the_machine_attached() -> void:
	_scene()
	_generate(ARGS)
	var mode := ResourceLoader.CACHE_MODE_IGNORE
	var packed := ResourceLoader.load(_scene_path(), "PackedScene", mode) as PackedScene
	var root := packed.instantiate()
	var machine := root.get_node("DogHPDA")
	assert_eq((machine.get_script() as Script).get_global_name(), &"DogHPDA")
	root.free()
