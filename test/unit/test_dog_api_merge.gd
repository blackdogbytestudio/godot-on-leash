# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## ADD (default): add the funcs that are missing, matching by name only.
## UPDATE (-u): also replace existing funcs whose text differs; early error, and
## nothing changes, if a func that would be replaced looks cut in the middle.
## FORCE (-f): keep the header and rewrite everything below it.

const HEAD := "extends CharacterBody2D\n\n\n"
const JUMP := "func jump() -> void:\n\t_dog_jump_2d.jump()"


func _block(func_name: String) -> Dictionary:
	return _block_text(
		func_name,
		"func %s() -> void:\n\t_dog_jump_2d.%s()" % [func_name, func_name]
	)


func _block_text(func_name: String, text: String) -> Dictionary:
	return { "name": func_name, "text": text }


func _update(source: String, blocks: Array) -> Dictionary:
	return DogApiMerge.merge(source, blocks, DogApiMerge.Mode.UPDATE)


func _force(source: String, blocks: Array) -> Dictionary:
	return DogApiMerge.merge(source, blocks, DogApiMerge.Mode.FORCE)


# --- ADD (default): add what is missing ------------------------------------


func test_adds_missing_func_after_header() -> void:
	var r := DogApiMerge.merge("extends CharacterBody2D\n", [_block("jump")])
	assert_eq(
		r.source,
		"extends CharacterBody2D\n\n\nfunc jump() -> void:\n\t_dog_jump_2d.jump()\n",
	)
	assert_eq(r.report, ["add func jump"])
	assert_eq(r.error, "")


func test_separates_new_funcs_with_two_blank_lines() -> void:
	var r := DogApiMerge.merge("extends CharacterBody2D\n", [_block("jump"), _block("run")])
	assert_eq(
		r.source,
		(
			"extends CharacterBody2D\n\n\nfunc jump() -> void:\n\t_dog_jump_2d.jump()\n\n\n"
			+ "func run() -> void:\n\t_dog_jump_2d.run()\n"
		)
	)


func test_skips_func_that_already_exists() -> void:
	var source := "extends CharacterBody2D\n\n\nfunc jump() -> void:\n\tprint(\"mine\")\n"
	var r := DogApiMerge.merge(source, [_block("jump")])
	assert_eq(r.source, source)
	assert_eq(r.report, ["skip func jump"])


func test_keeps_edited_body_and_adds_the_other_func() -> void:
	var source := "extends CharacterBody2D\n\n\nfunc jump() -> void:\n\tprint(\"mine\")\n"
	var r := DogApiMerge.merge(source, [_block("jump"), _block("run")])
	assert_string_contains(r.source, "\tprint(\"mine\")\n")
	assert_string_contains(r.source, "func run() -> void:")
	assert_eq(r.report, ["skip func jump", "add func run"])


func test_matches_whole_name_not_prefix() -> void:
	var source := "extends CharacterBody2D\n\n\nfunc jump_high() -> void:\n\tpass\n"
	var r := DogApiMerge.merge(source, [_block("jump")])
	assert_eq(r.report, ["add func jump"])


func test_ignores_func_name_inside_a_comment() -> void:
	var source := "extends CharacterBody2D\n# func jump() was removed\n"
	var r := DogApiMerge.merge(source, [_block("jump")])
	assert_eq(r.report, ["add func jump"])


func test_normalizes_trailing_blank_lines_to_two() -> void:
	var r := DogApiMerge.merge("extends CharacterBody2D\n\n\n\n\n", [_block("jump")])
	assert_eq(
		r.source,
		"extends CharacterBody2D\n\n\nfunc jump() -> void:\n\t_dog_jump_2d.jump()\n",
	)


func test_handles_source_without_final_newline() -> void:
	var r := DogApiMerge.merge("extends CharacterBody2D", [_block("jump")])
	assert_eq(
		r.source,
		"extends CharacterBody2D\n\n\nfunc jump() -> void:\n\t_dog_jump_2d.jump()\n",
	)


func test_no_blocks_leaves_source_alone() -> void:
	var source := "extends CharacterBody2D\n"
	var r := DogApiMerge.merge(source, [])
	assert_eq(r.source, source)
	assert_eq(r.report, [])


