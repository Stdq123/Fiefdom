extends "res://tests/NightRationsReplay.gd"

var legacy := false

func _continue() -> void:
	tree.change_scene_to_file("res://scenes/Title.tscn")
	await tree.scene_changed
	tree.current_scene.continue_button.pressed.emit()
	await tree.scene_changed
	await tree.process_frame
	ui = tree.current_scene.get_node("UI")

func _choose(panel: Control, index: int) -> bool:
	var picker: OptionButton = panel.priority_picker
	await _click(picker)
	var menu := picker.get_popup()
	if not _expect(menu.visible, "Open the normal ration priority selector."):
		return false
	menu.set_focused_item(index)
	for pressed in [true, false]:
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.physical_keycode = KEY_ENTER
		enter.pressed = pressed
		Input.parse_input_event(enter)
		Input.flush_buffered_events()
		await tree.process_frame
	return _expect(not menu.visible and picker.selected == index,
		"Confirm item %d in the ration menu (selected %d, menu open %s)." % [index, picker.selected, menu.visible])

func _overnight(panel: Control, dawn_capture := "") -> void:
	await _click(panel.get_node("%Sleep"))
	await tree.create_timer(0.58).timeout
	if not dawn_capture.is_empty():
		await _capture(dawn_capture)
	await tree.create_timer(0.59).timeout

func _check_window(panel: Control) -> void:
	var rect: Rect2 = tree.root.get_visible_rect().grow(-10.0)
	_expect(rect.encloses(panel.get_node("Center/Window").get_global_rect())
		and rect.encloses(panel.get_node("%Sleep").get_global_rect()), "The ledger and sleep action fit within the window.")

func _play() -> void:
	var panel := await _open()
	_check_window(panel)
	_expect("领足 渠伯" in panel.meal_forecast.text and "粮仓将余 1 份" in panel.meal_forecast.text
		and "预计离任 · 石墨、季青" in panel.meal_forecast.text,
		"The default order serves the field worker and retains the extra portion.")
	await _capture("01-default-forecast")
	await _click(panel.duties_button)
	var management: Control = ui.panel_manager.management_panel_instance
	_expect(management.visible and management.retainer_list_container.get_child_count() == 3,
		"The shortage ledger opens the existing duty choices.")
	await _click(management.get_node("CloseButton"))
	panel = await _open()
	if not await _choose(panel, 3):
		return
	_expect(state.night_rations.priority.name == "季青" and "领足 季青" in panel.meal_forecast.text
		and "预计离任 · 石墨" in panel.meal_forecast.text and "季青可教习" in panel.meal_forecast.text,
		"The same grain now covers the teacher and previews the consequences.")
	await _capture("02-teacher-first")
	await _click(panel.close_button)
	if not _expect(state.save_game() == OK, "Save the chosen priority before sleeping."):
		return
	var before_night: String = state.manual_save_path()
	await _continue()
	panel = await _open()
	_expect(state.current_day == 49 and panel.priority_picker.selected == 3 and state.night_rations.priority.name == "季青",
		"Continue restores the priority before bedtime.")
	await _overnight(panel, "03-dawn-with-departure")
	var meal: Dictionary = state.night_rations.last
	_expect(state.current_day == 50 and meal.served == 2 and meal.need == 5
		and meal.missed == PackedStringArray(["渠伯", "石墨"]) and meal.departed == PackedStringArray(["石墨"])
		and state.reputation == 50 + state.balance.confucian_teaching_reputation
		and state.player_stats.stats["RITES"]["xp"] == state.balance.confucian_teaching_rites_xp
		and state.silk_workshop.last_reeled == 0 and state.silk_workshop.cocoons == 3,
		"The fed teacher works and only the unfed workers take the loss.")
	_expect(state.retainers.size() == 2 and state.retainers[1].name == "季青" and state.retainers[1].loyalty == 18
		and state.king_storage == 3 and state.money == 2 and state.food_storage == 0,
		"The teacher keeps their loyalty and the settlement uses exactly the stored grain.")
	print("RATIONS_PRIORITY_TEACH served=", meal.served, "/", meal.need, " departed=", meal.departed, " rites=", state.player_stats.stats["RITES"]["xp"])
	await _continue()
	panel = await _open()
	_expect(state.current_day == 50 and state.night_rations.priority.name == "季青" and panel.priority_picker.selected == 2
		and "缺餐 · 渠伯、石墨" in panel.receipt.text and "已离任 · 石墨" in panel.receipt.text,
		"The morning checkpoint restores the priority at its new roster index and the named receipt.")
	_check_window(panel)
	await _capture("04-morning-receipt")
	await _click(panel.close_button)
	if not _expect(state.load_game(before_night) == OK, "Reopen the same evening with the same stores."):
		return
	await tree.scene_changed
	await tree.process_frame
	ui = tree.current_scene.get_node("UI")
	panel = await _open()
	if not await _choose(panel, 2):
		return
	_expect("领足 石墨" in panel.meal_forecast.text and "石墨可夜缫丝" in panel.meal_forecast.text,
		"The alternative portion keeps the artisan at the loom.")
	await _capture("05-artisan-first")
	await _overnight(panel)
	meal = state.night_rations.last
	_expect(state.current_day == 50 and meal.served == 2 and meal.need == 5
		and meal.departed == PackedStringArray(["季青"]) and state.reputation == 50
		and state.silk_workshop.last_reeled == 1 and state.silk_workshop.cocoons == 2
		and state.silk_workshop.last_reel_thread == state.silk_thread_yield(),
		"The fed artisan reels one cocoon while the unfed teacher departs.")
	print("RATIONS_PRIORITY_REEL served=", meal.served, "/", meal.need, " departed=", meal.departed, " silk=", state.silk_workshop.last_reel_thread)

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated ration profile."):
		_end()
		return
	seed(784)
	state = tree.root.get_node("Global")
	capture_dir = OS.get_environment("FIEFDOM_RATIONS_CAPTURES")
	if not legacy:
		var fixture := {
			"current_day": 49, "food_storage": 2, "money": 2, "king_storage": 3, "reputation": 50,
			"retainers": [
				{"name": "渠伯", "school": 4, "duty": 0, "loyalty": 86},
				{"name": "石墨", "school": 2, "duty": 1, "loyalty": 16},
				{"name": "季青", "school": 1, "duty": 2, "loyalty": 18},
			],
			"silk_workshop": {"built": true, "cocoons": 3, "night_reeling": true},
		}
		var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(fixture))
		file.close()
	await _continue()
	if legacy:
		var panel := await _open()
		_expect(state.current_day == 50 and state.retainers.size() == 1 and state.night_rations.priority == null
			and "用粮 2/5" in panel.receipt.text and not state.night_rations.last.has("missed"),
			"The old receipt keeps its original meal count without assigning names or a priority.")
		print("RATIONS_PRIORITY_OLD_SAVE day=", state.current_day, " served=", state.night_rations.last.served)
	else:
		await _play()
	_end()
