@tool
class_name DogPDA
extends DogMachine
## Pushdown automaton component. Expects DogPDAState instances so
## pause and resume are available.
##
## push() suspends current via pause(), activates new via enter().
## pop() exits top via exit(), resumes below via resume().
##
## [codeblock]
## var idle_state  := PlayerIdleState.new()  # extends PlayerAliveState
## var pause_state := PlayerPauseState.new() # extends PlayerLockedState
##
## func _ready() -> void:
##   pda.init(idle_state)
##
## func _process(delta: float) -> void:
##   pda.update(delta)
##
## func _on_pause_pressed() -> void:
##   pda.push(pause_state)
##
## func _on_resume_pressed() -> void:
##   pda.pop()
## [/codeblock]

# Error messages
const NOT_A_PDA_STATE := "Dog: %s needs a DogPDAState, got %s."

var _stack: Array[DogPDAState] = []


## Push the initial state onto the stack. A state that is not a DogPDAState is an
## error, and nothing is pushed.
func init(state: DogState) -> void:
	if not _is_pda_state(state):
		return
	push(state)


## Push a new state on top. Current state is paused, not exited.
func push(state: DogPDAState) -> void:
	if not _is_pda_state(state):
		return
	var previous := _current
	if previous != null:
		(previous as DogPDAState).pause(host)
	_stack.push_back(state)
	_current = state
	_current.enter(host)
	transitioned.emit(previous, _current)


## Pop the top state. Top is exited, the one below resumes.
func pop() -> void:
	if _stack.size() <= 1:
		push_warning("Dog: cannot pop the last state.")
		return
	var previous := _current
	previous.exit(host)
	_stack.pop_back()
	_current = _stack.back()
	(_current as DogPDAState).resume(host)
	transitioned.emit(previous, _current)


## The state below the top, without popping.
func peek() -> DogPDAState:
	if _stack.size() < 2:
		return null
	return _stack[_stack.size() - 2]


## Stack depth.
func depth() -> int:
	return _stack.size()


## Replaces the top of the stack: the states below stay paused.
func _change(next: DogState) -> void:
	if not _is_pda_state(next):
		return
	var previous := _current
	previous.exit(host)
	_stack[_stack.size() - 1] = next as DogPDAState
	_current = next
	_current.enter(host)
	transitioned.emit(previous, _current)


## Whether `state` can live on the stack; push_error when it can't.
func _is_pda_state(state: DogState) -> bool:
	if state is DogPDAState:
		return true
	var got := "null" if state == null else str(state.get_script().get_global_name())
	push_error(NOT_A_PDA_STATE % [get_script().get_global_name(), got])
	return false
