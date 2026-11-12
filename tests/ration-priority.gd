extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var replay = load("res://tests/RationPriorityReplay.gd").new()
	await replay.run(self)
