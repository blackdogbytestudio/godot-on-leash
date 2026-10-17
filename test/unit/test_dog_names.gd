# gdstyle:ignore-file=quality/max-public-methods
extends GutTest
## DogNames: the snake_case rule for actor and component names, and the
## snake_case -> PascalCase conversion used for class names.


func test_is_valid_name_accepts_digit_parts_and_rejects_bad_shapes() -> void:
	for ok in ["player", "character_body_2d", "dog_jump_2d", "a1", "a_10d"]:
		assert_true(DogNames.is_valid_name(ok), ok)
	for bad in ["", "Player", "_player", "player_", "a__b", "2d", "a-b", "a b", "a/b", "a\n"]:
		assert_false(DogNames.is_valid_name(bad), bad)


func test_to_pascal_capitalizes_each_part() -> void:
	assert_eq(DogNames.to_pascal("skinny_man"), "SkinnyMan")
	assert_eq(DogNames.to_pascal("enemy_alive_state"), "EnemyAliveState")


func test_to_pascal_without_underscore() -> void:
	assert_eq(DogNames.to_pascal("player"), "Player")


func test_to_pascal_capitalizes_the_letter_after_a_number() -> void:
	assert_eq(DogNames.to_pascal("character_body_2d"), "CharacterBody2D")
	assert_eq(DogNames.to_pascal("dog_jump_2d"), "DogJump2D")
	assert_eq(DogNames.to_pascal("a_10d"), "A10D")
	assert_eq(DogNames.to_pascal("a2b3c"), "A2B3C")


func test_to_pascal_keeps_trailing_digits() -> void:
	assert_eq(DogNames.to_pascal("area_2"), "Area2")
	assert_eq(DogNames.to_pascal("a1"), "A1")


func test_to_pascal_of_empty_is_empty() -> void:
	assert_eq(DogNames.to_pascal(""), "")
