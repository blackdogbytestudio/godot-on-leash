@abstract
class_name DogFSMState
extends DogState

## Blocks transitions to another state.
##
## Set to true when the state must wait for an event,
## such as a timer, animation, or signal.
var locked: bool = false
