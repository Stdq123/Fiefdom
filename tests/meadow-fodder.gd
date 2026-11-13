extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var replay = load("res://tests/SheepfoldReplay.gd").new()
	replay.meadow_only = true
	await replay.run(self)
