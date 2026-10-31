extends SceneTree
## Runs a leash command without the editor, the way the panel does:
##
##   godot --headless -s res://addons/leash/cli/leash_cmdln.gd -- bind player jump
##
## Everything after `--` is the command line (`help` when there is none). The output
## goes to stdout and the exit code is 0 when the command succeeded, 1 when it failed.
## Needs the class cache of the project, so run `godot --headless --import` once
## after a fresh checkout. Without the editor nothing reloads the scenes and scripts
## that are open there.

const COMMANDS := "res://addons/leash/cli/commands"


func _init() -> void:
	DogSettings.register()
	var cli := DogCli.new()
	cli.register_folder(COMMANDS)
	cli.printed.connect(func(text: String) -> void: print(text))

	var line := " ".join(OS.get_cmdline_user_args())
	var error := cli.execute(line if not line.is_empty() else "help")
	cli.dispose()
	quit(0 if error == OK else 1)
