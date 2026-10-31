@tool
class_name DogSceneEdit
extends RefCounted
## Edits the text of a .tscn file. Pure: no file or editor access.
##
## An edit only inserts lines or rewrites attributes in place, so the rest of the
## file stays as it was and the diff is the lines it touched. Godot puts the file in
## its own order the next time it saves the scene. The queries (root_type,
## root_script_path) read the text the same way and change nothing.

# Error messages
const NOT_A_SCENE := "not a scene file: it does not start with [gd_scene]."
const NO_ROOT := "the scene has no root node."
const NO_NODE_TYPE := "a node needs a type."
const NODE_EXISTS := "the scene already has a node named %s under the root."
const NO_NODE_NAME := "a node needs a name."
const NO_ROOT_TYPE := "the root node has no type (is it an instance of another scene?)."
const NO_ROOT_SCRIPT := "the root node has no script."
const BUILT_IN_ROOT_SCRIPT := "the script of the root node is built into the scene."
const NO_SCRIPT_RESOURCE := "the root node's script is ext_resource %s, which the scene lacks."

static var _id := RegEx.create_from_string("\\sid=\"([^\"]+)\"")
static var _node_name := RegEx.create_from_string("^\\[node name=\"([^\"]*)\"")
static var _node_parent := RegEx.create_from_string("\\sparent=\"([^\"]*)\"")
static var _load_steps := RegEx.create_from_string("load_steps=(\\d+)")
static var _uid := RegEx.create_from_string("\\suid=\"[^\"]*\"")
static var _path := RegEx.create_from_string("\\spath=\"([^\"]*)\"")
static var _type := RegEx.create_from_string("\\stype=\"([^\"]+)\"")
static var _script := RegEx.create_from_string("^script = (\\w+)\\(\"([^\"]*)\"\\)")


## Adds `[node name=<node_name> type=<node_type> parent="."]` as the last child of
## the root. With `script_path` the node also gets that script: its ext_resource
## is reused when the scene already has one, otherwise it is added (with
## `script_uid` when given). Returns {source, error}: `source` is the new text,
## and error is empty on success; on error `source` is the text as given.
static func add_node(
	source: String,
	node_name: String,
	node_type: String,
	script_path := "",
	script_uid := "",
) -> Dictionary:
	if node_type.is_empty():
		return _result(source, NO_NODE_TYPE)
	var scan := _read(source, script_path)
	if not scan.error.is_empty():
		return _result(source, scan.error)
	if scan.children.has(node_name):
		return _result(source, NODE_EXISTS % node_name)
	var lines := scan.lines

	var script_id := scan.script_id
	var adds_resource := not script_path.is_empty() and script_id.is_empty()
	if adds_resource:
		script_id = _new_id(scan, script_path)

	var node_lines: Array[String] = [
		"[node name=\"%s\" type=\"%s\" parent=\".\"]" % [node_name, node_type],
	]
	if not script_path.is_empty():
		node_lines.append("script = ExtResource(\"%s\")" % script_id)
	lines = _insert_node(lines, scan, node_lines)

	if adds_resource:
		lines = _insert_resource(lines, scan, _resource_line(script_path, script_uid, script_id))
	return _result("\n".join(lines), "")


## Drops `uid="..."` from the [gd_scene] header, so Godot gives the scene a new uid
## the next time it saves it. Returns {source, error} like add_node.
static func strip_uid(source: String) -> Dictionary:
	var lines := source.split("\n")
	if not _is_scene(lines):
		return _result(source, NOT_A_SCENE)
	lines[0] = _uid.sub(lines[0], "")
	return _result("\n".join(lines), "")


## Renames the root node to `node_name`. The children keep their `parent` paths,
## which never name the root. Returns {source, error} like add_node.
static func rename_root(source: String, node_name: String) -> Dictionary:
	if node_name.is_empty():
		return _result(source, NO_NODE_NAME)
	var scan := _read(source)
	if not scan.error.is_empty():
		return _result(source, scan.error)
	var lines := scan.lines
	lines[scan.root] = _node_name.sub(lines[scan.root], "[node name=\"%s\"" % node_name)
	return _result("\n".join(lines), "")


## The type of the root node. Returns {type, error}: an instanced root (one whose
## scene inherits another) has no type, which is an error.
static func root_type(source: String) -> Dictionary:
	var scan := _read(source)
	if not scan.error.is_empty():
		return { "type": "", "error": scan.error }
	var found := _type.search(scan.lines[scan.root])
	if found == null:
		return { "type": "", "error": NO_ROOT_TYPE }
	return { "type": found.get_string(1), "error": "" }


## The path of the script on the root node. Returns {path, error}: a root without
## script, or with a script built into the scene, is an error.
static func root_script_path(source: String) -> Dictionary:
	var scan := _read(source)
	var at := _root_script_resource(scan)
	if not scan.error.is_empty():
		return { "path": "", "error": scan.error }
	var found := _path.search(scan.lines[at])
	return { "path": found.get_string(1) if found != null else "", "error": "" }


## Points the ext_resource of the root's script to `new_path` and drops its uid, so
## Godot finds the script by its path and writes its uid on the next save. Every node
## that shares that ext_resource follows. Returns {source, error} like add_node.
static func retarget_root_script(source: String, new_path: String) -> Dictionary:
	var scan := _read(source)
	var at := _root_script_resource(scan)
	if not scan.error.is_empty():
		return _result(source, scan.error)
	var lines := scan.lines
	var line := _uid.sub(lines[at], "")
	lines[at] = _path.sub(line, " path=\"%s\"" % new_path)
	return _result("\n".join(lines), "")


