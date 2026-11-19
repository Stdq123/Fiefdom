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
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
