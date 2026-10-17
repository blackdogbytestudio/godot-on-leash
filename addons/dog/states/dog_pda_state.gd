@abstract
class_name DogPDAState
extends DogState
## Base class for states that live on a DogPDA stack.
##
## A state can be paused when another state
## is pushed on top of it and resumed when that state is removed.
##
## [codeblock]
## enter  → state becomes active
## pause  → state is suspended
## resume → state becomes active again
## exit   → state is removed from the stack
## [/codeblock]
##
## [br]
## [b]Example:[/b]
## [codeblock]
## class PauseState extends DogPDAState:
##     func pause(host: Node) -> void:
##         host.set_physics_process(false)
##
##     func resume(host: Node) -> void:
##         host.set_physics_process(true)
## [/codeblock]


## Called when another state is pushed on top of this state.
## Pause the state without cleaning up its resources.
@abstract
func pause(host: Node) -> void


## Called when the state above this one is removed.
## Resume the state from where it was paused.


@abstract
func resume(host: Node) -> void
