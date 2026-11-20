extends SceneTree

var state: Node
var pad: Node
var failed := false

func _initialize() -> void:
	_review.call_deferred()

func _review() -> void:
	if not OS.get_user_data_dir().contains("fiefdom-smoke-"):
		push_error("Run the panel focus check with an isolated profile.")
		quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	state = root.get_node("Global")
	pad = root.get_node("GamepadInput")
	state.current_day = 4
	state.day_progress = 0.38
	if not await _mount(state.ESTATE_SCENE):
		quit(1)
		return
	var ui := current_scene.get_node("UI")
	var before := _state()
	await _check_map(ui.estate_map, ui.hud.map_button, true)
	await _check_map(ui.calendar, ui.hud.calendar_button)
	_expect(before == _state(), "Reading the estate maps and calendar leaves the estate intact.")
	await _reclamation(ui)

	for path: String in [state.WILDERNESS_SCENE, state.WEST_MARKET_SCENE, state.WEST_ROAD_SCENE]:
		if not await _mount(path):
			quit(1)
			return
		before = _state()
		if path == state.WEST_ROAD_SCENE:
			var road_map: Control = current_scene.region_map
			await _check_map(road_map, road_map.road_button, false, true)
		else:
			var local: Control = current_scene.ravine_map if path == state.WILDERNESS_SCENE else current_scene.market_map
			await _check_map(local, local.open_button, true)
		_expect(before == _state(), "Reading the route charts leaves state and position intact in " + path)
	pad._use_mouse()
	state.estate_room = state.EstateRoom.HALL
	if not await _mount(state.ESTATE_SCENE):
		quit(1)
		return
	var wardrobe := current_scene.get_node("UI/Control/WardrobePanel") as Control
	before = _state()
	var attire: String = state.attire_id
	wardrobe.open_map()
	await _frames(3)
	await _tabs_inside(wardrobe.modal, 12)
	_key(KEY_ESCAPE)
	await _frames(4)
	_expect(not wardrobe.modal.visible and not paused and before == _state() and state.attire_id == attire,
		"The wardrobe traps focus while browsing and closes without changing clothes.")
	_expect(state.saved_games().is_empty(), "The panel fixture writes no campaign saves.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _mount(path: String) -> bool:
	paused = true
	if change_scene_to_file(path) != OK:
		_expect(false, "Mount the fixed interface " + path)
		return false
	await scene_changed
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var landscape := current_scene.get_node_or_null("Landscape")
	if landscape:
		landscape.process_mode = Node.PROCESS_MODE_DISABLED
	var ui := current_scene.get_node_or_null("UI")
	if ui:
		ui.process_mode = Node.PROCESS_MODE_ALWAYS
	paused = false
	await _frames(4)
	return true

func _check_map(map: Control, opener: Button, has_region := false, use_pad := false) -> void:
	pad._use_mouse()
	var pad_controls := has_region or use_pad
	if pad_controls:
		pad._use_gamepad(31)
		await _frames(3)
	_expect(opener.is_visible_in_tree() and not opener.disabled, "The real map entrance is ready.")
	opener.grab_focus()
	pad.snap_pointer_to_focus()
	opener.pressed.emit()
	await _frames(3)
	_expect(map.owns_pause and map.modal.is_visible_in_tree() and map.close_button.has_focus(),
		"The opening chart has focus on its return control.")
	if pad_controls:
		_expect(pad.cursor.position.is_equal_approx(map.close_button.get_global_rect().get_center()),
			"The gamepad pointer follows the initial chart focus.")
	await _tabs_inside(map.modal, 10)
	if has_region:
		var region: Control = map.region_map
		map.get_node("%RegionMap").pressed.emit()
		await _frames(3)
		_expect(paused and not map.modal.visible and region.local_button.has_focus(),
			"The regional chart receives focus and owns the open pause.")
		region.local_button.pressed.emit()
		await _frames(3)
		_expect(paused and not region.modal.visible and map.get_node("%RegionMap").has_focus(),
			"Local and regional charts retain focus across the switch.")
		map.get_node("%RegionMap").pressed.emit()
		map = region
		await _frames(3)
	if pad_controls:
		await _pad(JOY_BUTTON_B)
	else:
		_key(KEY_ESCAPE)
		await _frames(4)
	_expect(not paused and not map.modal.visible and opener.has_focus(),
		"Closing the chart returns to the button that originally opened it.")
	if pad_controls:
		_expect(pad.active and pad.cursor.position.is_equal_approx(opener.get_global_rect().get_center()),
			"The simulated gamepad pointer also returns to the original button.")

func _reclamation(ui: Node) -> void:
	if not is_instance_valid(ui):
		return
	pad._use_mouse()
	var opener: Button = ui.hud.reclaim_button
	var before := _state()
	opener.grab_focus()
	opener.pressed.emit()
	await _frames(4)
	var panel := ui.get_node("Control/ReclamationPanel") as Control
	_expect(panel.close_button.has_focus() and panel.reclaim_button.disabled
		and panel.close_button.text == "返回  Esc", "A locked survey opens with focus on its safe return control.")
	await _tabs_inside(panel.card, 24)
	_key(KEY_ESCAPE)
	await _frames(4)
	_expect(not is_instance_valid(panel) and opener.has_focus() and before == _state(),
		"Escape returns to the same HUD button and makes no change to the estate.")

	state.current_rank = state.Rank.ZHONG_SHI
	state._update_max_well_fields()
	var quote: Dictionary = state.reclamation_plan()
	state.money = quote.copper - 1
	state.food_storage = quote.grain + quote.crew_food
	opener.pressed.emit()
	await _frames(4)
	panel = ui.get_node("Control/ReclamationPanel") as Control
	_expect(panel.market_button.is_visible_in_tree() and panel.close_button.has_focus(),
		"The shortage shortcut is visible within the active survey.")
	await _pad(JOY_BUTTON_DPAD_UP)
	var current := root.gui_get_focus_owner()
	_expect(panel.close_button.text == "返回  B" and current != null and current != panel.close_button
		and panel.card.is_ancestor_of(current), "The gamepad changes its return cue and moves focus inside the ledger.")
	panel.market_button.grab_focus()
	state.money = quote.copper
	panel._refresh()
	_expect(not panel.market_button.is_visible_in_tree() and panel.close_button.has_focus(),
		"Focus returns to the footer when a selected shortage shortcut disappears.")
	before = _state()
	await _pad(JOY_BUTTON_B)
	_expect(not is_instance_valid(panel) and opener.has_focus() and before == _state()
		and pad.active and pad.cursor.position.is_equal_approx(opener.get_global_rect().get_center()),
		"Gamepad B returns to the exact HUD control without committing a survey.")

func _tabs_inside(card: Control, count: int) -> void:
	for backward in [false, true]:
		var escapes := 0
		for step in count:
			_key(KEY_TAB, backward)
			var focus := root.gui_get_focus_owner()
			escapes += int(not focus or not card.is_ancestor_of(focus))
		_expect(escapes == 0, "Tab stays inside %s across %d steps, actual escapes %d." % [card.name, count, escapes])

func _key(code: Key, shift := false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		event.shift_pressed = shift
		root.push_input(event, true)

func _pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 31
		event.button_index = button
		event.pressed = pressed
		pad._window_input(event)
		await _frames(2)
	await _frames(2)

func _state() -> Array:
	var actor := get_first_node_in_group("player") as Node2D
	return [state.current_day, state.day_progress, state.money, state.food_storage,
		state.current_stamina, hash(state.active_crops), hash(state.well_fields), actor.global_position]

func _frames(count: int) -> void:
	for frame in count:
		await process_frame

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)
