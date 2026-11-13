extends SceneTree

const NightRationsReplay := preload("res://tests/NightRationsReplay.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var replay := NightRationsReplay.new()
	await replay.run(self)
