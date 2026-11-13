extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var replay = load("res://tests/CouncilPrepReplay.gd").new()
	replay.petition = true
	await replay.run(self)
