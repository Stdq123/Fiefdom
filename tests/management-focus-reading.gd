extends SceneTree

var tree: SceneTree
var screen: Window
var failed := false

func _initialize() -> void:
	_review.call_deferred(self)

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _settle() -> void:
	for frame in 4:
		await tree.process_frame

func _key(code: Key, reverse := false, repeat := false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.shift_pressed = reverse
		event.echo = down and repeat
		screen.push_input(event, true)

func _pad(button: JoyButton) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await tree.process_frame
	await tree.process_frame

func _within(panel: Control) -> bool:
	var owner := screen.gui_get_focus_owner()
	return owner != null and panel.is_ancestor_of(owner)

func _tab_cycle(panel: Control, start: Control, backward: bool) -> void:
	start.grab_focus()
	for step in 80:
		_key(KEY_TAB, backward)
		if not _within(panel):
			_expect(false, "Tab left %s in direction %s at step %d." % [panel.name, backward, step + 1])
			return
		if start.has_focus():
			_expect(step > 0, "Tab reaches another control before returning to %s." % start.name)
			return
	_expect(false, "Tab must return to %s after going around the visible controls." % start.name)

func _check_arrows(panel: Control) -> void:
	for control: Control in panel.find_children("*", "Control", true, false):
		if not control.is_visible_in_tree() or control.focus_mode != Control.FOCUS_ALL or (control is BaseButton and control.disabled):
			continue
		for code in [KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN]:
			control.grab_focus()
			_key(code)
			_expect(_within(panel), "%s from %s must keep focus in %s." % [OS.get_keycode_string(code), control.name, panel.name])

func _sheet_keys(panel: Control) -> void:
	for index in panel.section_buttons.size():
		var tab: Button = panel.section_buttons[index]
		tab.grab_focus()
		_key(KEY_ENTER)
		await _settle()
		var page: Control = panel.tabs.get_current_tab_control()
		_expect(panel.tabs.current_tab == index and tab.has_focus(), "Enter opens " + tab.text)
		for backward in [false, true]:
			_tab_cycle(panel, tab, backward)
		_key(KEY_DOWN)
		var actionable := page.find_children("*", "BaseButton", true, false).any(func(button: BaseButton):
			return button.is_visible_in_tree() and button.focus_mode == Control.FOCUS_ALL and not button.disabled
		)
		_expect(_within(page) if actionable else _within(panel), "Down reaches the open page when it has an action: " + tab.text)
		if page == panel.technology_page:
			_expect(panel.water_next.has_focus(), "Down on technology reaches the current water action.")
		_check_arrows(panel)
	panel.close_button.grab_focus()
	_key(KEY_RIGHT, false, true)
	_expect(_within(panel), "A repeated arrow at the edge of management keeps the focus inside.")

func _cursor_on(pad: Node, control: Control) -> bool:
	return pad.active and control.has_focus() and pad.cursor.position.distance_to(control.get_global_rect().get_center()) < 2.0

func _estate_snapshot(state: Node, world: Node) -> Array:
	return [state.current_day, state.day_progress, state.money, state.food_storage, state.current_stamina,
		state.player_inventory, state.active_crops.duplicate(true), state.selected_seed_id, world.player.global_position,
		state.retainers.map(func(data: Resource): return data.duty), state.saved_games().size()]

func _review(scenario: SceneTree) -> void:
	tree = scenario
	screen = tree.root
	var profile := OS.get_user_data_dir()
	if not ("fiefdom-smoke-" in profile or "fiefdom-management-focus-" in profile):
		push_error("Use an isolated profile for the management focus check.")
		tree.quit(1)
		return
	tree.paused = true
	AudioServer.set_bus_mute(0, true)
	var state := screen.get_node("Global")
	var pad := screen.get_node("GamepadInput")
	if tree.change_scene_to_file(state.ESTATE_SCENE) != OK:
		tree.quit(1)
		return
	await tree.scene_changed
	var world := tree.current_scene.get_node("World")
	var ui := tree.current_scene.get_node("UI")
	# Freeze world input and the clock even during the two frames that deliver a shoulder press.
	world.process_mode = Node.PROCESS_MODE_DISABLED
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	await _settle()
	var before := _estate_snapshot(state, world)
	ui.manage_button.grab_focus()
	_key(KEY_ENTER)
	var panel: Control = ui.panel_manager.management_panel_instance
	if panel == null:
		push_error("The estate's Manage button must open the panel.")
		tree.quit(1)
		return
	await _settle()
	await _sheet_keys(panel)
	panel.show_estate()
	await _settle()
	var well_picker: OptionButton = panel.well_field_selector
	var seed_picker: OptionButton = panel.seed_plan_picker
	var selected := seed_picker.selected
	var popup := seed_picker.get_popup()
	seed_picker.grab_focus()
	_key(KEY_ENTER)
	await _settle()
	_expect(popup.visible, "Enter opens the existing seed dropdown.")
	tree.paused = false
	await _pad(JOY_BUTTON_RIGHT_SHOULDER)
	tree.paused = true
	_expect(popup.visible and panel.tabs.current_tab == 0, "Shoulders preserve the dropdown and the open page.")
	_key(KEY_ESCAPE)
	await _settle()
	_expect(panel.visible and not popup.visible and seed_picker.has_focus() and seed_picker.selected == selected,
		"Escape returns to the seed picker without editing it.")

	panel.show_market()
	await _settle()
	var amount: LineEdit = panel.market_panel.quantity.get_line_edit()
	amount.grab_focus()
	amount.deselect()
	amount.caret_column = amount.text.length()
	_key(KEY_LEFT)
	_expect(amount.has_focus() and amount.caret_column == amount.text.length() - 1, "The amount field still moves its caret.")
	var opener := panel.market_panel.get_node("MarketHeader/NightRations") as Button
	opener.grab_focus()
	pad.snap_pointer_to_focus()
	await _pad(JOY_BUTTON_A)
	await _settle()
	var rations := ui.get_node_or_null("Control/NightRationsPanel") as Control
	if rations == null:
		push_error("The controller can open the night book from the market.")
		tree.quit(1)
		return
	var ration_close: Button = rations.close_button
	_expect(_cursor_on(pad, ration_close), "The controller lands on the open night book's Return button.")
	for backward in [false, true]:
		_tab_cycle(rations, ration_close, backward)
	_check_arrows(rations)
	tree.paused = false
	await _pad(JOY_BUTTON_RIGHT_SHOULDER)
	tree.paused = true
	_expect(panel.tabs.current_tab == 1 and _within(rations), "Shoulders leave the management page alone behind the night book.")
	await _pad(JOY_BUTTON_B)
	await _settle()
	_expect(_cursor_on(pad, opener) and not is_instance_valid(rations), "Closing the night book restores its launcher.")

	tree.paused = false
	await _pad(JOY_BUTTON_LEFT_SHOULDER)
	tree.paused = true
	_expect(panel.tabs.current_tab == 0 and _cursor_on(pad, panel.section_buttons[0]),
		"LB selects the previous page and moves the pointer to its tab.")
	_key(KEY_DOWN)
	_expect(well_picker.has_focus(), "The estate tab leads to the well field picker.")
	await _pad(JOY_BUTTON_B)
	await _settle()
	_expect(not panel.visible and _cursor_on(pad, ui.manage_button), "B returns focus and pointer to the estate's Manage button.")
	_expect(tree.paused and _estate_snapshot(state, world) == before and state.saved_games().is_empty(),
		"UI input must leave the estate's time, position, economy, duties and saves untouched.")
	if not failed:
		print("MANAGEMENT_FOCUS_VIEWS_OK pages=9 paused=true saves=0 window=", screen.size)
		print("SCENARIO_OK")
	tree.quit(1 if failed else 0)
