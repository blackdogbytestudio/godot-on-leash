@tool
class_name DogFSM
extends DogMachine
## Flat finite state machine.
##
## States return the next DogState from update() to transition.
## force() transitions from the outside at any time.
##
## [codeblock]
## func _ready() -> void:
##   fsm.init(idle_state)
##
## func _process(delta: float) -> void:
##   fsm.update(delta)
##
## func _on_hitbox_area_entered(_area: Area2D) -> void:
##   fsm.force(hurt_state)
## [/codeblock]

var _locked: bool = false


## Force an immediate transition, bypassing locked.
func force(state: DogState) -> void:
	if state == null:
		push_warning("DOG_WARNING: force() received null state.")
		return
	_transition(state)


## Locks the machine.
func lock() -> void:
	if not _locked:
		_locked = true


## Unlocks the machine.
func unlock() -> void:
	if _locked:
		_locked = false


## Whether the machine is locked.
func is_locked() -> bool:
	return _locked
