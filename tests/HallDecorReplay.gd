extends "res://tests/HallInteriorReplay.gd"

var panel: Control
var legacy := false

func _play() -> void:
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	if legacy:
		await _continue_legacy()
		return
	await _press(tree.current_scene.new_button)
	if not await _estate() or not await _enter():
		return
	await _snapshot("01-window-shelf")
	if not await _preview_and_cancel() or not await _leave() or not await _earn_decor() or not await _enter():
		return
	if await _arrange():
		await _save_and_continue()

func _open_shelf() -> bool:
	await _walk_in_room(Vector2(0, 35))
	await _walk_in_room(Vector2(0, 3))
	await tree.physics_frame
	await tree.process_frame
	if not _expect(player.interaction_target == room.get_node("DecorShelf"), "Walk up to the window shelf."):
		return false
	await _key(KEY_E)
	panel = ui.get_node("Control/HallDecorPanel")
	return _expect(panel.modal.visible and tree.paused and not ui.hud.visible and not panel.exit_hint.visible,
		"E opens a paused preview of the real room.")

func _check_art(mat: String, shelf: String) -> bool:
	var view: HallDecorView = room.get_node("Decor")
	var mat_texture := view.mat_sprite.texture as AtlasTexture
	var shelf_texture := view.display_sprite.texture as AtlasTexture
	var mat_region := mat_texture.region if mat_texture else Rect2()
	var shelf_region := shelf_texture.region if shelf_texture else Rect2()
	return _expect(mat_region == Rect2(HallDecor.CATALOG[mat].region) and shelf_region == Rect2(HallDecor.CATALOG[shelf].region),
		"The room shows %s and %s." % [mat, shelf])

func _preview_and_cancel() -> bool:
	if not _check_art(HallDecor.DEFAULT_MAT, HallDecor.DEFAULT_SHELF) or not await _open_shelf():
		return false
	var tribute: Button = panel.rows["tribute_sheaf"]
	_expect(tribute.disabled and "公田" in tribute.text, "The locked tribute explains its requirement.")
	await _press(tribute)
	_check_art(HallDecor.DEFAULT_MAT, HallDecor.DEFAULT_SHELF)
	await _press(panel.mat_tab)
	await _press(panel.rows["bare_floor"])
	_expect(state.hall_mat_id == HallDecor.DEFAULT_MAT and not panel.apply_button.disabled,
		"The bare floor is only a draft until applied.")
	_check_art("bare_floor", HallDecor.DEFAULT_SHELF)
	await _snapshot("02-clear-floor-preview")
	await _key(KEY_ESCAPE)
	return _expect(not tree.paused and not panel.modal.visible and ui.hud.visible and panel.exit_hint.visible
		and room.room_camera.offset == Vector2.ZERO,
		"Esc cancels the preview and restores the normal room view.") and _check_art(HallDecor.DEFAULT_MAT, HallDecor.DEFAULT_SHELF)

func _earn_decor() -> bool:
	await Campaign.walk_to(tree, player, world.to_global(Vector2(66, 98)))
	for cell in [PUBLIC, PRIVATE]:
		for step in 3:
			await _crop_click(cell)
	await _press(ui.sleep_button)
	await tree.create_timer(1.24).timeout
	await _harvest()
	if not _expect(state.hall_decor_unlocked("tribute_sheaf") and state.current_day == 3,
		"The first public crop unlocks the sheaf at harvest."):
		return false
	# Set up the earlier provision delivery and copper. The neighborhood replay covers that trade.
	state.road_provisions_delivered = true
	state.road_provisions_day = state.current_day - 1
	state.money += state.balance.road_rest_cost
	if not _expect(state.fund_road_rest() and not state.hall_decor_unlocked("blue_mat"),
		"Funding the roadside bench alone does not unlock the blue mat."):
		return false
	await _press(ui.sleep_button)
	await tree.create_timer(1.24).timeout
	return _expect(state.road_rest_built() and state.hall_decor_unlocked("blue_mat"),
		"The blue mat unlocks when the bench opens the following dawn.")

func _gamepad_back() -> void:
	tree.root.notify_mouse_exited()
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_B
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await tree.process_frame
	await tree.process_frame

