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
