extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var replay = load("res://tests/RouteGoalsReplay.gd").new()
	await replay.run(self)
