extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var replay = load("res://tests/CampaignReplay.gd").new()
	await replay.run(self, "traditional", false, "", OS.get_cmdline_user_args().has("delegate-rations"))
