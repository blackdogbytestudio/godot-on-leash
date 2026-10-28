@tool
class_name DogCharacter2D
extends DogComponent
## Specialized [DogComponent] with a pre-typed host for [CharacterBody2D].

## Typed access to the host/owner as [CharacterBody2D].
var host: CharacterBody2D:
	get: return _host_type()


## Overrides [method DogComponent._host_type] with [CharacterBody2D].
func _host_type() -> CharacterBody2D:
	return owner
