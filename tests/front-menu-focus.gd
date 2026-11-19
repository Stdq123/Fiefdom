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

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run front-menu-focus with Test-GodotSmoke.ps1 to isolate its archive.")
		quit(1)
		return
	var state := root.get_node("Global")
	var entries := [
		{"campaign_id": "front-menu", "campaign_name": "柳湾", "file": "autosave-1.json",
			"save_origin": "ending", "current_day": 65, "outcome": state.Outcome.TRADITIONAL, "save_sequence": 2},
		{"campaign_id": "front-menu", "campaign_name": "柳湾", "file": "autosave-2.json",
			"save_origin": "ending", "current_day": 65, "outcome": state.Outcome.REFORMED, "save_sequence": 3},
		{"campaign_id": "front-menu-next", "campaign_name": "南路亭", "file": "savegame.json",
			"current_day": 21, "outcome": state.Outcome.RUNNING, "save_sequence": 1},
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
	await _key(KEY_LEFT)
	_expect(next_estate.has_focus(), "Left returns to the same estate.")
	await _key(KEY_TAB)
	_expect(next_record.has_focus(), "Tab enters the selected estate's records.")
	for i in 9:
		await _key(KEY_TAB)
		var focus := root.gui_get_focus_owner()
		_expect(focus != null and archive.is_ancestor_of(focus), "Tab must stay inside the archive.")
		_expect(next_estate.button_pressed, "Tab keeps the selected estate while browsing records.")
	archive.close_button.pressed.emit()
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
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
