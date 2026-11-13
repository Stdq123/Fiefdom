extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var replay = load("res://tests/MapTravelReplay.gd").new()
	await replay.run(self)
