@tool
class_name DogApiMerge
extends RefCounted
## Pure text merge behind the `api` command: no file or editor access here.
##
## `blocks` is an Array of Dictionaries {"kind", "name", "text"}:
## - "func" (default when "kind" is missing): `text` is the full func, no trailing newline.
## - "var" / "signal": `text` is the one-line declaration.
## - "func_line": `text` is one indented line that must exist inside the func
##   named by "func"; it goes to the top of the body, and the func is created when
##   missing. `name` is only used in the report. With "match" (a prefix), a body
##   line starting with it (indentation ignored) counts as present: ADD keeps it,
##   UPDATE replaces it when it differs from `text`.
## - "ready_line": a "func_line" for `_ready` (reported as "connect").
##
## Modes:
## - ADD (default): add what is missing, matching by name only.
## - UPDATE (-u): ADD, plus replace existing func/var/signal whose text differs.
##   If a func that would be replaced looks cut in the middle, nothing changes and
##   `error` says which func and "line N" (1-based line of its `func`).
## - FORCE (-f): keep the header and rewrite everything below it. The report ends
##   with "drop <keyword> <name>" for each old member that was not regenerated.
##
## New items follow the Godot style guide order: each goes after the last member
## of its category; without one, before the first member of a later category;
## without one, at the end. What already exists is never reordered.
## Returns {"source": String, "report": Array[String], "error": String}.

enum Mode {
	ADD,
	UPDATE,
	FORCE,
}

## A top-level line that starts a new declaration (so it can't be part of a body).
const DECLARATION := "^(@|##|(static\\s+func|func|var|const|signal|enum|class_name|class|extends)\\b)"
## Signatures for funcs that "func_line" creates; others get `func name() -> void:`.
const SIGNATURES := {
	"_ready": "func _ready() -> void:",
	"_process": "func _process(delta: float) -> void:",
	"_physics_process": "func _physics_process(delta: float) -> void:",
}
## An annotation alone on its line (e.g. `@export` above a `var`).
const ANNOTATION_ONLY := "^@\\w+(\\([^)]*\\))?\\s*$"
## Lines that belong to the top of the file, above the members.
const HEADER_LINE := "^(@tool|@icon|@static_unload|class_name|extends)\\b"
## Style guide rank of each member (lower comes first). Built-in virtuals keep
## the order of VIRTUAL_ORDER; the other built-in virtuals come right after them.
## Overridden custom methods can't be told apart, so they rank as plain funcs.
const RANK_SIGNAL := 50
const RANK_ENUM := 60
const RANK_CONST := 70
const RANK_STATIC_VAR := 80
const RANK_EXPORT_VAR := 90
const RANK_VAR := 100
const RANK_ONREADY_VAR := 110
const RANK_STATIC_INIT := 120
const RANK_STATIC_FUNC := 130
const RANK_VIRTUAL := 140
const RANK_OTHER_VIRTUAL := 150
const RANK_FUNC := 160
const RANK_CLASS := 170
## Before RANK_STATIC_INIT, members are one-liners that may sit together.
const FIRST_METHOD_RANK := RANK_STATIC_INIT
const VIRTUAL_ORDER := ["_init", "_enter_tree", "_ready", "_process", "_physics_process"]
const OTHER_VIRTUALS := [
	"_exit_tree", "_input", "_shortcut_input", "_unhandled_input", "_unhandled_key_input",
	"_notification", "_draw", "_integrate_forces", "_get_configuration_warnings", "_to_string",
	"_get", "_set", "_get_property_list", "_validate_property", "_property_can_revert",
	"_property_get_revert", "_gui_input", "_get_minimum_size", "_has_point",
	"_make_custom_tooltip", "_can_drop_data", "_drop_data", "_get_drag_data",
]
## Gaps in blank lines measured from these ranks (not members).
const GAP_FILE_START := -2
const GAP_HEADER := -1

# Error messages
const BODY_ON_SAME_LINE := (
	"func %s (line %d) has its body on the same line:"
	+ " can't add lines under it"
)
const FUNC_CUT := (
	"func %s (line %d) looks cut in the middle:"
	+ " line %d is neither a declaration nor part of its body"
)


