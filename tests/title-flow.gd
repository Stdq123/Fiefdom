extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, detail: String) -> void:
	if not condition:
		push_error(detail)
		failed = true

func _button(node: Node, prefix: String) -> Button:
	for button in node.find_children("*", "Button", true, false):
		if button.text.begins_with(prefix):
			return button
	return null

func _hover(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	await process_frame

func _click(point: Vector2) -> void:
	await _hover(point)
	for pressed in [true, false]:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = point
		mouse.global_position = point
		mouse.pressed = pressed
		root.push_input(mouse, true)
		await process_frame

func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event, true)

func _point(map: TileMapLayer, cell: Vector2i) -> Vector2:
	return map.get_global_transform_with_canvas() * map.map_to_local(cell)

func _open_settings(ui: Node) -> Panel:
	ui.settings_button.pressed.emit()
	await process_frame
	return ui.panel_manager.settings_panel_instance

func _return_to_title(ui: Node) -> void:
	var settings := await _open_settings(ui)
	_button(settings, "返回标题").pressed.emit()
	var confirmation := settings.get_node("TitleConfirmation") as ConfirmationDialog
	_expect(confirmation.visible, "Returning to the title asks before leaving the current game.")
	confirmation.confirmed.emit()
	await scene_changed

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run title-flow with Test-GodotSmoke.ps1 to isolate its save.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	var state := root.get_node("Global")
	var title := current_scene
	_expect(title.name == "Title" and title.continue_button.disabled and "还没有存档" in title.status.text, "A fresh launch opens the title and explains the empty slot.")
	_expect(not title.continue_button.visible and not title.archive_button.visible and title.new_button.has_focus(),
		"A fresh profile shows New Game as the main action.")
	title.get_node("Center/Menu/Settings").pressed.emit()
	_expect(title.settings_panel.visible and not title.menu.visible and not title.settings_panel.session_controls, "Title settings hide the menu and omit game-session actions.")
	_button(title.settings_panel, "关闭").pressed.emit()
	_expect(title.menu.visible, "Closing settings restores the title menu.")

	title.new_button.pressed.emit()
	await scene_changed
	var ui := current_scene.get_node("UI")
	var world := current_scene.get_node("World")
	_expect(state.current_day == 1 and state.well_fields.size() == 1, "New Game enters a fresh estate.")
	var guide: Label = ui.hud.guide
	var tribute := Vector2i(5, 5)
	var map := world.get_node("TileMapLayer") as TileMapLayer
	var cursor := map.get_node("FieldCursor")
	var millet := ui.hud.seed_buttons["millet"] as Button
	var rice := ui.hud.seed_buttons["rice"] as Button
	_expect("翻地" in guide.text, "The guide starts by pointing to the public field.")
	_expect(millet.button_pressed and not rice.button_pressed, "The default seed is visible in the tool belt.")
	await _hover(_point(map, tribute))
	_expect(cursor.visible and "公田 · 翻地" in cursor.label.text and "−2 体力" in cursor.label.text, "The first field previews the action and its cost.")
	var initial_stamina: int = state.current_stamina
	state.current_stamina = 1
	await _click(_point(map, tribute))
	_expect("体力不足" in cursor.label.text and not state.tilled_cells.has(tribute) and state.current_stamina == 1, "An exhausted player sees the reason and cannot change the field.")
	state.current_stamina = initial_stamina
	await _click(_point(map, tribute))
	_expect("播种" in guide.text and state.current_stamina == initial_stamina - 2, "Tilling charges the shown cost and advances the guide.")

	await _click(rice.get_global_rect().get_center())
	_expect(world.current_seed_id == "rice" and rice.button_pressed and not millet.button_pressed and not cursor.visible, "Clicking a seed selects it and dismisses the map cue.")
	await _click(_point(map, tribute))
	_expect("通水" in cursor.label.text and not state.active_crops.has(tribute) and state.current_stamina == initial_stamina - 2, "A dry plot previews and enforces the rice water requirement.")
	_press(KEY_1)
	_expect(world.current_seed_id == "millet" and millet.button_pressed and not rice.button_pressed, "The shortcut updates the same selection as the tool belt.")
	await _click(_point(map, tribute))
	_expect("浇水" in guide.text, "Sowing advances the guide to watering.")
	for night in range(2):
		await _click(_point(map, tribute))
		_expect("水已到田" in guide.text, "Watering points the player to the sleep button.")
		await _click(ui.sleep_button.get_global_rect().get_center())
		await create_timer(1.1).timeout
	_expect("收割" in guide.text and "入国库" in guide.text, "Ripening explains how to deliver the first tribute.")
	await _hover(_point(map, tribute))
	_expect("收获" in cursor.label.text and "−3 体力" in cursor.label.text, "Mature crops show their harvest cost.")
	await _click(_point(map, tribute))
	_expect(state.king_storage == 1 and "私田" in guide.text, "The first tribute moves the guide to the first private crop.")

	var planted := Vector2i(6, 5)
	world.handle_interaction(planted)
	world.handle_interaction(planted)
	ui.sleep_button.pressed.emit()
	await create_timer(1.1).timeout
	var saved_day: int = state.current_day
	state.silk_workshop.leaves = 7
	state.fertile_cells[planted] = true
	state.money = 23
	state.tech_unlocked["irrigation"] = true
	state.build_channel(Vector2i(2, 5))
	var settings := await _open_settings(ui)
	_button(settings, "保存游戏").pressed.emit()
	_expect(settings.save_status.text == "游戏已保存", "The estate can save before returning to the title.")
	var manual_path: String = state.manual_save_path()
	var save_text := FileAccess.get_file_as_string(manual_path)
	settings.hide()
	await _return_to_title(ui)
	title = current_scene
	_expect(not title.continue_button.disabled, "The title detects the saved campaign.")
	title.continue_button.pressed.emit()
	await scene_changed
	ui = current_scene.get_node("UI")
	_expect(ui.hud.guide.opening_cell == planted, "Continue points to the private crop that the player already planted.")
	_expect(state.current_day == saved_day and state.money == 19 and state.active_crops.has(planted)
		and state.silk_workshop.leaves == 7 and state.fertile_cells.has(planted)
		and state.irrigation.channels.has(Vector2i(2, 5)), "Continue restores the campaign state in the estate.")

	await _return_to_title(ui)
	title = current_scene
	title.new_button.pressed.emit()
	_expect(title.new_confirmation.visible, "New Game explains the save slot when a campaign already exists.")
	title.new_confirmation.confirmed.emit()
	await scene_changed
	ui = current_scene.get_node("UI")
	_expect(state.current_day == 1 and state.money == 0 and state.active_crops.is_empty()
		and state.fertile_cells.is_empty() and state.silk_workshop.leaves == 0
		and state.irrigation.channels.is_empty() and state.retainers.size() == 1, "A second New Game starts with clean campaign state.")
	_expect(FileAccess.get_file_as_string(manual_path) == save_text, "The previous file survives starting a new campaign before saving.")

	await _return_to_title(ui)
	title = current_scene
	for entry in state.saved_games():
		var bad := FileAccess.open(entry["path"], FileAccess.WRITE)
		bad.store_string("[1, 2]")
		bad.close()
	title.continue_button.pressed.emit()
	_expect(current_scene == title and "存档格式有误" in title.status.text, "A damaged save keeps the title usable and explains the problem.")
	_expect(title.new_button.has_focus() and title.archive_button.visible and not title.continue_button.visible,
		"With only damaged saves, New Game and the save picker remain available.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
