extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var replay = load("res://tests/MarketOrderReplay.gd").new()
	await replay.run(self)