func _arrange() -> bool:
	if not await _open_shelf():
		return false
	await _press(panel.rows["tribute_sheaf"])
	await _snapshot("03-tribute-preview")
	await _gamepad_back()
	if not _expect(not panel.modal.visible and not tree.paused and state.hall_shelf_id == HallDecor.DEFAULT_SHELF,
		"Gamepad B discards the shelf draft.") or not _check_art(HallDecor.DEFAULT_MAT, HallDecor.DEFAULT_SHELF):
		return false
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2.RIGHT
	Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	await tree.process_frame
	print("DECOR_CANCEL escape=true gamepad=true")
	if not await _open_shelf():
		return false
	await _press(panel.rows["tribute_sheaf"])
	await _press(panel.apply_button)
	_expect(not panel.modal.visible and state.hall_shelf_id == "tribute_sheaf" and state.hall_mat_id == HallDecor.DEFAULT_MAT,
		"Applying a shelf prop keeps the floor selection.")
	if not await _open_shelf():
		return false
	await _press(panel.mat_tab)
	await _press(panel.rows["blue_mat"])
	await _snapshot("04-blue-mat-preview")
	await _press(panel.apply_button)
	return _expect(not tree.paused and state.hall_mat_id == "blue_mat" and state.hall_shelf_id == "tribute_sheaf",
		"Applying the mat preserves the shelf prop.") and _check_art("blue_mat", "tribute_sheaf")

func _save_and_continue() -> void:
	await _press(ui.settings_button)
	var settings: Control = ui.panel_manager.settings_panel_instance
	for button: Button in settings.find_children("*", "Button", true, false):
		if button.text == "保存游戏":
			await _press(button)
			break
	if not _expect(settings.save_status.text == "游戏已保存", "Save both slots from the usual settings menu."):
		return
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	await _press(tree.current_scene.continue_button)
	if not await _estate():
		return
	_expect(state.estate_room == state.EstateRoom.HALL and state.hall_mat_id == "blue_mat"
		and state.hall_shelf_id == "tribute_sheaf" and room.room_camera.is_current()
		and player.global_position.is_equal_approx(room.get_node("Wake").global_position),
		"Title Continue restores both decor choices and the bed spawn in the hall.")
	_check_art("blue_mat", "tribute_sheaf")
	await _walk_in_room(Vector2(40, 42))
	await _snapshot("05-return-to-hall")
	print("DECOR_ROUND_TRIP day=", state.current_day, " mat=", state.hall_mat_id, " shelf=", state.hall_shelf_id)
	tree.change_scene_to_file(state.TITLE_SCENE)
	await tree.scene_changed
	await tree.process_frame
	var title := tree.current_scene
	await _press(title.new_button)
	title.new_name.text = "新封地"
	await _key(KEY_ENTER)
	if await _estate() and await _enter():
		_expect(state.hall_mat_id == HallDecor.DEFAULT_MAT and state.hall_shelf_id == HallDecor.DEFAULT_SHELF,
			"A new estate begins with the default decor.")
		_check_art(HallDecor.DEFAULT_MAT, HallDecor.DEFAULT_SHELF)
		print("DECOR_NEW_ESTATE mat=", state.hall_mat_id, " shelf=", state.hall_shelf_id)

func _continue_legacy() -> void:
	var latest: Dictionary = state.latest_saved_game()
	if not _expect(not latest.is_empty(), "Use a hall save written by the previous Windows build."):
		return
	var original := FileAccess.get_file_as_string(latest.path)
	var saved: Dictionary = JSON.parse_string(original)
	_expect(not saved.has("hall_mat") and not saved.has("hall_shelf"), "The previous save has no decor fields.")
	await _press(tree.current_scene.continue_button)
	if not await _estate():
		return
	_expect(state.estate_room == state.EstateRoom.HALL and state.hall_mat_id == HallDecor.DEFAULT_MAT
		and state.hall_shelf_id == HallDecor.DEFAULT_SHELF and FileAccess.get_file_as_string(latest.path) == original,
		"Continue adds default decor and leaves the existing save intact.")
	_check_art(HallDecor.DEFAULT_MAT, HallDecor.DEFAULT_SHELF)
	await _open_shelf()
	await _key(KEY_ESCAPE)
	print("DECOR_LEGACY day=", state.current_day, " mat=", state.hall_mat_id, " shelf=", state.hall_shelf_id)
