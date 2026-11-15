extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await load("res://tests/WalkingCheckpointReplay.gd").new().run_walking_checkpoint(self)
