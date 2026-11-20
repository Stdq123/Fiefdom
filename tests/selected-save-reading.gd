extends SceneTree

var state: Node
var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _expect(ok: bool, detail: String) -> bool:
	if not ok:
		failed = true
		push_error(detail)
	return ok

func _slot(campaign: String, filename := "savegame.json") -> String:
	var folder: String = state.CAMPAIGN_SAVE_ROOT.path_join(campaign.md5_text())
	_expect(DirAccess.make_dir_recursive_absolute(folder) == OK, "Create the isolated campaign directory.")
	return folder.path_join(filename)

func _record(id: String, estate: String, day: int, sequence: int, money: int) -> Dictionary:
	return {"campaign_id": id, "campaign_name": estate, "current_day": day, "save_sequence": sequence,
		"money": money, "location": "estate", "save_version": state.SAVE_VERSION}

func _put(path: String, record: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if _expect(file != null, "Open the isolated save fixture."):
		_expect(file.store_string(JSON.stringify(record)), "Stage the fixed save data.")
		file.close()

func _open_title() -> Node:
	paused = true
	_expect(change_scene_to_file(state.TITLE_SCENE) == OK, "Mount the title menu.")
	await scene_changed
	return current_scene

func _read(button: Button) -> void:
	button.pressed.emit()
	var travel := root.get_node("MapTravel")
	if travel.active:
		await travel.finished
	await process_frame
	await process_frame

func _record_button(archive: Control, campaign: String, day: int) -> Button:
	var key := campaign.md5_text()
	if not _expect(archive.campaign_buttons.has(key), "The archive offers campaign " + campaign):
		return null
	archive.campaign_buttons[key].pressed.emit()
	for row: Button in archive.records.get_children():
		if not row.disabled and "第 %d 天" % day in row.text:
			return row
	_expect(false, "The refreshed campaign list offers day %d." % day)
	return null

func _title_pins_campaign() -> void:
	_put(_slot("alpha"), _record("alpha", "青原", 11, 100, 37))
	var title := await _open_title()
	_expect("青原" in title.status.text and "第 11 天" in title.status.text, "The title offers the first estate.")
	_put(_slot("beta"), _record("beta", "柳湾", 3, 110, 83))
	await _read(title.continue_button)
	_expect(current_scene.scene_file_path == state.ESTATE_SCENE and state.campaign_id == "alpha"
		and state.current_day == 11 and state.money == 37, "Continue reads the estate shown before a newer arrival.")

func _archive_finds_backup() -> void:
	var title := await _open_title()
	title.archive_button.pressed.emit()
	var archive := title.get_node("SaveArchive") as Control
	var button := _record_button(archive, "alpha", 11)
	if not button:
		return
	var path := _slot("alpha")
	var backup: String = path + state.SAVE_BACKUP_SUFFIX
	var old_hash := FileAccess.get_sha256(path)
	_expect(DirAccess.rename_absolute(path, backup) == OK, "Move the displayed record to its slot's backup.")
	_put(path, _record("alpha", "青原", 12, 120, 99))
	var new_hash := FileAccess.get_sha256(path)
	await _read(button)
	if not _expect(current_scene.scene_file_path == state.ESTATE_SCENE and state.campaign_id == "alpha"
		and state.current_day == 11 and state.money == 37, "The archive follows the displayed record into the backup."):
		return
	var notice: Label = current_scene.get_node("UI").hud.save_notice
	_expect(notice.visible and "备份" in notice.text and "第 11 天" in notice.text
		and FileAccess.get_sha256(backup) == old_hash and FileAccess.get_sha256(path) == new_hash,
		"The recovery notice identifies the original day and reading leaves both files untouched.")

func _archive_detects_changed_content() -> void:
	var title := await _open_title()
	title.archive_button.pressed.emit()
	var archive := title.get_node("SaveArchive") as Control
	var shown := _record_button(archive, "alpha", 12)
	if not shown:
		return
	var entry: Dictionary = state.latest_saved_game()
	_put(_slot("alpha"), _record("alpha", "青原", 12, 120, 909))
	_expect(state.load_saved_entry(entry) == ERR_ALREADY_IN_USE and current_scene == title and state.money == 37,
		"Equal campaign, date, scene and sequence cannot substitute for the displayed contents.")
	await _read(shown)
	if not _expect(current_scene == title and is_instance_valid(archive) and archive.visible and paused
		and archive.status.visible and state.money == 37, "A changed archive entry keeps the list open and paused."):
		return
	var refreshed := _record_button(archive, "alpha", 12)
	if refreshed:
		await _read(refreshed)
		_expect(state.current_day == 12 and state.money == 909 and current_scene.scene_file_path == state.ESTATE_SCENE,
			"Choosing the refreshed same-date record loads its actual money.")

func _title_refreshes_missing_record() -> void:
	var title := await _open_title()
	_expect("青原" in title.status.text and "第 12 天" in title.status.text, "The next continue offer shows day 12.")
	_put(_slot("alpha"), _record("alpha", "青原", 17, 145, 112))
	_put(_slot("beta"), _record("beta", "柳湾", 8, 160, 185))
	await _read(title.continue_button)
	if not _expect(current_scene == title and state.money == 909 and "柳湾" in title.status.text
		and "第 8 天" in title.status.text, "The missing selection refreshes the date and estate before another choice."):
		return
	await _read(title.continue_button)
	_expect(state.campaign_id == "beta" and state.current_day == 8 and state.money == 185,
		"The second Continue accepts the newly displayed estate.")

func _archive_refreshes_date_and_estates() -> void:
	var title := await _open_title()
	title.archive_button.pressed.emit()
	var archive := title.get_node("SaveArchive") as Control
	var shown := _record_button(archive, "alpha", 17)
	if not shown:
		return
	_put(_slot("alpha"), _record("alpha", "青原", 18, 165, 213))
	_put(_slot("gamma"), _record("gamma", "芦浦", 5, 180, 881))
	await _read(shown)
	if not _expect(current_scene == title and is_instance_valid(archive) and archive.visible and paused
		and state.money == 185 and archive.campaign_buttons.has("gamma".md5_text()),
		"A missing archive selection rebuilds the estate column without leaving the menu."):
		return
	var refreshed := _record_button(archive, "alpha", 18)
	if refreshed:
		await _read(refreshed)
		_expect(state.campaign_id == "alpha" and state.current_day == 18 and state.money == 213,
			"The updated date in the record column opens the corresponding checkpoint.")

func _legacy_without_sequence() -> void:
	var path: String = state.SAVE_PATH
	_put(path, {"current_day": 9, "money": 57})
	var entry: Dictionary = state.latest_saved_game()
	_expect(entry.path == path and entry.legacy and entry.sequence > 0, "The versionless file uses its legacy sequence.")
	_expect(DirAccess.rename_absolute(path, path + state.SAVE_BACKUP_SUFFIX) == OK, "Stage the old-format backup.")
	_put(path, {"current_day": 9, "money": 58})
	if _expect(state.load_saved_entry(entry) == OK, "A legacy save with no recorded sequence can still be selected."):
		await scene_changed
		_expect(state.campaign_id == "legacy" and state.current_day == 9 and state.money == 57
			and state.checkpoint_sequence == entry.sequence, "The legacy selection retains its original data and sequence.")

func _campaign_recovery() -> void:
	var manual := _slot("recover")
	_put(manual, _record("recover", "南津", 22, 198, 111))
	_put(_slot("recover", "autosave-1.json"), _record("recover", "南津", 26, 199, 112))
	_put(_slot("recover", "autosave-2.json"), _record("recover", "南津", 20, 201, 113))
	var ending := _record("recover", "南津", 20, 200, 114)
	ending.outcome = state.Outcome.DEFEAT_ESTATE
	_put(_slot("recover", "autosave-3.json"), ending)
	state.campaign_id = "recover"
	state.current_day = 24
	state.checkpoint_sequence = 200
	var entry: Dictionary = state.latest_saved_game(true)
	_expect(entry.get("path", "") == manual, "Recovery excludes other estates, endings, later days and later sequences.")
	if _expect(state.load_latest_game(true) == OK, "The current estate has an eligible recovery record."):
		await scene_changed
		_expect(state.campaign_id == "recover" and state.current_day == 22 and state.money == 111,
			"Recovery restores the eligible campaign checkpoint.")

func _outcome_selection(won: bool) -> void:
	var estate := current_scene
	var hud := estate.get_node("CampaignHUD")
	var id := "finished" if won else "defeated"
	var path := _slot(id)
	_put(path, _record(id, "南津", 32, 320, 64))
	state.campaign_id = id
	state.current_day = 35
	state.checkpoint_sequence = 350
	state.money = 77
	var outcome: int = state.Outcome.TRADITIONAL if won else state.Outcome.DEFEAT_ESTATE
	state.outcome = outcome
	if won:
		state.ending_record = {"outcome": outcome, "date": "第 35 天", "memories": [],
			"accounts": [{"label": "国库", "value": 1}]}
	hud._show_outcome(outcome, true)
	var panel: Control = hud.summary
	var restore := panel.find_child("RestoreCampaign", true, false) as Button
	if won:
		restore.pressed.emit()
		_expect(panel.restore_confirmation.visible and panel.stay_button.has_focus()
			and "第 32 天" in panel.restore_detail.text, "The ending confirmation names the selected checkpoint.")
	else:
		_expect("第 32 天" in panel.checkpoint.text and restore.has_focus(),
			"The defeat page names and focuses the selected recovery point.")
	_put(path, _record(id, "南津", 33, 330, 65))
	var confirm: Button = panel.load_before_ending if won else restore
	confirm.pressed.emit()
	if not _expect(current_scene == estate and paused and panel.visible and "变动" in hud.status.text
		and state.campaign_id == id and state.current_day == 35 and state.checkpoint_sequence == 350
		and state.money == 77 and state.outcome == outcome, "A changed checkpoint keeps the outcome page and state intact."):
		return
	if won:
		restore.pressed.emit()
		_expect(panel.restore_confirmation.visible and "第 33 天" in panel.restore_detail.text,
			"Another confirmation offers the refreshed day before accepting it.")
	else:
		_expect(not restore.disabled and restore.has_focus() and "第 33 天" in panel.checkpoint.text
			and "第 32 天" not in panel.checkpoint.text, "The defeat page offers the updated checkpoint for a new choice.")
	panel.free()
	hud.summary = null

func _run() -> void:
	state = root.get_node("Global")
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-") or state.has_saved_game():
		push_error("Use an empty isolated smoke profile for selected-save-reading.")
		quit(1)
		return
	paused = true
	scene_changed.connect(func(): paused = true)
	await _title_pins_campaign()
	await _archive_finds_backup()
	await _archive_detects_changed_content()
	await _title_refreshes_missing_record()
	await _archive_refreshes_date_and_estates()
	await _legacy_without_sequence()
	await _campaign_recovery()
	if not failed:
		_outcome_selection(false)
	if not failed:
		_outcome_selection(true)
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
