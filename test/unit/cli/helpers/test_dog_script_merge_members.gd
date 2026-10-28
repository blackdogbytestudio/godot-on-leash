# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## Non-func blocks in DogScriptMerge: "signal", "var", "ready_line" (a line that
## must exist inside _ready) and "func_line". New items follow the style guide
## order (see test_dog_script_merge_order.gd); same-kind signals/vars stay together,
## funcs get two blank lines.

const HEAD := "extends CharacterBody2D\n\n\n"
const VAR_LINE := "@onready var _jump: FixtureJump2D = $Jump"
const SIGNAL_LINE := "signal landed(speed: float)"
const CONNECT_LINE := "\t_jump.landed.connect(landed.emit)"
# --- func_line (a line that must exist at the top of a given func) ---------
const UPDATE_LINE := "\t_dog_hpda.update(delta)"
# --- func_line with "match": one line per prefix, -u replaces it ------------
const INIT_PREFIX := "_dog_hpda.init("


func _var(var_name := "_jump") -> Dictionary:
	return {
		"kind": "var",
		"name": var_name,
		"text": "@onready var %s: FixtureJump2D = $Jump" % var_name,
	}


func _signal(signal_name := "landed") -> Dictionary:
	return {
		"kind": "signal",
		"name": signal_name,
		"text": "signal %s(speed: float)" % signal_name,
	}


func _connect(var_name := "_jump", signal_name := "landed") -> Dictionary:
	return {
		"kind": "ready_line",
		"name": "%s.%s" % [var_name, signal_name],
		"text": "\t%s.%s.connect(%s.emit)" % [var_name, signal_name, signal_name],
	}


func _func(func_name := "jump") -> Dictionary:
	return {
		"kind": "func",
		"name": func_name,
		"text": "func %s() -> void:\n\t_jump.%s()" % [func_name, func_name],
	}


func _update(source: String, blocks: Array) -> Dictionary:
	return DogScriptMerge.merge(source, blocks, DogScriptMerge.Mode.UPDATE)


func _force(source: String, blocks: Array) -> Dictionary:
	return DogScriptMerge.merge(source, blocks, DogScriptMerge.Mode.FORCE)


# --- var -------------------------------------------------------------------


func test_adds_var_after_header_with_one_blank_line() -> void:
	var r := DogScriptMerge.merge("extends CharacterBody2D\n", [_var()])
	assert_eq(r.source, "extends CharacterBody2D\n\n" + VAR_LINE + "\n")
	assert_eq(r.report, ["add var _jump"])


func test_added_onready_var_goes_before_existing_funcs() -> void:
	var source := HEAD + "func a() -> void:\n\tpass\n"
	var r := DogScriptMerge.merge(source, [_var()])
	assert_eq(
		r.source,
		"extends CharacterBody2D\n\n" + VAR_LINE + "\n\n\nfunc a() -> void:\n\tpass\n",
	)


func test_skips_existing_var_even_if_it_differs() -> void:
	var source := "extends CharacterBody2D\n\n@onready var _jump = $Other\n"
	var r := DogScriptMerge.merge(source, [_var()])
	assert_eq(r.source, source)
	assert_eq(r.report, ["skip var _jump"])


func test_var_matches_whole_name() -> void:
	var source := "extends CharacterBody2D\n\nvar _jump_high := 1\n"
	var r := DogScriptMerge.merge(source, [_var()])
	assert_eq(r.report, ["add var _jump"])


func test_var_matches_without_onready() -> void:
	var source := "extends CharacterBody2D\n\nvar _jump = null\n"
	var r := DogScriptMerge.merge(source, [_var()])
	assert_eq(r.report, ["skip var _jump"])


func test_var_matches_a_static_var() -> void:
	var source := "extends CharacterBody2D\n\nstatic var _jump = null\n"
	var r := DogScriptMerge.merge(source, [_var()])
	assert_eq(r.report, ["skip var _jump"])


