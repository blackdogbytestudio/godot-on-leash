class_name _CLASS_
extends CUSTOM_BASE

# Replace 'CUSTOM_BASE' with the class name of your base state class (e.g., PlayerState).
# Replace 'CUSTOM_HOST' with the specific class name of your host script (e.g., Player).
# Every hook below is optional: delete the ones this state doesn't use.


func _enter(host: CUSTOM_HOST) -> void:
	pass


func _exit(host: CUSTOM_HOST) -> void:
	pass


func _update(host: CUSTOM_HOST, delta: float) -> DogState:
	var next := super(host, delta)
	if next:
		return next
	return null


# Handle this state's events first; super() hands the rest to the parent state.
func _on_event(host: CUSTOM_HOST, event: StringName, data: Variant) -> DogState:
	return super(host, event, data)


func _pause(host: CUSTOM_HOST) -> void:
	pass


func _resume(host: CUSTOM_HOST) -> void:
	pass