func test_running_twice_changes_nothing_the_second_time() -> void:
	var first := DogApiMerge.merge("extends CharacterBody2D\n", [_block("jump"), _block("run")])
	var second := DogApiMerge.merge(first.source, [_block("jump"), _block("run")])
	assert_eq(second.source, first.source)
	assert_eq(second.report, ["skip func jump", "skip func run"])


func test_add_mode_does_not_validate_bodies() -> void:
	var source := HEAD + "func jump() -> void:\n\tfoo()\n# bar()\n\tbaz()\n"
	var r := DogApiMerge.merge(source, [_block("jump")])
	assert_eq(r.error, "")
	assert_eq(r.source, source)
	assert_eq(r.report, ["skip func jump"])


# --- UPDATE (-u): replace funcs whose text differs -------------------------


func test_update_replaces_edited_body() -> void:
	var source := HEAD + "func jump() -> void:\n\tprint(\"mine\")\n\t_dog_jump_2d.jump()\n"
	var r := _update(source, [_block("jump")])
	assert_eq(r.source, HEAD + JUMP + "\n")
	assert_eq(r.report, ["update func jump"])
	assert_eq(r.error, "")


func test_update_skips_func_that_is_already_equal() -> void:
	var source := HEAD + JUMP + "\n"
	var r := _update(source, [_block("jump")])
	assert_eq(r.source, source)
	assert_eq(r.report, ["skip func jump"])


func test_update_replaces_changed_signature() -> void:
	var source := HEAD + JUMP + "\n"
	var changed := "func jump(power: float) -> void:\n\t_dog_jump_2d.jump(power)"
	var r := _update(source, [_block_text("jump", changed)])
	assert_eq(r.source, HEAD + changed + "\n")
	assert_eq(r.report, ["update func jump"])


func test_update_keeps_neighbor_funcs_and_spacing() -> void:
	var source := (
		HEAD + "func a() -> void:\n\tpass\n\n\nfunc jump() -> void:\n\tprint(\"x\")\n\n\n"
		+ "func b() -> void:\n\tpass\n"
	)
	var r := _update(source, [_block("jump")])
	assert_eq(
		r.source,
		HEAD + "func a() -> void:\n\tpass\n\n\n" + JUMP + "\n\n\nfunc b() -> void:\n\tpass\n"
	)


func test_update_keeps_blank_lines_after_the_last_func() -> void:
	var source := HEAD + "func jump() -> void:\n\tprint(\"x\")\n\n\n"
	var r := _update(source, [_block("jump")])
	assert_eq(r.source, HEAD + JUMP + "\n\n\n")


func test_update_blank_line_inside_body_is_still_the_body() -> void:
	var source := (
		HEAD + "func jump() -> void:\n\tvar a := 1\n\n\tprint(a)\n\n\nfunc b() -> void:\n\tpass\n"
	)
	var r := _update(source, [_block("jump")])
	assert_eq(r.source, HEAD + JUMP + "\n\n\nfunc b() -> void:\n\tpass\n")


func test_update_stops_before_a_following_onready_var() -> void:
	var source := HEAD + "func jump() -> void:\n\tprint(\"x\")\n\n\n@onready var _x = $X\n"
	var r := _update(source, [_block("jump")])
	assert_eq(r.source, HEAD + JUMP + "\n\n\n@onready var _x = $X\n")


func test_update_stops_before_the_doc_comment_of_the_next_func() -> void:
	var source := (
		HEAD + "func jump() -> void:\n\tprint(\"x\")\n\n\n## Runs.\nfunc run() -> void:\n\tpass\n"
	)
	var r := _update(source, [_block("jump")])
	assert_eq(r.source, HEAD + JUMP + "\n\n\n## Runs.\nfunc run() -> void:\n\tpass\n")


func test_update_handles_a_single_blank_line_between_funcs() -> void:
	var source := HEAD + "func jump() -> void:\n\tprint(\"x\")\n\nfunc b() -> void:\n\tpass\n"
	var r := _update(source, [_block("jump")])
	assert_eq(r.source, HEAD + JUMP + "\n\nfunc b() -> void:\n\tpass\n")


