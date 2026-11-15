extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await load("res://tests/HarvestScopeReplay.gd").new().run_harvest_scope(self)
