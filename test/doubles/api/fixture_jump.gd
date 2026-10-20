class_name FixtureJump2D
extends FixtureBase
## Test double: a component with signals, args, defaults, a static and internals.

# Members exist only to be found by reflection, never used.
@warning_ignore_start("unused_signal", "unused_parameter", "shadowed_variable")
signal landed(speed: float)
signal _hidden

# Property accessors show up as `@power_setter` / `@power_getter` methods.
var power := 1.0:
	set(value):
		power = value
	get:
		return power


func jump() -> void:
	pass


func jump_with(power: float, times: int = 2) -> void:
	pass


func get_power() -> float:
	return 1.0


func _internal() -> void:
	pass


static func util() -> int:
	return 1
