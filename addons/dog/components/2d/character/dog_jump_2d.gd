class_name DogJump2D
extends DogCharacter2D
## Jump logic for a [CharacterBody2D].

@export var max_jumps: int = 1:
	set(value):
		max_jumps = value
		_jumps_remaining = value
@export var jump_force: float = 400.0
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.1
@export var jump_cut_multiplier: float = 0.5
@export var wall_jump_force: Vector2 = Vector2(300.0, -400.0)
@export var wall_slide_speed: float = 100.0

var _jumps_remaining: int = max_jumps
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0


func _physics_process(delta: float) -> void:
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func jump() -> void:
	host.velocity.y = -jump_force
	_jumps_remaining -= 1
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0


func can_jump() -> bool:
	return _jumps_remaining > 0 or _coyote_timer > 0.0


func cut_jump() -> void:
	if host.velocity.y < 0.0:
		host.velocity.y *= jump_cut_multiplier


func has_buffered_jump() -> bool:
	return _jump_buffer_timer > 0.0


func wall_jump(wall_normal: Vector2) -> void:
	host.velocity = wall_normal * wall_jump_force
	_jump_buffer_timer = 0.0


func wall_slide() -> void:
	host.velocity.y = minf(host.velocity.y, wall_slide_speed)


func reset_jumps() -> void:
	_jumps_remaining = max_jumps


func start_jump_buffer() -> void:
	_jump_buffer_timer = jump_buffer_time


func start_coyote() -> void:
	_coyote_timer = coyote_time
