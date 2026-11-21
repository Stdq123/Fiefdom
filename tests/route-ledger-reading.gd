extends SceneTree

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _tab() -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.physical_keycode = KEY_TAB
		event.pressed = down
		root.push_input(event, true)
	await process_frame

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run route-ledger-reading in an isolated profile.")
		quit(1)
		return
	var state := root.get_node("Global")
	var prefs := root.get_node("Preferences")
	state.tax_reform_choice = state.TaxReformChoice.REFORMED
	state.current_day = 53
	state.tax_reform_day = 50
	state.money = state.balance.ending_reformed_wealth - 7
	paused = true
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		push_error("Cannot mount the paused estate.")
		quit(1)
		return
	await scene_changed
	var ui := current_scene.get_node("UI")
	var book: Control = ui.route_goals
	paused = false
	ui._open_route_goals()
	_expect(paused and book.modal.visible, "The ordinary journal entry opens the route ledger.")
	var copper: PanelContainer = book.rows.get_child(2)
	var detail := copper.get_node("%GoalDetail") as Label
	var gap := copper.get_node("%GoalGap") as Label
	_expect(gap.text == "还差 7 铜钱" and "南路亭呈交新税册" in book.filing.text,
		"The missing balance and filing location are explicit.")
	var standard := detail.get_theme_font_size("font_size")
	_expect(prefs.set_reading_size(2) == OK and detail.get_theme_font_size("font_size") == standard + 6,
		"The route instructions follow the selected reading size.")
	var modal: Control = book.modal
	for step in 20:
		await _tab()
		var focus := root.gui_get_focus_owner()
		_expect(focus != null and modal.is_ancestor_of(focus), "Tab stays in the route ledger.")
	_expect(state.current_day == 53 and state.money == state.balance.ending_reformed_wealth - 7
		and state.saved_games().is_empty(), "Browsing leaves the isolated estate unchanged.")
	for traditional: bool in [true, false]:
		await _check_ready_route(state, traditional)
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _check_ready_route(state: Node, traditional: bool) -> void:
	state.tax_reform_choice = state.TaxReformChoice.TRADITIONAL if traditional else state.TaxReformChoice.REFORMED
	state.king_storage = 9 + state.balance.ending_traditional_tribute
	state.private_harvest_total = 8 + state.balance.ending_reformed_private
	state.silk_bolts_offered = state.balance.ending_silk_target
	state.silk_bolts_sold = state.balance.ending_silk_target
	state.money = state.balance.ending_reformed_wealth
	state.raids_defeated = state.balance.ending_raids_min
	state.set_route_baseline({"tribute": 9, "private": 8, "offered": 0, "sold": 0})
	if change_scene_to_file(state.ESTATE_SCENE) != OK:
		_expect(false, "Mount the estate that is ready to present its ledger.")
		return
	await scene_changed
	var world := current_scene.get_node("World")
	world.landscape.set_process(false)
	var ui := current_scene.get_node("UI")
	var book: Control = ui.route_goals
	var record: Node2D = world.get_node("Scenery/EndingRecord")
	var read := ui.hud.get_node_or_null("%ReadRouteLedger") as Button
	_expect(state.route_ready_to_present() and ui.hud.route_progress.text.begins_with("指路呈交"),
		"The journal keeps the direct route to a finished ledger desk.")
	_expect(read != null and read.visible, "A ready route still lets the player read its ledger before presenting it.")
	if not read:
		return
	paused = false
	var foot: Vector2 = world.player.position
	ui.hud.route_progress.pressed.emit()
	_expect(not book.modal.visible and ui.directions.tracked_place == record.record_name,
		"The existing journal shortcut starts directions in one press.")
	ui.directions.clear_tracking()
	read.grab_focus()
	read.pressed.emit()
	_expect(book.modal.visible and paused and ui.directions.tracked_place.is_empty(),
		"Reading opens the completed accounts without starting directions.")
	var count: int = state.route_objectives().size()
	var expected_place := "堂前呈交贡簿" if traditional else "南路亭呈交新税册"
	_expect("%d/%d 项" % [count, count] in book.summary.text and expected_place in book.filing.text,
		"The completed accounts show every goal and the correct filing place.")
	var follow := book.get_node("%FollowFiling") as Button
	_expect(follow.visible and not follow.disabled, "A completed ledger can mark its desk from the footer.")
	var reached := false
	for step in 8:
		await _tab()
		reached = reached or follow.has_focus()
	_expect(reached, "The footer action is reachable with Tab at the largest reading size.")
	for row in book.rows.get_children():
		_expect(row.get_node("%GoalCount").get_line_count() == 1,
			"Each achieved amount and its status fit on one line at the largest reading size.")
	follow.pressed.emit()
	_expect(not paused and not book.modal.visible and ui.directions.tracked_place == record.record_name
		and ui.directions.tracked_place_point == world.to_local(record.global_position),
		"The footer closes the ledger and starts the same route as the direct shortcut.")
	if not traditional:
		state.money -= 1
		root.get_node("GameEvents").money_changed.emit(state.money)
		_expect(not read.visible and ui.directions.tracked_place.is_empty(), "Dropping below the balance requirement removes the filing route.")
		ui.hud.route_progress.pressed.emit()
		_expect(book.modal.visible and not follow.visible and "达标后" in book.filing.text,
			"Reopening the ledger shows the remaining requirement without a filing shortcut.")
		book.close_map()
	_expect(world.player.position == foot and state.current_day == 53 and state.ending_record.is_empty()
		and state.saved_games().is_empty(), "Reading and marking the desk neither move the player nor present the book.")
