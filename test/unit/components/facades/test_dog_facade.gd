extends GutTest
## DogFacade: the components held in its variables are registered when it enters
## the tree, and freed with it when it never did.

const COMPONENTS := ["DogJump2D", "DogMove2D", "DogGravity2D"]


## Like an instanced scene: the facade's owner is set before it enters the tree.
func _host_with_facade() -> Array:
	var host := CharacterBody2D.new()
	var facade := DogPlatformerFacade2D.new()
	host.add_child(facade)
	facade.owner = host
	add_child_autofree(host)
	return [host, facade]


func _internal_names(facade: Node) -> Array:
	var names := []
	for child in facade.get_children(true):
		names.append(str(child.name))
	return names


func test_entering_the_tree_adopts_every_component_variable() -> void:
	var nodes := _host_with_facade()
	var facade: DogPlatformerFacade2D = nodes[1]
	assert_eq(_internal_names(facade), COMPONENTS)
	assert_eq(facade.get_children().size(), 0, "they are internal children")
	for child in facade.get_children(true):
		assert_eq(child.owner, nodes[0])


func test_entering_the_tree_again_does_not_duplicate_them() -> void:
	var nodes := _host_with_facade()
	var host: CharacterBody2D = nodes[0]
	var facade: DogPlatformerFacade2D = nodes[1]
	host.remove_child(facade)
	host.add_child(facade)
	assert_eq(_internal_names(facade), COMPONENTS)


func test_a_facade_that_never_entered_the_tree_frees_its_components() -> void:
	var facade := DogPlatformerFacade2D.new()
	var refs := []
	for value in [facade._jump, facade._move, facade._gravity]:
		refs.append(weakref(value))
	facade.free()
	for ref in refs:
		assert_null(ref.get_ref())


func test_a_facade_without_components_is_an_error() -> void:
	var host: Node = add_child_autofree(Node.new())
	host.add_child(EmptyFacade.new())
	assert_push_error("Dog: EmptyFacade has no DogComponent variables.")
