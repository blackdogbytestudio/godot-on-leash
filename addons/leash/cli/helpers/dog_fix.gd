@tool
class_name DogFix
extends RefCounted
## The --prefix / --suffix / --no-fix flags of a command: what goes around a short
## name to make a full one (dog, 2d: jump -> dog_jump_2d).
##
## --prefix / --suffix replace a setting (empty, as in --prefix=, drops that side)
## and --no-fix drops both; without them the prefix and suffix settings apply.
## Each command adds the three flags to its parser with its own help, then reads
## them with from_parser.

# Error messages
const NO_FIX_AND_FIX := "use either --no-fix or --prefix / --suffix, not both."

## What goes before and after a name ("" = nothing), without the joining "_".
var prefix := ""
var suffix := ""
## Whether --prefix, --suffix or --no-fix was passed.
var given := false
## NO_FIX_AND_FIX, or "".
var error := ""


## Reads --prefix, --suffix and --no-fix from a parsed `parser`.
static func from_parser(parser: DogOptParse) -> DogFix:
	var fix := DogFix.new()
	var given_prefix: Variant = parser.get_value_or_null("--prefix")
	var given_suffix: Variant = parser.get_value_or_null("--suffix")
	var no_fix: bool = parser.get_value("--no-fix")
	fix.given = no_fix or given_prefix != null or given_suffix != null
	if no_fix and (given_prefix != null or given_suffix != null):
		fix.error = NO_FIX_AND_FIX
		return fix
	if not no_fix:
		fix.prefix = _given_or(given_prefix, DogSettings.prefix()).trim_suffix("_")
		fix.suffix = _given_or(given_suffix, DogSettings.suffix()).trim_prefix("_")
	return fix


## `token` with the prefix and the suffix around it, joined by "_".
func apply(token: String) -> String:
	var full := token
	if not prefix.is_empty():
		full = prefix + "_" + full
	if not suffix.is_empty():
		full = full + "_" + suffix
	return full


## Whether apply adds anything to a token.
func is_applied() -> bool:
	return not prefix.is_empty() or not suffix.is_empty()


## `given` when the flag was passed (even empty), otherwise `setting`.
static func _given_or(given: Variant, setting: String) -> String:
	return setting if given == null else String(given)
