@abstract
class_name DogHFSMState
extends DogFSMState
## Base class for hierarchical finite state machine states.
##
## State hierarchy is defined through GDScript inheritance.
## Parent states can provide shared transition logic for child states.
##
## Call super() at the beginning of update() to allow parent states
## to handle transitions before running the child state logic.
