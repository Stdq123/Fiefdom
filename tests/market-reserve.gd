extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var replay = load("res://tests/MarketReserveReplay.gd").new()
	await replay.run_market_reserve(self)
