extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		push_error(detail)
		failed = true

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run irrigation-state with Test-GodotSmoke.ps1 to isolate its save.")
		quit(1)
		return
	change_scene_to_file("res://scenes/Main.tscn")
	await scene_changed
	var state := root.get_node("Global")
	var near := Vector2i(2, 5)
	var far := Vector2i(3, 5)
	var plot := Vector2i(4, 5)
	_expect(state.check_channel_site(near) == state.ChannelSite.LOCKED, "The technology gates channel placement.")
	state.tech_unlocked["irrigation"] = true
	_expect(state.check_channel_site(near) == state.ChannelSite.NO_FUNDS, "An empty purse prevents construction.")
	state.balance.irrigation_channel_cost = 6
	state.money = 18
	_expect(state.build_channel(far) == state.ChannelSite.AVAILABLE, "A dry section can be placed.")
	_expect(not state.irrigation.is_channel_wet(far), "A dry section cannot reach the water source.")
	_expect(state.build_channel(near) == state.ChannelSite.AVAILABLE, "The connector can be placed.")
	_expect(state.irrigation.supplies(plot) and not state.irrigation.supplies(Vector2i(4, 4)), "Supply reaches only neighboring cells.")
	_expect(state.build_channel(near) == state.ChannelSite.ALREADY_BUILT and state.money == 6, "Repeated placement charges nothing.")
	for cell in [state.irrigation.source_cell, plot, Vector2i(100, 100)]:
		_expect(state.check_channel_site(cell) == state.ChannelSite.BLOCKED, "The source, fields and out-of-bounds cells are reserved.")
	state.current_rank = state.Rank.ZHONG_SHI
	state._update_max_well_fields()
	_expect(not state.can_add_well_field(Vector2i(1, 4)) and state.can_add_well_field(Vector2i(9, 5)), "Reclamation cannot cover the water source or its canals.")
	_expect(state.fill_channel(near) and not state.irrigation.supplies(plot), "Filling the connector cuts supply.")
	_expect(not state.fill_channel(near) and state.money == 6, "Filling an empty cell has no effect.")
	_expect(state.save_game() == OK and state.load_game() == OK, "A canal save reloads.")
	await scene_changed
	_expect(state.irrigation.channels.has(far) and not state.irrigation.is_channel_wet(far), "A disconnected canal stays dry across reload.")
	_expect(state.build_channel(near) == state.ChannelSite.AVAILABLE and state.irrigation.supplies(plot), "The loaded network can reconnect.")
	state.irrigation.add_channel(Vector2i(10, 10))
	_expect(state.reclamation_site(Vector2i(9, 10)) == state.ReclamationSite.CANAL
		and state.reclamation_site(Vector2i(1, 4)) == state.ReclamationSite.SOURCE
		and state.reclamation_site(Vector2i(-20, 0)) == state.ReclamationSite.EDGE,
		"The survey distinguishes an existing ditch, the water source and the boundary.")

	var old_save := FileAccess.open("user://savegame.json", FileAccess.WRITE)
	old_save.store_string('{"current_day":4,"well_fields":[{"center_pos":"(5, 5)","is_unlocked":true},{"center_pos":"(1, 5)","is_unlocked":true}],"active_crops":{"1,5":{"id":"rice","age":1,"watered":true}}}')
	old_save.close()
	_expect(state.load_game(state.SAVE_PATH) == OK, "The old save loads with its existing rice.")
	await scene_changed
	_expect(state.irrigation.channels.is_empty() and state.irrigation.source_cell == Vector2i(5, 1), "The source respects existing fields in legacy saves.")
	_expect(state.active_crops[Vector2i(1, 5)]["watered"] and not state.active_crops[Vector2i(1, 5)]["requires_channel"], "Existing rice keeps manual watering.")
	_expect(state.active_crops[Vector2i(1, 5)]["growth_nights"] == 4, "Legacy crops receive their original unmodified growth target.")
	var ui := current_scene.get_node("UI")
	ui.sleep_button.pressed.emit()
	await create_timer(1.1).timeout
	_expect(state.active_crops[Vector2i(1, 5)]["age"] == 2, "Manually watered legacy rice still grows overnight.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
