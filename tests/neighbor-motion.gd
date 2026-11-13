extends SceneTree

const NeighborMotionReplay := preload("res://tests/NeighborMotionReplay.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var replay := NeighborMotionReplay.new()
	await replay.run(self)
