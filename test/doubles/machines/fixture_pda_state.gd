class_name FixturePdaState
extends DogPDAState
## A DogPDAState that does nothing.


func enter(_host: Node) -> void:
	pass


func exit(_host: Node) -> void:
	pass


func update(_host: Node, _delta: float) -> DogState:
	return null


func pause(_host: Node) -> void:
	pass


func resume(_host: Node) -> void:
	pass
