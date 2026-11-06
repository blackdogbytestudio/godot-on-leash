extends GutTest
## DogCharacter2D: the host is the owner when it is a CharacterBody2D, and the
## component warns when it is not.


func _component_owned_by(host: Node) -> DogCharacter2D:
	var component := DogJump2D.new()
	host.add_child(component)
	component.owner = host
	add_child_autofree(host)
	return component


func test_a_character_body_owner_is_the_host() -> void:
	var host := CharacterBody2D.new()
	var component := _component_owned_by(host)
	assert_eq(component.host, host)
	assert_eq(component._get_configuration_warnings(), PackedStringArray())


func test_an_owner_of_another_type_is_no_host_and_a_warning() -> void:
	var component := _component_owned_by(Node2D.new())
	assert_null(component.host)
	assert_eq(
		component._get_configuration_warnings(),
		PackedStringArray(["This component needs a host as CharacterBody2D."]),
	)
