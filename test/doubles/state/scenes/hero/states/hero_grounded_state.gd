class_name HeroGroundedState
extends HeroAliveState

# Generated stubs: the hooks are empty, so host and delta are unused.
@warning_ignore_start("unused_parameter")


func _enter(host: Hero) -> void:
	pass


func _exit(host: Hero) -> void:
	pass


func _update(host: Hero, delta: float) -> DogState:
	var next := super(host, delta)
	if next:
		return next
	return null


func _pause(host: Hero) -> void:
	pass


func _resume(host: Hero) -> void:
	pass
