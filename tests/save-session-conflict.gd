extends SceneTree

var game: Node
var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		failed = true
		push_error(message)
	return condition

func _write_from_another_instance(path: String, day: int, coins: int, origin := "manual") -> bool:
	var output: Array = []
	var result := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), "--quit-after", "1200",
		"--script", "res://tests/save-session-conflict.gd", "--", "write", path, str(day), str(coins), origin,
	]), output, true)
	print("SECOND_INSTANCE ", output[0] if not output.is_empty() else result)
	return _expect(result == 0 and not output.is_empty() and "WRITER_SAVED" in str(output[0]),
		"The second Windows process must commit its save and exit before the first writes.")

func _record(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

func _check_stale_session() -> void:
	game.campaign_name = "青原"
	game.current_day = 16
	game.money = 63
	if not _expect(game.save_game() == OK, "Create a checkpoint that both processes can load."):
		return
	var path: String = game.manual_save_path()
	if not _expect(game.load_game(path) == OK, "The first instance loads the common checkpoint."):
		return
	await scene_changed
	if not _write_from_another_instance(path, 24, 87):
		return
	var primary := FileAccess.get_sha256(path)
	var backup_path: String = path + game.SAVE_BACKUP_SUFFIX
	var backup := FileAccess.get_sha256(backup_path)
	var sequence: int = game.checkpoint_sequence
	game.current_day = 17
	game.money = 67
	var first: int = game.save_game()
	game.current_day = 18
	game.money = 69
	var second: int = game.save_game()
	print("SAVE_CONFLICT_RESULTS first=%d second=%d primary_day=%s backup_day=%s" % [
		first, second, _record(path).get("current_day"), _record(backup_path).get("current_day"),
	])
	if not _expect(first == ERR_ALREADY_IN_USE and second == ERR_ALREADY_IN_USE,
			"The older session must refuse to replace the newer checkpoint on either attempt."):
		return
	_expect(FileAccess.get_sha256(path) == primary and FileAccess.get_sha256(backup_path) == backup
		and game.checkpoint_sequence == sequence and game.current_day == 18 and game.money == 69,
		"A refused write preserves both disk records, the checkpoint sequence and the live session.")

	var settings: Panel = current_scene.get_node("UI").panel_manager.settings_panel_instance
	settings.show()
	settings.save_button.pressed.emit()
	if not _expect("另存" in settings.save_button.text and "存档已更新" in settings.save_status.text
			and FileAccess.get_sha256(path) == primary, "Settings offers a copy after a refused save."):
		return
	var original_id: String = game.campaign_id
	settings.save_button.pressed.emit()
	var copy: String = game.manual_save_path()
	var saved := _record(copy)
	if not _expect(game.campaign_id != original_id and saved.get("campaign_id") == game.campaign_id
			and saved.get("current_day") == 18 and saved.get("money") == 69 and "副本" in game.campaign_name
			and "已另存" in settings.save_status.text, "Saving a copy preserves the unsaved progress on a separate estate."):
		return
	_expect(FileAccess.get_sha256(path) == primary and FileAccess.get_sha256(backup_path) == backup,
		"Saving a copy preserves both records in the original estate.")
	settings.hide()

	if not _write_from_another_instance(path, 25, 91):
		return
	root.get_node("Preferences").autosave = true
	game.current_day = 19
	_expect(game.save_automatically("dawn") == OK, "A write to another estate cannot block this estate's autosaves.")
	var older: Dictionary = game.saved_games().filter(func(entry: Dictionary) -> bool: return entry.path == copy)[0]
	if not _expect(game.load_saved_entry(older) == OK, "Select an older checkpoint after its estate's newer autosave is already listed."):
		return
	await scene_changed
	_expect(game.current_day == 18 and game.money == 69 and game.save_game() == OK,
		"Intentionally loading an older checkpoint permits ordinary saving.")
	print("SAVE_CONFLICT_COPY copy_day=", _record(copy).current_day, " original_day=", _record(path).current_day)

func _check_autosave_and_return() -> void:
	var path: String = game.manual_save_path()
	var listed: Dictionary = game.latest_campaign_save()
	if not _write_from_another_instance(path, 20, 101, "dawn"):
		return
	var replacement: Dictionary = game.latest_campaign_save()
	var autosave_path: String = replacement.path
	var auto_hash := FileAccess.get_sha256(autosave_path)
	if not _expect(autosave_path != path and game.load_saved_entry(listed) == OK,
			"Load what was shown before the other instance wrote to a different slot."):
		return
	await scene_changed
	root.get_node("Preferences").autosave = true
	_expect(game.save_automatically("dawn") == ERR_ALREADY_IN_USE and FileAccess.get_sha256(autosave_path) == auto_hash,
		"An autosave in a different slot of the same estate pauses this session's writes.")
	var ui := current_scene.get_node("UI")
	_expect("自动保存暂停" in ui.hud.save_notice.text, "The game HUD shows how to keep the current progress.")

	var settings: Panel = ui.panel_manager.settings_panel_instance
	settings.show()
	_expect(settings.save_button.text == "另存为封地副本",
		"The automatic conflict prepares the copy action before the player opens Settings.")
	var dialog := settings.get_node("TitleConfirmation") as ConfirmationDialog
	dialog.ask("返回标题前保留当前进度。")
	await process_frame
	dialog.save_button.pressed.emit()
	if not _expect(dialog.visible and dialog.get_cancel_button().has_focus()
			and dialog.save_button.text == "另存副本并返回" and "存档已更新" in dialog.dialog_text
			and current_scene.scene_file_path == game.ESTATE_SCENE, "A refused save keeps the return dialog open."):
		return
	dialog.save_button.pressed.emit()
	for frame in range(5):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path == game.TITLE_SCENE:
			break
	_expect(is_instance_valid(current_scene) and current_scene.scene_file_path == game.TITLE_SCENE
		and game.manual_save_path() != path
		and _record(game.manual_save_path()).get("money") == 69 and FileAccess.get_sha256(autosave_path) == auto_hash,
		"Explicitly saving a copy returns to the title with the original autosave still intact.")

func _check_ending_copy() -> void:
	var path: String = game.manual_save_path()
	if not _expect(game.load_game(path) == OK, "Load the copied estate for a fixed outcome report."):
		return
	await scene_changed
	if not _write_from_another_instance(path, 30, 105):
		return
	var hash := FileAccess.get_sha256(path)
	game.outcome = game.Outcome.TRADITIONAL
	game.ending_record = {"outcome": game.outcome, "date": "第 18 天", "memories": [],
		"accounts": [{"label": "国库", "value": 1}]}
	var hud := current_scene.get_node("CampaignHUD")
	hud._show_outcome(game.outcome, true)
	var ending: Control = hud.summary
	ending.ending_saved = false
	ending.save_button.pressed.emit()
	if not _expect(ending.save_button.text == "另存结局副本" and not ending.ending_saved,
			"A conflict leaves the outcome report available to save separately."):
		return
	ending.save_button.pressed.emit()
	var entry: Dictionary = game.latest_campaign_save()
	_expect(ending.ending_saved and ending.estate_name.text == game.campaign_name
		and entry.get("outcome") == game.Outcome.TRADITIONAL and entry.get("path") != path
		and paused and FileAccess.get_sha256(path) == hash, "The copied ending remains readable as its own result.")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run the save-session check with an isolated smoke profile.")
		quit(1)
		return
	paused = true
	game = root.get_node("Global")
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0] == "write":
		if not _expect(args.size() == 5, "The isolated writer needs a path, day, purse and save origin."):
			quit(1)
			return
		if not _expect(game.load_game(args[1]) == OK, "The second instance must load the fixture."):
			quit(1)
			return
		await scene_changed
		game.current_day = args[2].to_int()
		game.money = args[3].to_int()
		root.get_node("Preferences").autosave = true
		var result: int = game.save_game() if args[4] == "manual" else game.save_automatically(args[4])
		if _expect(result == OK, "The second instance must complete its save."):
			print("WRITER_SAVED day=%d coins=%d pid=%d" % [game.current_day, game.money, OS.get_process_id()])
	else:
		await _check_stale_session()
		if not failed:
			await _check_autosave_and_return()
		if not failed:
			await _check_ending_copy()
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
