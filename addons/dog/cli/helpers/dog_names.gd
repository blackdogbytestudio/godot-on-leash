@tool
class_name DogNames
extends RefCounted
## Name rules shared by the generator commands. Pure: no file or editor access.

# Error messages
const INVALID_ACTOR := "'%s' is not a valid actor name (use snake_case)."
const INVALID_FOLDER := "'%s' is not a valid folder (snake_case names separated by /)."

# snake_case where a part may start with a digit (character_body_2d), unlike
# DogStateTree's rule, which is meant for state names. "\z" (not "$") because
# "$" also matches before a trailing newline.
static var _valid_name := RegEx.create_from_string("^[a-z][a-z0-9]*(_[a-z0-9]+)*\\z")


## Actor and component names: snake_case, parts may start with a digit.
static func is_valid_name(name: String) -> bool:
	return _valid_name.search(name) != null


## The error for an invalid actor name, or "".
static func actor_error(actor: String) -> String:
	return "" if is_valid_name(actor) else INVALID_ACTOR % actor


## The error for an invalid `--folder` (snake_case parts separated by /), or "".
## An empty folder is valid: it means "no folder".
static func folder_error(folder: String) -> String:
	if folder.is_empty():
		return ""
	for part in folder.split("/"):
		if not is_valid_name(part):
			return INVALID_FOLDER % folder
	return ""


## snake_case -> PascalCase. The first letter of each part is upper case, and so
## is the letter right after a number: `character_body_2d` -> `CharacterBody2D`
## (String.to_pascal_case gives `CharacterBody2d`).
static func to_pascal(snake: String) -> String:
	var pascal := ""
	var upper_next := true
	for c in snake:
		if c == "_":
			upper_next = true
			continue
		var is_digit := c >= "0" and c <= "9"
		pascal += c.to_upper() if upper_next else c
		upper_next = is_digit
	return pascal
