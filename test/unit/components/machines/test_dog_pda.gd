extends GutTest
## DogPDA: only DogPDAStates go on the stack; anything else is an error and the
## stack stays as it was. Events replace the top; push and pop emit transitioned.

const NOT_A_PDA_STATE := "Dog: DogPDA needs a DogPDAState, got %s."

var _pda: DogPDA


func before_each() -> void:
	_pda = autofree(DogPDA.new())


func test_init_pushes_a_pda_state() -> void:
	_pda.init(FixturePdaState.new())
	assert_eq(_pda.depth(), 1)


func test_init_with_another_state_is_an_error() -> void:
	_pda.init(FixtureFsmState.new())
	assert_push_error(NOT_A_PDA_STATE % "FixtureFsmState")
	assert_eq(_pda.depth(), 0)


func test_push_null_is_an_error() -> void:
	_pda.init(FixturePdaState.new())
	_pda.push(null)
	assert_push_error(NOT_A_PDA_STATE % "null")
	assert_eq(_pda.depth(), 1)
