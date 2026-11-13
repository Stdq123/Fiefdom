extends SceneTree

const Campaign := preload("res://tests/CampaignReplay.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, detail: String) -> void:
	print(("PASS " if condition else "FAIL ") + detail)
	if not condition:
		failures += 1

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.physical_keycode = code
	root.push_input(event, true)

func _click(point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await process_frame

func _sleep(ui: Node) -> void:
	ui.sleep_button.pressed.emit()
	await create_timer(1.05).timeout

func _find_button(node: Node, prefix: String) -> Button:
	for button in node.find_children("*", "Button", true, false):
		if button.text.begins_with(prefix):
			return button
	return null

func _visit(world: Node, ui: Node, state: Node) -> void:
	if state.retainers.size() >= 3 or world.active_visitors.is_empty() or not is_instance_valid(world.active_visitors[0]):
		return
	await Campaign.walk_to(self, world.player, world.active_visitors[0].global_position)
	_key(KEY_E)
	var dialog = ui.get_node_or_null("Control/DialoguePanel")
	if dialog == null:
		return
	var talk := _find_button(dialog, "交谈")
	if talk and not talk.disabled:
		talk.pressed.emit()
		await process_frame
		_key(KEY_E)
		dialog = ui.get_node_or_null("Control/DialoguePanel")
		if dialog == null:
			return
	var recruit := _find_button(dialog, "招募")
	if recruit and not recruit.disabled:
		recruit.pressed.emit()
	else:
		_find_button(dialog, "离开").pressed.emit()
	await process_frame

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run estate-flow with Test-GodotSmoke.ps1 to isolate its save.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	seed(1794)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	current_scene.new_button.pressed.emit()
	await scene_changed
	await process_frame
	var state := root.get_node("Global")
	var world := current_scene.get_node("World")
	var ui := current_scene.get_node("UI")
	var guide = ui.hud.guide
	state.balance.raid_first_day = 10000
	Input.action_press("ui_down")
	for frame in range(49):
		await physics_frame
	Input.action_release("ui_down")
	var cells: Array[Vector2i] = []
	for x in range(4, 7):
		for y in range(4, 7):
			cells.append(Vector2i(x, y))

	for round_number in range(20):
		for cell in cells:
			_key(KEY_1 if cell == Vector2i(5, 5) else KEY_7)
			if not state.tilled_cells.has(cell):
				world.handle_interaction(cell)
			world.handle_interaction(cell)
		for day in range(2):
			for cell in cells:
				world.handle_interaction(cell)
			await _sleep(ui)
			await _visit(world, ui, state)
		for cell in cells:
			world.handle_interaction(cell)

		ui.manage_button.pressed.emit()
		await process_frame
		var panel = ui.panel_manager.management_panel_instance
		var market = panel.market_panel
		if state.player_inventory > 0:
			market.quantity.value = state.player_inventory
			market.convert_button.pressed.emit()
		var purchase := mini(6, mini(maxi(0, 120 - state.food_storage), state.affordable_market_food()))
		if purchase > 0:
			market.quantity.value = purchase
			market.buy_button.pressed.emit()
		panel.get_node("CloseButton").pressed.emit()
		print("LIVE_ROUND ", round_number + 1, " day=", state.current_day, " rep=", state.reputation, " copper=", state.money, " food=", state.food_storage, " retainers=", state.retainers.size())
		if state.quest_completed and state.current_rank >= state.Rank.ZHONG_SHI and state.retainers.size() >= 3 and state.money >= state.balance.reclamation_cost_copper * (state.current_rank + 1) and state.food_storage >= state.balance.reclamation_cost_food * (state.current_rank + 1) + 24:
			break

	_check(state.king_storage >= 10 and state.quest_completed, "The first tribute quest completes from crops harvested in a fresh game")
	_check(state.current_rank >= state.Rank.ZHONG_SHI and state.retainers.size() == 3 and "开垦第二块井田" in guide.heading.text, "Ordinary crops, market actions, visitors and sleep reach the second field prerequisites")
	ui.reclaim_button.pressed.emit()
	await process_frame
	var reclaim := ui.get_node("Control/ReclamationPanel")
	var center := Vector2i(9, 5)
	var location: Vector2 = world.tile_map.get_global_transform_with_canvas() * world.tile_map.map_to_local(center)
	await _click(location)
	await _click(reclaim.get_node("Panel/ReclaimButton").get_global_rect().get_center())
	await _click(reclaim.get_node("Panel/CloseButton").get_global_rect().get_center())
	_check(state.well_fields.size() == 2, "Real map selection and confirmation start the second well field")
	if state.well_fields.size() != 2:
		quit(1)
		return
	_check("开垦第二块井田" in guide.heading.text and "0/4" in guide.text, "The guide shows the construction countdown.")
	for day in range(4):
		await _sleep(ui)
	_check(guide.heading.text == "晋升" + state.rank_names[state.current_rank + 1],
		"After the second field is ready the guide names the next promotion.")
	_check(state.well_fields[1]["is_unlocked"], "Second well field unlocks after four regular nights")
	ui.manage_button.pressed.emit()
	var panel = ui.panel_manager.management_panel_instance
	_check(panel.well_field_selector.item_count == 2, "Management can switch between the two unlocked fields")
	panel.well_field_selector.select(1)
	panel.well_field_selector.item_selected.emit(1)
	var item = panel.map_grid_container.get_child(4)
	_check(item.grid_pos == center and item.text.begins_with("公田 ·"), "Second well field center appears as public land")
	item._drop_data(Vector2.ZERO, state.retainers[1])
	panel.get_node("CloseButton").pressed.emit()
	for round_number in range(8):
		if state.current_rank >= state.Rank.SHANG_SHI:
			break
		_key(KEY_1)
		for field in state.well_fields:
			var cell: Vector2i = field["center_pos"]
			if not state.tilled_cells.has(cell):
				world.handle_interaction(cell)
			world.handle_interaction(cell)
		for night in range(2):
			for field in state.well_fields:
				world.handle_interaction(field["center_pos"])
			await _sleep(ui)
		for field in state.well_fields:
			world.handle_interaction(field["center_pos"])
	_check(state.current_rank >= state.Rank.SHANG_SHI, "Normal tribute and farming experience reach a second promotion.")
	_check(state.save_game() == OK and state.load_game() == OK, "Expanded estate can be saved and reloaded")
	await scene_changed
	var restored = current_scene.get_node("World")
	_check(restored.tile_map.get_cell_tile_data(center).get_custom_data("is_public_field") and state.retainers[1].assigned_area == center, "Expansion and its assignment survive scene reload")
	if not failures:
		print("SCENARIO_OK")
	quit(1 if failures else 0)
