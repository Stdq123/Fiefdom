extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run gamepad with Test-GodotSmoke.ps1 to isolate its saves.")
		quit(1)
		return
	var replay = load("res://tests/GamepadReplay.gd").new()
	await replay.run(self)
