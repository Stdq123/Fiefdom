extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run key-bindings with Test-GodotSmoke.ps1 to isolate settings and saves.")
		quit(1)
		return
	var replay = load("res://tests/KeyBindingsReplay.gd").new()
	await replay.run(self, "", false, true)
