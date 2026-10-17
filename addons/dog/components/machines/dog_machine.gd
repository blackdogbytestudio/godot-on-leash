@tool
class_name DogMachine
extends DogComponent
## Base for all state machine components.

## Reference to the host/owner. Passed to the state on enter/exit/update.
var host: Node:
	get: return host_type()
var _current: DogState


## Initialise the machine with a starting state reference. Call once,
## in the host/owner's _ready().
##
## [codeblock]
## func _ready() -> void:
##   fsm.init(idle_state)
## [/codeblock]
func init(state: DogState) -> void:
	_current = state
	_current.enter(host)


## Drive the active state. Call from the host/owner's _physics_process:
##
## [codeblock]
## func _physics_process(delta: float) -> void:
##   fsm.update(delta)
## [/codeblock]
func update(delta: float) -> void:
	if _current == null:
		return
	var next: DogState = _current.update(host, delta)
	if next != null:
		_transition(next)


func _transition(next: DogState) -> void:
	if next == null:
		return
	if _current != null:
		if _current.get_script() == next.get_script():
			return
		_current.exit(host)
	_current = next
	_current.enter(host)
