extends "res://tests/NightRationsReplay.gd"

const Campaign := preload("res://tests/CampaignReplay.gd")
const RATION_CHOICE := "查看今夜安排"

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
	panel.scroll.ensure_control_visible(picker)
	await tree.process_frame
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

func _overnight(panel: Control, dawn_capture := "", confirm_departure := false) -> void:
	await _click(panel.get_node("%Sleep"))
	await tree.process_frame
	if confirm_departure and not await _confirm_departure():
		return
	await _wait_for_dawn(dawn_capture)

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
	await _click(panel.get_node("%Sleep"))
	await tree.process_frame
	var warning := _bedtime_warning()
	if not _expect(warning != null and "2/5" in warning.text_label.text and "石墨缺餐后将离任" in warning.text_label.text
		and "渠伯" not in warning.text_label.text and warning.choices.front().text == RATION_CHOICE
		and warning.choices.front().has_focus(), "The plan warns only about the worker who would leave and focuses reviewing the meal."):
		return
	var visible_rect := tree.root.get_visible_rect().grow(-10.0)
	_expect(visible_rect.encloses(warning.choices.front().get_global_rect())
		and visible_rect.encloses(warning.choices.back().get_global_rect()), "Both warning actions fit in the viewport.")
	await _capture("rations-priority-bedtime-warning")
	if not await _confirm_departure():
		return
	await _wait_for_dawn("rations-priority-dawn-with-departure")
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
	if not await _load_evening(before_night):
		return
	panel = await _open()
	if not await _choose(panel, 2):
		return
	_expect("领足 石墨" in panel.meal_forecast.text and "石墨可夜缫丝" in panel.meal_forecast.text,
		"The alternative portion keeps the artisan at the loom.")
	await _capture("05-artisan-first")
	await _overnight(panel, "", true)
	meal = state.night_rations.last
	_expect(state.current_day == 50 and meal.served == 2 and meal.need == 5
		and meal.departed == PackedStringArray(["季青"]) and state.reputation == 50
		and state.silk_workshop.last_reeled == 1 and state.silk_workshop.cocoons == 2
		and state.silk_workshop.last_reel_thread == state.silk_thread_yield(),
		"The fed artisan reels one cocoon while the unfed teacher departs.")
	print("RATIONS_PRIORITY_REEL served=", meal.served, "/", meal.need, " departed=", meal.departed, " silk=", state.silk_workshop.last_reel_thread)
	if await _load_evening(before_night):
		await _play_forage_rescue()

func _load_evening(path: String) -> bool:
	if not _expect(state.load_game(path) == OK, "Reopen the same evening with the same stores."):
		return false
	await tree.scene_changed
	await tree.process_frame
	ui = tree.current_scene.get_node("UI")
	return true

