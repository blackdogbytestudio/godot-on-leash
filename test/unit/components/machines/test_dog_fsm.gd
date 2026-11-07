extends GutTest
## DogFSM: update() moves to the state it returns, unless it is the active one;
## send() hands an event to the active state and enters what it returns, even
## the active one; every change emits transitioned.

var _fsm: DogFSM
var _history: Array
var _idle: Step
var _hurt: Step


func before_each() -> void:
	_fsm = autofree(DogFSM.new())
	_history = []
	_idle = Step.new("idle", _history)
	_hurt = Step.new("hurt", _history)


func test_update_moves_to_the_state_it_returns() -> void:
	_idle.on_update = _hurt
	_fsm.init(_idle)
	_fsm.update(0.1)
	assert_eq(_history, ["enter idle", "exit idle", "enter hurt"])


func test_update_returning_the_active_state_keeps_it_running() -> void:
	_idle.on_update = _idle
	_fsm.init(_idle)
	_fsm.update(0.1)
	assert_eq(_history, ["enter idle"])


func test_send_hands_the_event_and_its_data_to_the_active_state() -> void:
	_idle.on_hurt = _hurt
	_fsm.init(_idle)
	_fsm.send(&"hurt", 20)
	assert_eq(_history, ["enter idle", "hurt 20", "exit idle", "enter hurt"])


func test_send_enters_the_active_state_again() -> void:
	_hurt.on_hurt = _hurt
	_fsm.init(_hurt)
	_fsm.send(&"hurt", 5)
	assert_eq(_history, ["enter hurt", "hurt 5", "exit hurt", "enter hurt"])


func test_an_event_the_state_ignores_changes_nothing() -> void:
	_fsm.init(_idle)
	_fsm.send(&"jump")
	assert_eq(_history, ["enter idle"])


func test_send_before_init_does_nothing() -> void:
	_fsm.send(&"hurt", 5)
	assert_eq(_history, [])


func test_every_change_emits_transitioned() -> void:
	_idle.on_hurt = _hurt
	watch_signals(_fsm)
	_fsm.init(_idle)
	assert_signal_emitted_with_parameters(_fsm, "transitioned", [null, _idle])
	_fsm.send(&"hurt", 5)
	assert_signal_emitted_with_parameters(_fsm, "transitioned", [_idle, _hurt])


## Writes its lifecycle to `history`; goes to `on_update` from update() and to
## `on_hurt` from the hurt event.
class Step:
	extends DogFSMState

	var label: String
	var history: Array
	var on_update: DogState
	var on_hurt: DogState

	func _init(label_: String, history_: Array) -> void:
		label = label_
		history = history_

	func enter(_host: Node) -> void:
		history.append("enter " + label)

	func exit(_host: Node) -> void:
		history.append("exit " + label)

	func update(_host: Node, _delta: float) -> DogState:
		return on_update

	func on_event(_host: Node, event: StringName, data: Variant) -> DogState:
		if event != &"hurt":
			return null
		history.append("hurt %s" % [data])
		return on_hurt