static func merge(source: String, blocks: Array, mode := Mode.ADD) -> Dictionary:
	var lines := source.split("\n")
	var dropped := PackedStringArray()
	if mode == Mode.FORCE:
		dropped = _dropped(lines, blocks)
		lines = _trim_blank_tail(lines.slice(0, _header_end(lines)))
		if not lines.is_empty():
			lines.append("")
		mode = Mode.ADD

	var report := []
	var to_add: Array = []
	var to_replace: Array = []
	var lines_to_insert := {}  # func name -> PackedStringArray, for funcs that exist
	var funcs_to_create := {}  # func name -> PackedStringArray, in block order
	var lines_to_update: Array = []  # func_line blocks whose "match" line differs

	# Pass 1 only reads: classify every block and validate before touching anything.
	for block in blocks:
		var kind: String = block.get("kind", "func")
		var block_name: String = block["name"]
		var text: String = block["text"]
		var label := "%s %s" % [_word(kind), block_name]

		if kind == "ready_line" or kind == "func_line":
			var target: String = "_ready" if kind == "ready_line" else block["func"]
			var func_start := _find(lines, "func", target)
			if func_start == -1:
				if not funcs_to_create.has(target):
					funcs_to_create[target] = PackedStringArray()
					report.append("add func " + target)
				funcs_to_create[target].append(text)
				report.append("add " + label)
				continue
			if not lines[func_start].strip_edges().ends_with(":"):
				return _error(source, BODY_ON_SAME_LINE % [target, func_start + 1])
			var match_prefix: String = block.get("match", "")
			var matched := -1 if match_prefix.is_empty() else _find_line(lines, func_start, match_prefix)
			if matched != -1:
				if mode == Mode.UPDATE and lines[matched].strip_edges() != text.strip_edges():
					lines_to_update.append({ "func": target, "match": match_prefix, "text": text })
					report.append("update " + label)
				else:
					report.append("skip " + label)
			elif _has_line(lines, func_start, text):
				report.append("skip " + label)
			else:
				if not lines_to_insert.has(target):
					lines_to_insert[target] = PackedStringArray()
				lines_to_insert[target].append(text)
				report.append("add " + label)
			continue

		var start := _find(lines, kind, block_name)
		if start == -1:
			to_add.append(block)
			report.append("add " + label)
			continue

		if mode == Mode.UPDATE:
			var span := _span_for(kind, lines, start)
			var bad_line: int = span["bad_line"]
			if bad_line != -1:
				return _error(source, FUNC_CUT % [block_name, start + 1, bad_line + 1])
			var end: int = span["end"]
			if "\n".join(lines.slice(start, end + 1)) != text:
				to_replace.append(block)
				report.append("update " + label)
				continue
		report.append("skip " + label)

	# Pass 2 writes. Replace first (positions shift, so find again every time).
	for block in to_replace:
		var kind: String = block.get("kind", "func")
		var text: String = block["text"]
		var start := _find(lines, kind, block["name"])
		var end: int = _span_for(kind, lines, start)["end"]
		lines = lines.slice(0, start) + text.split("\n") + lines.slice(end + 1)

	for line in lines_to_update:
		lines[_find_line(lines, _find(lines, "func", line["func"]), line["match"])] = line["text"]

	for target in lines_to_insert:
		var at := _find(lines, "func", target) + 1
		lines = lines.slice(0, at) + lines_to_insert[target] + lines.slice(at)

	for target in funcs_to_create:
		var signature: String = SIGNATURES.get(target, "func %s() -> void:" % target)
		to_add.append({ "text": signature + "\n" + "\n".join(funcs_to_create[target]) })

	for block in to_add:
		lines = _insert(lines, block["text"].split("\n"))

	for label in dropped:
		report.append("drop " + label)
	return { "source": "\n".join(lines), "report": report, "error": "" }


## "<keyword> <name>" of each member below the header that no block regenerates.
static func _dropped(lines: PackedStringArray, blocks: Array) -> PackedStringArray:
	var regenerated := {}
	for block in blocks:
		var kind: String = block.get("kind", "func")
		if kind == "ready_line":
			regenerated["func _ready"] = true
		elif kind == "func_line":
			regenerated["func " + block["func"]] = true
		else:
			regenerated["%s %s" % [kind, block["name"]]] = true

	var re := RegEx.new()
	re.compile("^(static\\s+)?(func|var|const|signal|enum|class)\\s+(\\w+)")
	var dropped := PackedStringArray()
	for member in _members(lines):
		var found := re.search(_strip_annotations(lines[member["decl"]]))
		if found == null:
			continue
		var label := "%s %s" % [found.get_string(2), found.get_string(3)]
		if not regenerated.has(label):
			dropped.append(label)
	return dropped


