class_name _CLASS_
extends CUSTOM_BASE

# Replace 'CUSTOM_BASE' with the class name of your base state class (e.g., PlayerState).
# Replace 'CUSTOM_HOST' with the specific class name of your host script (e.g., Player).


func _enter(host: CUSTOM_HOST) -> void:
	pass


func _exit(host: CUSTOM_HOST) -> void:
	pass


func _update(host: CUSTOM_HOST, delta: float) -> DogState:
	return null
