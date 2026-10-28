@tool
class_name DogFacade
extends DogComponent
## Base class for facade components.
##
## The Facade orchestrates multiple components and exposes a
## single, flattened [code]@export[/code] surface for them.
##
## This centralizes and simplifies the interface of components
## that converge with one another. It prevents polluting
## the host/owner tree with dozens of exposed nodes.
##
## [codeblock]
## @export var max_jumps: int = 1:
##     set(value):
##         max_jumps = value
##         _jump.max_jumps = value
##
## var _jump: JumpComponent = JumpComponent.new()
## [/codeblock]
##
## Every [DogComponent] held in a script variable is registered on its own:
## when the facade enters the tree it becomes an internal child, owned by
## [method DogComponent._host_type]. If the facade is freed without ever
## entering the tree, it frees them too.
##
## [b]Note:[/b] don't use @onready for component vars, the var must
## exist before the @export setter runs, and @onready only resolves
## after _ready():

# Error messages
const NO_COMPONENTS := "Dog: %s has no DogComponent variables."


func _enter_tree() -> void:
	var components := _own_components()
	if components.is_empty():
		push_error(NO_COMPONENTS % get_script().get_global_name())
		return
	for c in components:
		if not c.get_parent():
			add_child(c, false, Node.INTERNAL_MODE_BACK)
			c.owner = _host_type()
			c.name = c.get_script().get_global_name()


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	for c in _own_components():
		if not c.get_parent():
			c.free()


## The DogComponents held in this script's variables, in declaration order.
func _own_components() -> Array[DogComponent]:
	var found: Array[DogComponent] = []
	for property in get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var value: Variant = get(property["name"])
		if is_instance_valid(value) and value is DogComponent:
			found.append(value)
	return found
