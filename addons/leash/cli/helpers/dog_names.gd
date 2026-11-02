@tool
class_name DogNames
extends RefCounted
## Name rules shared by the generator commands. Pure: no file or editor access.
##
## Actor names and folders are snake_case. Class names (an actor's base, a state
## base, a template, a bind component) accept snake_case, PascalCase (literal) and
## hybrid, all made PascalCase by to_pascal: area_2d, Area2D and Area_2d are Area2D,
## CPU_particles_2d is CPUParticles2D.

# Error messages
const INVALID_ACTOR := "'%s' is not a valid actor name (use snake_case)."
const INVALID_FOLDER := "'%s' is not a valid folder (snake_case names separated by /)."
const INVALID_SETTING := "Setting %s: %s"
const INVALID_CLASS := (
	"'%s' is not a valid class name"
	+ " (snake_case, PascalCase or hybrid: area_2d, Area2D, CPU_particles_2d)."
)

# snake_case where a part may start with a digit (character_body_2d), unlike
# DogStateTree's rule, which is meant for state names. "\z" (not "$") because
# "$" also matches before a trailing newline.
static var _valid_name := RegEx.create_from_string("^[a-z][a-z0-9]*(_[a-z0-9]+)*\\z")
# A class name as typed: snake_case, PascalCase or hybrid. Starts with a letter, then
# letters and digits in any case, with single underscores between parts.
static var _valid_class := RegEx.create_from_string("^[A-Za-z][A-Za-z0-9]*(_[A-Za-z0-9]+)*\\z")


## Actor and component names: snake_case, parts may start with a digit.
static func is_valid_name(name: String) -> bool:
	return _valid_name.search(name) != null


## Class names as typed: snake_case, PascalCase or hybrid (see to_pascal).
static func is_valid_class_token(token: String) -> bool:
	return _valid_class.search(token) != null


## The error for an invalid actor name, or "".
static func actor_error(actor: String) -> String:
	return "" if is_valid_name(actor) else INVALID_ACTOR % actor


## The error for an invalid `--folder` (snake_case parts separated by /), or "".
## An empty folder is valid: it means "no folder".
static func folder_error(folder: String, setting := "") -> String:
	if folder.is_empty():
		return ""
	for part in folder.split("/"):
		if not is_valid_name(part):
			var error: String = INVALID_FOLDER % folder
			return error if setting.is_empty() else INVALID_SETTING % [setting, error]
	return ""


## A class name as typed -> PascalCase. The first letter of each part is upper case,
## and so is the letter right after a number: `character_body_2d` -> `CharacterBody2D`
## (String.to_pascal_case gives `CharacterBody2d`). Other letters keep their case, so
## a PascalCase name stays as it is (CPUParticles2D) and a hybrid one joins its parts
## (CPU_particles_2d -> CPUParticles2D).
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
