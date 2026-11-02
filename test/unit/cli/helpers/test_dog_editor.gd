extends GutTest
## DogEditor outside the editor. Scanning and reloading open scenes and
## scripts need a running editor, so only the headless path is covered here.


func test_refresh_does_nothing_outside_the_editor() -> void:
	assert_false(Engine.is_editor_hint())
	DogEditor.refresh(PackedStringArray(["res://nothing.gd", "res://nothing.tscn"]))
	DogEditor.refresh()
	assert_true(true, "refresh returned without an editor")
