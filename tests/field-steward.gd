extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var replay = load("res://tests/FieldSeedPlanReplay.gd").new()
	replay.steward_story = true
	await replay.run(self)
