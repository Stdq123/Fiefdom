extends SceneTree

var state: Node
var ui: Node
var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run route-defense-reading in an isolated profile.")
		quit(1)
		return
	state = root.get_node("Global")
	state.current_day = 53
	state.balance.raid_first_day = 9
	state.balance.raid_interval_days = 8
	state.tax_reform_day = 50
	state.tax_reform_choice = state.TaxReformChoice.TRADITIONAL
	var retainer_data: GDScript = state.retainers[0].get_script()
	var guard: Resource = retainer_data.new("弋戎", "行伍", retainer_data.School.MILITARY)
	state.retainers.clear()
	paused = true
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		_expect(false, "Mount the fixed estate.")
		quit(1)
		return
	await scene_changed
	ui = current_scene.get_node("UI")
	ui.world.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	var prefs := root.get_node("Preferences")
	_expect(prefs.set_reading_size(2) == OK, "Review the largest reading size.")
	await _check_future_without_guards()
	await _check_guard_picker(guard, retainer_data.Duty.GUARD)
	await _check_tomorrow()
	_check_active_raid()
	_expect(state.raids_defeated == 0 and state.saved_games().is_empty(), "Only defense guidance is reviewed.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _defense_row() -> Control:
	ui.hud.route_progress.pressed.emit()
	var rows: Control = ui.route_goals.rows
	_expect(ui.route_goals.modal.visible and rows.get_child_count() == state.route_objectives().size(),
		"The normal journal button opens the route ledger.")
	return rows.get_child(rows.get_child_count() - 1) as Control

func _check_future_without_guards() -> void:
	var before := _snapshot()
	ui.hud.rations_button.pressed.emit()
	var night := ui.get_node("Control/NightRationsPanel") as Control
	_expect(not night.raid_plan.visible, "A normal evening keeps its one-night defense preview.")
	night.free()
	var row := _defense_row()
	var action := row.get_node("%GoalAction") as Button
	var detail: String = row.get_node("%GoalDetail").text
	_expect(action.text == "查看守备准备" and "第 57 天卯时" in detail and "射箭" in detail,
		"Both next encounter and personal preparation are available before a guard is hired.")
	action.pressed.emit()
	await _settle()
	night = ui.get_node_or_null("Control/NightRationsPanel") as Control
	_expect(night != null and night.raid_plan.is_visible_in_tree() and "第 57 天卯时" in night.raid_heading.text,
		"The defense shortcut shows the relevant future raid instead of a roster with no guards.")
	if night:
		night.free()
	ui.panel_manager.hide_management_panel()
	_expect(before == _snapshot(), "Reading the forecast preserves the calendar, accounts and guard assignments.")

func _check_guard_picker(guard: Resource, guard_duty: int) -> void:
	var retainer_data: GDScript = guard.get_script()
	for resident: String in ["季青", "渠伯", "陶辛", "蒲宁", "石墨"]:
		state.retainers.append(retainer_data.new(resident, "农人", retainer_data.School.AGRARIAN))
	state.retainers.append(guard)
	var before := _snapshot()
	var row := _defense_row()
	var action := row.get_node("%GoalAction") as Button
	_expect(action.text == "分派守卫" and "弋戎" in row.get_node("%GoalDetail").text,
		"Name the available military retainer before opening management.")
	action.pressed.emit()
	await _settle()
	var office: Control = ui.panel_manager.management_panel_instance
	_expect(office != null and office.visible, "The existing management panel handles the assignment.")
	if office:
		var entries: Control = office.retainer_list_container
		var item: Control = entries.get_child(entries.get_child_count() - 1)
		var picker: OptionButton = item.duty_picker
		var roster := entries.get_parent() as ScrollContainer
		_expect(item.data == guard and picker.has_focus() and picker.is_visible_in_tree()
			and roster.get_global_rect().grow(0.5).encloses(picker.get_global_rect())
			and not picker.is_item_disabled(picker.get_item_index(guard_duty)), "Focus the guard's usable duty picker.")
		ui.panel_manager.hide_management_panel()
	_expect(before == _snapshot(), "The shortcut leaves the duty unchanged until a player selects it.")
	guard.duty = guard_duty
	row = _defense_row()
	_expect(row.get_node("%GoalAction").text == "查看守卫" and "弋戎已任守卫" in row.get_node("%GoalDetail").text,
		"The ledger reflects the fixed assignment.")
	ui.route_goals.close_map()

func _check_tomorrow() -> void:
	state.current_day = 56
	state.east_watch_day = 48
	state.tax_reform_choice = state.TaxReformChoice.REFORMED
	var before := _snapshot()
	var row := _defense_row()
	var action := row.get_node("%GoalAction") as Button
	_expect("税亩富民" in ui.route_goals.heading.text and action.text == "查看明日守备"
		and "明日卯时" in row.get_node("%GoalDetail").text, "The reformed ledger shares the same attack schedule.")
	action.pressed.emit()
	await _settle()
	var night := ui.get_node_or_null("Control/NightRationsPanel") as Control
	_expect(night != null and night.raid_plan.is_visible_in_tree() and night.find_watch.has_focus(),
		"Tomorrow's shortcut focuses the available east watch directions.")
	if night:
		_expect(state.raid_name(state.raid_kind_on(57)) in night.raid_heading.text
			and "弋戎已任守卫" in night.raid_instructions.text, "The existing watch identifies the threat and assigned guard.")
		night.find_watch.pressed.emit()
		await _settle()
		_expect(ui.directions.tracked_place == "东路岗", "Select the real east watch location.")
		ui.directions.cancel_tracking()
	_expect(before == _snapshot(), "Reading tomorrow's forecast and marking the post leaves the estate intact.")

func _check_active_raid() -> void:
	state.raid_day = state.current_day
	state.raid_kind = 1
	var before := _snapshot()
	var row := _defense_row()
	var action := row.get_node("%GoalAction") as Button
	_expect(action.text == "标出来敌" and "东路已有斥候" in row.get_node("%GoalDetail").text,
		"An active threat takes precedence over the next scheduled date.")
	action.pressed.emit()
	_expect(ui.directions.following_raid and before == _snapshot(), "The existing tracking action leaves the active state intact.")

func _settle() -> void:
	for frame in 5:
		await process_frame

func _snapshot() -> Array:
	return [state.current_day, state.day_progress, state.current_rank, state.raid_day, state.money, state.food_storage,
		state.king_storage, state.current_stamina, state.watch_snare_armed, state.retainers.map(func(data: Resource) -> int: return data.duty)]
