extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	await load("res://tests/FieldJourneyReplay.gd").new().run_journey(self, "", "field-journey" if args.is_empty() else args[0])
