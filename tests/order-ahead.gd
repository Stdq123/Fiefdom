extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var replay = load("res://tests/OrderPreparationReplay.gd").new()
	replay.start_planting_early = true
	await replay.run(self)
