class_name _CLASS_
extends _BASE_

# Replace 'CUSTOM_HOST' with the specific class name of your host script (e.g., Player).
# Every hook below is optional: delete the ones this state doesn't use.


func enter(host: Node) -> void:
	_enter(host as CUSTOM_HOST)


func exit(host: Node) -> void:
	_exit(host as CUSTOM_HOST)


func update(host: Node, delta: float) -> DogState:
	return _update(host as CUSTOM_HOST, delta)


func pause(host: Node) -> void:
	_pause(host as CUSTOM_HOST)


func resume(host: Node) -> void:
	_resume(host as CUSTOM_HOST)


func _enter(host: CUSTOM_HOST) -> void:
	pass


func _exit(host: CUSTOM_HOST) -> void:
	pass


func _update(host: CUSTOM_HOST, delta: float) -> DogState:
	return null


func _pause(host: CUSTOM_HOST) -> void:
	pass


func _resume(host: CUSTOM_HOST) -> void:
	pass
