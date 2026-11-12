extends "res://tests/CanalFlowReplay.gd"

const PUBLIC := Vector2i(5, 5)
const PRIVATE := Vector2i(6, 5)
const TRIBUTE_PLAN := NodePath("%TributePlan")

var baseline := false
var legacy := false

func _open_title(continue_game := false) -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	var title := tree.current_scene
	await _button(title.continue_button if continue_game else title.new_button)
	if tree.current_scene == null:
		await tree.scene_changed
	await _estate()

func _sleep() -> void:
	await _button(ui.sleep_button)
	await tree.create_timer(1.12).timeout

func _save() -> void:
	await _button(ui.settings_button)
	var settings: Control = ui.panel_manager.settings_panel_instance
	await _button(settings.save_button)
	_expect("游戏已保存" in settings.save_status.text, "Use the normal manual save button.")
	await _button(settings.close_button)

func _open_plan(button: Button) -> Control:
	await _button(button)
	await tree.process_frame
	var panel := ui.get_node_or_null("Control/NightRationsPanel") as Control
	if _expect(panel != null, "Open the usual night planning sheet."):
		_expect(tree.root.get_visible_rect().encloses(panel.get_node("Center/Window").get_global_rect()),
			"The full sheet fits the current viewport.")
	return panel

func _first_harvest() -> void:
	for cell in [PUBLIC, PRIVATE]:
		for action in 3:
			await _click(_point(cell))
	await _sleep()
	for cell in [PUBLIC, PRIVATE]:
		await _click(_point(cell))
	await _sleep()
	for cell in [PUBLIC, PRIVATE]:
		await _click(_point(cell))
	_expect(state.current_day == 3 and state.king_storage == 1 and state.player_inventory == 1
		and state.days_without_contribution == 0, "Harvest the first public and private crops through normal farming.")

func _plant_again() -> void:
	if not baseline:
		await _key(KEY_3)
		var panel := await _open_plan(ui.hud.tribute_button)
		if panel == null:
			return
		_expect("第 7 天过夜前" in panel.tribute_deadline.text and "累计纳贡 1/10" in panel.tribute_goal.text
			and "最早第 5 天" in panel.tribute_details.text and panel.find_tribute.text == "选黍并指路",
			"The first harvest resets the rolling deadline and keeps the cumulative goal visible.")
		await _capture("01-next-tribute")
		await _button(panel.find_tribute)
		_expect(ui.directions.tracked_plot == PUBLIC and state.field_route_status == state.TributeRoute.TEND
			and world.current_seed_id == "millet" and state.king_storage == 1 and not state.active_crops.has(PUBLIC),
			"The chosen guidance selects millet and marks the empty public plot without harvesting or planting.")
		await _save()
		await _open_title(true)
		_expect(state.current_day == 3 and ui.directions.tracked_plot == PUBLIC and "播种" in ui.directions.caption.text,
			"The route and its selected seed survive a manual save from the real title.")
	await _click(_point(PUBLIC))
	await _click(_point(PUBLIC))
	await _sleep()
	if not baseline:
		var panel := await _open_plan(ui.hud.tribute_button)
		if panel == null:
			return
		_expect("今天待浇" in panel.tribute_details.text and "最早第 5 天" in panel.tribute_details.text,
			"Tomorrow's harvest estimate explicitly needs today's water.")
		await _capture("02-water-public-plot")
		await _button(panel.find_tribute)
		_expect(ui.directions.tracked_plot == PUBLIC and "待浇水" in ui.directions.caption.text,
			"The same route now marks the watering action.")
	await _click(_point(PUBLIC))
	await _sleep()
	while state.current_day < 7 and not failed:
		await _sleep()
	_expect(state.current_day == 7 and state.field_crop_is_ripe(PUBLIC) and state.days_without_contribution == 4,
		"Reach the last safe evening with an unharvested ripe public crop.")

func _open_due_plan(overdue := false) -> Control:
	var hud_title := "欠贡" if overdue else "今夜前"
	var sheet_title := "已逾期" if overdue else "今夜到期"
	_expect(hud_title in ui.hud.tribute_button.text and "声望 −8" in ui.sleep_button.tooltip_text,
		"The live HUD and sleep control warn about the real deadline.")
	var panel := await _open_plan(ui.hud.tribute_button)
	if panel != null:
		_expect(sheet_title in panel.tribute_deadline.text and "声望 −8" in panel.tribute_details.text
			and panel.find_tribute.text == "找熟公田", "The evening sheet explains both the risk and the available harvest.")
	return panel

