# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogStateGenerator.build against a real scene in test/doubles/state: the hero
## scene (class_name Hero, a DogHPDA child named Brain) and its states, already
## generated and registered. build never writes, so the fixture stays untouched.

const ROOT := "res://test/doubles/state/scenes"
const ARGS := ["hpda", "hero", "alive", ".grounded", "dead"]


func _build(extra: Array = []) -> DogStateGenerator.Result:
	var request := DogStateCommand.parse_request(PackedStringArray(ARGS + extra))
	assert_eq(request.error, "", "unexpected parse error: %s" % request.error)
	return DogStateGenerator.build(DogStateCommand.options_for(request, ROOT))


## The host is the global class Hero already, so compile it without its class_name.
func _compile(source: String) -> int:
	var script := GDScript.new()
	script.source_code = source.replace("class_name Hero\n", "")
	return script.reload()


func _assert_in_order(source: String, parts: Array) -> void:
	var at := -1
	for part in parts:
		var found := source.find(part)
		assert_gt(found, at, "'%s' out of order in:\n%s" % [part, source])
		at = found


func test_add_result_compiles_in_style_guide_order_and_keeps_user_code() -> void:
	var result := _build()
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
	var first := _build()
	var blocks := DogStateGenerator.host_blocks(
		"hero",
		DogStateTree.parse(PackedStringArray(ARGS.slice(2))),
		"DogHPDA",
		"Brain",
		"grounded",
	)
	var second := DogApiMerge.merge(first.host_source, blocks)
	assert_eq(second.source, first.host_source)
	for line in second.report:
		assert_true(line.begins_with("skip "), line)


func test_force_result_compiles_and_lists_what_it_drops() -> void:
	var result := _build(["-f"])
	assert_eq(result.error, "")
	assert_eq(_compile(result.host_source), OK, result.host_source)
	_assert_in_order(result.host_source, [
		"class_name Hero", "extends CharacterBody2D", "var alive_state", "@onready var _dog_hpda",
		"func _ready() -> void:", "func _physics_process(delta: float) -> void:",
	])
	assert_false(result.host_source.contains("jump"))
	assert_eq(result.delete_dir, ROOT + "/hero/states")
	for line in [
		"drop file states/hero_state.gd",
		"drop file states/hero_alive_state.gd",
		"drop var speed",
		"drop func jump",
	]:
		assert_has(result.report, line)
	assert_eq(result.files.size(), 4)


func test_build_never_writes() -> void:
	var before := FileAccess.get_file_as_string(ROOT + "/hero/hero.gd")
	_build(["-f"])
	assert_eq(FileAccess.get_file_as_string(ROOT + "/hero/hero.gd"), before)
	assert_true(FileAccess.file_exists(ROOT + "/hero/states/hero_dead_state.gd"))
