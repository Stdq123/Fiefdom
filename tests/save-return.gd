extends SceneTree

const ESTATE := "res://scenes/Main.tscn"
const TITLE := "res://scenes/Title.tscn"

var state: Node
var preferences: Node
var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _open_estate(campaign: String, day: int) -> void:
	paused = true
	state.campaign_id = campaign
	state.campaign_name = "存档确认样例"
	state.current_day = day
	state.day_progress = 0.45
	state.outcome = state.Outcome.RUNNING
	state.tax_reform_choice = state.TaxReformChoice.NONE
	state.ending_record.clear()
	change_scene_to_file(ESTATE)
	await scene_changed
	await process_frame

func _settings() -> Panel:
	var manager: Node = current_scene.get_node("UI").panel_manager
	manager.show_settings_panel()
	return manager.settings_panel_instance

func _prompt_from_settings(panel: Panel) -> ConfirmationDialog:
	for button: Button in panel.find_children("*", "Button", true, false):
		if button.text == "返回标题":
			button.pressed.emit()
			break
	return panel.get_node("TitleConfirmation")

func _present_ending(traditional: bool) -> Control:
	state.current_rank = state.Rank.DA_FU
	state.outcome = state.Outcome.TRADITIONAL if traditional else state.Outcome.REFORMED
	state.tax_reform_choice = state.TaxReformChoice.TRADITIONAL if traditional else state.TaxReformChoice.REFORMED
	state.ending_record = {
		"outcome": state.outcome, "date": "第 3 年 · 谷雨   第 %d 天 · 大夫" % state.current_day,
		"accounts": [{"label": "现有铜钱", "value": 325, "target": 300}],
		"memories": ["渠伯在木案上记下了今日的收成。"],
	}
	var hud := current_scene.get_node("CampaignHUD")
	hud._show_outcome(state.outcome)
	var ending: Control = hud.summary
	ending.skip_button.pressed.emit()
	return ending

func _blocked_write(path: String) -> String:
	var pending := "%s.%d.tmp" % [path, OS.get_process_id()]
	_expect(DirAccess.make_dir_recursive_absolute(pending) == OK, "Create an isolated block at the temporary save path.")
	return pending

func _wait_for_title() -> void:
	if current_scene == null or current_scene.scene_file_path != TITLE:
		await scene_changed
	_expect(current_scene.scene_file_path == TITLE and not paused, "Return to the actual unpaused title.")

func _regular_settings() -> void:
	await _open_estate("return-from-settings", 9)
	var panel := _settings()
	var dialog := _prompt_from_settings(panel)
	await process_frame
	_expect(dialog.visible and "本局尚无存档" in dialog.dialog_text and dialog.save_button.has_focus() and dialog.can_process(),
		"The menu explains that the estate has no record and focuses Save and Return.")
	var path: String = state.manual_save_path()
	dialog.save_button.pressed.emit()
	await _wait_for_title()
	var record: Dictionary = state.latest_campaign_save()
	_expect(FileAccess.file_exists(path) and record.get("day") == 9 and record.get("path") == path,
		"Save and Return writes the present day before opening the title.")
	_expect(current_scene.continue_button.text == "继续游戏", "The title offers the just-saved ordinary campaign.")
	print("SAVE_RETURN_SETTINGS")

func _failed_ending_save() -> void:
	await _open_estate("return-after-write-failure", 62)
	var path: String = state.manual_save_path()
	_expect(state.save_game() == OK, "Write the older manual record in the test profile.")
	var previous_hash := FileAccess.get_sha256(path)
	state.current_day = 65
	preferences.autosave = true
	var pending_auto := _blocked_write(path.get_base_dir().path_join("autosave-1.json"))
	var pending_manual := _blocked_write(path)
	var ending := _present_ending(true)
	_expect("结局自动保存失败" in ending.status.text and not ending.ending_saved, "Show the failed ending autosave.")
	ending.title_button.pressed.emit()
	var dialog := ending.get_node("TitleConfirmation") as ConfirmationDialog
	await process_frame
	_expect(dialog.visible and "第 62 天" in dialog.dialog_text and "结局尚未保存" in dialog.dialog_text,
		"The unsaved ending shows the actual older checkpoint before leaving.")
	dialog.save_button.pressed.emit()
	await process_frame
	_expect(dialog.visible and "保存失败" in dialog.dialog_text and dialog.save_button.has_focus()
		and current_scene.scene_file_path == ESTATE and paused and state.current_day == 65,
		"A failed retry leaves the record and its confirm dialog open at the same day.")
	_expect(FileAccess.get_sha256(path) == previous_hash and not ending.ending_saved, "A failed write keeps the previous record intact.")
	_expect(DirAccess.remove_absolute(pending_manual) == OK and DirAccess.remove_absolute(pending_auto) == OK,
		"Clear the empty files' temporary-path blockers.")
	dialog.save_button.pressed.emit()
	await _wait_for_title()
	var record: Dictionary = state.latest_campaign_save()
	_expect(record.get("day") == 65 and record.get("outcome") == state.Outcome.TRADITIONAL
		and current_scene.continue_button.text == "查看结算" and "守礼安邦" in current_scene.status.text,
		"Retry stores the completed route before the title reads the latest record.")
	print("SAVE_RETURN_RETRY")

func _cancel_and_leave() -> void:
	await _open_estate("return-without-writing", 59)
	preferences.autosave = false
	var ending := _present_ending(false)
	ending.title_button.pressed.emit()
	var dialog := ending.get_node("TitleConfirmation") as ConfirmationDialog
	_expect(dialog.visible and dialog.get_cancel_button().text == "留在结算", "Offer to stay when automatic saving is off.")
	dialog.get_cancel_button().pressed.emit()
	await process_frame
	_expect(not dialog.visible and ending.report.visible and paused and state.latest_campaign_save().is_empty(),
		"Staying returns to the report with the ending and files as they were.")
	ending.title_button.pressed.emit()
	dialog.get_ok_button().pressed.emit()
	await _wait_for_title()
	_expect(state.latest_campaign_save().is_empty(), "Direct Return does not write a record.")
	print("SAVE_RETURN_STAY_OR_LEAVE")

func _already_saved() -> void:
	await _open_estate("return-with-saved-ending", 63)
	preferences.autosave = true
	var ending := _present_ending(false)
	var entry: Dictionary = state.latest_campaign_save()
	_expect(ending.ending_saved and not entry.is_empty(), "Create a saved ending while automatic saving is enabled.")
	ending.title_button.pressed.emit()
	await _wait_for_title()
	_expect(state.latest_campaign_save() == entry and current_scene.continue_button.text == "查看结算"
		and "税亩富民" in current_scene.status.text, "A saved ending returns directly without a second save.")
	await _open_estate("return-with-saved-ending", 64)
	var dialog := _prompt_from_settings(_settings())
	_expect(dialog.visible and "结局自动存档 · 第 63 天" in dialog.dialog_text,
		"The saved ending still counts as the last record when preparing to leave the estate.")
	dialog.get_ok_button().pressed.emit()
	await _wait_for_title()
	_expect(state.latest_campaign_save() == entry, "Leaving the later unsaved state preserves the saved ending.")
	print("SAVE_RETURN_ALREADY_SAVED")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run save-return only in an isolated smoke profile.")
		quit(1)
		return
	state = root.get_node("Global")
	preferences = root.get_node("Preferences")
	await _regular_settings()
	await _failed_ending_save()
	await _cancel_and_leave()
	await _already_saved()
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
