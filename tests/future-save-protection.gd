extends SceneTree

var state: Node
var failed := false
var left_session := false

func _initialize() -> void:
	_run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _fixture(campaign: String) -> String:
	state.campaign_id = campaign
	state.campaign_name = campaign
	state.current_day = 50
	state.checkpoint_sequence = 25
	var path: String = state.manual_save_path()
	_expect(DirAccess.make_dir_recursive_absolute(path.get_base_dir()) == OK, "Create the fixture campaign directory.")
	return path

func _put(path: String, version: int, sequence: int, header_only := false) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "Open the isolated save fixture.")
	if file:
		var data := {"save_version": version, "campaign_name": state.campaign_name}
		if not header_only:
			data.merge({"current_day": sequence, "save_sequence": sequence, "campaign_id": state.campaign_id})
		_expect(file.store_string(JSON.stringify(data)), "Write the fixture to its original slot.")
		file.close()

func _hashes(paths: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for path in paths:
		result.append(FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "")
		var backup: String = path + state.SAVE_BACKUP_SUFFIX
		result.append(FileAccess.get_sha256(backup) if FileAccess.file_exists(backup) else "")
	return result

func _manual() -> void:
	var path := _fixture("future-manual")
	var backup: String = path + state.SAVE_BACKUP_SUFFIX
	var supported: int = state.SAVE_VERSION
	var future := supported + 1
	# Negative versions here mean that side of the fixture is absent.
	for versions: Array in [[-1, future], [future, -1], [future, supported], [supported, future], [future, future]]:
		for side: int in range(2):
			var file_path := path if side == 0 else backup
			if versions[side] >= 0:
				_put(file_path, versions[side], 20 - side, versions[0] == -1)
			elif FileAccess.file_exists(file_path):
				_expect(DirAccess.remove_absolute(file_path) == OK, "Stage the missing side of the fixture.")
		var before := _hashes([path])
		var catalog: Array = state.saved_games()
		if catalog.size() != 1:
			_expect(false, "A logical slot protected on either side must appear exactly once.")
			return
		_expect(catalog[0].required_version == future, "A protected slot keeps the required newer version.")
		if supported in versions:
			var use_backup: bool = versions[1] == supported
			_expect(catalog[0].error == OK and catalog[0].from_backup == use_backup
				and catalog[0].day == (19 if use_backup else 20),
				"Only the supported side supplies the mixed slot's readable day and backup marker.")
		else:
			_expect(catalog[0].error == ERR_FILE_UNRECOGNIZED and state.load_game(path) == ERR_FILE_UNRECOGNIZED
				and state.load_latest_game() == ERR_FILE_UNRECOGNIZED,
				"Loading the slot or the fully newer catalog reports an unsupported version.")
		_expect(state.save_game() == ERR_FILE_UNRECOGNIZED and state.checkpoint_sequence == 25,
			"A newer primary or backup prevents the manual save without advancing its sequence.")
		_expect(_hashes([path]) == before and not FileAccess.file_exists("%s.%d.tmp" % [path, OS.get_process_id()]),
			"Both sides of the protected logical slot keep their original bytes and no pending file remains.")

	_expect(DirAccess.remove_absolute(path) == OK, "Stage a lone damaged backup.")
	_put(backup, -1, 21)
	var damaged: Dictionary = state.saved_games()[0]
	_expect(damaged.from_backup and damaged.error == ERR_FILE_CORRUPT and damaged.required_version == 0,
		"A damaged backup is reported at its own file, separate from newer-format protection.")
	_put(path, supported, 22)
	_put(backup, supported, 21)
	var original := FileAccess.get_sha256(path)
	_expect(state.save_game() == OK and state.checkpoint_sequence > 25, "A supported manual slot remains writable.")
	_expect(FileAccess.get_sha256(backup) == original and _stored_day(path) == 50,
		"The old primary becomes the backup and the new day becomes primary.")

func _stored_day(path: String) -> int:
	var snapshot: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return int(snapshot.current_day) if snapshot is Dictionary else -1

func _save_before_leaving() -> void:
	var path := _fixture("future-on-exit")
	_put(path, state.SAVE_VERSION + 1, 71)
	_put(path + state.SAVE_BACKUP_SUFFIX, state.SAVE_VERSION, 45)
	var before := _hashes([path])
	for exit_game: bool in [false, true]:
		var dialog: ConfirmationDialog = load("res://scripts/ReturnToTitleDialog.gd").new()
		dialog.exits_game = exit_game
		dialog.save_progress = state.save_game
		dialog.return_requested.connect(func(): left_session = true)
		root.add_child(dialog)
		dialog.ask("保留这次进度吗？")
		await process_frame
		dialog.save_button.pressed.emit()
		await process_frame
		_expect(dialog.visible and not left_session and dialog.get_cancel_button().has_focus()
			and "新版存档" in dialog.dialog_text and "保存失败" in dialog.dialog_text,
			"A protected save keeps the return or quit dialog open with focus on staying.")
		_expect(_hashes([path]) == before and state.checkpoint_sequence == 25,
			"Trying to save before leaving preserves both files and the committed checkpoint.")
		dialog.free()

func _automatic() -> void:
	var manual := _fixture("future-automatic")
	var slots: PackedStringArray = state._campaign_auto_slots(manual.get_base_dir())
	var supported: int = state.SAVE_VERSION
	var future := supported + 1
	_put(slots[0], supported, 7)
	_put(slots[0] + state.SAVE_BACKUP_SUFFIX, future, 6)
	_put(slots[1], supported, 14)
	var oldest_protected := _hashes([slots[0]])
	var oldest_usable := FileAccess.get_sha256(slots[1])
	_expect(state.save_automatically("dawn") == OK and _stored_day(slots[2]) == 50,
		"An empty auto slot takes precedence over the older existing slots.")
	_expect(_hashes([slots[0]]) == oldest_protected and FileAccess.get_sha256(slots[1]) == oldest_usable,
		"Filling the empty slot preserves the other two records.")
	var newest := _hashes([slots[2]])
	state.current_day = 51
	_expect(state.save_automatically("dawn") == OK and _stored_day(slots[1]) == 51,
		"When full, the oldest writable slot rotates even though a protected slot is older.")
	_expect(FileAccess.get_sha256(slots[1] + state.SAVE_BACKUP_SUFFIX) == oldest_usable
		and _hashes([slots[0]]) == oldest_protected and _hashes([slots[2]]) == newest,
		"Rotation only updates the chosen slot and preserves its preceding record.")

	_put(slots[1], future, 40)
	_put(slots[2], future, 33)
	_put(slots[2] + state.SAVE_BACKUP_SUFFIX, future + 1, 32)
	var before := _hashes(slots)
	var sequence: int = state.checkpoint_sequence
	_expect(state.save_automatically("dawn") == ERR_FILE_UNRECOGNIZED and state.checkpoint_sequence == sequence,
		"Three protected automatic slots refuse the write and keep the last committed sequence.")
	_expect(_hashes(slots) == before and not FileAccess.file_exists(manual),
		"A refused automatic save preserves all six files and does not spill into the manual slot.")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run future-save-protection in an isolated smoke profile.")
		quit(1)
		return
	paused = true
	state = root.get_node("Global")
	if state.has_saved_game():
		push_error("Use an empty save profile for the future-only catalog check.")
		quit(1)
		return
	root.get_node("Preferences").autosave = true
	_manual()
	_automatic()
	await _save_before_leaving()
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
