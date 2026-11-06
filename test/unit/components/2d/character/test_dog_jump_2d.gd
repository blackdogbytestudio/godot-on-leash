extends GutTest
## DogJump2D: jump, wall jump and wall slide move the host's velocity.

var _host: CharacterBody2D
var _jump: DogJump2D


func before_each() -> void:
	_host = CharacterBody2D.new()
	_jump = DogJump2D.new()
	_host.add_child(_jump)
	_jump.owner = _host
	add_child_autofree(_host)


func test_wall_jump_pushes_away_from_a_wall_on_the_left() -> void:
	_jump.wall_jump(Vector2.RIGHT)
	assert_eq(_host.velocity, Vector2(300.0, -400.0))


func test_wall_jump_pushes_away_from_a_wall_on_the_right() -> void:
	_jump.wall_jump(Vector2.LEFT)
	assert_eq(_host.velocity, Vector2(-300.0, -400.0))


func test_wall_slide_caps_the_fall_speed() -> void:
	_host.velocity.y = 500.0
	_jump.wall_slide()
	assert_eq(_host.velocity.y, 100.0)
