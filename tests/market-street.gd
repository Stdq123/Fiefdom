extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var variant := "market-street" if arguments.is_empty() else arguments[0]
	await load("res://tests/MarketStreetReplay.gd").new().run_street(self, "", variant)