## Puts `text` where the style guide wants it (see the top of this file) and
## rewrites the blank lines on both sides of it; everything else stays as is.
static func _insert(lines: PackedStringArray, text: PackedStringArray) -> PackedStringArray:
	var rank := _rank(text, 0, text.size() - 1)
	var members := _members(lines)
	var next := -1
	for i in members.size():
		if members[i]["rank"] == rank:
			next = i + 1
	if next == -1:
		next = members.size()
		for i in members.size():
			if members[i]["rank"] > rank:
				next = i
				break

	var cut: int = members[next]["start"] if next < members.size() else lines.size()
	var before := _trim_blank_tail(lines.slice(0, cut))
	var previous_rank := GAP_FILE_START if before.is_empty() else GAP_HEADER
	if next > 0:
		previous_rank = members[next - 1]["rank"]

	var result := before
	result.append_array(_blank(_gap(previous_rank, rank)))
	result.append_array(text)
	if next < members.size():
		result.append_array(_blank(_gap(rank, members[next]["rank"])))
		result.append_array(lines.slice(cut))
	else:
		result.append("")
	return result


static func _gap(previous_rank: int, rank: int) -> int:
	if previous_rank == GAP_FILE_START:
		return 0
	if previous_rank >= FIRST_METHOD_RANK or rank >= FIRST_METHOD_RANK:
		return 2
	if previous_rank == rank:
		return 0
	return 1


static func _blank(count: int) -> PackedStringArray:
	var blank := PackedStringArray()
	blank.resize(count)
	return blank


## The top-level members below the header, in file order: [{"start", "decl", "rank"}].
## A member starts at its doc comment or annotation lines when they touch it.
static func _members(lines: PackedStringArray) -> Array:
	var members: Array = []
	var lead := -1
	for i in range(_header_end(lines), lines.size()):
		var line := lines[i]
		if line.strip_edges().is_empty() or line.begins_with("\t") or line.begins_with(" "):
			lead = -1
		elif line.begins_with("#") or _matches(ANNOTATION_ONLY, line):
			if lead == -1:
				lead = i
		elif _matches(DECLARATION, line):
			var start := i if lead == -1 else lead
			members.append({ "start": start, "decl": i, "rank": _rank(lines, start, i) })
			lead = -1
		else:
			lead = -1
	return members


## Rank of the declaration at `decl`, with the annotation lines from `start` on.
static func _rank(lines: PackedStringArray, start: int, decl: int) -> int:
	var annotations := ""
	var i := start
	while i <= decl and (lines[i].begins_with("#") or _matches(ANNOTATION_ONLY, lines[i])):
		if not lines[i].begins_with("#"):
			annotations += lines[i] + " "
		i += 1
	var line := annotations + lines[i]
	var bare := _strip_annotations(line)
	if bare.begins_with("signal"):
		return RANK_SIGNAL
	if bare.begins_with("enum"):
		return RANK_ENUM
	if bare.begins_with("const"):
		return RANK_CONST
	if _matches("^static\\s+var\\b", bare):
		return RANK_STATIC_VAR
	if bare.begins_with("var"):
		if _matches("^@export", line):
			return RANK_EXPORT_VAR
		if _matches("^(@\\w+(\\([^)]*\\))?\\s+)*@onready\\b", line):
			return RANK_ONREADY_VAR
		return RANK_VAR
	if _matches("^(static\\s+)?func\\s+_static_init\\b", bare):
		return RANK_STATIC_INIT
	if _matches("^static\\s+func\\b", bare):
		return RANK_STATIC_FUNC
	if bare.begins_with("func"):
		var func_name := bare.trim_prefix("func").strip_edges().get_slice("(", 0).strip_edges()
		if func_name in VIRTUAL_ORDER:
			return RANK_VIRTUAL + VIRTUAL_ORDER.find(func_name)
		if func_name in OTHER_VIRTUALS:
			return RANK_OTHER_VIRTUAL
		return RANK_FUNC
	if _matches("^class\\s", bare):
		return RANK_CLASS
	return RANK_FUNC


