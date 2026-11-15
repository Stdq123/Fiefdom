extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await load("res://tests/HarvestReplantReplay.gd").new().run_replanting(self)