func test_update_replaces_a_var_line_that_differs() -> void:
	var source := (
		"extends CharacterBody2D\n\n@onready var _jump = $Other\n\n\nfunc a() -> void:\n\tpass\n"
	)
	var r := _update(source, [_var()])
	assert_eq(
		r.source,
		"extends CharacterBody2D\n\n" + VAR_LINE + "\n\n\nfunc a() -> void:\n\tpass\n",
	)
	assert_eq(r.report, ["update var _jump"])


# --- signal ----------------------------------------------------------------


func test_adds_signal_after_header() -> void:
	var r := DogScriptMerge.merge("extends CharacterBody2D\n", [_signal()])
	assert_eq(r.source, "extends CharacterBody2D\n\n" + SIGNAL_LINE + "\n")
	assert_eq(r.report, ["add signal landed"])


func test_skips_existing_signal() -> void:
	var source := "extends CharacterBody2D\n\nsignal landed\n"
	var r := DogScriptMerge.merge(source, [_signal()])
	assert_eq(r.source, source)
	assert_eq(r.report, ["skip signal landed"])


func test_signal_matches_whole_name() -> void:
	var source := "extends CharacterBody2D\n\nsignal landed_hard\n"
	var r := DogScriptMerge.merge(source, [_signal()])
	assert_eq(r.report, ["add signal landed"])


func test_update_replaces_a_signal_line_that_differs() -> void:
	var source := "extends CharacterBody2D\n\nsignal landed\n"
	var r := _update(source, [_signal()])
	assert_eq(r.source, "extends CharacterBody2D\n\n" + SIGNAL_LINE + "\n")
	assert_eq(r.report, ["update signal landed"])


# --- ordering and spacing --------------------------------------------------


func test_signals_come_before_vars_regardless_of_block_order() -> void:
	var r := DogScriptMerge.merge("extends CharacterBody2D\n", [_var(), _signal()])
	assert_eq(r.source, "extends CharacterBody2D\n\n" + SIGNAL_LINE + "\n\n" + VAR_LINE + "\n")


func test_same_kind_declarations_stay_together() -> void:
	var r := DogScriptMerge.merge(
		"extends CharacterBody2D\n", [_signal("landed"), _signal("dashed")]
	)
	assert_eq(
		r.source,
		"extends CharacterBody2D\n\nsignal landed(speed: float)\nsignal dashed(speed: float)\n"
	)


func test_func_after_a_var_gets_two_blank_lines() -> void:
	var r := DogScriptMerge.merge("extends CharacterBody2D\n", [_func(), _var()])
	assert_eq(
		r.source,
		"extends CharacterBody2D\n\n" + VAR_LINE + "\n\n\nfunc jump() -> void:\n\t_jump.jump()\n"
	)


# --- ready_line ------------------------------------------------------------


func test_creates_ready_when_it_is_missing() -> void:
	var r := DogScriptMerge.merge("extends CharacterBody2D\n", [_connect()])
	assert_eq(r.source, HEAD + "func _ready() -> void:\n" + CONNECT_LINE + "\n")
	assert_eq(r.report, ["add func _ready", "add connect _jump.landed"])


func test_created_ready_goes_after_vars_and_before_funcs() -> void:
	var r := DogScriptMerge.merge("extends CharacterBody2D\n", [_func(), _connect(), _var()])
	assert_eq(
		r.source,
		(
			"extends CharacterBody2D\n\n" + VAR_LINE + "\n\n\nfunc _ready() -> void:\n"
			+ CONNECT_LINE + "\n\n\nfunc jump() -> void:\n\t_jump.jump()\n"
		)
	)
	assert_eq(
		r.report,
		["add func jump", "add func _ready", "add connect _jump.landed", "add var _jump"],
	)


func test_inserts_connect_under_the_signature_of_an_existing_ready() -> void:
	var source := HEAD + "func _ready() -> void:\n\tpass\n"
	var r := DogScriptMerge.merge(source, [_connect()])
	assert_eq(r.source, HEAD + "func _ready() -> void:\n" + CONNECT_LINE + "\n\tpass\n")
	assert_eq(r.report, ["add connect _jump.landed"])


