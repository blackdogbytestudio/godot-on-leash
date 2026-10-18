# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## Where DogApiMerge puts new members: Godot style guide order. A new member goes
## after the last member of its category; without one, before the first member of
## a later category; without one, at the end. What exists is never reordered.

const HEAD := "extends CharacterBody2D\n"
const SIGNAL_LINE := "signal landed(speed: float)"
const VAR_LINE := "@onready var _jump: Node = $Jump"
const CONNECT_LINE := "\t_jump.ready.connect(landed.emit)"
const UPDATE_LINE := "\tmove_and_slide()"
const JUMP := "func jump() -> void:\n\t_jump.jump()"
const GODOT_TEMPLATE := """extends CharacterBody2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
"""


func _signal(signal_name := "landed") -> Dictionary:
	return {
		"kind": "signal",
		"name": signal_name,
		"text": "signal %s(speed: float)" % signal_name,
	}


func _var() -> Dictionary:
	return { "kind": "var", "name": "_jump", "text": VAR_LINE }


func _connect() -> Dictionary:
	return { "kind": "ready_line", "name": "_jump.landed", "text": CONNECT_LINE }


func _update_line() -> Dictionary:
	return {
		"kind": "func_line",
		"func": "_physics_process",
		"name": "move_and_slide",
		"text": UPDATE_LINE,
	}


func _func(func_name := "jump") -> Dictionary:
	return {
		"kind": "func",
		"name": func_name,
		"text": "func %s() -> void:\n\t_jump.%s()" % [func_name, func_name],
	}


func _all() -> Array:
	return [_func(), _update_line(), _connect(), _var(), _signal()]


func _compile(source: String) -> int:
	var script := GDScript.new()
	script.source_code = source
	return script.reload()


# --- where things go -------------------------------------------------------


func test_empty_file_gets_no_leading_blank_lines() -> void:
	var r := DogApiMerge.merge("", [_func(), _signal()])
	assert_eq(r.source, SIGNAL_LINE + "\n\n\n" + JUMP + "\n")


func test_header_only_file_gets_the_style_guide_order() -> void:
	var r := DogApiMerge.merge(HEAD, _all())
	assert_eq(
		r.source,
		(
			HEAD + "\n" + SIGNAL_LINE + "\n\n" + VAR_LINE + "\n\n\n"
			+ "func _ready() -> void:\n" + CONNECT_LINE + "\n\n\n"
			+ "func _physics_process(delta: float) -> void:\n" + UPDATE_LINE + "\n\n\n"
			+ JUMP + "\n"
		)
	)


func test_godot_template_keeps_its_funcs_and_comments_in_place() -> void:
	var r := DogApiMerge.merge(GODOT_TEMPLATE, [_var(), _update_line(), _connect(), _func()])
	assert_eq(r.source, """extends CharacterBody2D

@onready var _jump: Node = $Jump


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_jump.ready.connect(landed.emit)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	move_and_slide()


func jump() -> void:
	_jump.jump()
""")

# gdstyle:ignore-file=quality/max-function-length
# gdstyle:ignore-file=quality/unnecessary-pass
func test_file_already_in_order_gets_each_new_member_in_its_group() -> void:
	var source := """extends CharacterBody2D

signal died

const SPEED := 200.0

@export var hp := 3
var speed := 200
@onready var _a: Node = $A


func _ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	pass


func run() -> void:
	pass
"""
	var r := DogApiMerge.merge(source, [_func(), _update_line(), _var(), _signal()])
	assert_eq(r.source, """extends CharacterBody2D

signal died
signal landed(speed: float)

const SPEED := 200.0

@export var hp := 3
var speed := 200
@onready var _a: Node = $A
@onready var _jump: Node = $Jump


func _ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	move_and_slide()
	pass


func run() -> void:
	pass


func jump() -> void:
	_jump.jump()
""")


func test_out_of_order_file_is_not_reordered() -> void:
	var source := (
		"extends CharacterBody2D\n\nvar speed := 200\nsignal died\n\n\nfunc _ready() -> void:\n"
		+ "\tpass\n"
	)
	var blocks := [
		{ "kind": "signal", "name": "landed", "text": "signal landed" },
		{
			"kind": "var",
			"name": "_dog_hpda",
			"text": "@onready var _dog_hpda: DogHPDA = $DogHPDA",
		},
		{ "kind": "func", "name": "jump", "text": "func jump() -> void:\n\t_dog_hpda.jump()" },
	]
	var r := DogApiMerge.merge(source, blocks)
	assert_eq(r.source, """extends CharacterBody2D

var speed := 200
signal died
signal landed

@onready var _dog_hpda: DogHPDA = $DogHPDA


func _ready() -> void:
	pass


func jump() -> void:
	_dog_hpda.jump()
""")


func test_created_physics_process_goes_after_ready_and_before_custom_funcs() -> void:
	var source := HEAD + "\n\nfunc _ready() -> void:\n\tpass\n\n\nfunc run() -> void:\n\tpass\n"
	var r := DogApiMerge.merge(source, [_update_line()])
	assert_eq(
		r.source,
		(
			HEAD + "\n\nfunc _ready() -> void:\n\tpass\n\n\n"
			+ "func _physics_process(delta: float) -> void:\n" + UPDATE_LINE + "\n\n\n"
			+ "func run() -> void:\n\tpass\n"
		)
	)


func test_multiline_enum_and_annotation_on_its_own_line_stay_whole() -> void:
	var source := "extends Node\n\nenum State {\n\tIDLE,\n\tRUN,\n}\n@export\nvar hp := 3\n"
	var blocks := [
		{ "kind": "signal", "name": "landed", "text": "signal landed" },
		{ "kind": "var", "name": "_x", "text": "@onready var _x: Node = $X" },
	]
	var r := DogApiMerge.merge(source, blocks)
	assert_eq(
		r.source,
		(
			"extends Node\n\nsignal landed\n\nenum State {\n\tIDLE,\n\tRUN,\n}\n@export\n"
			+ "var hp := 3\n\n@onready var _x: Node = $X\n"
		)
	)


# --- running again, FORCE and compiling --------------------------------------


func test_running_twice_on_the_template_only_skips() -> void:
	var first := DogApiMerge.merge(GODOT_TEMPLATE, _all())
	var second := DogApiMerge.merge(first.source, _all())
	assert_eq(second.source, first.source)
	assert_eq(
		second.report,
		[
			"skip func jump",
			"skip line move_and_slide",
			"skip connect _jump.landed",
			"skip var _jump",
			"skip signal landed",
		]
	)


func test_force_rebuilds_in_style_guide_order() -> void:
	var source := (
		HEAD + "\nfunc old() -> void:\n\tpass\nvar x := 1\nsignal s\n\n\nfunc _ready() -> void:\n"
		+ "\tpass\n"
	)
	var forced := DogApiMerge.merge(source, _all(), DogApiMerge.Mode.FORCE)
	assert_eq(forced.source, DogApiMerge.merge(HEAD, _all()).source)


func test_generated_text_compiles() -> void:
	for source in [
		HEAD,
		GODOT_TEMPLATE,
		HEAD + "\nvar speed := 200\nsignal died\n\n\nfunc _ready() -> void:\n\tpass\n",
	]:
		for mode in [DogApiMerge.Mode.ADD, DogApiMerge.Mode.FORCE]:
			var r := DogApiMerge.merge(
				source,
				[_signal(), _var(), _connect(), _update_line()],
				mode,
			)
			assert_eq(_compile(r.source), OK, "mode %d:\n%s" % [mode, r.source])
