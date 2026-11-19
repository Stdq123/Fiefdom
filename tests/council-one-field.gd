extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var replay = load("res://tests/CouncilPrepReplay.gd").new()
	replay.single_field = true
	await replay.run(self)