func test_skips_connect_line_that_is_already_there() -> void:
	var source := HEAD + "func _ready() -> void:\n" + CONNECT_LINE + "\n\tprint(\"hi\")\n"
	var r := DogScriptMerge.merge(source, [_connect()])
	assert_eq(r.source, source)
	assert_eq(r.report, ["skip connect _jump.landed"])


func test_inserts_only_the_missing_connect_lines_in_order() -> void:
	var source := HEAD + "func _ready() -> void:\n\t_dash.dashed.connect(dashed.emit)\n\tpass\n"
	var r := DogScriptMerge.merge(
		source, [_connect("_jump", "landed"), _connect("_dash", "dashed")]
	)
	assert_eq(
		r.source,
		(
			HEAD + "func _ready() -> void:\n\t_jump.landed.connect(landed.emit)\n"
			+ "\t_dash.dashed.connect(dashed.emit)\n\tpass\n"
		)
	)
	assert_eq(r.report, ["add connect _jump.landed", "skip connect _dash.dashed"])


func test_connect_line_in_another_func_does_not_count() -> void:
	var source := (
		HEAD + "func _ready() -> void:\n\tpass\n\n\nfunc other() -> void:\n" + CONNECT_LINE + "\n"
	)
	var r := DogScriptMerge.merge(source, [_connect()])
	assert_eq(r.report, ["add connect _jump.landed"])


func test_ready_with_body_on_the_same_line_is_an_error() -> void:
	var source := HEAD + "func _ready(): pass\n"
	var r := DogScriptMerge.merge(source, [_connect()])
	assert_string_contains(r.error, "_ready")
	assert_string_contains(r.error, "line 4")
	assert_eq(r.source, source)
	assert_eq(r.report, [])


# --- everything together ---------------------------------------------------


func test_running_twice_with_every_kind_changes_nothing() -> void:
	var blocks := [_signal(), _var(), _connect(), _func()]
	var first := DogScriptMerge.merge("extends CharacterBody2D\n", blocks)
	var second := DogScriptMerge.merge(first.source, blocks)
	assert_eq(second.source, first.source)
	assert_eq(
		second.report,
		["skip signal landed", "skip var _jump", "skip connect _jump.landed", "skip func jump"]
	)


func test_force_orders_signals_vars_ready_then_funcs_below_the_header() -> void:
	var source := "@tool\nextends CharacterBody2D\n\n\nfunc old() -> void:\n\tpass\n"
	var r := _force(source, [_func(), _signal(), _connect(), _var()])
	assert_eq(
		r.source,
		(
			"@tool\nextends CharacterBody2D\n\n" + SIGNAL_LINE + "\n\n" + VAR_LINE + "\n\n\n"
			+ "func _ready() -> void:\n" + CONNECT_LINE + "\n\n\nfunc jump() -> void:\n"
			+ "\t_jump.jump()\n"
		)
	)
	assert_false(r.source.contains("old"))


func _func_line(func_name: String, line_name: String, text: String) -> Dictionary:
	return { "kind": "func_line", "func": func_name, "name": line_name, "text": text }


func _update_line() -> Dictionary:
	return _func_line("_physics_process", "_dog_hpda.update", UPDATE_LINE)


func test_func_line_creates_physics_process_with_delta_when_missing() -> void:
	var r := DogScriptMerge.merge("extends CharacterBody2D\n", [_update_line()])
	assert_eq(
		r.source,
		HEAD + "func _physics_process(delta: float) -> void:\n" + UPDATE_LINE + "\n",
	)
	assert_eq(r.report, ["add func _physics_process", "add line _dog_hpda.update"])
	assert_eq(r.error, "")


func test_func_line_goes_to_the_top_of_an_existing_body() -> void:
	var source := HEAD + "func _physics_process(delta: float) -> void:\n\tmove_and_slide()\n"
	var r := DogScriptMerge.merge(source, [_update_line()])
	assert_eq(
		r.source,
		(
			HEAD + "func _physics_process(delta: float) -> void:\n" + UPDATE_LINE + "\n"
			+ "\tmove_and_slide()\n"
		),
	)
	assert_eq(r.report, ["add line _dog_hpda.update"])


