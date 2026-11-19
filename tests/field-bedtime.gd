extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await load("res://tests/FieldWorkWaitReplay.gd").new().run_bedtime(self)