## The line of the ext_resource the root's script comes from, read from the
## properties below the root (up to the next section). Sets scan.error when there is
## none and returns -1; does nothing when scan.error is already set.
static func _root_script_resource(scan: Scan) -> int:
	if not scan.error.is_empty():
		return -1
	var lines := scan.lines
	var i := scan.root + 1
	while i < lines.size() and not lines[i].begins_with("["):
		var found := _script.search(lines[i])
		i += 1
		if found == null:
			continue
		var id := found.get_string(2)
		if found.get_string(1) != "ExtResource":
			scan.error = BUILT_IN_ROOT_SCRIPT
		elif not scan.resources.has(id):
			scan.error = NO_SCRIPT_RESOURCE % id
		else:
			return scan.resources[id]
		return -1
	scan.error = NO_ROOT_SCRIPT
	return -1


## Where the new node goes: after the last node, before the connections and the
## editable instances. Inserting it last keeps the tree order Godot writes.
static func _insert_node(
	lines: PackedStringArray,
	scan: Scan,
	node_lines: Array[String],
) -> PackedStringArray:
	var result := PackedStringArray()
	if scan.trailing >= 0:
		result.append_array(lines.slice(0, scan.trailing))
		if scan.trailing > 0 and not lines[scan.trailing - 1].strip_edges().is_empty():
			result.append("")
		result.append_array(node_lines)
		result.append("")
		result.append_array(lines.slice(scan.trailing))
		return result

	var end := lines.size()
	while end > 0 and lines[end - 1].strip_edges().is_empty():
		end -= 1
	result.append_array(lines.slice(0, end))
	result.append("")
	result.append_array(node_lines)
	result.append("")
	return result


## The resource goes after the last ext_resource, or right below the header when
## the scene has none. Its position is before every node, so inserting the node
## first does not move it.
static func _insert_resource(
	lines: PackedStringArray,
	scan: Scan,
	resource_line: String,
) -> PackedStringArray:
	var result := PackedStringArray()
	var at := scan.last_resource + 1 if scan.last_resource >= 0 else 1
	result.append_array(lines.slice(0, at))
	if scan.last_resource < 0:
		result.append("")
	result.append(resource_line)
	if scan.last_resource < 0 and not lines[at].strip_edges().is_empty():
		result.append("")
	result.append_array(lines.slice(at))

	var steps := _load_steps.search(result[0])
	if steps != null:
		var count := int(steps.get_string(1)) + 1
		result[0] = result[0].replace(steps.get_string(), "load_steps=%d" % count)
	return result


static func _resource_line(script_path: String, script_uid: String, id: String) -> String:
	var uid := " uid=\"%s\"" % script_uid if not script_uid.is_empty() else ""
	return "[ext_resource type=\"Script\"%s path=\"%s\" id=\"%s\"]" % [uid, script_path, id]


## `<ordinal>_<5 chars>` like the ids Godot writes, but the chars come from the
## path, so the same edit always gives the same text. Skips ids already taken.
static func _new_id(scan: Scan, seed_text: String) -> String:
	var ordinal := scan.resource_count + 1
	var suffix := seed_text.md5_text().substr(0, 5)
	var id := "%d_%s" % [ordinal, suffix]
	while scan.ids.has(id):
		ordinal += 1
		id = "%d_%s" % [ordinal, suffix]
	return id


## The lines of `source` and what _scan finds in them, with scan.error set when the
## text is not a scene or has no root.
static func _read(source: String, script_path := "") -> Scan:
	var lines := source.split("\n")
	if not _is_scene(lines):
		var not_scene := Scan.new()
		not_scene.error = NOT_A_SCENE
		return not_scene
	var scan := _scan(lines, script_path)
	if scan.root < 0:
		scan.error = NO_ROOT
	return scan


static func _is_scene(lines: PackedStringArray) -> bool:
	return lines[0].begins_with("[gd_scene")


static func _scan(lines: PackedStringArray, script_path: String) -> Scan:
	var scan := Scan.new()
	scan.lines = lines
	var script_marker := "path=\"%s\"" % script_path
	for i in lines.size():
		var line := lines[i]
		if line.begins_with("[ext_resource"):
			scan.resource_count += 1
			scan.last_resource = i
			var found := _id.search(line)
			if found != null:
				scan.ids[found.get_string(1)] = true
				scan.resources[found.get_string(1)] = i
				if not script_path.is_empty() and line.contains(script_marker):
					scan.script_id = found.get_string(1)
		elif line.begins_with("[sub_resource"):
			var found := _id.search(line)
			if found != null:
				scan.ids[found.get_string(1)] = true
		elif line.begins_with("[node "):
			_scan_node(scan, line, i)
		elif scan.trailing < 0 and (
			line.begins_with("[connection") or line.begins_with("[editable")
		):
			scan.trailing = i
	return scan


static func _scan_node(scan: Scan, line: String, at: int) -> void:
	var parent := _node_parent.search(line)
	if parent == null:
		if scan.root < 0:
			scan.root = at
		return
	if parent.get_string(1) != ".":
		return
	var named := _node_name.search(line)
	if named != null:
		scan.children[named.get_string(1)] = true


static func _result(source: String, error: String) -> Dictionary:
	return { "source": source, "error": error }


## What _scan finds in the text of a scene.
class Scan:
	var lines := PackedStringArray()
	## Why the text can't be edited ("" = it can).
	var error := ""
	## Line of the root node (-1 = none).
	var root := -1
	## Names of the direct children of the root.
	var children := {}
	## Every id used by an ext_resource or a sub_resource.
	var ids := {}
	## Line of each ext_resource, by id.
	var resources := {}
	var resource_count := 0
	## Line of the last ext_resource (-1 = none).
	var last_resource := -1
	## Id of the ext_resource that already points to the script ("" = none).
	var script_id := ""
	## Line of the first [connection] or [editable] (-1 = none).
	var trailing := -1
