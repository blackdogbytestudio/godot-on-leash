@tool
class_name DogCharacterFacade2D
extends DogFacade
## Base for facades whose host is a [CharacterBody2D].


func _host_type() -> CharacterBody2D:
	return owner
