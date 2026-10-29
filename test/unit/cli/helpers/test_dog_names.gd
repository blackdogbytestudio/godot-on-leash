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


func test_actor_error_is_empty_for_a_valid_actor() -> void:
	assert_eq(DogNames.actor_error("skinny_man"), "")


func test_actor_error_names_the_bad_actor() -> void:
	assert_eq(DogNames.actor_error("Player"), DogNames.INVALID_ACTOR % "Player")


func test_folder_error_accepts_empty_and_snake_case_parts() -> void:
	assert_eq(DogNames.folder_error(""), "")
	assert_eq(DogNames.folder_error("enemies/slime_2d"), "")


func test_folder_error_accepts_res_as_a_name() -> void:
	assert_eq(DogNames.folder_error("res"), "")
	assert_eq(DogNames.folder_error("res/scenes"), "")


func test_folder_error_rejects_bad_parts() -> void:
	var bad_folders := [
		"Enemies",  # upper case letter
		"enemies/",  # trailing slash leaves an empty part
		"/enemies",  # leading slash leaves an empty part
		"enemies//slime",  # double slash leaves an empty part
		"../x",  # dots, no going up
		"a/../b",  # dots in the middle
		"a b",  # space
		"a.b",  # dot
		"a,b",  # comma
		"res://scenes",  # res:// is added for you, colon and double slash
	]
	for bad in bad_folders:
		assert_eq(DogNames.folder_error(bad), DogNames.INVALID_FOLDER % bad, bad)


func test_folder_error_names_the_setting_when_given() -> void:
	var key := "leash/generators/explicit_folder"
	var error: String = DogNames.INVALID_FOLDER % "res://scenes"
	assert_eq(DogNames.folder_error("res://scenes", key), DogNames.INVALID_SETTING % [key, error])
	assert_eq(DogNames.folder_error("scenes", key), "")
