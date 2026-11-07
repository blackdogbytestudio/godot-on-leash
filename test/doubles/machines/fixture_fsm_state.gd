class_name FixtureFsmState
extends DogFSMState
## A DogFSMState that does nothing: it can't live on a DogPDA stack.


func enter(_host: Node) -> void:
	pass


func exit(_host: Node) -> void:
	pass


func update(_host: Node, _delta: float) -> DogState:
	return null
