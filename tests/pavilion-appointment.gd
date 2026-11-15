extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await load("res://tests/PavilionAppointmentReplay.gd").new().run_appointment(self, "", "pavilion-appointment")
