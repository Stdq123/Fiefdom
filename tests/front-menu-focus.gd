extends SceneTree

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event, true)
	await process_frame

func _pad(button: JoyButton) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		root.window_input.emit(event)
		await process_frame

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run front-menu-focus with Test-GodotSmoke.ps1 to isolate its archive.")
		quit(1)
		return
	var state := root.get_node("Global")
	var preferences := root.get_node("Preferences")
	var entries := [
		{"campaign_id": "front-menu", "campaign_name": "柳湾", "file": "autosave-1.json",
			"save_origin": "ending", "current_day": 65, "outcome": state.Outcome.TRADITIONAL, "save_sequence": 2},
		{"campaign_id": "front-menu", "campaign_name": "柳湾", "file": "autosave-2.json",
			"save_origin": "ending", "current_day": 65, "outcome": state.Outcome.REFORMED, "save_sequence": 3},
		{"campaign_id": "front-menu-next", "campaign_name": "南路亭", "file": "savegame.json",
			"current_day": 21, "outcome": state.Outcome.RUNNING, "save_sequence": 1, "inside_hall": true},
	]
	for entry: Dictionary in entries:
		var folder: String = state.CAMPAIGN_SAVE_ROOT.path_join(entry.campaign_id.md5_text())
		if DirAccess.make_dir_recursive_absolute(folder) != OK:
			push_error("Cannot stage the archive.")
			quit(1)
			return
		var path := folder.path_join(entry.file)
		var file := FileAccess.open(path, FileAccess.WRITE)
		if not file:
			push_error("Cannot stage " + path)
			quit(1)
			return
		entry.erase("file")
		entry.save_version = state.SAVE_VERSION
		file.store_string(JSON.stringify(entry))
		file.close()
	change_scene_to_file(state.TITLE_SCENE)
	await scene_changed
	var title := current_scene
	title.archive_button.grab_focus()
	title.archive_button.pressed.emit()
	await process_frame
	var archive: Control = title.get_node("SaveArchive")
	var estate: Button = archive.campaign_buttons["front-menu".md5_text()]
	var first: Button = archive.records.get_child(0)
	var second: Button = archive.records.get_child(1)
	var standard := first.get_theme_font_size(&"font_size")
	_expect(preferences.set_reading_size(2) == OK and first.get_theme_font_size(&"font_size") == standard + 6,
		"The archive must react to a larger reading size while visible.")
	_expect(estate.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and first.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"Long names and record metadata must wrap instead of clipping.")
	_expect("税亩富民" in first.text and "守礼安邦" in second.text and first.icon != null and second.icon != null,
		"Each checkpoint must identify its own ending inside the same estate.")
	var reform_volume := first.icon as AtlasTexture
	var tribute_volume := second.icon as AtlasTexture
	_expect(reform_volume != null and tribute_volume != null and reform_volume.region != tribute_volume.region,
		"The two endings must show their own ledger art.")
	await _key(KEY_RIGHT)
	_expect(first.has_focus(), "Right from an estate must enter its list of records.")
	await _key(KEY_LEFT)
	_expect(estate.has_focus(), "Left from a record must return to the selected estate.")
	var next_estate: Button = archive.campaign_buttons["front-menu-next".md5_text()]
	await _key(KEY_DOWN)
	_expect(next_estate.has_focus() and next_estate.button_pressed and "南路亭" in archive.records_heading.text,
		"Focusing the second estate changes the visible record list.")
	await _key(KEY_RIGHT)
	var next_record: Button = archive.records.get_child(0)
	_expect(next_record.has_focus() and "第 21 天" in next_record.text,
		"Right enters the focused estate's records.")
	_expect(next_record.get_theme_font_size(&"font_size") == standard + 6,
		"Records rebuilt after changing estates keep the selected reading size.")
	var hall := next_record.icon as AtlasTexture
	_expect("堂屋" in next_record.text and hall != null and hall.region.position == Vector2(192, 0),
		"An old inside_hall checkpoint gets the hall caption and location picture.")
	await _key(KEY_LEFT)
	_expect(next_estate.has_focus(), "Left returns to the same estate.")
	await _key(KEY_TAB)
	_expect(next_record.has_focus(), "Tab enters the selected estate's records.")
	for i in 9:
		await _key(KEY_TAB)
		var focus := root.gui_get_focus_owner()
		_expect(focus != null and archive.is_ancestor_of(focus), "Tab must stay inside the archive.")
		_expect(next_estate.button_pressed, "Tab keeps the selected estate while browsing records.")
	next_estate.grab_focus()
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	_expect(next_record.has_focus(), "D-pad Right enters the active estate's records.")
	await _pad(JOY_BUTTON_B)
	await process_frame
	await process_frame
	_expect(title.archive_button.has_focus(), "Closing the archive must restore the title action.")
	var settings_button := title.get_node("Center/Menu/Settings") as Button
	settings_button.pressed.emit()
	await process_frame
	var settings: Panel = title.settings_panel
	_expect(settings.master_slider.has_focus(), "Keyboard users must enter settings on a volume control.")
	settings.shortcuts.pressed.emit()
	_expect(settings.bindings_page.is_ancestor_of(root.gui_get_focus_owner()), "The binding list must receive focus.")
	settings.close_button.pressed.emit()
	_expect(settings.shortcuts.has_focus(), "Back from bindings must focus the shortcut that opened it.")
	settings.close_button.pressed.emit()
	_expect(settings_button.has_focus() and current_scene == title and get_nodes_in_group("player").is_empty(),
		"Closing settings must return to the menu without starting a campaign.")
	await _check_new_game_form(title, preferences)
	_expect(current_scene == title and state.saved_games().size() == entries.size(),
		"The title check keeps the staged records and does not enter the estate.")
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)

