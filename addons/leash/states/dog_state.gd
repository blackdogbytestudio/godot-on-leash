@abstract
class_name DogState
extends RefCounted
## Base class for all Dog states.
##
## States are pure objects and do not enter the scene tree.
## The host is passed explicitly to lifecycle methods.


## Called when this state becomes active.
@abstract
func enter(host: Node) -> void


## Called when this state is deactivated.


@abstract
func exit(host: Node) -> void


## Called to update this state.
##
## Return a DogState to request a transition.
## Return null to remain in the current state.


@abstract
func update(host: Node, delta: float) -> DogState


## Called when the machine receives an event (see [method DogMachine.send]).
##
## Return a DogState to transition to it, even when it is this same state: the
## state is exited and entered again. Return null to ignore the event.
## Hand the data to the next state before returning it:
##
## [codeblock]
## func on_event(host: Node, event: StringName, data: Variant) -> DogState:
##     if event == &"hurt":
##         host.hurt_state.hit = data
##         return host.hurt_state
##     return null
## [/codeblock]


func on_event(_host: Node, _event: StringName, _data: Variant) -> DogState:
	return null
