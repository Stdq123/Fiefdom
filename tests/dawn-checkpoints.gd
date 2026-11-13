extends SceneTree

const DawnCheckpointReplay := preload("res://tests/DawnCheckpointReplay.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var replay := DawnCheckpointReplay.new()
	await replay.run(self, OS.get_environment("FIEFDOM_DAWN_PHASE"))
