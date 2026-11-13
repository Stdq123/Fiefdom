extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run title-presentation with an isolated player profile.")
		quit(1)
		return
	var replay = load("res://tests/TitlePresentationReplay.gd").new()
	await replay.run(self)
