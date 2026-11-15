extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await load("res://tests/LedgerAudioReplay.gd").new().run_ledger_audio(self)
