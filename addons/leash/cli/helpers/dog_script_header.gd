@tool
class_name DogScriptHeader
extends RefCounted
## Reads and edits the class_name and the extends of a GDScript text. Pure: no file
## or editor access.
##
## Only the class_name or the extends line changes (or is added), so the rest of the
## text stays as it was.

# Error messages
const NO_EXTENDS := "the script has no extends line."
const INVALID_CLASS := "'%s' is not a valid class name."

static var _class_name := RegEx.create_from_string("^class_name\\s+(\\w+)")
static var _extends := RegEx.create_from_string("^extends\\b")
# The class after `extends`, on its own line or after `class_name A`: a name, a
# dotted name or a quoted path.
static var _extended := RegEx.create_from_string(
	"^(?:class_name\\s+\\w+\\s+)?extends\\s+(\"[^\"]*\"|[\\w.]+)"
)


## The `class_name` written in `source`, or "".
static func declared_class_name(source: String) -> String:
	for line in source.split("\n"):
		var found := _class_name.search(line)
		if found != null:
			return found.get_string(1)
	return ""


## The class written after `extends` in `source` (a name, a dotted name or a quoted
## path, as written), or "" when the script has no extends.
static func declared_extends(source: String) -> String:
	for line in source.split("\n"):
		var found := _extended.search(line)
		if found != null:
			return found.get_string(1)
	return ""


## Makes the script extend `class_text`: the class after the first `extends` is
## replaced, on its own line or in `class_name A extends B`. A script without
## extends is an error. Returns {source, error} like set_class_name.
static func set_extends(source: String, class_text: String) -> Dictionary:
	if not class_text.is_valid_identifier():
		return _result(source, INVALID_CLASS % class_text)
	var lines := source.split("\n")
	for i in lines.size():
		var found := _extended.search(lines[i])
		if found != null:
			var line := lines[i]
			lines[i] = line.left(found.get_start(1)) + class_text + line.substr(found.get_end(1))
			return _result("\n".join(lines), "")
	return _result(source, NO_EXTENDS)


## Gives the script `class_name <class_text>`: the name is replaced where the script
## already declares one (`class_name A extends B` included), otherwise the line is
## inserted right before `extends`. Returns {source, error}: `source` is the new
## text, and error is empty on success; on error `source` is the text as given.
static func set_class_name(source: String, class_text: String) -> Dictionary:
	if not class_text.is_valid_identifier():
		return _result(source, INVALID_CLASS % class_text)
	var lines := source.split("\n")
	for i in lines.size():
		var found := _class_name.search(lines[i])
		if found != null:
			var name_at := found.get_start(1)
			lines[i] = lines[i].left(name_at) + class_text + lines[i].substr(found.get_end(1))
			return _result("\n".join(lines), "")

	for i in lines.size():
		if _extends.search(lines[i]) != null:
			lines.insert(i, "class_name " + class_text)
			return _result("\n".join(lines), "")
	return _result(source, NO_EXTENDS)


static func _result(source: String, error: String) -> Dictionary:
	return { "source": source, "error": error }
