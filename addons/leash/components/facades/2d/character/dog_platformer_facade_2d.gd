@tool
class_name DogPlatformerFacade2D
extends DogCharacterFacade2D
## Flattened configuration surface for a simple platformer character.
## Orchestrates [DogJump2D], [DogMove2D], and [DogGravity2D] behind a
## single set of grouped [code]@export[/code] properties.

@export_group("Jump")
@export var max_jumps: int = 1:
	set(value):
		max_jumps = value
		_jump.max_jumps = value
@export var jump_force: float = 400.0:
	set(value):
		jump_force = value
		_jump.jump_force = value
@export var coyote_time: float = 0.15:
	set(value):
		coyote_time = value
		_jump.coyote_time = value
@export var jump_buffer_time: float = 0.1:
	set(value):
		jump_buffer_time = value
		_jump.jump_buffer_time = value
@export var jump_cut_multiplier: float = 0.5:
	set(value):
		jump_cut_multiplier = value
		_jump.jump_cut_multiplier = value
@export var wall_jump_force: Vector2 = Vector2(300.0, -400.0):
	set(value):
		wall_jump_force = value
		_jump.wall_jump_force = value
@export var wall_slide_speed: float = 100.0:
	set(value):
		wall_slide_speed = value
		_jump.wall_slide_speed = value
@export_group("Move")
@export var speed: float = 200.0:
	set(value):
		speed = value
		_move.speed = value
@export var acceleration: float = 1500.0:
	set(value):
		acceleration = value
		_move.acceleration = value
@export var friction: float = 1200.0:
	set(value):
		friction = value
		_move.friction = value
@export_group("Gravity")
@export var gravity: float = 980.0:
	set(value):
		gravity = value
		_gravity.gravity = value

var _jump: DogJump2D = DogJump2D.new()
var _move: DogMove2D = DogMove2D.new()
var _gravity: DogGravity2D = DogGravity2D.new()


func dog_leash(...components: Array) -> void:
	super.dog_leash(_jump, _move, _gravity)


func jump() -> void:
	_jump.jump()


func can_jump() -> bool:
	return _jump.can_jump()


func cut_jump() -> void:
	_jump.cut_jump()


func start_jump_buffer() -> void:
	_jump.start_jump_buffer()


func has_buffered_jump() -> bool:
	return _jump.has_buffered_jump()


func wall_jump(wall_normal: Vector2) -> void:
	_jump.wall_jump(wall_normal)


func wall_slide() -> void:
	_jump.wall_slide()


func reset_jumps() -> void:
	_jump.reset_jumps()


func start_coyote() -> void:
	_jump.start_coyote()


func move(direction: Vector2, delta: float) -> void:
	_move.move(direction, delta)


func move_x(direction: float, delta: float) -> void:
	_move.move_x(direction, delta)


func move_y(direction: float, delta: float) -> void:
	_move.move_y(direction, delta)


func apply_gravity(delta: float) -> void:
	_gravity.apply_gravity(delta)