static func _strip_annotations(line: String) -> String:
	var re := RegEx.new()
	re.compile("^(@\\w+(\\([^)]*\\))?\\s*)+")
	return re.sub(line, "").strip_edges()


static func _error(source: String, message: String) -> Dictionary:
	return { "source": source, "report": [], "error": message }


static func _word(kind: String) -> String:
	match kind:
		"ready_line":
			return "connect"
		"func_line":
			return "line"
	return kind


## Index of the line that declares `block_name`, or -1. Whole-name match:
## `jump` never matches `jump_high`, and a commented-out line doesn't start with
## the keyword.
static func _find(lines: PackedStringArray, kind: String, block_name: String) -> int:
	if kind == "func":
		var prefix := "func %s(" % block_name
		for i in lines.size():
			if lines[i].begins_with(prefix):
				return i
		return -1
	if not block_name.is_valid_identifier():
		return -1
	var pattern := "^signal\\s+%s\\b" % block_name
	if kind == "var":
		pattern = "^(@\\w+(\\([^)]*\\))?\\s+)*var\\s+%s\\b" % block_name
	var re := RegEx.new()
	re.compile(pattern)
	for i in lines.size():
		if re.search(lines[i]) != null:
			return i
	return -1


static func _span_for(kind: String, lines: PackedStringArray, start: int) -> Dictionary:
	if kind == "func":
		return _span(lines, start)
	return { "end": start, "bad_line": -1 }


## Index of the first body line of the func at `start` that begins with `prefix`
## (indentation ignored), or -1.
static func _find_line(lines: PackedStringArray, start: int, prefix: String) -> int:
	var end: int = _span(lines, start)["end"]
	for i in range(start + 1, end + 1):
		if lines[i].strip_edges().begins_with(prefix):
			return i
	return -1


## Is `text` (compared without surrounding whitespace) in the body of the func at `start`?
static func _has_line(lines: PackedStringArray, start: int, text: String) -> bool:
	var wanted := text.strip_edges()
	var end: int = _span(lines, start)["end"]
	for i in range(start + 1, end + 1):
		if lines[i].strip_edges() == wanted:
			return true
	return false


## Where the func starting at `start` ends: the last indented line before the
## first non-blank line without indentation. Blank lines never end it.
## `bad_line` is the line that proves the func was cut in the middle, or -1.
static func _span(lines: PackedStringArray, start: int) -> Dictionary:
	var end := start
	var i := start + 1
	while i < lines.size():
		var line := lines[i]
		if line.strip_edges().is_empty():
			i += 1
			continue
		if line.begins_with("\t") or line.begins_with(" "):
			end = i
			i += 1
			continue
		break

	if i >= lines.size() or _matches(DECLARATION, lines[i]):
		return { "end": end, "bad_line": -1 }

	if lines[i].begins_with("#"):
		# A plain column-0 comment is fine between members, but not in the middle
		# of a body: if the next real line is indented, the body went on.
		var j := i + 1
		while j < lines.size() and (lines[j].strip_edges().is_empty() or lines[j].begins_with("#")):
			j += 1
		if j >= lines.size() or not (lines[j].begins_with("\t") or lines[j].begins_with(" ")):
			return { "end": end, "bad_line": -1 }

	return { "end": end, "bad_line": i }


## Number of lines that make up the header: everything before the first member.
## A comment counts only when it is detached from the member that follows it.
static func _header_end(lines: PackedStringArray) -> int:
	var end := 0
	for i in lines.size():
		var line := lines[i]
		if line.strip_edges().is_empty():
			continue
		if _matches(HEADER_LINE, line):
			end = i + 1
			continue
		if line.begins_with("#") and _comment_is_detached(lines, i):
			end = i + 1
			continue
		break
	return end


static func _comment_is_detached(lines: PackedStringArray, index: int) -> bool:
	var j := index + 1
	while j < lines.size() and lines[j].begins_with("#"):
		j += 1
	return j >= lines.size() or lines[j].strip_edges().is_empty() or _matches(HEADER_LINE, lines[j])


static func _trim_blank_tail(lines: PackedStringArray) -> PackedStringArray:
	var n := lines.size()
	while n > 0 and lines[n - 1].strip_edges().is_empty():
		n -= 1
	return lines.slice(0, n)


static func _matches(pattern: String, line: String) -> bool:
	var re := RegEx.new()
	re.compile(pattern)
	return re.search(line) != null
