extends SceneTree

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run first-tribute-reading in an isolated profile.")
		quit(1)
		return
	var state := root.get_node("Global")
	var preferences := root.get_node("Preferences")
	paused = true
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		push_error("Cannot mount the paused estate.")
		quit(1)
		return
	await scene_changed
	var ui := current_scene.get_node("UI")
	var handover: Control = ui.handover
	current_scene.get_node("World").process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	ui.hud.handover_button.grab_focus()
	ui._open_handover()
	_expect(paused and handover.modal.visible, "Open the handover from the estate UI.")
	var due: int = state.tribute_deadline()
	_expect(handover.tribute_due.text == "首贡 1 份 · 第 %d 天过夜前" % due,
		"The handover shows the actual deadline.")
	_expect(handover.sketch.get_child(4).get_child(0).text == "公田"
		and handover.sketch.get_child(0).get_child(0).text == "私", "Text identifies public and private plots.")
	var letter := handover.get_node("%Letter") as Label
	var standard := letter.get_theme_font_size("font_size")
	_expect(preferences.set_reading_size(2) == OK and letter.get_theme_font_size("font_size") == standard + 6,
		"The handover follows the selected reading size.")
	await _check_public_plot_link(ui, state)
	paused = true

	state.current_day = due
	state.days_without_contribution = state.balance.no_contribution_threshold - 1
	state.estate_room = state.EstateRoom.HALL
	var retainer_data: GDScript = state.retainers[0].get_script()
	var teacher: Resource = retainer_data.new("季青", "士人", retainer_data.School.CONFUCIAN)
	teacher.duty = retainer_data.Duty.TEACH
	teacher.loyalty = 10.0
	state.retainers.append(teacher)
	var threshold: int = state.balance.rank_strip_threshold
	var penalty: int = state.balance.no_contribution_penalty
	var teaching: int = state.balance.confucian_teaching_reputation
	state.reputation = threshold + penalty
	state.food_storage = state.retainer_food_cost()
	var fed_note := "讲学声望 +%d" % teaching
	var missed_note := "讲学门客缺餐"
	var loss := "将失去封地"
	var demotion := "将削爵为下士"
	_check_first_tribute(ui, state, threshold + teaching, fed_note, "", false)

	var events := root.get_node("GameEvents")
	ui.panel_manager.show_management_panel()
	var office: Control = ui.panel_manager.management_panel_instance
	office.show_technology()
	state.food_storage -= 1
	events.food_changed.emit(state.food_storage)
	_check_consequence(office.rank_tribute.text, threshold, missed_note, loss)
	ui.panel_manager.hide_management_panel()
	_check_first_tribute(ui, state, threshold, missed_note, loss, true)

	state.current_rank = state.Rank.ZHONG_SHI
	events.rank_changed.emit(state.current_rank)
	_check_first_tribute(ui, state, threshold, missed_note, demotion, true)
	teacher.loyalty = 90.0
	await _check_retained_teacher_route(ui, state)
	_check_planned_tribute(ui, state, retainer_data)
	_expect(state.current_day == due and state.saved_games().is_empty(),
		"Reading the warnings and ledgers keeps the date and the empty save catalog.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _check_public_plot_link(ui: Node, state: Node) -> void:
	var handover: Control = ui.handover
	var public_button := handover.get_node_or_null("%FindPublicPlot") as Button
	var world: Node2D = current_scene.get_node("World")
	if not public_button:
		_expect(false, "The handover must let players mark the public plot directly.")
		handover.close_map()
		return
	_expect(public_button.has_focus() and handover.find_keeper.is_visible_in_tree(),
		"Open at the public plot action with the keeper still accessible.")
	var original_seed: String = world.current_seed_id
	world.select_seed("rice")
	var before := _snapshot(state)
	var foot: Vector2 = world.player.position
	public_button.pressed.emit()
	var plot: Vector2i = state.well_fields[0].center_pos
	for frame in 4:
		await process_frame
	_expect(not paused and not handover.modal.visible and ui.directions.tracked_plot == plot
		and state.field_route_status == state.TributeRoute.TEND and "公田" in ui.hud.cancel_directions.text,
		"Mark the actual center plot on the estate after leaving the handover.")
	_expect(ui.hud.handover_button.has_focus(), "Returning from the handover restores its opening focus.")
	_expect(world.current_seed_id == "rice" and state.selected_seed_id == "rice" and world.player.position == foot
		and _snapshot(state) == before, "Pointing to the plot preserves the seed, player position, date and economy.")
	ui._open_handover()
	handover.find_keeper.pressed.emit()
	_expect(ui.directions.tracked_neighbor == "渠伯" and ui.directions.tracked_plot == null,
		"The keeper action still follows the resident.")
	ui.directions.cancel_tracking()
	world.select_seed(original_seed)

func _check_first_tribute(ui: Node, state: Node, remaining: int, lesson: String, consequence: String,
		expect_shortage: bool) -> void:
	var before := _snapshot(state)
	ui._request_sleep()
	var warning := ui.get_node_or_null("Control/DialoguePanel") as Control
	_expect(warning != null, "The unsown public plot opens its warning before sleep.")
	if not warning:
		return
	_check_consequence(warning.text_label.text, remaining, lesson, consequence)
	var field: Dictionary = state.tribute_field_plan()
	_expect("从南门出去" in warning.text_label.text and warning.choices[0].text == "选%s并指路" % field.crop
		and warning.choices[0].has_focus() and warning.choices.back().text == "仍然过夜",
		"The indoor route, default field action and sleep option remain available.")
	_expect(warning.choices.size() == (3 if expect_shortage else 2), "Only a shortage adds a third action.")
	if expect_shortage:
		_expect(warning.choices[1].text == "查看今夜安排" and "季青缺餐后将离任" in warning.text_label.text,
			"The combined warning gives the affected teacher and a route to the meal plan.")
	warning.free()

	ui._show_night_rations()
	var night := ui.get_node("Control/NightRationsPanel") as Control
	_check_consequence(night.tribute_details.text, remaining, lesson, consequence)
	night.free()
	ui.panel_manager.show_management_panel()
	var office: Control = ui.panel_manager.management_panel_instance
	office.show_technology()
	_check_consequence(office.rank_tribute.text, remaining, lesson, consequence)
	ui.panel_manager.hide_management_panel()
	_expect(_snapshot(state) == before, "Forecasts do not serve meals, teach, collect tribute or advance the estate.")

func _check_consequence(report: String, remaining: int, lesson: String, consequence: String) -> void:
	_expect(lesson in report and "扣后余 %d。" % remaining in report, "Show the meal-adjusted score: " + report)
	_expect(("失去封地" in report) == (consequence == "将失去封地")
		and ("削爵" in report) == (consequence == "将削爵为下士")
		and (consequence.is_empty() or consequence in report), "Show the correct rank consequence: " + report)

func _check_retained_teacher_route(ui: Node, state: Node) -> void:
	var before := _snapshot(state)
	ui._request_sleep()
	var warning := ui.get_node_or_null("Control/DialoguePanel") as Control
	if not warning:
		_expect(false, "A teacher missing a meal still gets the first-tribute warning.")
		return
	var has_meal_link: bool = warning.choices.size() == 3 and warning.choices[1].text == "查看今夜安排"
	_expect(has_meal_link and "讲学门客缺餐" in warning.text_label.text and "离任" not in warning.text_label.text,
		"A retained teacher's missed meal offers the night plan without announcing a departure.")
	if not has_meal_link:
		warning.free()
		return
	warning.choices[1].pressed.emit()
	await warning.tree_exited
	await process_frame
	await process_frame
	var night := ui.get_node_or_null("Control/NightRationsPanel") as Control
	_expect(night != null and night.focus_shortage, "Following the link opens tonight's ration controls.")
	if night:
		night.free()
	_expect(_snapshot(state) == before, "Following the meal link does not settle the evening.")

func _check_planned_tribute(ui: Node, state: Node, retainer_data: GDScript) -> void:
	state.king_storage = 1
	state.retainers[0].duty = retainer_data.Duty.HARVEST
	state.wait_for_fields_before_sleep = true
	var cell: Vector2i = state.well_fields[0].center_pos
	var crop: Resource = root.get_node("ItemManager").get_crop("millet")
	var nights: int = state.sowing_nights(crop)
	state.tilled_cells[cell] = true
	state.active_crops[cell] = {"id": "millet", "data": crop, "age": nights, "growth_nights": nights,
		"requires_channel": false, "watered": false}
	var before := _snapshot(state)
	ui._show_night_rations()
	var night := ui.get_node("Control/NightRationsPanel") as Control
	var note: String = night.tribute_details.text
	_expect("收工预计纳贡 1 份" in note and "扣后余" not in note and "削爵" not in note,
		"A planned public harvest takes precedence over a missed-tribute penalty.")
	night.free()
	_expect(_snapshot(state) == before, "The projected harvest leaves the ripe crop and treasury untouched.")

	var private_cell := cell + Vector2i.RIGHT
	state.active_crops[private_cell] = state.active_crops[cell]
	state.active_crops.erase(cell)
	state.tilled_cells[private_cell] = true
	state.food_storage = state.retainer_food_cost() - 1
	state.set_night_rations(true, 0)
	before = _snapshot(state)
	ui._show_night_rations()
	night = ui.get_node("Control/NightRationsPanel") as Control
	note = night.tribute_details.text
	_expect("收工后可再核对分餐" in note and "收工预计纳贡" not in note,
		"A private harvest that could supply the missing serving makes the forecast conditional.")
	night.free()
	_expect(_snapshot(state) == before, "The conditional forecast does not harvest or convert the private crop.")

func _snapshot(state: Node) -> Array:
	var resident_state := []
	for resident: Resource in state.retainers:
		resident_state.append([resident.name, resident.duty, resident.loyalty])
	return [state.current_day, state.day_progress, state.days_without_contribution, state.reputation,
		state.current_rank, state.outcome, state.food_storage, state.king_storage, state.money,
		state.quest_progress, state.crop_stock.lots.duplicate(), resident_state, state.night_rations.last.duplicate(true),
		state.active_crops.duplicate(true), state.player_stats.stats.duplicate(true)]
