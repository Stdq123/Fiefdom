extends SceneTree

const FieldKeeperReplay := preload("res://tests/FieldKeeperReplay.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var replay := FieldKeeperReplay.new()
	await replay.run(self)
