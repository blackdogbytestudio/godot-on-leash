@tool
class_name DogStateTree
extends RefCounted

# Error messages
const NO_STATES := "no states given."
const DOTS_WITHOUT_NAME := "'%s' has dots but no name."
const INVALID_STATE := "'%s' is not a valid state name (use snake_case)."
const NESTED_FIRST := "'%s' can't be nested: the first state must be a root."
const NESTED_TOO_DEEP := "'%s' is nested too deep: previous state is at depth %d."
const DECLARED_TWICE := "'%s' is declared twice."

# Strict snake_case: every segment starts with a letter, so there are no double,
# leading or trailing underscores. "\z" (not "$") because "$" also matches before
# a trailing newline.
static var _valid_name := RegEx.create_from_string("^[a-z][a-z0-9]*(_[a-z][a-z0-9]*)*\\z")

var nodes: Array[StateNode] = []
var error := ""


static func is_valid_name(name: String) -> bool:
	return _valid_name.search(name) != null


static func parse(tokens: PackedStringArray) -> DogStateTree:
	var tree := DogStateTree.new()
	if tokens.is_empty():
		return _fail(tree, NO_STATES)

	var path: Array[String] = []
	var seen: Dictionary[String, bool] = {}

	for token in tokens:
		var depth := 0
		while depth < token.length() and token[depth] == ".":
			depth += 1

		var state_name := token.substr(depth)
		if state_name.is_empty():
			return _fail(tree, DOTS_WITHOUT_NAME % token)

		if not is_valid_name(state_name):
			return _fail(tree, INVALID_STATE % state_name)

		if depth > path.size():
			if path.is_empty():
				return _fail(tree, NESTED_FIRST % state_name)
			return _fail(tree, NESTED_TOO_DEEP % [state_name, path.size() - 1])

		if seen.has(state_name):
			return _fail(tree, DECLARED_TWICE % state_name)
		seen[state_name] = true

		path.resize(depth)

		var node := StateNode.new()
		node.name = state_name
		node.parent = path[depth - 1] if depth > 0 else ""
		node.depth = depth
		tree.nodes.append(node)

		path.append(state_name)

	return tree


# On any error the tree is returned empty, so a caller can never generate from a
# half-parsed tree.
static func _fail(tree: DogStateTree, message: String) -> DogStateTree:
	tree.nodes.clear()
	tree.error = message
	return tree


## Parses a dot-depth state tree into a flat, ordered list of nodes.
## Example: alive .grounded ..run ...run_ground ..idle dead


class StateNode:
	var name: String
	var parent: String  # Empty for roots.
	var depth: int
