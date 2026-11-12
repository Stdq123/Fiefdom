extends SceneTree

const EstateDirectionsReplay := preload("res://tests/EstateDirectionsReplay.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var replay := EstateDirectionsReplay.new()
	await replay.run(self)
