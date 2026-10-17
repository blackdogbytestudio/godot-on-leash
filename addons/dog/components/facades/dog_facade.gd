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
## after _ready():
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
## [b]Note:[/b] don't use @onready for component vars, the var must
## exist before the @export setter runs, and @onready only resolves
## after _ready():


func _enter_tree() -> void:
	dog_leash()


## Registers components to the facade.
## The components host/owner is assings as [member DogComponent.host_type]
##
## [codeblock]
## func dog_leash() -> void:
##     super.dog_leash(_jump, _move, _gravity)
## [/codeblock]
func dog_leash(...components: Array) -> void:
	if components.is_empty():
		push_error("%s: must override dog_leash() and register its components" % [get_script().get_global_name()])
		return
	for c in components:
		if not c is DogComponent:
			push_error("%s: dog_leash() received a non-DogComponent (%s)" % [get_script().get_global_name(), c])
			continue
		if not c.get_parent():
			add_child(c, false, Node.INTERNAL_MODE_BACK)
			c.owner = host_type()
			c.name = c.get_script().get_global_name()