func test_func_line_already_there_is_skipped() -> void:
	var source := (
		HEAD + "func _physics_process(delta: float) -> void:\n\tmove_and_slide()\n"
		+ UPDATE_LINE + "\n"
	)
	var r := DogScriptMerge.merge(source, [_update_line()])
	assert_eq(r.source, source)
	assert_eq(r.report, ["skip line _dog_hpda.update"])


func test_func_line_in_a_one_line_func_is_an_error() -> void:
	var source := HEAD + "func _physics_process(delta): pass\n"
	var r := DogScriptMerge.merge(source, [_update_line()])
	assert_string_contains(r.error, "_physics_process")
	assert_string_contains(r.error, "line 4")
	assert_eq(r.source, source)
	assert_eq(r.report, [])


func test_func_line_on_ready_matches_ready_line() -> void:
	var as_func_line := _func_line("_ready", "_jump.landed", CONNECT_LINE)
	for source in ["extends CharacterBody2D\n", HEAD + "func _ready() -> void:\n\tpass\n"]:
		assert_eq(
			DogScriptMerge.merge(source, [as_func_line]).source,
			DogScriptMerge.merge(source, [_connect()]).source
		)


func test_func_lines_for_two_funcs_go_to_their_own_funcs() -> void:
	var source := (
		HEAD + "func _ready() -> void:\n\tpass\n\n\nfunc _physics_process(delta: float) -> void:\n"
		+ "\tpass\n"
	)
	var r := DogScriptMerge.merge(
		source,
		[_update_line(), _func_line("_ready", "_dog_hpda.init", "\t_dog_hpda.init(idle_state)")],
	)
	assert_eq(
		r.source,
		(
			HEAD + "func _ready() -> void:\n\t_dog_hpda.init(idle_state)\n\tpass\n\n\n"
			+ "func _physics_process(delta: float) -> void:\n" + UPDATE_LINE + "\n\tpass\n"
		)
	)
	assert_eq(r.report, ["add line _dog_hpda.update", "add line _dog_hpda.init"])


func _init_line(state: String) -> Dictionary:
	var line := _func_line("_ready", "_dog_hpda.init", "\t_dog_hpda.init(%s)" % state)
	line["match"] = INIT_PREFIX
	return line


func test_match_keeps_a_differing_line_in_add_mode() -> void:
	var source := HEAD + "func _ready() -> void:\n\t_dog_hpda.init(idle_state)\n"
	var r := DogScriptMerge.merge(source, [_init_line("run_state")])
	assert_eq(r.source, source)
	assert_eq(r.report, ["skip line _dog_hpda.init"])


func test_match_replaces_a_differing_line_in_update_mode() -> void:
	var source := (
		HEAD + "func _ready() -> void:\n\tprint(1)\n\t_dog_hpda.init(idle_state)\n\tprint(2)\n"
	)
	var r := _update(source, [_init_line("run_state")])
	assert_eq(
		r.source,
		HEAD + "func _ready() -> void:\n\tprint(1)\n\t_dog_hpda.init(run_state)\n\tprint(2)\n",
	)
	assert_eq(r.report, ["update line _dog_hpda.init"])


func test_match_skips_an_equal_line_in_update_mode() -> void:
	var source := HEAD + "func _ready() -> void:\n\t_dog_hpda.init(run_state)\n"
	var r := _update(source, [_init_line("run_state")])
	assert_eq(r.source, source)
	assert_eq(r.report, ["skip line _dog_hpda.init"])


func test_match_adds_at_the_top_when_no_line_has_the_prefix() -> void:
	var source := HEAD + "func _ready() -> void:\n\tpass\n"
	var r := _update(source, [_init_line("run_state")])
	assert_eq(r.source, HEAD + "func _ready() -> void:\n\t_dog_hpda.init(run_state)\n\tpass\n")
	assert_eq(r.report, ["add line _dog_hpda.init"])
