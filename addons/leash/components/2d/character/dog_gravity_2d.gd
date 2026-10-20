class_name DogGravity2D
extends DogCharacter2D
## Gravity logic for a [CharacterBody2D].

@export var gravity: float = 980.0


func apply_gravity(delta: float) -> void:
	host.velocity.y += gravity * delta
