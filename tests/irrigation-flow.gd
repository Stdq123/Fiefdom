extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		push_error(detail)
		failed = true

func _click(point: Vector2, shift := false) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.shift_pressed = shift
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await process_frame

func _click_cell(world: Node, cell: Vector2i, shift := false) -> void:
	var tile_map: TileMapLayer = world.tile_map
	await _click(tile_map.get_global_transform_with_canvas() * tile_map.map_to_local(cell), shift)

func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event, true)

func _sleep(ui: Node) -> void:
	await _click(ui.sleep_button.get_global_rect().get_center())
	await create_timer(1.1).timeout

func _study(ui: Node) -> void:
	await _click(ui.manage_button.get_global_rect().get_center())
	var panel: Control = ui.panel_manager.management_panel_instance
	panel.get_node("HBoxContainer/RightPanel").current_tab = 2
	await process_frame
	await _click(panel.read_button.get_global_rect().get_center())
	await _click(panel.get_node("CloseButton").get_global_rect().get_center())

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run irrigation-flow with Test-GodotSmoke.ps1 to isolate its save.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	seed(71)
	change_scene_to_file("res://scenes/Main.tscn")
	await scene_changed
	await process_frame
	var state := root.get_node("Global")
	var world := current_scene.get_node("World")
	var ui := current_scene.get_node("UI")
	_expect(ui.channel_button.disabled, "Construction starts locked.")

	var millet_cells := [Vector2i(6, 4), Vector2i(6, 5), Vector2i(6, 6)]
	for cell in millet_cells:
		await _click_cell(world, cell)
		await _click_cell(world, cell)
	for day in range(2):
		for cell in millet_cells:
			await _click_cell(world, cell)
		await _study(ui)
		await _sleep(ui)
	for cell in millet_cells:
		await _click_cell(world, cell)
	_expect(state.money == 15, "Three manually watered private crops pay for construction.")

	var rice := Vector2i(4, 5)
	_press(KEY_3)
	await _click_cell(world, rice)
	await _click_cell(world, rice)
	_expect(state.tilled_cells.has(rice) and not state.active_crops.has(rice) and "通水" in ui.help_label.text, "Dry ground cannot accept new rice and the HUD gives the requirement.")

	await _click(ui.manage_button.get_global_rect().get_center())
	var management = ui.panel_manager.management_panel_instance
	var tabs := management.get_node("HBoxContainer/RightPanel") as TabContainer
	tabs.current_tab = 3
	await process_frame
	await _click(management.irrigation_button.get_global_rect().get_center())
	_expect(ui.channel_button.disabled and management.irrigation_button.disabled and "2/3" in management.irrigation_button.text,
		"The technology tab explains the remaining literacy requirement.")
	await _click(management.get_node("CloseButton").get_global_rect().get_center())
	for night in range(2):
		await _study(ui)
		await _sleep(ui)
	await _study(ui)
	await _click(ui.manage_button.get_global_rect().get_center())
	tabs.current_tab = 3
	await process_frame
	await _click(management.irrigation_button.get_global_rect().get_center())
	_expect(state.tech_unlocked["irrigation"] and not ui.channel_button.disabled, "Reading and the technology button unlock map construction.")
	await _click(management.get_node("CloseButton").get_global_rect().get_center())

	var connector := Vector2i(2, 5)
	await _click(ui.channel_button.get_global_rect().get_center())
	_expect(world.channel_mode and "4 铜钱" in ui.help_label.text, "The HUD shows the live cost and switches to canal editing.")
	await _click_cell(world, Vector2i(3, 5))
	_expect(not state.irrigation.supplies(rice), "A disconnected section does not water its neighbor.")
	await _click_cell(world, connector)
	_expect(state.irrigation.supplies(rice) and state.money == 7 and "已通水" in ui.help_label.text, "Building the connector supplies the plot, charges twice and updates the HUD.")
	_press(KEY_ESCAPE)
	_expect(not world.channel_mode, "Escape returns to farming.")
	await _click_cell(world, rice)
	_expect(state.active_crops.has(rice) and state.active_crops[rice]["requires_channel"], "The supplied plot accepts rice.")
	if not state.active_crops.has(rice):
		quit(1)
		return
	await _sleep(ui)
	_expect(state.active_crops[rice]["age"] == 1, "Supplied rice grows without manual watering.")

	await _click(ui.channel_button.get_global_rect().get_center())
	await _click_cell(world, connector, true)
	_press(KEY_ESCAPE)
	await _click_cell(world, rice)
	await _sleep(ui)
	_expect(state.active_crops[rice]["age"] == 1, "Removing the connector pauses rice through the night.")
	await _click(ui.channel_button.get_global_rect().get_center())
	await _click_cell(world, connector)
	_press(KEY_ESCAPE)
	_expect(state.save_game() == OK and state.load_game() == OK, "The irrigated field saves and reloads.")
	await scene_changed
	await process_frame
	world = current_scene.get_node("World")
	ui = current_scene.get_node("UI")
	_expect(state.irrigation.supplies(rice) and not ui.channel_button.disabled, "Canal flow and technology survive reload.")
	for night in range(3):
		await _sleep(ui)
	await _click_cell(world, rice)
	_expect(not state.active_crops.has(rice) and state.money == 15, "The restored water supply matures rice and its private harvest pays twelve copper.")

	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
