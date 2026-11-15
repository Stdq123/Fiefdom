extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await load("res://tests/DutyRationsReplay.gd").new().run_duty_rations(self)
