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

var _stack: Array[DogPDAState] = []


## Push the initial state onto the stack.
func init(state: DogState) -> void:
	push(state as DogPDAState)


## Push a new state on top. Current state is paused, not exited.
func push(state: DogPDAState) -> void:
	if _current != null:
		(_current as DogPDAState).pause(host)
	_stack.push_back(state)
	_current = state
	_current.enter(host)


## Pop the top state. Top is exited, the one below resumes.
func pop() -> void:
	if _stack.size() <= 1:
		push_warning("Dog: cannot pop the last state.")
		return
	_current.exit(host)
	_stack.pop_back()
	_current = _stack.back()
	(_current as DogPDAState).resume(host)


## The state below the top, without popping.
func peek() -> DogPDAState:
	if _stack.size() < 2:
		return null
	return _stack[_stack.size() - 2]


## Stack depth.
func depth() -> int:
	return _stack.size()


func _transition(next: DogState) -> void:
	if next == null:
		return
	if _current.get_script() == next.get_script():
		return
	_current.exit(host)
	_stack[_stack.size() - 1] = next as DogPDAState
	_current = next
	_current.enter(host)
