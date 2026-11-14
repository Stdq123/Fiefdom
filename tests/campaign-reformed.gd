extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var replay = load("res://tests/CampaignReplay.gd").new()
	var arguments := OS.get_cmdline_user_args()
	replay.use_reform_sale = arguments.has("reform-sale")
	await replay.run(self, "reformed", false, "", arguments.has("delegate-rations"))
