extends SceneTree

var state: Node
var ui: Node
var workshop: RefCounted
var actions: Dictionary
var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _review() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run route-silk-reading in an isolated profile.")
		quit(1)
		return
	state = root.get_node("Global")
	state.current_day = 53
	state.tax_reform_day = 50
	state.tax_reform_choice = state.TaxReformChoice.TRADITIONAL
	workshop = state.silk_workshop
	actions = workshop.get_script().Action
	workshop.built = true
	workshop.bolts = 1
	paused = true
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		_expect(false, "Mount the fixed estate.")
		quit(1)
		return
	await scene_changed
	ui = current_scene.get_node("UI")
	ui.world.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	_expect(root.get_node("Preferences").set_reading_size(2) == OK, "Review the highest reading size.")
	await _check_trade(state.TaxReformChoice.TRADITIONAL, "去进献", "进献 1 匹", actions.OFFER, actions.SELL)
	await _check_trade(state.TaxReformChoice.REFORMED, "去出售", "出售 1 匹", actions.SELL, actions.OFFER)
	await _check_production()
	await _check_leaves()
	await _check_workshop_build()
	_expect(state.saved_games().is_empty(), "Reading and following the workshop routes does not write a save.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _open_silk(goal: int, label: String, note: String) -> Control:
	ui.hud.route_progress.pressed.emit()
	var book: Control = ui.route_goals
	_expect(paused and book.modal.visible, "The existing route journal button opens the ledger.")
	var goals: Array[Dictionary] = state.route_objectives()
	for index in goals.size():
		if goals[index].kind != goal:
			continue
		var row: Control = book.rows.get_child(index)
		var action := row.get_node("%GoalAction") as Button
		_expect(action.text == label and note in row.get_node("%GoalDetail").text, "The ledger shows the next step " + label)
		action.pressed.emit()
		await _settle()
		var office: Control = ui.panel_manager.management_panel_instance
		_expect(office != null and office.visible and office.silk_panel.is_visible_in_tree(), "The existing silk page opens.")
		return office.silk_panel if office else null
	_expect(false, "The fixed route must have the requested silk goal.")
	book.close_map()
	return null

func _check_trade(choice: int, label: String, note: String, step: int, other: int) -> void:
	state.tax_reform_choice = choice
	var before := _snapshot()
	var goal: int = state.RouteGoal.OFFER_SILK if step == actions.OFFER else state.RouteGoal.SELL_SILK
	var panel := await _open_silk(goal, label, note)
	if panel:
		var button: Button = panel.buttons[step]
		_expect(button.has_focus() and button.is_visible_in_tree() and not button.disabled
			and not panel.buttons[other].disabled, "Focus the route's trade while keeping both existing workshop trades available.")
	await _close_silk(before)

func _check_production() -> void:
	workshop.bolts = 0
	workshop.raw_silk = state.balance.silk_thread_per_bolt * 2
	workshop.cocoons = 2
	var before := _snapshot()
	var panel := await _open_silk(state.RouteGoal.SELL_SILK, "准备织绸", "可织 2 匹")
	if panel:
		_check_focus_in_body(panel, panel.buttons[actions.WEAVE])
	await _close_silk(before)
	workshop.raw_silk = 0
	before = _snapshot()
	panel = await _open_silk(state.RouteGoal.SELL_SILK, "准备缫丝", "2 只蚕茧")
	if panel:
		_check_focus_in_body(panel, panel.buttons[actions.REEL])
	await _close_silk(before)
	workshop.cocoons = 0
	workshop.leaves = state.balance.silk_leaves_per_night * state.balance.silk_batch_nights
	before = _snapshot()
	panel = await _open_silk(state.RouteGoal.SELL_SILK, "准备养蚕", "桑叶已备齐")
	if panel:
		_check_focus_in_body(panel, panel.buttons[actions.START_BATCH])
	await _close_silk(before)

func _check_leaves() -> void:
	state.tax_reform_choice = state.TaxReformChoice.TRADITIONAL
	workshop.leaves = 1
	workshop.nights_left = 2
	var cell: Vector2i = state.well_fields[0].center_pos + Vector2i.RIGHT
	var crop: Resource = root.get_node("ItemManager").get_crop("mulberry")
	var nights: int = state.sowing_nights(crop)
	state.tilled_cells[cell] = true
	state.active_crops[cell] = {"id": "mulberry", "data": crop, "age": nights, "growth_nights": nights,
		"requires_channel": false, "watered": false}
	var before := _snapshot()
	var panel := await _open_silk(state.RouteGoal.OFFER_SILK, "准备桑叶", "还缺 3 片桑叶")
	if panel:
		var gather: Button = panel.mulberry_button
		_check_focus_in_body(panel, gather)
		_expect(gather.text == "指路收桑", "Use the existing route to the ripe private mulberry.")
		gather.pressed.emit()
		await _settle()
		_expect(ui.directions.tracked_plot == cell, "The selected route marks the same ripe mulberry.")
		ui.directions.cancel_tracking()
	await _close_silk(before)
	workshop.leaves = 4
	before = _snapshot()
	panel = await _open_silk(state.RouteGoal.OFFER_SILK, "查看蚕批", "照料 2 夜")
	if panel:
		_expect(panel.buttons[actions.START_BATCH].disabled and panel.status_label.is_visible_in_tree(),
			"An already fed batch shows its remaining nights without suggesting another batch.")
	await _close_silk(before)

func _check_workshop_build() -> void:
	workshop.built = false
	workshop.nights_left = 0
	var before := _snapshot()
	var panel := await _open_silk(state.RouteGoal.OFFER_SILK, "查看研读", "建蚕室需书 2 级")
	if panel:
		_check_focus_in_body(panel, panel.study_button)
	await _close_silk(before)

func _check_focus_in_body(panel: Control, button: Button) -> void:
	var body: Rect2 = panel.production.get_global_rect()
	_expect(button.has_focus() and button.is_visible_in_tree() and not button.disabled
		and body.grow(0.5).encloses(button.get_global_rect()), "Focus and reveal " + button.text)

func _close_silk(before: Array) -> void:
	ui.panel_manager.hide_management_panel()
	await _settle()
	_expect(before == _snapshot(), "The handoff does not consume materials, trade, or advance time.")

func _settle() -> void:
	for frame in 5:
		await process_frame

func _snapshot() -> Array:
	return [state.current_day, state.day_progress, state.money, state.reputation, state.silk_bolts_sold,
		state.silk_bolts_offered, workshop.built, workshop.leaves, workshop.cocoons, workshop.raw_silk,
		workshop.bolts, workshop.nights_left, hash(state.active_crops), state.selected_seed_id]
