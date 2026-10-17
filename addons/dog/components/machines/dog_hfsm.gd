@tool
class_name DogHFSM
extends DogFSM
## Hierarchical state machine component.
##
## Works exactly like [DogFSM],
## the hierarchy lives inside the states via GDScript inheritance and
## super(). The machine itself does not change.
##
## [codeblock]
## var idle_state     := PlayerIdleState.new()     # extends PlayerGroundedState
## var walk_state     := PlayerWalkState.new()     # extends PlayerGroundedState
## var airborne_state := PlayerAirborneState.new() # extends PlayerAliveState
##
## func _ready() -> void:
##   hfsm.init(idle_state)
##
##
## func _process(delta: float) -> void:
##   hfsm.update(delta)
## [/codeblock]
