extends SceneTree

const CreekWildlifeReplay := preload("res://tests/CreekWildlifeReplay.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var replay := CreekWildlifeReplay.new()
	await replay.run(self)
