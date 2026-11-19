extends SceneTree

const TITLE := "res://scenes/Title.tscn"
const ESTATE := "res://scenes/Main.tscn"

var state: Node
var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _expect(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error(detail)

func _put(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "Open isolated fixture file.")
	if file:
		_expect(file.store_string(contents), "Write isolated fixture file.")
		file.close()

func _campaign(key: String, day: int) -> void:
	state.campaign_id = key
	state.campaign_name = "归档样例"
	state.current_day = day
	state.day_progress = 0.45
	state.outcome = state.Outcome.RUNNING

func _open_title() -> void:
	_expect(change_scene_to_file(TITLE) == OK, "Open the actual title.")
	await scene_changed
	await process_frame

func _interrupt_manual_write() -> void:
	_campaign("interrupted-save", 62)
	state.money = 119
	_expect(state.save_game() == OK, "Write the original manual record.")
	var slot: String = state.manual_save_path()
	var backup := slot + ".bak"
	var original := FileAccess.get_sha256(slot)
	state.current_day = 64
	state.money = 184
	_expect(state.save_game() == OK, "Replace the old manual record.")
	_expect(FileAccess.get_sha256(backup) == original and state.saved_games().size() == 1
		and not state.latest_campaign_save().from_backup, "A usable primary is listed once, while its previous version is kept.")
	var good := FileAccess.get_sha256(slot)
	var sequence: int = state.checkpoint_sequence
	var pending := "%s.%d.tmp" % [slot, OS.get_process_id()]
	_put(pending, "stage")
	var held := FileAccess.open(pending, FileAccess.READ)
	_expect(held != null, "Hold the Windows temp file open so promotion fails after rotating the old record.")
	state.current_day = 65
	state.money = 225
	_expect(state.save_game() != OK, "Report the actual promotion failure.")
	held.close()
	_expect(not FileAccess.file_exists(slot) and FileAccess.get_sha256(backup) == good
		and FileAccess.file_exists(pending) and state.checkpoint_sequence == sequence,
		"The preceding checkpoint stays intact and the failed update never advances the committed sequence.")
	await _open_title()
	_expect(state.has_saved_game() and current_scene.continue_button.visible and "备份 · 手动存档 · 第 64 天" in current_scene.status.text,
		"The title finds the prior manual record, instead of promoting the temporary file.")
	current_scene.continue_button.pressed.emit()
	await scene_changed
	var notice: Label = current_scene.get_node("UI").hud.save_notice
	_expect(state.current_day == 64 and state.money == 184 and notice.visible and notice.text == "已从备份恢复第 64 天",
		"Continue from the title recovers the same stable day and names it in the HUD.")
	_expect(current_scene.scene_file_path == ESTATE and FileAccess.get_sha256(backup) == good,
		"Reading the backup resumes the estate and leaves the backup alone.")
	_put(slot, JSON.stringify({"current_day": 99, "active_crops": []}))
	var recovered: Dictionary = state.latest_campaign_save()
	_expect(recovered.from_backup and recovered.day == 64, "A valid JSON header with a broken payload also uses the backup.")
	state.current_day = 66
	_expect(state.save_game() == OK and state.latest_campaign_save().day == 66
		and not state.latest_campaign_save().from_backup and FileAccess.get_sha256(backup) == good,
		"Saving again repairs the slot without moving the broken payload onto the usable backup.")
	print("SAVE_RECOVERY_MANUAL")

func _check_rotation() -> void:
	_campaign("rotating-save", 10)
	root.get_node("Preferences").autosave = true
	for day in range(10, 14):
		state.current_day = day
		_expect(state.save_automatically("dawn") == OK, "Write a fixture day into the actual rotation.")
	var newest: Dictionary = state.latest_campaign_save()
	var slot: String = newest.path
	var backup := slot + ".bak"
	_expect(newest.day == 13 and state.saved_games().size() == 4 and FileAccess.file_exists(backup),
		"The rotation exposes exactly three automatic slots in addition to the earlier manual record.")
	_put(slot, "{")
	var prior_auto: Array = state.saved_games().filter(func(entry: Dictionary) -> bool: return entry.path == slot)
	_expect(prior_auto.size() == 1 and prior_auto[0].from_backup and prior_auto[0].day == 10
		and prior_auto[0].source == "晨间自动存档" and state.latest_campaign_save().day == 12,
		"A damaged automatic slot recovers its own preceding version without hiding newer healthy slots.")
	print("SAVE_RECOVERY_ROTATION")

func _check_legacy() -> void:
	_campaign("absent-local-slot", 8)
	_put("user://savegame.json.bak", JSON.stringify({"current_day": 7, "money": 37}))
	_expect(state.load_game() == OK and state.campaign_id == "legacy" and state.current_day == 7 and state.money == 37,
		"A backup of a versionless legacy save loads through the old manual path.")
	await scene_changed
	print("SAVE_RECOVERY_LEGACY")

func _check_market() -> void:
	_campaign("market-restore", 4)
	var path: String = state.manual_save_path()
	_expect(DirAccess.make_dir_recursive_absolute(path.get_base_dir()) == OK, "Create the isolated market slot.")
	_put(path + ".bak", JSON.stringify({"current_day": 3, "location": "west_market", "campaign_id": state.campaign_id}))
	_expect(state.load_game(path) == OK, "Load a market save using its normal logical slot.")
	await scene_changed
	await process_frame
	var hud := current_scene.get_node("CampaignHUD")
	_expect(current_scene.scene_file_path == state.WEST_MARKET_SCENE and hud.notice.text == "已从备份恢复第 3 天"
		and hud.notice.is_visible_in_tree(), "The same recovery date is visible outside the home estate.")
	print("SAVE_RECOVERY_MARKET")

func _check_lock() -> void:
	_campaign("locked-save", 4)
	var guard: RefCounted = load("res://scripts/SaveWriteLock.gd").new()
	_expect(guard.acquire() == OK, "Take the native write guard.")
	_expect(state.save_game() == ERR_BUSY and state.latest_campaign_save().is_empty(),
		"A second writer cannot create a slot while the owner handle is open.")
	guard.release()
	_expect(state.save_game() == OK and state.latest_campaign_save().day == 4,
		"Closing the owner handle allows the next write without touching its guard directory manually.")
	print("SAVE_RECOVERY_LOCK")

func _run() -> void:
	if OS.get_name() != "Windows" or not ProjectSettings.globalize_path("user://").contains("fiefdom-smoke-"):
		push_error("Run save-recovery with Windows and an isolated smoke profile.")
		quit(1)
		return
	paused = true
	state = root.get_node("Global")
	await _interrupt_manual_write()
	_check_rotation()
	await _check_legacy()
	await _check_market()
	_check_lock()
	if not failed:
		print("SCENARIO_OK")
	quit(1 if failed else 0)