func _check_new_game_form(title: Node, preferences: Node) -> void:
	var pad := root.get_node("GamepadInput")
	var new_game: Button = title.new_button
	var dialog: ConfirmationDialog = title.new_confirmation
	var field: LineEdit = title.new_name
	var start := dialog.get_ok_button()
	var cancel := dialog.get_cancel_button()
	var menu_size := new_game.get_theme_font_size(&"font_size")
	var name_size := field.get_theme_font_size(&"font_size")
	_expect(preferences.set_reading_size(0) == OK and new_game.get_theme_font_size(&"font_size") == menu_size - 6
		and field.get_theme_font_size(&"font_size") == name_size - 6, "The title buttons and new estate field share the reading preference.")
	title.continue_button.grab_focus()
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_expect(new_game.has_focus(), "D-pad browses the title actions.")
	new_game.pressed.emit()
	await process_frame
	_expect(dialog.visible and start.has_focus() and cancel.text == "取消  B", "Gamepad opens the form on Start and labels Cancel.")
	await _pad(JOY_BUTTON_DPAD_UP)
	_expect(field.has_focus(), "D-pad reaches the name field from the confirmation buttons.")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_expect(start.has_focus(), "D-pad returns from the name to Start.")
	var direction := JOY_BUTTON_DPAD_LEFT if cancel.position.x < start.position.x else JOY_BUTTON_DPAD_RIGHT
	await _pad(direction)
	_expect(cancel.has_focus(), "D-pad moves to the form's other action.")
	await _pad(JOY_BUTTON_B)
	await process_frame
	_expect(not dialog.visible and new_game.has_focus()
		and pad.cursor.position.is_equal_approx(new_game.get_global_rect().get_center()), "B restores the title focus and pointer.")
	pad._use_mouse()
	new_game.pressed.emit()
	_expect(dialog.visible and field.has_focus() and field.get_selected_text() == field.placeholder_text
		and cancel.text == "取消  Esc", "Keyboard opening selects the suggested name for immediate editing.")
	await _key(KEY_TAB)
	_expect(start.has_focus() or cancel.has_focus(), "Tab moves from the name to the form actions.")
	await _key(KEY_ESCAPE)
	_expect(not dialog.visible and new_game.has_focus(), "Escape backs out without starting a new game.")
