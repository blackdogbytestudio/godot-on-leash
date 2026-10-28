@tool
class_name DogComponent
extends Node
## Base class for all components.
##
## Dog is your best friend. It can encapsulate a specific behavior
## for its host. The host has to be of a type other than null.
## [br][br]
## It is expected that subclasses override [method _host_type] with a strict type,
## allowing the framework to validate the host structure automatically.
##
## [codeblock]
## var host: CharacterBody2D:
##     get: return _host_type()
##
## func _host_type() -> CharacterBody2D:
##     return owner
## [/codeblock]
##
## [b]Note:[/b] A component is meant to be unique on its host, you can have
## multiple different types, but not two of the same type. If you
## want more functionality, or want to disable one, prefer creating
## a new component that extends the previous one.


func _get_configuration_warnings() -> PackedStringArray:
	return _validate_host()


## Override to define the type of expected host/owner.
func _host_type() -> Node:
	return owner


func _validate_host() -> PackedStringArray:
	if not _host_type():
		var expected_type: String = "Node"

		for method in get_method_list():
			if method.name == "_host_type":
				var return_info: Dictionary = method["return"]
				if return_info.has("class_name") and return_info["class_name"] != &"":
					expected_type = return_info["class_name"]
				break
		return [
			"This component needs a host as %s." % expected_type,
		]
	return []
