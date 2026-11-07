@tool
class_name DogFSM
extends DogMachine
## Flat finite state machine.
##
## States return the next DogState from update() to transition, and from
## on_event() to react to what send() hands them.
##
## [codeblock]
## func _ready() -> void:
##   fsm.init(idle_state)
##
## func _physics_process(delta: float) -> void:
##   fsm.update(delta)
##
## func _on_hurtbox_hurt(hit: DogHit) -> void:
##   fsm.send(&"hurt", hit)
## [/codeblock]