func _miss_and_resume() -> void:
	var before: int = state.reputation
	await _sleep()
	_expect(state.current_day == 8 and state.reputation == before - 8, "The missed evening applies the announced deduction.")
	if baseline:
		print("TRIBUTE_BASELINE day=", state.current_day, " penalty=", before - state.reputation)
		return
	await _open_title(true)
	_expect(state.current_day == 8 and state.reputation == before - 8 and state.last_dawn.get("tribute_penalty") == 8,
		"The real dawn autosave restores the result.")
	var sheet := await _open_plan(ui.hud.morning_button)
	if sheet == null:
		return
	_expect(sheet.show_previous and "欠贡 · 声望 −8" in sheet.milestones.text, "The morning page names the actual deduction.")
	await _capture("05-missed-tribute-receipt")
	await _button(sheet.close_button)
	print("TRIBUTE_MISSED day=", state.current_day, " penalty=", state.last_dawn.tribute_penalty)

func _deliver(panel: Control) -> void:
	var day: int = state.current_day
	var before: int = state.reputation
	await _button(panel.find_tribute)
	await _click(_point(PUBLIC))
	_expect(state.king_storage == 2 and state.reputation == before + 10 and state.days_without_contribution == 0
		and state.tribute_deadline() == day + 4 and state.field_route_status < 0,
		"Harvesting the marked public crop actually delivers tribute, moves the deadline and completes the route.")
	var sheet := await _open_plan(ui.hud.tribute_button)
	if sheet != null:
		_expect("第 %d 天过夜前" % (day + 4) in sheet.tribute_deadline.text and "累计纳贡 2/10" in sheet.tribute_goal.text,
			"Both the renewed deadline and the cumulative count are shown.")
		await _capture("06-renewed-deadline")
		await _button(sheet.close_button)
	await _sleep()
	_expect(state.current_day == day + 1 and state.reputation == before + 10 and state.last_dawn.get("tribute_penalty", 0) == 0,
		"The next dawn keeps the reputation and records no new deduction.")
	print("TRIBUTE_RENEWED day=", day, " deadline=", state.tribute_deadline(), " total=", state.king_storage)

func _fresh_campaign() -> void:
	await _open_title()
	await _first_harvest()
	if failed:
		return
	await _plant_again()
	if failed:
		return
	if baseline:
		await _capture("01-old-journal")
		var old_sheet := await _open_plan(ui.hud.rations_button)
		if old_sheet == null:
			return
		_expect("上缴" in ui.hud.quest_label.text and not old_sheet.has_node(TRIBUTE_PLAN),
			"The old build shows cumulative harvests and gives no deadline in the night sheet.")
		await _capture("02-old-night-sheet")
		await _button(old_sheet.close_button)
		await _save()
		await _miss_and_resume()
		return
	var panel := await _open_due_plan()
	if panel == null:
		return
	await _capture("03-due-tonight")
	var pad = load("res://tests/GamepadReplay.gd").new()
	pad.tree = tree
	pad.pad = tree.root.get_node("GamepadInput")
	await pad._click(panel.find_tribute)
	_expect(pad.failures == 0 and ui.directions.tracked_plot == PUBLIC and "收获" in ui.directions.caption.text,
		"The controller can select the actual ripe public field.")
	await _capture("04-public-harvest-marker")
	await pad._mouse_handoff()
	await _miss_and_resume()
	if failed:
		return
	panel = await _open_due_plan(true)
	if panel != null:
		await _deliver(panel)

func _old_save() -> void:
	await _open_title(true)
	if not _expect(state.current_day == 7 and state.king_storage == 1 and state.days_without_contribution == 4
		and state.field_crop_is_ripe(PUBLIC), "The genuine old manual save restores the deadline and crop from existing state."):
		return
	var panel := await _open_due_plan()
	if panel != null:
		await _capture("03-due-tonight")
		await _deliver(panel)

func run_tribute(game_tree: SceneTree, capture_path := "") -> void:
	tree = game_tree
	state = tree.root.get_node("Global")
	captures = capture_path
	if _expect(ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"), "Isolate the tribute replay profile."):
		tree.root.notify_mouse_entered()
		if legacy:
			await _old_save()
		else:
			await _fresh_campaign()
	if not failed:
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
