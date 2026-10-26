@tool
extends EditorPlugin

var _cli: DogCli
var _panel: DogPanel


func _enter_tree() -> void:
	DogSettings.register()
	_cli = DogCli.new()
	_cli.register_folder("res://addons/leash/cli/commands")
	_panel = DogPanel.new(_cli)
	add_control_to_bottom_panel(_panel, "Leash")


func _exit_tree() -> void:
	remove_control_from_bottom_panel(_panel)
	_panel.free()
	_cli.dispose()


func _enable_plugin() -> void:
	DogScaffoldSetup.install()
	DogTemplateSetup.install()


func _disable_plugin() -> void:
	pass
