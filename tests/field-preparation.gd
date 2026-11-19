extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await load("res://tests/FieldPreparationReplay.gd").new().run_preparation(self)
