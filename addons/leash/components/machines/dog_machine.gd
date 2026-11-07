@tool
class_name DogMachine
extends DogComponent
## Base for all state machine components.
##
## The active state changes in two ways: update() returns the next state, every
## frame, and send() hands an event to the active state, which may return one.

## Emitted after every change of the active state, with the state left (null at
## init) and the state entered.
signal transitioned(from: DogState, to: DogState)

## Reference to the host/owner. Passed to the state on enter/exit/update.
var host: Node:
	get: return _host_type()
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
	transitioned.emit(null, _current)


## Drive the active state. Call from the host/owner's _physics_process:
##
## [codeblock]
## func _physics_process(delta: float) -> void:
##   fsm.update(delta)
## [/codeblock]
##
## A state returned by update() that is the active one is ignored: a parent
## state that returns idle every frame while on the floor keeps idle running.
func update(delta: float) -> void:
	if _current == null:
		return
	var next: DogState = _current.update(host, delta)
	if next == null or next == _current:
		return
	_change(next)


## Hand an event to the active state (see [method DogState.on_event]). The state
## it returns is entered, even when it is the active one: a second hit restarts
## the hurt state. Nothing happens before init() or when the state returns null.
##
## [codeblock]
## func _on_hurtbox_hurt(hit: DogHit) -> void:
##   fsm.send(&"hurt", hit)
## [/codeblock]
func send(event: StringName, data: Variant = null) -> void:
	if _current == null:
		return
	var next: DogState = _current.on_event(host, event, data)
	if next == null:
		return
	_change(next)


## Exits the active state, enters `next` and emits transitioned.
func _change(next: DogState) -> void:
	var previous := _current
	previous.exit(host)
	_current = next
	_current.enter(host)
	transitioned.emit(previous, _current)
