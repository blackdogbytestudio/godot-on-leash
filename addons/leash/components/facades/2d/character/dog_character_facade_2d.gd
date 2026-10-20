@tool
class_name DogCharacterFacade2D
extends DogFacade
## Base for facades whose host is a [CharacterBody2D].


func host_type() -> CharacterBody2D:
	return owner
