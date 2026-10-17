class_name DogMove2D
extends DogCharacter2D
## Movement logic for a [CharacterBody2D].

@export var speed: float = 200.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0


func move(direction: Vector2, delta: float) -> void:
	move_x(direction.x, delta)
	move_y(direction.y, delta)


func move_x(direction: float, delta: float) -> void:
	if direction != 0.0:
		host.velocity.x = move_toward(host.velocity.x, direction * speed, acceleration * delta)
	else:
		host.velocity.x = move_toward(host.velocity.x, 0.0, friction * delta)


func move_y(direction: float, delta: float) -> void:
	if direction != 0.0:
		host.velocity.y = move_toward(host.velocity.y, direction * speed, acceleration * delta)
	else:
		host.velocity.y = move_toward(host.velocity.y, 0.0, friction * delta)
