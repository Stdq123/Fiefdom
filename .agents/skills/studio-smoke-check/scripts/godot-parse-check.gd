extends SceneTree
## Based on Game Studios' MIT-licensed godot-parse-check.gd.
## Load scripts after startup so their Autoload references can resolve.


func _initialize() -> void:
	var paths := OS.get_cmdline_user_args()
	if paths.is_empty():
		printerr("godot-parse-check: no scripts given. Pass res:// paths after '--'.")
		quit(2)
		return
	var failed := 0
	for path in paths:
		var script := load(path) as Script
		if script == null or not script.can_instantiate():
			printerr("PARSE FAIL: ", path)
			failed += 1
		else:
			print("ok: ", path)
	quit(1 if failed > 0 else 0)