func _play_forage_rescue() -> void:
	await _click(ui.sleep_button)
	var warning := _bedtime_warning()
	if not _expect(warning != null and warning.context_label.text == "门客口粮", "The direct sleep button warns about the same meal."):
		return
	_key(KEY_ESCAPE)
	await tree.create_timer(0.62).timeout
	_expect(_bedtime_warning() == null and not ui.world.player.conversation_open and state.current_day == 49
		and state.money == 2 and state.food_storage == 2 and state.retainers.size() == 3
		and (state.retainers[1] as RetainerData).loyalty == 16, "Escape leaves the evening, stores and loyalty intact.")
	await _click(ui.sleep_button)
	warning = _bedtime_warning()
	if not _expect(warning != null and warning.choices.front().has_focus(), "Reopen the warning after cancelling."):
		return
	await _tap_pad(JOY_BUTTON_DPAD_RIGHT)
	_expect(warning.choices.back().has_focus(), "The controller can reach the deliberate overnight action.")
	await _tap_pad(JOY_BUTTON_DPAD_LEFT)
	_expect(warning.choices.front().has_focus(), "The controller can return to revising the meal.")
	await _tap_pad(JOY_BUTTON_A)
	await tree.process_frame
	await tree.process_frame
	var panel := _panel()
	if not _expect(panel != null and _bedtime_warning() == null and state.current_day == 49 and state.food_storage == 2
		and panel.find_fruit.has_focus() and "预计离任 · 石墨" in panel.meal_forecast.text,
		"Review opens the current meal with the berry route focused and the departure still visible."):
		return
	var scroll_rect: Rect2 = panel.scroll.get_global_rect()
	_expect(scroll_rect.encloses(panel.find_fruit.get_global_rect()) and scroll_rect.encloses(panel.meal_forecast.get_global_rect()),
		"The route and its consequences are visible together without scrolling.")
	await _capture("rations-priority-berry-option")
	await _click(panel.find_fruit)
	var world: Node2D = ui.world
	if not _expect(_panel() == null and state.ravine_trip_target == "野果坳" and state.current_day == 49
		and state.food_storage == 2 and state.money == 2, "Choosing the route sets a wayfinding target and keeps this evening open."):
		return
	await Campaign.walk_estate_road_to(tree, world, world.get_node("EastArrival").global_position)
	if not _expect(await Campaign.walk_through_gates(tree, &"ui_right", state.WILDERNESS_SCENE), "Follow the east gate to the ravine."):
		return
	await tree.process_frame
	var ravine := tree.current_scene as Node2D
	if not _expect(ravine.active_waypoint() == "野果坳", "The ravine resumes the berry route from the night plan."):
		return
	var fruit := ravine.get_node("WildFruit") as Node2D
	await Campaign.walk_ravine_to(tree, ravine, fruit.global_position + Vector2(0, 16))
	if not _expect(ravine.get_node("Player").interaction_target == fruit,
		"The route leads to the berry bush through the real map."):
		return
	_key(KEY_E)
	await tree.process_frame
	_expect(state.food_storage == 2 + state.balance.wild_food_yield and state.last_forage_day == 49,
		"Picking fruit covers tonight's meal and uses the daily forage turn.")
	await _capture("rations-priority-berry-grove")
	await Campaign.walk_to_ravine_exit(tree, ravine)
	if not _expect(await Campaign.walk_through_gates(tree, &"ui_left", state.ESTATE_SCENE), "Walk the same day back to the estate."):
		return
	ui = tree.current_scene.get_node("UI")
	await tree.process_frame
	var plan: Dictionary = state.night_rations_plan()
	_expect(state.current_day == 49 and plan.served == plan.need and plan.departing.is_empty(),
		"Returning with the berries clears the forecast before bedtime.")
	await _sleep()
	var meal: Dictionary = state.night_rations.last
	_expect(_bedtime_warning() == null and state.current_day == 50 and meal.served == 5 and meal.need == 5
		and not meal.has("departed") and state.retainers.size() == 3 and state.king_storage == 3,
		"Once fed, all three workers stay and the next night proceeds normally.")
	print("RATIONS_PRIORITY_RESCUE day=", state.current_day, " served=", meal.served, "/", meal.need, " retainers=", state.retainers.size())

func _tap_pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await tree.process_frame
	await tree.process_frame

func _play_bedtime_with_tribute() -> void:
	var file := FileAccess.open(state.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"current_day": 5, "food_storage": 0, "money": 5, "reputation": 30,
		"days_without_contribution": 4, "estate_room": state.EstateRoom.HALL,
		"retainers": [{"name": "渠伯", "school": 4, "duty": 0, "loyalty": 20}],
		"well_fields": [{"center_pos": "5,5", "is_unlocked": true}],
	}))
	file.close()
	if not await _load_evening(state.SAVE_PATH):
		return
	var world: Node2D = ui.world
	var room := world.get_node("HallInterior") as Node2D
	await Campaign.walk_to(tree, world.player, room.to_global(Vector2(55, 35)))
	if not _expect(world.player.interaction_target == room.get_node("Bed"), "Reach the bed in the restored hall."):
		return
	_key(KEY_E)
	await tree.process_frame
	var panel := _panel()
	if not _expect(panel != null, "The bed opens the night plan."):
		return
	await _click(panel.get_node("%Sleep"))
	await tree.process_frame
	var warning := _bedtime_warning()
	if not _expect(warning != null and warning.choices.size() == 3 and warning.choices[0].text == "标出公田"
		and warning.choices[1].text == RATION_CHOICE and "声望" in warning.text_label.text
		and "渠伯缺餐后将离任" in warning.text_label.text, "One warning offers both routes when tribute and the meal are at risk."):
		return
	await _capture("rations-priority-tribute-and-meal")
	await _click(warning.choices[1])
	await tree.process_frame
	await tree.process_frame
	panel = _panel()
	if not _expect(panel != null and panel.accept_offer.has_focus() and state.current_day == 5 and state.money == 5,
		"A funded quote gets focus after returning to the meal from bed."):
		return
	await _click(panel.accept_offer)
	await _click(panel.get_node("%Sleep"))
	await tree.process_frame
	warning = _bedtime_warning()
	_expect(warning != null and warning.context_label.text == "第一次纳贡" and warning.choices.size() == 2
		and "离任" not in warning.text_label.text and state.night_rations_plan().served == 1 and state.money == 5,
		"Accepting the quote clears the departure from the next warning and keeps the price until dawn.")

func run(game_tree: SceneTree) -> void:
	tree = game_tree
	if not _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Use an isolated ration profile."):
		_end()
		return
	seed(784)
	state = tree.root.get_node("Global")
	if capture_dir.is_empty():
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
		if not failed:
			await _play_bedtime_with_tribute()
	_end()