func test_update_handles_no_blank_line_between_funcs() -> void:
	var source := HEAD + "func jump() -> void:\n\tprint(\"x\")\nfunc b() -> void:\n\tpass\n"
	var r := _update(source, [_block("jump")])
	assert_eq(r.source, HEAD + JUMP + "\nfunc b() -> void:\n\tpass\n")


func test_update_replaces_a_one_line_func() -> void:
	var source := HEAD + "func jump() -> void: pass\n\n\nfunc b() -> void:\n\tpass\n"
	var r := _update(source, [_block("jump")])
	assert_eq(r.source, HEAD + JUMP + "\n\n\nfunc b() -> void:\n\tpass\n")


func test_update_adds_missing_updates_changed_and_skips_equal() -> void:
	var source := (
		HEAD + "func jump() -> void:\n\tprint(\"x\")\n\n\nfunc run() -> void:\n"
		+ "\t_dog_jump_2d.run()\n"
	)
	var r := _update(source, [_block("jump"), _block("run"), _block("dash")])
	assert_eq(
		r.source,
		(
			HEAD + JUMP + "\n\n\nfunc run() -> void:\n\t_dog_jump_2d.run()\n\n\n"
			+ "func dash() -> void:\n\t_dog_jump_2d.dash()\n"
		)
	)
	assert_eq(r.report, ["update func jump", "skip func run", "add func dash"])


func test_update_leaves_funcs_that_are_not_targets() -> void:
	var source := HEAD + "func old() -> void:\n\tpass\n\n\nfunc jump() -> void:\n\tprint(\"x\")\n"
	var r := _update(source, [_block("jump")])
	assert_eq(r.source, HEAD + "func old() -> void:\n\tpass\n\n\n" + JUMP + "\n")
	assert_eq(r.report, ["update func jump"])


func test_update_ignores_a_malformed_func_that_is_not_a_target() -> void:
	var source := (
		HEAD + "func helper() -> void:\n\tpass\n# stray\n\tpass\n\n\nfunc jump() -> void:\n"
		+ "\tprint(\"x\")\n"
	)
	var r := _update(source, [_block("jump")])
	assert_eq(r.error, "")
	assert_string_contains(r.source, "# stray\n\tpass\n")
	assert_string_contains(r.source, JUMP)


func test_update_twice_skips_everything_the_second_time() -> void:
	var source := HEAD + "func jump() -> void:\n\tprint(\"x\")\n"
	var first := _update(source, [_block("jump"), _block("run")])
	var second := _update(first.source, [_block("jump"), _block("run")])
	assert_eq(second.source, first.source)
	assert_eq(second.report, ["skip func jump", "skip func run"])


# --- UPDATE (-u): early error, nothing changes -----------------------------


func test_update_errors_on_a_column_zero_comment_inside_the_body() -> void:
	var source := (
		HEAD + "func jump() -> void:\n\tfoo()\n# bar()\n\tbaz()\n\n\nfunc b() -> void:\n\tpass\n"
	)
	var r := _update(source, [_block("jump")])
	assert_string_contains(r.error, "jump")
	assert_string_contains(r.error, "line 4")
	assert_eq(r.source, source)
	assert_eq(r.report, [])


func test_update_errors_on_text_at_column_zero_inside_the_body() -> void:
	var source := (
		HEAD + "func jump() -> void:\n\tvar t = \"\"\"\ntexto na coluna zero\n\"\"\"\n"
		+ "\tprint(t)\n\n\nfunc b() -> void:\n\tpass\n"
	)
	var r := _update(source, [_block("jump")])
	assert_string_contains(r.error, "jump")
	assert_string_contains(r.error, "line 4")
	assert_eq(r.source, source)
	assert_eq(r.report, [])


func test_update_error_changes_nothing_even_for_the_other_funcs() -> void:
	var source := (
		HEAD + "func a() -> void:\n\tprint(\"x\")\n\n\nfunc jump() -> void:\n\tfoo()\n# bar()\n"
		+ "\tbaz()\n"
	)
	var r := _update(source, [_block("a"), _block("jump")])
	assert_string_contains(r.error, "jump")
	assert_string_contains(r.error, "line 8")
	assert_eq(r.source, source)
	assert_eq(r.report, [])


# --- FORCE (-f): keep the header, rewrite the rest -------------------------


