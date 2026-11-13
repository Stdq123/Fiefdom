extends SceneTree

const EndingFilmReplay := preload("res://tests/EndingFilmReplay.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var replay := EndingFilmReplay.new()
	await replay.run(self)