func test_force_on_header_only_file_matches_default_mode() -> void:
	var source := "extends CharacterBody2D\n"
	var forced := _force(source, [_block("jump")])
	var normal := DogApiMerge.merge(source, [_block("jump")])
	assert_eq(forced.source, normal.source)


func test_force_drops_everything_below_the_header() -> void:
	var source := "extends CharacterBody2D\n\n\nfunc old() -> void:\n\tpass\n"
	var r := _force(source, [_block("jump")])
	assert_eq(
		r.source,
		"extends CharacterBody2D\n\n\nfunc jump() -> void:\n\t_dog_jump_2d.jump()\n",
	)
	assert_eq(r.error, "")


func test_force_rewrites_a_func_that_already_exists() -> void:
	var source := "extends CharacterBody2D\n\n\nfunc jump() -> void:\n\tprint(\"mine\")\n"
	var r := _force(source, [_block("jump")])
	assert_eq(
		r.source,
		"extends CharacterBody2D\n\n\nfunc jump() -> void:\n\t_dog_jump_2d.jump()\n",
	)


func test_force_keeps_annotations_class_name_and_doc_comment() -> void:
	var source := (
		"@tool\nclass_name Player\nextends CharacterBody2D\n## The player.\n\n\n"
		+ "func old() -> void:\n\tpass\n"
	)
	var r := _force(source, [_block("jump")])
	assert_eq(
		r.source,
		(
			"@tool\nclass_name Player\nextends CharacterBody2D\n## The player.\n\n\n"
			+ "func jump() -> void:\n\t_dog_jump_2d.jump()\n"
		)
	)


func test_force_keeps_class_name_written_after_extends() -> void:
	var source := "extends CharacterBody2D\nclass_name Player\n\n\nfunc old() -> void:\n\tpass\n"
	var r := _force(source, [_block("jump")])
	assert_string_contains(r.source, "extends CharacterBody2D\nclass_name Player\n")
	assert_false(r.source.contains("old"))


func test_force_header_ends_at_the_first_member() -> void:
	var source := "extends CharacterBody2D\n\nvar speed := 1\n\n\nfunc old() -> void:\n\tpass\n"
	var r := _force(source, [_block("jump")])
	assert_eq(
		r.source,
		"extends CharacterBody2D\n\n\nfunc jump() -> void:\n\t_dog_jump_2d.jump()\n",
	)


func test_force_does_not_error_on_malformed_funcs_below_the_header() -> void:
	var source := HEAD + "func jump() -> void:\n\tfoo()\n# bar()\n\tbaz()\n"
	var r := _force(source, [_block("jump")])
	assert_eq(r.error, "")
	assert_eq(r.source, HEAD + JUMP + "\n")


# --- FORCE (-f): report what was dropped -----------------------------------


func test_force_reports_each_dropped_member_in_file_order() -> void:
	var source := (
		HEAD + "signal died\nvar speed := 1\n@onready var _x: Node = $X\n\n\nfunc old() -> void:\n"
		+ "\tpass\n"
	)
	var r := _force(source, [_block("jump")])
	assert_eq(
		r.report,
		["add func jump", "drop signal died", "drop var speed", "drop var _x", "drop func old"],
	)


func test_force_does_not_report_regenerated_members_as_dropped() -> void:
	var source := (
		HEAD + "func _ready() -> void:\n\tpass\n\n\nfunc jump() -> void:\n\tprint(\"mine\")\n"
	)
	var connect := {
		"kind": "ready_line",
		"name": "_x.landed",
		"text": "\t_x.landed.connect(landed.emit)",
	}
	var r := _force(source, [_block("jump"), connect])
	assert_eq(r.report, ["add func jump", "add func _ready", "add connect _x.landed"])


func test_force_on_header_only_reports_no_drops() -> void:
	var r := _force("extends CharacterBody2D\n", [_block("jump")])
	assert_eq(r.report, ["add func jump"])


func test_add_and_update_never_report_drops() -> void:
	var source := HEAD + "func old() -> void:\n\tpass\n"
	assert_eq(DogApiMerge.merge(source, [_block("jump")]).report, ["add func jump"])
	assert_eq(_update(source, [_block("jump")]).report, ["add func jump"])
